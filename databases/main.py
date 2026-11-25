from datetime import datetime
from typing import Optional
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pymysql
import paho.mqtt.client as mqtt
import json


class RegisterRequest(BaseModel):
    nombre: str
    email: str
    password: str

# ============================================================================
# CONFIGURACIÓN BASE DE DATOS Y CONSTANTES (LARAGON)
# ============================================================================
DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "password": "",
    "database": "control_robot_db",
    "cursorclass": pymysql.cursors.DictCursor,
}

def get_db():
    return pymysql.connect(**DB_CONFIG)

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
MQTT_BROKER = "broker.hivemq.com" # O tu broker local/IP si usas Mosquitto en Laragon
MQTT_PORT = 1883

def on_connect(client, userdata, flags, rc):
    print(f"[MQTT] Conectado al Broker con código: {rc}")
    # Suscripciones a los tópicos del robot
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
                # Datos del BMP280 vía LoRa -> MQTT
                cursor.execute(
                    """
                    INSERT INTO mediciones (robot_id, temperatura, presion, timestamp)
                    VALUES (%s, %s, %s, NOW());
                    """,
                    (robot_id, float(data.get("temperatura", 0)), float(data.get("presion", 0)))
                )
            elif "gps" in topic:
                # Coordenadas del módulo GPS
                cursor.execute(
                    """
                    UPDATE robot_status 
                    SET latitud = %s, longitud = %s, ultima_conexion = NOW()
                    WHERE robot_id = %s;
                    """,
                    (float(data.get("lat", 0)), float(data.get("lng", 0)), robot_id)
                )
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"[MQTT] Error procesando telemetría: {e}")

try:
    mqtt_client = mqtt.Client()
    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message
    mqtt_client.connect(MQTT_BROKER, MQTT_PORT, 60)
    mqtt_client.loop_start()
except Exception as e:
    print(f"[MQTT] Error iniciando cliente: {e}")

# ============================================================================
# FASTAPI APP Y MIDDLEWARE
# ============================================================================
app = FastAPI(title="Robot Control API - MariaDB")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# MODELOS PYDANTIC
# ============================================================================
class LoginRequest(BaseModel):
    email: str
    password: str

class CommandRequest(BaseModel):
    robot_id: str
    comando: str # Ej: "adelante", "atras", "stop"
    modo: str # "manual" o "automatico"

# ============================================================================
# ENDPOINTS REST
# ============================================================================
@app.post("/api/register", status_code=201)
def register(user: RegisterRequest):
    conn = get_db()
    try:
        with conn.cursor() as cursor:
            # 1. Verificar si el correo ya existe
            cursor.execute("SELECT id_user FROM users WHERE email = %s;", (user.email,))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="El correo ya está registrado")

            # 2. Insertar el nuevo usuario (rol 'Usuario' por defecto)
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
            # CORRECCIÓN: Se cambió 'id' por 'id_user' en el SELECT
            cursor.execute(
                "SELECT id_user, nombre, email, password, rol FROM users WHERE email = %s;",
                (credentials.email,)
            )
            user = cursor.fetchone()

            if not user or user["password"] != credentials.password:
                raise HTTPException(status_code=401, detail="Correo o contraseña incorrectos")

        return {
            "user": {
                # CORRECCIÓN: Se lee 'id_user' del diccionario de la base de datos
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
    topic = f"robot/{cmd.robot_id}/command"
    payload = json.dumps({"comando": cmd.comando, "modo": cmd.modo})
    
    try:
        mqtt_client.publish(topic, payload)
        return {"status": "success", "message": f"Comando '{cmd.comando}' enviado al robot {cmd.robot_id}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error MQTT: {e}")