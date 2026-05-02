#include <WiFi.h>

#include <WebServer.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <MPU6050.h>
#include <DHT.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Preferences.h>  // EEPROM-like persistent storage (ESP32 NVS)

// ============== Device Info ==============
const char* deviceId = "ESP32-ACCIDENT-001";
const char* deviceName = "Accident Detection Unit 1";
const char* firmwareVersion = "1.2.2";

// ============== AP Mode Config (Setup Hotspot) ==============
const char* AP_SSID = "SMART-AMBULANCE-001";
const char* AP_PASSWORD = "setup123";
// When in AP mode, ESP32 IP is always 192.168.4.1

// ============== Pin Definitions ==============
#define MPU_SDA 21
#define MPU_SCL 22
#define DHT_PIN 4
#define MQ135_DIGITAL_PIN 19
#define MQ135_ANALOG_PIN 35

#define DHTTYPE DHT11

// ============== OLED Configuration ==============
#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1
#define SCREEN_ADDRESS 0x3C

// ============== Thresholds ==============
#define IMPACT_THRESHOLD 3.0  // ~2G net dynamic impact above gravity baseline (1G always present)
#define GAS_THRESHOLD 200  // PPM threshold for UNSAFE alert (MQ-135 analog-based)

// ============== Display Cycling ==============
#define SCREEN_COUNT 4
#define SCREEN_INTERVAL 5000  // 5 seconds per screen
#define WELCOME_DURATION 3000 // 3 seconds for welcome screen

// ============== Objects ==============
WebServer server(80);
MPU6050 mpu;
DHT dht(DHT_PIN, DHTTYPE);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
Preferences prefs;  // NVS storage for WiFi credentials

// ============== WiFi State ==============
bool isAPMode = false;     // true = setup hotspot mode, false = normal STA mode
String savedSSID = "";
String savedPassword = "";

// ============== Sensor Data ==============
struct SensorData {
  float accelX;
  float accelY;
  float accelZ;
  float totalAccel;
  int mq135Digital;
  int mq135Analog;
  float mq135PPM;
  float temperature;
  float humidity;
  int rssi;
  int batteryLevel;
  unsigned long timestamp;
} sensorData;

float mq135_R0 = 10.0;

// ============== Display State ==============
int currentScreen = 0;
unsigned long lastScreenChange = 0;
bool welcomeDone = false;

// ============== Setup ==============
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n\n=================================");
  Serial.println("Ambulance Response System v1.2.2");
  Serial.println("ESP32 Accident Detection");
  Serial.println("=================================\n");

  initializeSensors();
  displayWelcome();

  // Load saved WiFi credentials from NVS
  loadWiFiCredentials();

  if (savedSSID.length() > 0) {
    // We have saved credentials — try to connect
    Serial.println("Saved WiFi found: " + savedSSID);
    connectToWiFi(savedSSID.c_str(), savedPassword.c_str());

    if (WiFi.status() != WL_CONNECTED) {
      // Saved WiFi failed (hotspot off?) — fall back to AP mode
      Serial.println("Could not connect to saved WiFi. Starting AP mode.");
      startAPMode();
    }
  } else {
    // No saved credentials — start AP mode for first-time setup
    Serial.println("No saved WiFi. Starting AP mode for setup.");
    startAPMode();
  }

  setupServerEndpoints();
  server.begin();
  Serial.println("HTTP Server started");

  delay(WELCOME_DURATION);
  welcomeDone = true;
  lastScreenChange = millis();
}

// ============== Main Loop ==============
void loop() {
  server.handleClient();

  // Read sensors every 100ms
  static unsigned long lastRead = 0;
  if (millis() - lastRead > 100) {
    readAllSensors();
    lastRead = millis();
  }

  checkAccidentConditions();

  // Cycle display screens
  if (millis() - lastScreenChange >= SCREEN_INTERVAL) {
    currentScreen = (currentScreen + 1) % SCREEN_COUNT;
    lastScreenChange = millis();
  }

  // Update display every 500ms
  static unsigned long lastDisplay = 0;
  if (millis() - lastDisplay > 500) {
    updateDisplay();
    lastDisplay = millis();
  }
}

