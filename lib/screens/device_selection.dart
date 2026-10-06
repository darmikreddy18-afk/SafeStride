import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/bluetooth_service.dart';
import 'patient_dashboard.dart';

class DeviceSelectionScreen extends StatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  State<DeviceSelectionScreen> createState() =>
      _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState
    extends State<DeviceSelectionScreen> {
  final SafeStrideBluetoothService bluetoothService =
      SafeStrideBluetoothService();

  StreamSubscription<List<ScanResult>>? scanSubscription;

  bool searching = false;

  BluetoothDevice? selectedDevice;

  List<ScanResult> devices = [];

  // SafeStride BLE service UUID.
  static const String safeStrideServiceUuid =
      '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';

  @override
  void initState() {
    super.initState();

    scanSubscription =
        bluetoothService.scanResults.listen((results) {
      if (!mounted) return;

      setState(() {
        devices = results.where((result) {
          return _isSafeStrideDevice(result);
        }).toList();
      });
    });
  }

  // =========================================================
  // CHECK SAFE STRIDE DEVICE
  // =========================================================

  bool _isSafeStrideDevice(ScanResult result) {
    final deviceName =
        result.device.platformName.trim();

    // Our ESP32 advertises as SafeStride Walker.
    if (deviceName == 'SafeStride Walker') {
      return true;
    }

    // Also allow the ESP32 if the platform name is
    // displayed differently but its advertisement contains
    // the SafeStride service UUID.
    for (final serviceUuid
        in result.advertisementData.serviceUuids) {
      if (serviceUuid.toString().toUpperCase() ==
          safeStrideServiceUuid.toUpperCase()) {
        return true;
      }
    }

    return false;
  }

  // =========================================================
  // START SCAN
  // =========================================================

  Future<void> searchForDevices() async {
    if (searching) return;

    setState(() {
      searching = true;
      devices = [];
    });

    try {
      await bluetoothService.startScan();

      await Future.delayed(
        const Duration(seconds: 5),
      );

      await bluetoothService.stopScan();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bluetooth scan failed: $e',
          ),
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      searching = false;
    });
  }

  // =========================================================
  // CONNECT DEVICE
  // =========================================================

  Future<void> connectDevice(
    BluetoothDevice device,
  ) async {
    try {
      await bluetoothService.connect(device);

      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'No logged-in user found.',
        );
      }

      // Save the connected walker to Firebase.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'deviceId': device.remoteId.toString(),
          'deviceName': 'SafeStride Walker',
          'deviceType': 'walker',
          'deviceRegisteredAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        selectedDevice = device;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SafeStride Walker connected and registered.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not connect to SafeStride Walker: $e',
          ),
        ),
      );
    }
  }

  // =========================================================
  // DISCONNECT
  // =========================================================

  Future<void> disconnectDevice() async {
    if (selectedDevice == null) return;

    try {
      await bluetoothService.disconnect(
        selectedDevice!,
      );
    } catch (_) {
      // Ignore disconnect errors.
    }

    if (!mounted) return;

    setState(() {
      selectedDevice = null;
    });
  }

  // =========================================================
  // CONTINUE TO DASHBOARD
  // =========================================================

  void continueToDashboard() {
    if (selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please connect your SafeStride Walker first.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDashboard(
          device: selectedDevice!,
        ),
      ),
    );
  }

  // =========================================================
  // DEVICE NAME
  // =========================================================

  String getDeviceName(
    ScanResult result,
  ) {
    final name =
        result.device.platformName.trim();

    if (name.isNotEmpty) {
      return name;
    }

    return 'SafeStride Walker';
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Device',
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const SizedBox(height: 10),

              // =================================================
              // HEADER
              // =================================================

              Center(
                child: Container(
                  width: 90,
                  height: 90,

                  decoration: BoxDecoration(
                    color:
                        Colors.blue.withValues(
                      alpha: 0.1,
                    ),
                    shape: BoxShape.circle,
                  ),

                  child: const Icon(
                    Icons.accessibility_new,
                    size: 50,
                    color: Colors.blue,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              const Center(
                child: Text(
                  'Connect Your SafeStride Walker',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 25,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Center(
                child: Text(
                  'Make sure your SafeStride Walker is powered on and nearby.',

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // =================================================
              // SEARCH BUTTON
              // =================================================

              SizedBox(
                width: double.infinity,
                height: 54,

                child: ElevatedButton.icon(
                  onPressed: searching
                      ? null
                      : searchForDevices,

                  icon: searching
                      ? const SizedBox(
                          width: 20,
                          height: 20,

                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.bluetooth_searching,
                        ),

                  label: Text(
                    searching
                        ? 'Searching...'
                        : 'Search for Devices',
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // =================================================
              // CONNECTED DEVICE
              // =================================================

              if (selectedDevice != null)
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(18),

                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,

                              decoration:
                                  BoxDecoration(
                                color: Colors.green
                                    .withValues(
                                  alpha: 0.12,
                                ),
                                shape:
                                    BoxShape.circle,
                              ),

                              child:
                                  const Icon(
                                Icons.check,
                                color:
                                    Colors.green,
                                size: 30,
                              ),
                            ),

                            const SizedBox(
                              width: 15,
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [
                                  const Text(
                                    'SafeStride Walker',

                                    style:
                                        TextStyle(
                                      fontSize: 18,
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 5,
                                  ),

                                  const Text(
                                    'Connected',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.green,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Text(
                                    selectedDevice!
                                        .remoteId
                                        .toString(),

                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Icon(
                              Icons
                                  .bluetooth_connected,
                              color:
                                  Colors.green,
                            ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        SizedBox(
                          width:
                              double.infinity,

                          child:
                              OutlinedButton(
                            onPressed:
                                disconnectDevice,

                            child:
                                const Text(
                              'Disconnect',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // =================================================
              // SEARCH RESULTS
              // =================================================

              if (selectedDevice == null) ...[
                const Text(
                  'Available Devices',

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                if (!searching &&
                    devices.isEmpty)
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(20),

                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons
                                  .bluetooth_disabled,
                              size: 40,
                              color:
                                  Colors.grey,
                            ),

                            const SizedBox(
                              height: 10,
                            ),

                            const Text(
                              'No SafeStride devices found.',
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            const Text(
                              'Turn on your walker and search again.',

                              textAlign:
                                  TextAlign.center,

                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                ...devices.map(
                  _buildDeviceCard,
                ),
              ],

              const SizedBox(height: 25),

              // =================================================
              // CONTINUE
              // =================================================

              SizedBox(
                width: double.infinity,
                height: 58,

                child: ElevatedButton(
                  onPressed:
                      selectedDevice == null
                          ? null
                          : continueToDashboard,

                  child: const Text(
                    'Continue to Dashboard',

                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DEVICE CARD
  // =========================================================

  Widget _buildDeviceCard(
    ScanResult result,
  ) {
    final device = result.device;

    final deviceName =
        getDeviceName(result);

    final isSelected =
        selectedDevice?.remoteId ==
            device.remoteId;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      child: Padding(
        padding:
            const EdgeInsets.all(16),

        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,

              decoration:
                  BoxDecoration(
                color:
                    Colors.blue.withValues(
                  alpha: 0.1,
                ),
                shape:
                    BoxShape.circle,
              ),

              child: const Icon(
                Icons.accessibility_new,
                color: Colors.blue,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Text(
                    deviceName,

                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    device.remoteId
                        .toString(),

                    style:
                        const TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    'Signal: ${result.rssi} dBm',

                    style:
                        const TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            ElevatedButton(
              onPressed: isSelected
                  ? null
                  : () {
                      connectDevice(
                        device,
                      );
                    },

              child: Text(
                isSelected
                    ? 'Connected'
                    : 'Connect',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CLEANUP
  // =========================================================

  @override
  void dispose() {
    scanSubscription?.cancel();
    bluetoothService.stopScan();
    bluetoothService.dispose();

    super.dispose();
  }
}