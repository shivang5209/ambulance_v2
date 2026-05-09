import math
import socket
import time

from flask import Flask, jsonify, request

DEVICE_ID = "RPI-ACCIDENT-001"
DEVICE_NAME = "Accident Detection Unit Pi"
FIRMWARE_VERSION = "1.0.0-pi"

DHT_PIN = 4
MQ135_DIGITAL_PIN = 19
IMPACT_THRESHOLD = 3.0
GAS_THRESHOLD = 200

app = Flask(__name__)
started_at = time.time()

mpu = None
dht = None
display = None
mq135_input = None
sensor_data = {
    "accel_x": 0.0,
    "accel_y": 0.0,
    "accel_z": 0.0,
    "total_accel": 0.0,
    "mq135_digital": 1,
    "mq135_analog": 0,
    "mq135_ppm": 0.0,
    "temperature": 0.0,
    "humidity": 0.0,
    "timestamp": 0,
}


class SimpleMPU6050:
    def __init__(self, bus_number=1, address=0x68):
        from smbus2 import SMBus

        self.address = address
        self.bus = SMBus(bus_number)
        self.bus.write_byte_data(self.address, 0x6B, 0x00)
        time.sleep(0.1)

    def _read_word_signed(self, register):
        high = self.bus.read_byte_data(self.address, register)
        low = self.bus.read_byte_data(self.address, register + 1)
        value = (high << 8) | low
        if value >= 0x8000:
            value = -((65535 - value) + 1)
        return value

    @property
    def acceleration(self):
        accel_scale = 16384.0
        return (
            self._read_word_signed(0x3B) / accel_scale * 9.80665,
            self._read_word_signed(0x3D) / accel_scale * 9.80665,
            self._read_word_signed(0x3F) / accel_scale * 9.80665,
        )


def get_ip_address():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            return sock.getsockname()[0]
    except OSError:
        return "127.0.0.1"


def initialize_sensors():
    global mpu, dht, display, mq135_input

    try:
        import board
        import busio
        import adafruit_mpu6050
        import adafruit_ssd1306
        import adafruit_dht
        from gpiozero import DigitalInputDevice

        i2c = busio.I2C(board.SCL, board.SDA)

        try:
            mpu = adafruit_mpu6050.MPU6050(i2c)
            try:
                mpu.accelerometer_range = adafruit_mpu6050.Range.RANGE_4_G
            except Exception as exc:
                print(f"MPU6050 range setup skipped: {exc}")
            print("MPU6050: OK")
        except Exception as exc:
            try:
                mpu = SimpleMPU6050()
                _ = mpu.acceleration
                print(f"MPU6050: OK via smbus2 fallback ({exc})")
            except Exception as fallback_exc:
                print(f"MPU6050: FAILED ({exc}; fallback: {fallback_exc})")

        try:
            display = adafruit_ssd1306.SSD1306_I2C(128, 64, i2c)
            display.fill(0)
            display.show()
            print("OLED: OK")
        except Exception as exc:
            print(f"OLED: FAILED ({exc})")

        try:
            dht = adafruit_dht.DHT11(getattr(board, f"D{DHT_PIN}"))
            print("DHT11: OK")
        except Exception as exc:
            print(f"DHT11: FAILED ({exc})")

        try:
            mq135_input = DigitalInputDevice(MQ135_DIGITAL_PIN, pull_up=False)
            print("MQ135 digital: OK")
        except Exception as exc:
            print(f"MQ135 digital: FAILED ({exc})")
    except Exception as exc:
        print(f"Sensor library setup failed: {exc}")


def read_all_sensors():
    if mpu:
        try:
            ax, ay, az = mpu.acceleration
            sensor_data["accel_x"] = ax / 9.80665
            sensor_data["accel_y"] = ay / 9.80665
            sensor_data["accel_z"] = az / 9.80665
            sensor_data["total_accel"] = math.sqrt(
                sensor_data["accel_x"] ** 2
                + sensor_data["accel_y"] ** 2
                + sensor_data["accel_z"] ** 2
            )
        except Exception as exc:
            print(f"MPU read failed: {exc}")

    if dht:
        try:
            temperature = dht.temperature
            humidity = dht.humidity
            if temperature is not None:
                sensor_data["temperature"] = float(temperature)
            if humidity is not None:
                sensor_data["humidity"] = float(humidity)
        except RuntimeError:
            pass
        except Exception as exc:
            print(f"DHT read failed: {exc}")

    if mq135_input:
        try:
            sensor_data["mq135_digital"] = 1 if mq135_input.value else 0
        except Exception as exc:
            print(f"MQ135 read failed: {exc}")

    sensor_data["timestamp"] = int((time.time() - started_at) * 1000)


