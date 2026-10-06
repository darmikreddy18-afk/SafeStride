import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SafeStrideBluetoothService {
  // =========================================================
  // SAFESTRIDE BLE UUIDs
  // =========================================================

  static const String serviceUuid =
      '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';

  static const String characteristicUuid =
      '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';

  // =========================================================
  // SCAN
  // =========================================================

  Stream<List<ScanResult>> get scanResults =>
      FlutterBluePlus.scanResults;

  Stream<BluetoothAdapterState> get bluetoothState =>
      FlutterBluePlus.adapterState;

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 5),
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  // =========================================================
  // STATUS STREAM
  // =========================================================

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Stream<String> get statusStream =>
      _statusController.stream;

  BluetoothCharacteristic? _statusCharacteristic;

  StreamSubscription<List<int>>? _notificationSubscription;

  // =========================================================
  // CONNECT
  // =========================================================

  Future<void> connect(
    BluetoothDevice device,
  ) async {
    await device.connect(
      license: License.nonprofit,
    );

    await setupNotifications(device);
  }

  // =========================================================
  // SETUP BLE NOTIFICATIONS
  // =========================================================

  Future<void> setupNotifications(
    BluetoothDevice device,
  ) async {
    final services =
        await device.discoverServices();

    BluetoothCharacteristic? foundCharacteristic;

    for (final service in services) {
      final currentServiceUuid =
          service.uuid.toString().toUpperCase();

      if (currentServiceUuid !=
          serviceUuid.toUpperCase()) {
        continue;
      }

      for (final characteristic
          in service.characteristics) {
        final currentCharacteristicUuid =
            characteristic.uuid
                .toString()
                .toUpperCase();

        if (currentCharacteristicUuid ==
            characteristicUuid.toUpperCase()) {
          foundCharacteristic =
              characteristic;

          break;
        }
      }

      if (foundCharacteristic != null) {
        break;
      }
    }

    if (foundCharacteristic == null) {
      throw Exception(
        'SafeStride BLE characteristic not found.',
      );
    }

    _statusCharacteristic =
        foundCharacteristic;

    // Remove an old notification listener if one exists.
    await _notificationSubscription?.cancel();

    // Enable notifications from ESP32.
    await _statusCharacteristic!
        .setNotifyValue(true);

    // Listen for ESP32 messages.
    _notificationSubscription =
        _statusCharacteristic!
            .onValueReceived
            .listen((value) {
      if (value.isEmpty) return;

      final message =
          String.fromCharCodes(value).trim();

      if (message.isEmpty) return;

      _statusController.add(message);
    });
  }

  // =========================================================
  // SEND COMMAND TO ESP32
  // =========================================================

  Future<void> sendCommand(
    String command,
  ) async {
    if (_statusCharacteristic == null) {
      throw Exception(
        'SafeStride Walker is not connected.',
      );
    }

    await _statusCharacteristic!.write(
      command.codeUnits,
      withoutResponse: false,
    );
  }

  // =========================================================
  // DISCONNECT
  // =========================================================

  Future<void> disconnect(
    BluetoothDevice device,
  ) async {
    await _notificationSubscription?.cancel();

    _notificationSubscription = null;
    _statusCharacteristic = null;

    await device.disconnect();
  }

  // =========================================================
  // CLEANUP
  // =========================================================

  Future<void> dispose() async {
    await _notificationSubscription?.cancel();

    _notificationSubscription = null;
    _statusCharacteristic = null;

    await _statusController.close();
  }
}