// ============== NVS: Load WiFi Credentials ==============
void loadWiFiCredentials() {
  prefs.begin("wifi", true);  // read-only namespace "wifi"
  savedSSID = prefs.getString("ssid", "");
  savedPassword = prefs.getString("pass", "");
  prefs.end();
  Serial.print("Loaded SSID: ");
  Serial.println(savedSSID.length() > 0 ? savedSSID : "(none)");
}

void saveWiFiCredentials(const char* ssid, const char* password) {
  prefs.begin("wifi", false);  // read-write
  prefs.putString("ssid", ssid);
  prefs.putString("pass", password);
  prefs.end();
  Serial.println("WiFi credentials saved to NVS.");
}

void clearWiFiCredentials() {
  prefs.begin("wifi", false);
  prefs.clear();
  prefs.end();
  Serial.println("WiFi credentials cleared.");
}

// ============== AP Mode (Setup Hotspot) ==============
void startAPMode() {
  isAPMode = true;
  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASSWORD);
  IPAddress apIP = WiFi.softAPIP();
  Serial.println("AP Mode started!");
  Serial.print("Hotspot SSID: "); Serial.println(AP_SSID);
  Serial.print("Hotspot Password: "); Serial.println(AP_PASSWORD);
  Serial.print("AP IP Address: "); Serial.println(apIP);
}

// ============== WiFi STA Connection ==============
void connectToWiFi(const char* ssid, const char* password) {
  isAPMode = false;
  Serial.print("Connecting to WiFi: ");
  Serial.println(ssid);

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected!");
    Serial.print("IP Address: "); Serial.println(WiFi.localIP());
    Serial.print("RSSI: "); Serial.print(WiFi.RSSI()); Serial.println(" dBm");
  } else {
    Serial.println("\nWiFi connection failed.");
  }
}

// ============== Sensor Initialization ==============
void initializeSensors() {
  Serial.println("Initializing sensors...");

  Wire.begin(MPU_SDA, MPU_SCL);

  Serial.print("  MPU6050... ");
  mpu.initialize();
  if (mpu.testConnection()) {
    Serial.println("OK");
    mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_4);  // ±4G range, divisor 8192
  } else {
    Serial.println("FAILED");
  }

  Serial.print("  OLED Display... ");
  if (display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println("OK");
    display.clearDisplay();
    display.display();
  } else {
    Serial.println("FAILED");
  }

  Serial.print("  DHT Sensor... ");
  dht.begin();
  Serial.println("OK");

  Serial.print("  MQ-135... ");
  pinMode(MQ135_DIGITAL_PIN, INPUT);
  pinMode(MQ135_ANALOG_PIN, INPUT);
  Serial.println("OK");

  calibrateMQ135();
  Serial.println("All sensors initialized!\n");
}

// ============== Server Endpoints ==============
void setupServerEndpoints() {
  server.on("/", HTTP_GET, handleRoot);
  server.on("/info", HTTP_GET, handleInfo);
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/sensors", HTTP_GET, handleSensors);
  server.on("/data", HTTP_GET, handleSensors);
  server.on("/config", HTTP_GET, handleGetConfig);
  server.on("/config", HTTP_POST, handleSetConfig);
  server.on("/calibrate", HTTP_POST, handleCalibrate);
  server.on("/restart", HTTP_POST, handleRestart);
  server.on("/wifi", HTTP_POST, handleWiFiSetup);    // New: receive WiFi credentials
  server.on("/wifi", HTTP_GET, handleWiFiStatus);    // New: check current WiFi status
  server.on("/wifi/reset", HTTP_POST, handleWiFiReset); // New: clear saved WiFi
  server.onNotFound(handleNotFound);

  // CORS headers for all responses (needed when app and ESP32 are on different subnets)
  server.enableCORS(true);
}