def draw_display():
    if not display:
        return

    try:
        from PIL import Image, ImageDraw, ImageFont

        image = Image.new("1", (128, 64))
        draw = ImageDraw.Draw(image)
        font = ImageFont.load_default()
        gas_alert = sensor_data["mq135_digital"] == 0
        impact_alert = sensor_data["total_accel"] > IMPACT_THRESHOLD

        draw.text((0, 0), "AMBULANCE PI", font=font, fill=255)
        draw.text((0, 14), f"Temp: {sensor_data['temperature']:.1f} C", font=font, fill=255)
        draw.text((0, 26), f"Hum : {sensor_data['humidity']:.1f} %", font=font, fill=255)
        draw.text((0, 38), f"Impact: {sensor_data['total_accel']:.2f} G", font=font, fill=255)
        draw.text((0, 50), f"Gas: {'DANGER' if gas_alert else 'SAFE'}", font=font, fill=255)
        if impact_alert:
            draw.text((82, 38), "ALERT", font=font, fill=255)

        display.image(image)
        display.show()
    except Exception as exc:
        print(f"OLED draw failed: {exc}")


def response_sensor_payload():
    gas_alert = sensor_data["mq135_digital"] == 0
    return {
        **sensor_data,
        "impact": sensor_data["total_accel"],
        "mq135": sensor_data["mq135_ppm"],
        "lat": 0.0,
        "lng": 0.0,
        "altitude": 0.0,
        "alt": 0.0,
        "speed": 0.0,
        "gps_accuracy": 0.0,
        "orientation": 0.0,
        "pressure": 1013.25,
        "battery_voltage": 5.0,
        "rssi": 0,
        "flame": False,
        "fire": False,
        "gas_alert": gas_alert,
    }


@app.route("/")
def root():
    return """
    <html><body>
    <h1>Smart Ambulance System</h1>
    <p>Raspberry Pi accident detection service is running.</p>
    <ul>
      <li><a href="/info">/info</a></li>
      <li><a href="/status">/status</a></li>
      <li><a href="/sensors">/sensors</a></li>
    </ul>
    </body></html>
    """


@app.route("/info")
def info():
    return jsonify(
        {
            "device_id": DEVICE_ID,
            "name": DEVICE_NAME,
            "firmware": FIRMWARE_VERSION,
            "ip_address": get_ip_address(),
            "mac_address": "",
            "rssi": 0,
            "mode": "pi",
        }
    )


@app.route("/status")
def status():
    return jsonify(
        {
            "device_id": DEVICE_ID,
            "name": DEVICE_NAME,
            "firmware": FIRMWARE_VERSION,
            "uptime": int(time.time() - started_at),
            "wifi_connected": get_ip_address() != "127.0.0.1",
            "rssi": 0,
            "battery": 100,
            "free_heap": 0,
            "sensors_ok": mpu is not None,
            "mode": "pi",
        }
    )


@app.route("/sensors")
@app.route("/data")
def sensors():
    read_all_sensors()
    return jsonify(response_sensor_payload())


@app.route("/config", methods=["GET", "POST"])
def config():
    if request.method == "POST":
        return jsonify({"status": "ok"})
    return jsonify(
        {
            "sampling_rate": 10,
            "sensitivity": 1.0,
            "impact_threshold": IMPACT_THRESHOLD,
            "gas_threshold": GAS_THRESHOLD,
        }
    )


@app.route("/calibrate", methods=["POST"])
def calibrate():
    return jsonify({"status": "digital-only", "message": "Use ADS1115 for MQ135 analog PPM."})


def main():
    initialize_sensors()
    last_display = 0
    print(f"Open this on the Pi: http://127.0.0.1:5000")
    print(f"Open this from phone/laptop on same WiFi: http://{get_ip_address()}:5000")

    # Flask handles web requests; sensor reads happen when /sensors is called.
    # The display gets one initial draw so you can confirm the service started.
    read_all_sensors()
    if time.time() - last_display >= 0:
        draw_display()

    app.run(host="0.0.0.0", port=5000)


if __name__ == "__main__":
    main()
