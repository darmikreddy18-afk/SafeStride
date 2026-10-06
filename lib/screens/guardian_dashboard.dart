import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'guardian_family_screen.dart';
import 'guardian_monitoring_screen.dart';

class GuardianDashboard extends StatefulWidget {
  const GuardianDashboard({super.key});

  @override
  State<GuardianDashboard> createState() =>
      _GuardianDashboardState();
}

class _GuardianDashboardState extends State<GuardianDashboard> {
  String? _lastKnownPatientId;
  bool _showConnecting = false;
  String? _approvedPatientName;

  StreamSubscription<
      DocumentSnapshot<Map<String, dynamic>>>?
      _guardianSubscription;

  @override
  void initState() {
    super.initState();
    _startGuardianListener();
  }

  void _startGuardianListener() {
    final guardian =
        FirebaseAuth.instance.currentUser;

    if (guardian == null) {
      return;
    }

    _guardianSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(guardian.uid)
        .snapshots()
        .listen(_handleGuardianUpdate);
  }

  Future<void> _handleGuardianUpdate(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) async {
    if (!snapshot.exists) {
      return;
    }

    final data = snapshot.data();

    final patientIds =
        (data?['patientIds'] as List?)
                ?.whereType<String>()
                .toList() ??
            [];

    if (patientIds.isEmpty) {
      if (!mounted) return;

      setState(() {
        _lastKnownPatientId = null;
        _showConnecting = false;
        _approvedPatientName = null;
      });

      return;
    }

    final newestPatientId = patientIds.last;

    // First connection detected.
    if (_lastKnownPatientId == null) {
      _lastKnownPatientId = newestPatientId;

      await _showApprovalScreen(
        newestPatientId,
      );

      return;
    }

    // A new patient was added.
    if (_lastKnownPatientId != newestPatientId) {
      _lastKnownPatientId = newestPatientId;

      await _showApprovalScreen(
        newestPatientId,
      );
    }
  }

  Future<void> _showApprovalScreen(
    String patientId,
  ) async {
    try {
      final patientSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(patientId)
              .get();

      final patientData =
          patientSnapshot.data();

      final patientName =
          patientData?['name']?.toString() ??
              'SafeStride Patient';

      if (!mounted) return;

      setState(() {
        _approvedPatientName = patientName;
        _showConnecting = true;
      });

      // Give the user time to see the approval
      // and connection screen.
      await Future.delayed(
        const Duration(seconds: 3),
      );

      if (!mounted) return;

      setState(() {
        _showConnecting = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _showConnecting = false;
      });
    }
  }

  @override
  void dispose() {
    _guardianSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showConnecting) {
      return _AccessApprovedScreen(
        patientName:
            _approvedPatientName ??
                'SafeStride Patient',
      );
    }

    final guardian =
        FirebaseAuth.instance.currentUser;

    if (guardian == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in again.',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F8FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'SafeStride',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Family',
            icon: const Icon(
              Icons.family_restroom,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const GuardianFamilyScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(
              Icons.settings,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'Settings will be added next.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(guardian.uid)
            .snapshots(),
        builder: (
          context,
          snapshot,
        ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Unable to load caregiver information.',
              ),
            );
          }

          final data =
              snapshot.data?.data();

          final patientIds =
              (data?['patientIds'] as List?)
                      ?.whereType<String>()
                      .toList() ??
                  [];

          if (patientIds.isEmpty) {
            return _NoPatientView(
              onConnect: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const GuardianFamilyScreen(),
                  ),
                );
              },
            );
          }

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(guardian.uid)
                    .get();
              },
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),

                  const Text(
                    'Guardian Dashboard',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    patientIds.length == 1
                        ? 'Monitoring 1 family member'
                        : 'Monitoring ${patientIds.length} family members',
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 18),

                  ...patientIds.map(
                    (patientId) => Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 18,
                      ),
                      child: _PatientDashboardCard(
                        patientId: patientId,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  SizedBox(
                    height: 52,
                    child:
                        OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const GuardianFamilyScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.person_add_alt_1,
                      ),
                      label: const Text(
                        'Add Family Member',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      style:
                          OutlinedButton.styleFrom(
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// ACCESS APPROVED SCREEN
// ============================================================

class _AccessApprovedScreen
    extends StatefulWidget {
  final String patientName;

  const _AccessApprovedScreen({
    required this.patientName,
  });

  @override
  State<_AccessApprovedScreen> createState() =>
      _AccessApprovedScreenState();
}

class _AccessApprovedScreenState
    extends State<_AccessApprovedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController
      _animationController;

  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F8FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 105,
                  height: 105,
                  decoration: BoxDecoration(
                    color:
                        Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 70,
                    color:
                        Colors.green.shade600,
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  'Access Approved',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Approved by ${widget.patientName}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Colors.grey.shade800,
                  ),
                ),

                const SizedBox(height: 30),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(
                          alpha: 0.05,
                        ),
                        blurRadius: 15,
                        offset:
                            const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      RotationTransition(
                        turns:
                            _animationController,
                        child:
                            const CircularProgressIndicator(),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Connecting to family...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Connecting you to ${widget.patientName}\'s SafeStride family.',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color: Colors
                              .grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_user,
                      size: 18,
                      color:
                          Colors.green.shade700,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Family access secured',
                      style: TextStyle(
                        color:
                            Colors.green.shade700,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PATIENT DASHBOARD CARD
// ============================================================

class _PatientDashboardCard
    extends StatelessWidget {
  final String patientId;

  const _PatientDashboardCard({
    required this.patientId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .snapshots(),
      builder: (
        context,
        patientSnapshot,
      ) {
        if (patientSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (!patientSnapshot.hasData ||
            !patientSnapshot.data!.exists) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Patient information unavailable.',
              ),
            ),
          );
        }

        final patient =
            patientSnapshot.data!.data()!;

        final name =
            patient['name']?.toString() ??
                'SafeStride Patient';

        final mobile =
            patient['mobile']?.toString() ??
                'Not available';

        final familyId =
            patient['familyId']?.toString() ??
                'Not available';

        final deviceName =
            patient['deviceName']?.toString() ??
                'SafeStride Walker';

        return StreamBuilder<
            DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('walkerStatus')
              .doc(patientId)
              .snapshots(),
          builder: (
            context,
            statusSnapshot,
          ) {
            final walkerStatus =
                statusSnapshot.data?.data();

            return _PatientContent(
              patientId: patientId,
              name: name,
              mobile: mobile,
              familyId: familyId,
              deviceName: deviceName,
              walkerStatus: walkerStatus,
            );
          },
        );
      },
    );
  }
}