void handleRoot() {
  String html = "<html><body>";
  html += "<h1>Smart Ambulance System</h1>";
  html += "<p>Device: " + String(deviceName) + "</p>";
  html += "<p>ID: " + String(deviceId) + "</p>";
  html += "<p>Firmware: " + String(firmwareVersion) + "</p>";
  html += "<p>Mode: " + String(isAPMode ? "SETUP (AP)" : "Normal (STA)") + "</p>";
  html += "<h2>Endpoints:</h2><ul>";
  html += "<li><a href='/info'>/info</a></li>";
  html += "<li><a href='/status'>/status</a></li>";
  html += "<li><a href='/sensors'>/sensors</a></li>";
  html += "<li><a href='/wifi'>/wifi</a> - WiFi status / POST to configure</li>";
  html += "</ul></body></html>";
  server.send(200, "text/html", html);
}

void handleInfo() {
  StaticJsonDocument<256> doc;
  doc["device_id"] = deviceId;
  doc["name"] = deviceName;
  doc["firmware"] = firmwareVersion;
  doc["ip_address"] = isAPMode ? WiFi.softAPIP().toString() : WiFi.localIP().toString();
  doc["mac_address"] = WiFi.macAddress();
  doc["rssi"] = isAPMode ? 0 : WiFi.RSSI();
  doc["mode"] = isAPMode ? "ap" : "sta";
  String output;
  serializeJson(doc, output);
  server.send(200, "application/json", output);
}

void handleStatus() {
  StaticJsonDocument<512> doc;
  doc["device_id"] = deviceId;
  doc["name"] = deviceName;
  doc["firmware"] = firmwareVersion;
  doc["uptime"] = millis() / 1000;
  doc["wifi_connected"] = WiFi.status() == WL_CONNECTED;
  doc["rssi"] = isAPMode ? 0 : WiFi.RSSI();
  doc["battery"] = getBatteryLevel();
  doc["free_heap"] = ESP.getFreeHeap();
  doc["sensors_ok"] = mpu.testConnection();
  doc["mode"] = isAPMode ? "ap" : "sta";
  String output;
  serializeJson(doc, output);
  server.send(200, "application/json", output);
}

void handleSensors() {
  StaticJsonDocument<1024> doc;
  doc["accel_x"] = sensorData.accelX;
  doc["accel_y"] = sensorData.accelY;
  doc["accel_z"] = sensorData.accelZ;
  doc["total_accel"] = sensorData.totalAccel;
  doc["impact"] = sensorData.totalAccel;
  doc["mq135_digital"] = sensorData.mq135Digital;
  doc["mq135_analog"] = sensorData.mq135Analog;
  doc["mq135_ppm"] = sensorData.mq135PPM;
  doc["mq135"] = sensorData.mq135PPM;
  doc["temperature"] = sensorData.temperature;
  doc["humidity"] = sensorData.humidity;
  doc["lat"] = 0.0;
  doc["lng"] = 0.0;
  doc["altitude"] = 0.0;
  doc["alt"] = 0.0;
  doc["speed"] = 0.0;
  doc["gps_accuracy"] = 0.0;
  doc["orientation"] = 0.0;
  doc["pressure"] = 1013.25;
  doc["battery_voltage"] = getBatteryVoltage();
  doc["rssi"] = isAPMode ? 0 : WiFi.RSSI();
  doc["timestamp"] = sensorData.timestamp;
  doc["flame"] = false;
  doc["fire"] = false;
  String output;
  serializeJson(doc, output);
  server.send(200, "application/json", output);
}

// ============== WiFi Setup Endpoint ==============
// POST /wifi  body: {"ssid":"YourHotspot","password":"YourPass"}
void handleWiFiSetup() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", "{\"error\":\"No body\"}");
    return;
  }

  StaticJsonDocument<256> doc;
  DeserializationError err = deserializeJson(doc, server.arg("plain"));
  if (err) {
    server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    return;
  }

  const char* newSSID = doc["ssid"];
  const char* newPassword = doc["password"];

  if (!newSSID || strlen(newSSID) == 0) {
    server.send(400, "application/json", "{\"error\":\"SSID required\"}");
    return;
  }

  // Save to NVS
  saveWiFiCredentials(newSSID, newPassword ? newPassword : "");

  // Respond before restarting
  server.send(200, "application/json", "{\"status\":\"saved\",\"message\":\"Restarting and connecting to your WiFi...\"}");

  Serial.println("New WiFi credentials received. Restarting...");
  delay(1500);
  ESP.restart();
}

