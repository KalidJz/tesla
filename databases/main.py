import os
import json
from datetime import datetime
from typing import Optional
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
                    humedad DOUBLE PRECISION,
                    presion DOUBLE PRECISION,
                    distancia DOUBLE PRECISION,
                    modo VARCHAR(30),
                    timestamp TIMESTAMP DEFAULT NOW()
                );
            """)
            # Agrega columnas nuevas si la tabla ya existía en Render
            cursor.execute("ALTER TABLE mediciones ADD COLUMN IF NOT EXISTS humedad DOUBLE PRECISION;")
            cursor.execute("ALTER TABLE mediciones ADD COLUMN IF NOT EXISTS distancia DOUBLE PRECISION;")
            cursor.execute("ALTER TABLE mediciones ADD COLUMN IF NOT EXISTS modo VARCHAR(30);")

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS robot_status (
                    robot_id VARCHAR(100) PRIMARY KEY,
                    latitud DOUBLE PRECISION,
                    longitud DOUBLE PRECISION,
                    ultima_conexion TIMESTAMP DEFAULT NOW()
                );
            """)
        conn.commit()
        print("[DB] Tablas verificadas correctamente.")
    except Exception as e:
        print(f"[DB] Error inicializando tablas: {e}")
    finally:
        conn.close()

# ============================================================================
# GESTOR MQTT (NUEVOS TÓPICOS DEL GATEWAY)
# ============================================================================
MQTT_BROKER = "broker.hivemq.com"
MQTT_PORT = 1883
TOPIC_TEL = "ucol/entornos/rover/telemetria"
TOPIC_CMD = "ucol/entornos/rover/comandos"

# Caché en memoria con la última telemetría recibida
latest_telemetry = {
    "online": False,
    "t": 0.0,
    "h": 0.0,
    "p": 0.0,
    "d": -1,
    "lat": 0.0,
    "lng": 0.0,
    "m": "manual",
    "updated_at": None,
}

def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] Conectado al Broker con código: {rc}")
    client.subscribe(TOPIC_TEL)

def on_message(client, userdata, msg):
    raw_payload = msg.payload.decode("utf-8", errors="ignore").strip()
    try:
        data = json.loads(raw_payload)
        robot_id = "ESP32-ROBOT-01"

        t = float(data.get("t", 0.0))
        h = float(data.get("h", 0.0))
        p = float(data.get("p", 0.0))
        d = float(data.get("d", -1))
        lat = float(data.get("lat", 0.0))
        lng = float(data.get("lng", 0.0))
        modo = str(data.get("m", "manual"))

        latest_telemetry.update({
            "online": True,
            "t": t,
            "h": h,
            "p": p,
            "d": d,
            "lat": lat,
            "lng": lng,
            "m": modo,
            "updated_at": datetime.utcnow().isoformat(),
        })

        conn = get_db()
        with conn.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO mediciones (robot_id, temperatura, humedad, presion, distancia, modo, timestamp)
                VALUES (%s, %s, %s, %s, %s, %s, NOW());
                """,
                (robot_id, t, h, p, d, modo)
            )
            if lat != 0.0 or lng != 0.0:
                cursor.execute(
                    """
                    INSERT INTO robot_status (robot_id, latitud, longitud, ultima_conexion)
                    VALUES (%s, %s, %s, NOW())
                    ON CONFLICT (robot_id) DO UPDATE
                    SET latitud = EXCLUDED.latitud,
                        longitud = EXCLUDED.longitud,
                        ultima_conexion = NOW();
                    """,
                    (robot_id, lat, lng)
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
    robot_id: str = "ESP32-ROBOT-01"
    comando: str
    modo: str  # "manual", "linea", "automatico"
    velocidad: Optional[int] = None  # 0 a 100 (%)
    lat: Optional[float] = None
    lng: Optional[float] = None

# ============================================================================
# ENDPOINTS REST
# ============================================================================
@app.get("/")
def health_check():
    return {"status": "online", "service": "Robot Control API"}

@app.get("/api/robot/telemetry")
def get_telemetry():
    """Devuelve la última lectura recibida por MQTT desde el Gateway"""
    return latest_telemetry

@app.get("/api/robot/history")
def get_history(limit: int = 50):
    """Devuelve los últimos registros almacenados en la tabla mediciones"""
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT id, robot_id, temperatura, humedad, presion, distancia, modo, timestamp
                FROM mediciones
                ORDER BY timestamp DESC
                LIMIT %s;
                """,
                (min(limit, 200),)
            )
            rows = cursor.fetchall()
            for r in rows:
                if r.get("timestamp"):
                    r["timestamp"] = r["timestamp"].isoformat()
        return {"count": len(rows), "data": rows}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

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
    """Recibe comandos desde Flutter y los publica en el tópico del Gateway"""
    if mqtt_client is None:
        raise HTTPException(status_code=503, detail="Cliente MQTT no inicializado")

    payload_dict = {
        "modo": cmd.modo,
        "comando": cmd.comando,
    }
    if cmd.velocidad is not None:
        payload_dict["velocidad"] = max(0, min(100, cmd.velocidad))
    if cmd.lat is not None and cmd.lng is not None:
        payload_dict["lat"] = cmd.lat
        payload_dict["lng"] = cmd.lng

    try:
        mqtt_client.publish(TOPIC_CMD, json.dumps(payload_dict))
        return {"status": "success", "payload": payload_dict}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error MQTT: {e}")