// ============================================================
// PATIENT CONTENT
// ============================================================

class _PatientContent extends StatelessWidget {
  final String patientId;
  final String name;
  final String mobile;
  final String familyId;
  final String deviceName;
  final Map<String, dynamic>? walkerStatus;

  const _PatientContent({
    required this.patientId,
    required this.name,
    required this.mobile,
    required this.familyId,
    required this.deviceName,
    required this.walkerStatus,
  });

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  String _lastSeen(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      final difference =
          DateTime.now().difference(date);

      if (difference.inSeconds < 60) {
        return 'Just now';
      }

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      }

      if (difference.inHours < 24) {
        return '${difference.inHours} hr ago';
      }

      return '${date.day}/${date.month}/${date.year}';
    }

    return 'No data';
  }

  @override
  Widget build(BuildContext context) {
    final connected =
        walkerStatus?['deviceConnected'] ==
            true;

    final status =
        walkerStatus?['status']?.toString() ??
            'SAFE';

    final lastEvent =
        walkerStatus?['lastEvent']?.toString() ??
            'No recent events';

    final batteryValue =
        walkerStatus?['battery'];

    final battery = batteryValue is num
        ? batteryValue.toInt()
        : null;

    final latitude =
        _toDouble(
      walkerStatus?['latitude'],
    );

    final longitude =
        _toDouble(
      walkerStatus?['longitude'],
    );

    final emergency =
        status.toUpperCase().contains('FALL') ||
        status.toUpperCase().contains('SOS') ||
        status
            .toUpperCase()
            .contains('EMERGENCY');

    Color statusColor;

    if (status == 'SAFE') {
      statusColor = Colors.green;
    } else if (status == 'LOW LIGHT') {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            // --------------------------------------------------
            // PATIENT HEADER
            // --------------------------------------------------

            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      Colors.blue.shade50,
                  child: Icon(
                    Icons.person,
                    size: 32,
                    color:
                        Colors.blue.shade700,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style:
                            const TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Connected Family Member',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.verified,
                  color:
                      Colors.green.shade600,
                ),
              ],
            ),

            const SizedBox(height: 18),

            // --------------------------------------------------
            // WALKER CONNECTION
            // --------------------------------------------------

            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: connected
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius:
                    BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,
                      color: connected
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      connected
                          ? 'Walker Connected'
                          : 'Walker Disconnected',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w600,
                        color: connected
                            ? Colors.green
                                .shade800
                            : Colors.orange
                                .shade800,
                      ),
                    ),
                  ),
                  Icon(
                    connected
                        ? Icons
                            .bluetooth_connected
                        : Icons
                            .bluetooth_disabled,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // SAFETY STATUS
            // --------------------------------------------------

            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: emergency
                  ? Colors.red.shade50
                  : Colors.grey.shade50,
              child: Padding(
                padding:
                    const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 35,
                      backgroundColor:
                          statusColor.withValues(
                        alpha: 0.12,
                      ),
                      child: Icon(
                        status == 'SAFE'
                            ? Icons.shield
                            : Icons
                                .warning_rounded,
                        size: 40,
                        color: statusColor,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight:
                            FontWeight.bold,
                        color: statusColor,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      emergency
                          ? 'Immediate attention may be required.'
                          : status == 'SAFE'
                              ? 'No safety events detected.'
                              : 'Walker safety status updated.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // --------------------------------------------------
            // BATTERY / LAST SEEN
            // --------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: _SmallInfoCard(
                    icon:
                        Icons.battery_full,
                    title: 'Battery',
                    value: battery != null
                        ? '$battery%'
                        : '--',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SmallInfoCard(
                    icon:
                        Icons.access_time,
                    title: 'Last Seen',
                    value: _lastSeen(
                      walkerStatus?[
                          'lastSeen'],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // LATEST EVENT
            // --------------------------------------------------

            Container(
              padding:
                  const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: emergency
                    ? Colors.red.shade50
                    : Colors.white,
                borderRadius:
                    BorderRadius.circular(15),
                border: Border.all(
                  color: emergency
                      ? Colors.red.shade300
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    emergency
                        ? Icons
                            .warning_amber_rounded
                        : Icons
                            .notifications_none,
                    color: emergency
                        ? Colors.red.shade700
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Latest Event',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 4,
                        ),
                        Text(lastEvent),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // PATIENT DETAILS
            // --------------------------------------------------

            _InfoRow(
              icon: Icons.phone,
              label: 'Mobile',
              value: mobile,
            ),

            const SizedBox(height: 10),

            _InfoRow(
              icon:
                  Icons.directions_walk,
              label: 'Device',
              value: deviceName,
            ),

            const SizedBox(height: 10),

            _InfoRow(
              icon:
                  Icons.family_restroom,
              label: 'Family ID',
              value: familyId,
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // LOCATION
            // --------------------------------------------------

            _LocationCard(
              latitude: latitude,
              longitude: longitude,
            ),

            const SizedBox(height: 16),

            // --------------------------------------------------
            // MONITOR
            // --------------------------------------------------

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          GuardianMonitoringScreen(
                        patientId: patientId,
                        patientName: name,
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.monitor_heart,
                ),
                label: const Text(
                  'Monitor Patient',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                style:
                    ElevatedButton.styleFrom(
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 11,
                horizontal: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 20,
                    color:
                        Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Family access approved',
                      style: TextStyle(
                        color: Colors
                            .green.shade800,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SMALL INFO CARD
// ============================================================

class _SmallInfoCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SmallInfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 27,
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INFO ROW
// ============================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 75,
          child: Text(
            label,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// LOCATION CARD
// ============================================================

class _LocationCard
    extends StatelessWidget {
  final double? latitude;
  final double? longitude;

  const _LocationCard({
    required this.latitude,
    required this.longitude,
  });

  Future<void> _openMaps(
    BuildContext context,
  ) async {
    if (latitude == null ||
        longitude == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Patient GPS location is not available yet.',
          ),
        ),
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=$latitude,$longitude',
    );

    try {
      final opened = await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );

      if (!opened &&
          context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open Google Maps.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open location.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final available =
        latitude != null &&
            longitude != null;

    return InkWell(
      onTap: available
          ? () => _openMaps(context)
          : null,
      borderRadius:
          BorderRadius.circular(16),
      child: Container(
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: available
              ? Colors.blue.shade50
              : Colors.grey.shade50,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: available
                ? Colors.blue.shade200
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: available
                    ? Colors.blue.shade100
                    : Colors.grey.shade200,
                borderRadius:
                    BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.location_on,
                color: available
                    ? Colors.blue.shade700
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    available
                        ? 'Patient Location'
                        : 'Location Unavailable',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    available
                        ? '${latitude!.toStringAsFixed(5)}, '
                          '${longitude!.toStringAsFixed(5)}'
                        : 'Waiting for GPS location',
                    style: TextStyle(
                      color:
                          Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (available)
              const Icon(
                Icons.open_in_new,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// NO PATIENT
// ============================================================

class _NoPatientView
    extends StatelessWidget {
  final VoidCallback onConnect;

  const _NoPatientView({
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(26),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color:
                      Colors.blue.shade50,
                  shape:
                      BoxShape.circle,
                ),
                child: Icon(
                  Icons.family_restroom,
                  size: 52,
                  color:
                      Colors.blue.shade700,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Welcome to SafeStride',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Connect with a family member using their SafeStride Family ID.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child:
                    ElevatedButton.icon(
                  onPressed: onConnect,
                  icon: const Icon(
                    Icons.person_add_alt_1,
                  ),
                  label: const Text(
                    'Connect to Family',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}