// GET /wifi — returns current WiFi status and saved SSID
void handleWiFiStatus() {
  StaticJsonDocument<256> doc;
  doc["mode"] = isAPMode ? "ap" : "sta";
  doc["connected"] = WiFi.status() == WL_CONNECTED;
  doc["saved_ssid"] = savedSSID;
  doc["ap_ssid"] = AP_SSID;
  doc["ip"] = isAPMode ? WiFi.softAPIP().toString() : WiFi.localIP().toString();
  String output;
  serializeJson(doc, output);
  server.send(200, "application/json", output);
}

// POST /wifi/reset — clears saved credentials and restarts in AP mode
void handleWiFiReset() {
  clearWiFiCredentials();
  server.send(200, "application/json", "{\"status\":\"cleared\",\"message\":\"Restarting in setup mode...\"}");
  delay(1500);
  ESP.restart();
}

void handleGetConfig() {
  StaticJsonDocument<256> doc;
  doc["sampling_rate"] = 10;
  doc["sensitivity"] = 1.0;
  doc["impact_threshold"] = IMPACT_THRESHOLD;
  doc["gas_threshold"] = GAS_THRESHOLD;
  String output;
  serializeJson(doc, output);
  server.send(200, "application/json", output);
}

void handleSetConfig() {
  if (server.hasArg("plain")) {
    StaticJsonDocument<256> doc;
    DeserializationError error = deserializeJson(doc, server.arg("plain"));
    if (!error) {
      server.send(200, "application/json", "{\"status\":\"ok\"}");
    } else {
      server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    }
  } else {
    server.send(400, "application/json", "{\"error\":\"No data\"}");
  }
}

void handleCalibrate() {
  calibrateMQ135();
  server.send(200, "application/json", "{\"status\":\"calibrated\"}");
}

void handleRestart() {
  server.send(200, "application/json", "{\"status\":\"restarting\"}");
  delay(1000);
  ESP.restart();
}

void handleNotFound() {
  server.send(404, "application/json", "{\"error\":\"Not found\"}");
}

// ============== Sensor Reading ==============
void readAllSensors() {
  int16_t ax, ay, az;
  mpu.getAcceleration(&ax, &ay, &az);
  sensorData.accelX = ax / 16384.0;  // ±2G range (default): 16384 LSB/g
  sensorData.accelY = ay / 16384.0;
  sensorData.accelZ = az / 16384.0;
  sensorData.totalAccel = sqrt(
    sensorData.accelX * sensorData.accelX +
    sensorData.accelY * sensorData.accelY +
    sensorData.accelZ * sensorData.accelZ
  );

  sensorData.mq135Digital = digitalRead(MQ135_DIGITAL_PIN);
  sensorData.mq135Analog = analogRead(MQ135_ANALOG_PIN);
  sensorData.mq135PPM = calculateMQ135PPM(sensorData.mq135Analog);

  sensorData.temperature = dht.readTemperature();
  sensorData.humidity = dht.readHumidity();
  if (isnan(sensorData.temperature)) sensorData.temperature = 0.0;
  if (isnan(sensorData.humidity)) sensorData.humidity = 0.0;

  sensorData.rssi = isAPMode ? 0 : WiFi.RSSI();
  sensorData.batteryLevel = getBatteryLevel();
  sensorData.timestamp = millis();
}

// ============== MQ-135 Calibration ==============
void calibrateMQ135() {
  Serial.println("Calibrating MQ-135 in clean air...");
  delay(2000);
  float sum = 0;
  for (int i = 0; i < 50; i++) {
    int raw = analogRead(MQ135_ANALOG_PIN);
    float voltage = raw * (3.3 / 4095.0);
    float RS = (3.3 - voltage) / voltage * 10.0;
    sum += RS;
    delay(100);
  }
  mq135_R0 = sum / 50.0 / 3.6;
  Serial.print("Calibration complete! R0 = ");
  Serial.println(mq135_R0);
}

