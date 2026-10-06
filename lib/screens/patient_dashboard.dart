import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/bluetooth_service.dart';
import '../services/walker_firestore_service.dart';
import 'family_requests_screen.dart';

class PatientDashboard extends StatefulWidget {
  final dynamic device;

  const PatientDashboard({
    super.key,
    required this.device,
  });

  @override
  State<PatientDashboard> createState() =>
      _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final SafeStrideBluetoothService _bluetoothService =
      SafeStrideBluetoothService();

  final WalkerFirestoreService _firestoreService =
      WalkerFirestoreService();

  StreamSubscription<String>? _statusSubscription;
  StreamSubscription<dynamic>? _connectionSubscription;

  bool _connected = false;
  bool _monitoring = true;

  String _status = 'SAFE';
  String _lastEvent = 'No recent events';

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();

    _checkInitialConnection();
    _startListening();
  }

  Future<void> _checkInitialConnection() async {
    try {
      final connected = widget.device.isConnected;

      if (!mounted) return;

      setState(() {
        _connected = connected;
      });

      await _syncConnectionToFirebase(connected);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _connected = false;
      });

      await _syncConnectionToFirebase(false);
    }
  }

  Future<void> _syncConnectionToFirebase(
    bool connected,
  ) async {
    final patient = FirebaseAuth.instance.currentUser;

    if (patient == null) {
      return;
    }

    try {
      await _firestoreService.updateConnection(
        patientId: patient.uid,
        connected: connected,
      );
    } catch (_) {
      // Firebase synchronization failure should not
      // interrupt the local walker connection.
    }
  }

  Future<void> _startListening() async {
    try {
      await _bluetoothService.setupNotifications(
        widget.device,
      );

      _statusSubscription =
          _bluetoothService.statusStream.listen(
        _handleWalkerMessage,
      );

      _connectionSubscription =
          widget.device.connectionState.listen(
        (state) {
          if (!mounted) return;

          final connected =
              state.toString().contains('connected');

          setState(() {
            _connected = connected;
          });

          _syncConnectionToFirebase(connected);
        },
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _connected = false;
      });

      await _syncConnectionToFirebase(false);
    }
  }

  Future<void> _handleWalkerMessage(
    String message,
  ) async {
    if (!mounted) return;

    final trimmedMessage = message.trim();

    if (trimmedMessage.isEmpty) {
      return;
    }

    final patient = FirebaseAuth.instance.currentUser;

    if (patient == null) {
      return;
    }

    /*
     * GPS message format:
     *
     * GPS,latitude,longitude
     */
    if (trimmedMessage.startsWith('GPS,')) {
      final parts = trimmedMessage.split(',');

      if (parts.length >= 3) {
        final lat = double.tryParse(parts[1]);
        final lng = double.tryParse(parts[2]);

        if (lat != null && lng != null) {
          if (!mounted) return;

          setState(() {
            _latitude = lat;
            _longitude = lng;
            _lastEvent = 'GPS location updated';
          });

          try {
            await _firestoreService.updateLocation(
              patientId: patient.uid,
              latitude: lat,
              longitude: lng,
            );
          } catch (_) {
            // Keep local GPS functionality working even
            // if Firebase synchronization fails.
          }
        }
      }

      return;
    }

    String newStatus = _status;

    switch (trimmedMessage) {
      case 'SAFE':
        newStatus = 'SAFE';
        break;

      case 'FALL':
        newStatus = 'FALL DETECTED';
        break;

      case 'SOS':
        newStatus = 'SOS ALERT';
        break;

      case 'DARK':
        newStatus = 'LOW LIGHT';
        break;

      default:
        newStatus = _status;
        break;
    }

    if (!mounted) return;

    setState(() {
      _status = newStatus;
      _lastEvent = trimmedMessage;
    });

    try {
      await _firestoreService.updateWalkerStatus(
        patientId: patient.uid,
        status: newStatus,
        lastEvent: trimmedMessage,
        latitude: _latitude,
        longitude: _longitude,
        deviceConnected: _connected,
      );
    } catch (_) {
      // Keep local walker functionality working even
      // if Firebase synchronization fails.
    }
  }

  Future<void> _findMyWalker() async {
    try {
      await _bluetoothService.sendCommand('FIND');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Find My Walker command sent.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Walker is not connected.',
          ),
        ),
      );
    }
  }

  Future<void> _openLocation() async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'GPS location is not available yet.',
          ),
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open Google Maps.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open location.',
          ),
        ),
      );
    }
  }

  void _openFamilyRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FamilyRequestsScreen(),
      ),
    );
  }

  void _emergencySOS() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Emergency SOS feature will be connected next.',
        ),
      ),
    );
  }

  void _openSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Settings will be added next.',
        ),
      ),
    );
  }

  void _openSafetyMonitoring() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Safety monitoring is active.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }

  Color _statusColor() {
    if (_status == 'SAFE') {
      return Colors.green;
    }

    if (_status == 'LOW LIGHT') {
      return Colors.orange;
    }

    return Colors.red;
  }

  String _statusDescription() {
    switch (_status) {
      case 'SAFE':
        return 'No safety events detected.';

      case 'FALL DETECTED':
        return 'A possible fall was detected.';

      case 'SOS ALERT':
        return 'Emergency SOS has been triggered.';

      case 'LOW LIGHT':
        return 'Low-light conditions detected.';

      default:
        return 'Walker safety status updated.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SafeStride',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.family_restroom,
            ),
            tooltip: 'Family Requests',
            onPressed: _openFamilyRequests,
          ),
          IconButton(
            icon: const Icon(
              Icons.settings,
            ),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _checkInitialConnection,
          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          child: Icon(
                            _connected
                                ? Icons.bluetooth_connected
                                : Icons.bluetooth_disabled,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _connected
                                    ? 'Walker Connected'
                                    : 'Walker Disconnected',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _connected
                                    ? 'SafeStride Walker is connected.'
                                    : 'Connect your SafeStride Walker.',
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor:
                              _statusColor().withValues(
                            alpha: 0.12,
                          ),
                          child: Icon(
                            _status == 'SAFE'
                                ? Icons.shield
                                : Icons.warning_rounded,
                            size: 48,
                            color: _statusColor(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _status,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                            color: _statusColor(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusDescription(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latest Event',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _lastEvent,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _infoCard(
                        icon: Icons.battery_full,
                        title: 'Battery',
                        value: '85%',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoCard(
                        icon: Icons.bluetooth,
                        title: 'Bluetooth',
                        value: _connected
                            ? 'Connected'
                            : 'Offline',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _infoCard(
                        icon: Icons.location_on,
                        title: 'GPS',
                        value: _latitude != null
                            ? 'Available'
                            : 'Waiting',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoCard(
                        icon: Icons.monitor_heart,
                        title: 'Monitoring',
                        value: _monitoring
                            ? 'Active'
                            : 'Paused',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed:
                        _connected ? _findMyWalker : null,
                    icon: const Icon(
                      Icons.search,
                    ),
                    label: const Text(
                      'Find My Walker',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _latitude != null
                        ? _openLocation
                        : null,
                    icon: const Icon(
                      Icons.location_on,
                    ),
                    label: const Text(
                      'View Walker Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _openFamilyRequests,
                    icon: const Icon(
                      Icons.family_restroom,
                    ),
                    label: const Text(
                      'Family Requests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _emergencySOS,
                    icon: const Icon(
                      Icons.emergency,
                    ),
                    label: const Text(
                      'Emergency SOS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.health_and_safety,
                    ),
                    title: const Text(
                      'Safety Monitoring',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      _monitoring
                          ? 'Safety monitoring is active.'
                          : 'Safety monitoring is paused.',
                    ),
                    trailing: Switch(
                      value: _monitoring,
                      onChanged: (value) {
                        setState(() {
                          _monitoring = value;
                        });

                        _openSafetyMonitoring();
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connected Walker',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'SafeStride Walker',
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Device: ${widget.device.remoteId}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}