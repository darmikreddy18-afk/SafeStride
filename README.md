# SafeStride

SafeStride is a smart mobility and safety project built around a connected walker for elderly people and people with mobility difficulties.

The current prototype combines an ESP32, distance sensors, an accelerometer, GPS, GSM and Bluetooth with a Flutter mobile application and Firebase backend.

The goal is to add useful safety features to a conventional walker while keeping the system practical and affordable for the Indian market.

## What We've Built

The current prototype supports:

* Obstacle detection using VL53L0X ToF sensors
* Directional vibration feedback
* Fall detection using an ADXL345 accelerometer
* SOS button
* GPS location tracking
* GSM communication
* Bluetooth/BLE communication with the mobile app
* Light detection
* LED and buzzer alerts
* Walker status synchronisation
* Patient and guardian accounts
* Family ID-based caregiver connection
* Guardian access requests and approval
* Patient location and walker monitoring

## Hardware

The current prototype uses:

* ESP32 DevKit
* ADXL345 accelerometer
* 2 × VL53L0X ToF sensors
* 2 × LDR sensors
* NEO-6M GPS
* SIM800L GSM module
* Left and right vibration motors
* Buzzer
* LED
* SOS push button

The current hardware uses development modules to make prototyping and testing easier. The next hardware iteration will move toward a custom PCB and a more integrated mechanical design.

## Mobile Application

The mobile application is built with Flutter.

There are currently two user roles:

### Patient

The patient uses the application to connect to the SafeStride walker and access features such as:

* Walker connection
* Walker status
* GPS location
* SOS
* Fall alerts
* Find My Walker
* Family ID
* Guardian access requests
* Device information

### Guardian

The guardian dashboard provides information about the connected patient and walker, including:

* Patient information
* Walker connection status
* Safety status
* Battery status
* Last known location
* Latest walker event
* Family connection status

## Family ID

SafeStride uses a Family ID system to connect a patient with a guardian.

A patient receives a Family ID when creating an account. A guardian can enter that ID to find the patient and send an access request.

The patient has to approve the request before the accounts are linked.

This gives the patient control over who can access their information.

## Bluetooth

The ESP32 currently advertises as:

```text
SafeStride_ESP32
```

The Flutter application uses `flutter_blue_plus` for BLE communication.

The current implementation uses a custom BLE service and characteristic for communication between the walker and the application.

## Firebase

Firebase is currently used for authentication, database storage and backend functionality.

The project uses:

* Firebase Authentication
* Cloud Firestore
* Firebase Cloud Functions
* Firebase Cloud Messaging

Firestore currently stores user information, family connections, access requests, walker status, locations and alerts.

The application is being structured so that safety-critical functions can continue to operate locally on the ESP32 instead of depending completely on an internet connection.

## Technology Stack

**Firmware / Hardware**

* ESP32
* Arduino/C++
* ADXL345
* VL53L0X
* NEO-6M
* SIM800L
* BLE

**Mobile**

* Flutter
* Dart
* Flutter Blue Plus

**Backend**

* Firebase Authentication
* Cloud Firestore
* Firebase Cloud Functions
* Firebase Cloud Messaging

**Development**

* Android Studio
* VS Code
* Git
* GitHub

## Current Status

SafeStride is currently in the working prototype and engineering-development stage.

The basic hardware, Bluetooth communication, Flutter application and Firebase integration are working.

The current focus is on improving reliability and preparing the system for more structured testing.

Areas still being worked on include:

* Better fall-detection reliability
* Reducing false alerts
* Battery optimization
* More reliable background communication
* Device identification
* Custom PCB development
* Mechanical redesign
* Mechanical and electrical safety testing
* User testing

## Future Work

The longer-term plan is to develop SafeStride beyond the current walker prototype.

Possible future devices include a smart wearable, walking stick and other safety-oriented assistive devices.

The wearable side will explore health-related sensing such as heart rate, SpO₂ and ECG. These features will require proper validation before being presented as medical measurements.

Another area I want to explore is an AI-based conversational assistant that co