float calculateMQ135PPM(int rawValue) {
  float voltage = rawValue * (3.3 / 4095.0);
  if (voltage == 0) return 0;
  float RS = (3.3 - voltage) / voltage * 10.0;
  float ratio = RS / mq135_R0;
  float ppm = 116.6020682 * pow(ratio, -2.769034857);
  return ppm;
}

// ============== Accident Detection ==============
void checkAccidentConditions() {
  static bool accidentDetected = false;
  if (sensorData.totalAccel > IMPACT_THRESHOLD) {
    if (!accidentDetected) {
      Serial.println("!! HIGH IMPACT DETECTED!");
      Serial.print("G-Force: ");
      Serial.println(sensorData.totalAccel);
      accidentDetected = true;
    }
  } else {
    accidentDetected = false;
  }
  // DO pin is active-LOW on most MQ-135 modules (LOW = gas detected)
  if (sensorData.mq135Digital == LOW || sensorData.mq135PPM > GAS_THRESHOLD) {
    Serial.println("!! DANGEROUS GAS LEVELS!");
    Serial.print("PPM: ");
    Serial.println(sensorData.mq135PPM);
  }
}

// ============== OLED Display Functions ==============

void displayWelcome() {
  display.clearDisplay();
  display.drawRect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, SSD1306_WHITE);
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(10, 8);
  display.println("AMBULANCE RESPONSE");
  display.setCursor(30, 20);
  display.println("SYSTEM v1.2.2");
  display.drawLine(10, 32, 118, 32, SSD1306_WHITE);
  display.setCursor(14, 38);
  display.println("Initializing...");
  display.setCursor(14, 50);
  display.println("Sensors: Ready");
  display.display();
}

void updateDisplay() {
  switch (currentScreen) {
    case 0: drawSystemInfo(); break;
    case 1: drawTempHumidity(); break;
    case 2: drawImpact(); break;
    case 3: drawGasQuality(); break;
  }
}

