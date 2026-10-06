# SafeStride

SafeStride is a smart mobility and safety project focused on making everyday movement safer for elderly people and people with mobility difficulties.

The current prototype is a connected smart walker that can detect obstacles, identify possible falls, provide directional feedback, send SOS alerts, share location, and connect a user with a caregiver through a mobile application.

The project is being developed as an India-first, affordable assistive technology platform rather than as a single-purpose walking aid.

---

## Why SafeStride?

Traditional walkers help with physical support, but they do not know when the user is approaching an obstacle, falling, or needs immediate assistance.

SafeStride explores how low-cost sensors, embedded systems, wireless communication, and a mobile application can add an additional layer of safety around a conventional mobility aid.

The goal is simple:

> Make assistive technology more connected without making it unnecessarily expensive or complicated.

---

## Current Prototype

The current SafeStride prototype is built around an ESP32 and includes:

* Obstacle detection
* Directional vibration feedback
* Fall detection
* SOS button
* GPS location tracking
* GSM communication
* Bluetooth connectivity
* Ambient light detection
* LED and buzzer alerts
* Caregiver notifications
* "Find My Walker" functionality

The walker makes immediate safety decisions locally on the ESP32 while communicating relevant information to the mobile application.

---

## Hardware

### Main Controller

* ESP32 DevKit

### Sensors

* ADXL345 accelerometer
* 2 × VL53L0X ToF distance sensors
* 2 × LDR light sensors
* NEO-6M GPS module

### Communication

* Bluetooth / BLE
* SIM800L GSM module

### User Feedback

* Left vibration motor
* Right vibration motor
* Buzzer
* LED
* SOS push button

The current prototype uses commercially available development modules so that the system can be tested and modified quickly. A future production version will move toward a custom PCB and a more integrated mechanical design.

---

## How It Works

At a high level:

```text
                    SafeStride Walker
                           |
                         ESP32
                           |
          +----------------+----------------+
          |                |                |
       Sensors         Local Safety     Communication
          |              Logic               |
          |                |          +------+------+
          |                |          |             |
      ToF / IMU       Alerts / Haptic  BLE        GSM
      / Light             Feedback      |             |
                                        |             |
                                        v             v
                                  SafeStride App   Remote Alerts
                                        |
                                        v
                                     Firebase
                                        |
                                        v
                                  Caregiver App
```

The ESP32 handles time-sensitive safety functionality locally. The application and backend are used for monitoring, family connections, alerts, and device information.

---

# SafeStride Mobile App

The mobile application is being developed using Flutter.

The current application includes two main user roles:

### Patient

The patient is the primary SafeStride walker user.

The patient side currently includes:

* SafeStride walker connection
* Bluetooth communication
* Walker status
* GPS location
* SOS alerts
* Fall alerts
* Find My Walker
* Family ID
* Guardian access requests
* Device information

### Guardian

The guardian/caregiver side is designed to provide visibility into the connected patient's SafeStride device.

The guardian dashboard includes:

* Connected patient information
* Walker connection status
* Safety status
* Battery information
* Last known location
* Latest event
* Family connection
* Patient monitoring

---

# Family Connection

SafeStride uses a Family ID based connection system rather than requiring a caregiver to manually search for a patient's account.

The basic flow is:

```text
Patient creates account
        ↓
SafeStride generates Family ID
        ↓
Patient shares Family ID
        ↓
Guardian enters Family ID
        ↓
Guardian sends access request
        ↓
Patient approves request
        ↓
Patient + Guardian are linked
        ↓
Guardian can monitor the connected patient
```

The relationship is stored in Firebase so that access can be managed at the account level.

---

# Firebase Backend

Firebase is currently used for the application's backend infrastructure.

Current architecture:

```text
Flutter App
    |
    +---- Firebase Authentication
    |
    +---- Cloud Firestore
    |
    +---- Firebase Cloud Messaging
    |
    +---- Cloud Functions
```

Firestore currently stores information such as:

* User profiles
* Patient / guardian roles
* Family IDs
* Access requests
* Family relationships
* Walker status
* Walker location
* Alerts

The project also contains a Firebase Functions setup for server-side functionality.

---

# Bluetooth Communication

The ESP32 currently advertises as:

```text
SafeStride_ESP32
```

The Flutter application discovers the walker over BLE and communicates with it through a custom service/characteristic.

Current BLE service:

```text
Service:
6E400001-B5A3-F393-E0A9-E50E24DCCA9E

Characteristic:
6E400002-B5A3-F393-E0A9-E50E24DCCA9E
```

The BLE layer is used for communicating walker status, GPS information, alerts, and commands between the ESP32 and the mobile application.

---

# Development Status

SafeStride is currently at the working prototype stage.

### Completed

* ESP32-based walker prototype
* Obstacle detection
* Directional vibration feedback
* Fall detection logic
* SOS functionality
* GPS integration
* GSM integration
* Bluetooth communication
* Flutter application
* Firebase Authentication
* Firestore integration
* Patient / guardian roles
* Family ID system
* Guardian access requests
* Patient approval flow
* Guardian dashboard
* Walker status synchronization
* GPS data synchronization
* GitHub project setup

### Currently being developed

* More reliable automatic notifications
* Better background communication
* Production-oriented hardware d
