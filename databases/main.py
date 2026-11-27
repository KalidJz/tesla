import os
import json
from datetime import datetime
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
import paho.mqtt.client as mqtt

# ============================================================================
# CONFIGURACIÓN BASE DE DATOS (POSTGRESQL EN RENDER)
# ============================================================================
DATABASE_URL = os.getenv("DATABASE_URL")
if DATABASE_URL and DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql://", 1)

def get_db():
    if not DATABASE_URL:
        raise RuntimeError("Falta la variable de entorno DATABASE_URL")
    return psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)

def init_db():
    """Crea las tablas automáticamente si la base de datos está vacía."""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id_user SERIAL PRIMARY KEY,
                    nombre VARCHAR(100) NOT NULL,
                    email VARCHAR(150) UNIQUE NOT NULL,
                    password VARCHAR(255) NOT NULL,
                    rol VARCHAR(50) DEFAULT 'Usuario',
                    created_at TIMESTAMP DEFAULT NOW()
                );
            """)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS mediciones (
                    id SERIAL PRIMARY KEY,
                    robot_id VARCHAR(100) NOT NULL,
                    temperatura DOUBLE PRECISION,
                    presion DOUBLE PRECISION,
                    timestamp TIMESTAMP DEFAULT NOW()
                );
            """)
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS robot_status (
                    robot_id VARCHAR(100) PRIMARY KEY,
                    latitud DOUBLE PRECISION,
                    longitud DOUBLE PRECISION,
                    ultima_conexion TIMESTAMP DEFAULT NOW()
                );
            """)
        conn.commit()
        print("[DB] Tablas verificadas/creadas correctamente.")
    except Exception as e:
        print(f"[DB] Error inicializando tablas: {e}")
    finally:
        conn.close()

def to_json(row: dict) -> dict:
    if row is None:
        return None
    out = {}
    for k, v in row.items():
        if isinstance(v, datetime):
            out[k] = v.isoformat()
        elif hasattr(v, "as_tuple"):
            out[k] = float(v)
        else:
            out[k] = v
    return out

# ============================================================================
# GESTOR MQTT (CLIENTE Y CALLBACKS DEL GATEWAY)
# ============================================================================
MQTT_BROKER = "broker.hivemq.com"
MQTT_PORT = 1883

def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] Conectado al Broker con código: {rc}")
    client.subscribe("robot/+/telemetry")
    client.subscribe("robot/+/gps")

def on_message(client, userdata, msg):
    topic = msg.topic
    raw_payload = msg.payload.decode("utf-8", errors="ignore").strip()

    try:
        data = json.loads(raw_payload)
        robot_id = topic.split("/")[1]

        conn = get_db()
        with conn.cursor() as cursor:
            if "telemetry" in topic:
                cursor.execute(
                    """
                    INSERT INTO mediciones (robot_id, temperatura, presion, timestamp)
                    VALUES (%s, %s, %s, NOW());
                    """,
                    (robot_id, float(data.get("temperatura", 0)), float(data.get("presion", 0)))
                )
            elif "gps" in topic:
                cursor.execute(
                    """
                    INSERT INTO robot_status (robot_id, latitud, longitud, ultima_conexion)
                    VALUES (%s, %s, %s, NOW())
                    ON CONFLICT (robot_id) DO UPDATE
                    SET latitud = EXCLUDED.latitud,
                        longitud = EXCLUDED.longitud,
                        ultima_conexion = NOW();
                    """,
                    (robot_id, float(data.get("lat", 0)), float(data.get("lng", 0)))
                )
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"[MQTT] Error procesando telemetría: {e}")

mqtt_client = None
try:
    mqtt_client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message
    mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
    mqtt_client.loop_start()
except Exception as e:
    print(f"[MQTT] Error iniciando cliente: {e}")

# ============================================================================
# FASTAPI APP Y MIDDLEWARE
# ============================================================================
app = FastAPI(title="Robot Control API - PostgreSQL")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup_event():
    init_db()

# ============================================================================
# MODELOS PYDANTIC
# ============================================================================
class RegisterRequest(BaseModel):
    nombre: str
    email: str
    password: str

class LoginRequest(BaseModel):
    email: str
    password: str

class CommandRequest(BaseModel):
    robot_id: str
    comando: str
    modo: str

# ============================================================================
# ENDPOINTS REST
# ============================================================================
@app.get("/")
def health_check():
    return {"status": "online", "service": "Robot Control API"}

@app.post("/api/register", status_code=201)
def register(user: RegisterRequest):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id_user FROM users WHERE email = %s;", (user.email,))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="El correo ya está registrado")

            cursor.execute(
                """
                INSERT INTO users (nombre, email, password, rol, created_at)
                VALUES (%s, %s, %s, 'Usuario', NOW());
                """,
                (user.nombre, user.email, user.password)
            )
        conn.commit()
        return {"message": "Registro exitoso"}
    except HTTPException:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/api/login")
def login(credentials: LoginRequest):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT id_user, nombre, email, password, rol FROM users WHERE email = %s;",
                (credentials.email,)
            )
            user = cursor.fetchone()

            if not user or user["password"] != credentials.password:
                raise HTTPException(status_code=401, detail="Correo o contraseña incorrectos")

        return {
            "user": {
                "id": user["id_user"],
                "nombre": user["nombre"],
                "email": user["email"],
                "rol": user["rol"],
            }
        }
    finally:
        conn.close()

@app.post("/api/robot/command")
def send_command(cmd: CommandRequest):
    """Recibe comandos desde la UI de Flutter (Joystick) y los manda por MQTT al Gateway"""
    if mqtt_client is None:
        raise HTTPException(status_code=503, detail="Cliente MQTT no inicializado")

    topic = f"robot/{cmd.robot_id}/command"
    payload = json.dumps({"comando": cmd.comando, "modo": cmd.modo})

    try:
        mqtt_client.publish(topic, payload)
        return {"status": "success", "message": f"Comando '{cmd.comando}' enviado al robot {cmd.robot_id}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error MQTT: {e}")