void drawScreenHeader(const char* title) {
  display.fillRect(0, 0, SCREEN_WIDTH, 12, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  int titleLen = strlen(title);
  int xPos = (SCREEN_WIDTH - (titleLen * 6)) / 2;
  display.setCursor(xPos, 2);
  display.println(title);
  display.setTextColor(SSD1306_WHITE);
  int dotY = 60;
  int dotStartX = (SCREEN_WIDTH - (SCREEN_COUNT * 8)) / 2;
  for (int i = 0; i < SCREEN_COUNT; i++) {
    int dotX = dotStartX + (i * 8);
    if (i == currentScreen) {
      display.fillCircle(dotX, dotY, 2, SSD1306_WHITE);
    } else {
      display.drawCircle(dotX, dotY, 2, SSD1306_WHITE);
    }
  }
}

void drawSystemInfo() {
  display.clearDisplay();

  if (isAPMode) {
    // ── AP / SETUP MODE screen ──
    drawScreenHeader("SETUP MODE");
    display.setTextSize(1);
    display.setCursor(0, 16);
    display.println("Connect to WiFi:");
    display.setCursor(0, 27);
    display.print(AP_SSID);
    display.setCursor(0, 38);
    display.print("Pass: setup123");
    display.setCursor(0, 49);
    display.print("IP: 192.168.4.1");
  } else {
    // ── Normal SYSTEM INFO screen ──
    drawScreenHeader("SYSTEM INFO");
    display.setTextSize(1);

    // Device ID (shortened to fit)
    display.setCursor(0, 16);
    display.print("ID: ");
    display.println(deviceId);

    // Uptime
    unsigned long uptimeSec = millis() / 1000;
    unsigned long hrs = uptimeSec / 3600;
    unsigned long mins = (uptimeSec % 3600) / 60;
    unsigned long secs = uptimeSec % 60;
    display.setCursor(0, 27);
    display.print("Up: ");
    if (hrs < 10) display.print("0");
    display.print(hrs); display.print(":");
    if (mins < 10) display.print("0");
    display.print(mins); display.print(":");
    if (secs < 10) display.print("0");
    display.println(secs);

    // WiFi + IP
    display.setCursor(0, 38);
    if (WiFi.status() == WL_CONNECTED) {
      display.print("WiFi: ");
      display.print(WiFi.RSSI());
      display.println(" dBm");
      display.setCursor(0, 49);
      display.print("IP: ");
      display.println(WiFi.localIP());
    } else {
      display.println("WiFi: Reconnecting..");
      display.setCursor(0, 49);
      display.println("Check hotspot");
    }
  }

  display.display();
}

void drawTempHumidity() {
  display.clearDisplay();
  drawScreenHeader("ENVIRONMENT");
  display.setTextSize(2);
  display.setCursor(0, 18);
  display.print(sensorData.temperature, 1);
  display.setTextSize(1);
  display.print(" C");
  display.setCursor(90, 18);
  display.println("TEMP");
  display.drawLine(0, 36, SCREEN_WIDTH, 36, SSD1306_WHITE);
  display.setTextSize(2);
  display.setCursor(0, 40);
  display.print(sensorData.humidity, 1);
  display.setTextSize(1);
  display.print(" %");
  display.setCursor(90, 40);
  display.println("HUM");
  display.display();
}

void drawImpact() {
  display.clearDisplay();
  drawScreenHeader("IMPACT MONITOR");
  display.setTextSize(2);
  display.setCursor(0, 16);
  display.print(sensorData.totalAccel, 2);
  display.setTextSize(1);
  display.print(" G");
  if (sensorData.totalAccel > IMPACT_THRESHOLD) {
    display.setCursor(90, 16);
    display.println("!ALERT!");
  }
  display.drawLine(0, 34, SCREEN_WIDTH, 34, SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 38);
  display.print("X:");
  display.print(sensorData.accelX, 2);
  display.setCursor(64, 38);
  display.print("Y:");
  display.println(sensorData.accelY, 2);
  display.setCursor(0, 49);
  display.print("Z:");
  display.print(sensorData.accelZ, 2);
  int barWidth = map(constrain((int)(sensorData.totalAccel * 100), 0, 500), 0, 500, 0, 50);
  display.setCursor(64, 49);
  display.print("Force:");
  display.drawRect(64, 56, 50, 4, SSD1306_WHITE);
  display.fillRect(64, 56, barWidth, 4, SSD1306_WHITE);
  display.display();
}

void drawGasQuality() {
  display.clearDisplay();
  drawScreenHeader("AIR QUALITY");
  display.setTextSize(2);
  display.setCursor(0, 16);
  display.print(sensorData.mq135PPM, 0);
  display.setTextSize(1);
  display.print(" PPM");
  // DO pin is active-LOW, or PPM above threshold
  bool gasAlert = (sensorData.mq135Digital == LOW) || (sensorData.mq135PPM > GAS_THRESHOLD);
  if (gasAlert) {
    display.setCursor(80, 16);
    display.println("DANGER!");
  }
  display.drawLine(0, 34, SCREEN_WIDTH, 34, SSD1306_WHITE);
  bool gasUnsafe = (sensorData.mq135Digital == LOW) || (sensorData.mq135PPM > GAS_THRESHOLD);
  display.setTextSize(1);
  display.setCursor(0, 38);
  display.print("Status: ");
  display.println(gasUnsafe ? "UNSAFE" : "SAFE");
  display.setCursor(0, 49);
  display.print("Raw: ");
  display.print(sensorData.mq135Analog);
  int barWidth = map(constrain(sensorData.mq135Analog, 0, 4095), 0, 4095, 0, 50);
  display.drawRect(70, 49, 50, 6, SSD1306_WHITE);
  display.fillRect(70, 49, barWidth, 6, SSD1306_WHITE);
  display.display();
}

// ============== Battery (placeholder) ==============
int getBatteryLevel() {
  return 85;
}

float getBatteryVoltage() {
  return 3.7;
}
