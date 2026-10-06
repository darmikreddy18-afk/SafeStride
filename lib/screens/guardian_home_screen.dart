import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'guardian_dashboard.dart';
import 'guardian_family_screen.dart';

class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  State<GuardianHomeScreen> createState() =>
      _GuardianHomeScreenState();
}

class _GuardianHomeScreenState
    extends State<GuardianHomeScreen> {
  StreamSubscription<
          DocumentSnapshot<Map<String, dynamic>>>?
      _guardianSubscription;

  bool _openingDashboard = false;
  bool _hasHandledExistingConnection = false;

  @override
  void initState() {
    super.initState();
    _listenForFamilyConnection();
  }

  void _listenForFamilyConnection() {
    final guardian = FirebaseAuth.instance.currentUser;

    if (guardian == null) {
      return;
    }

    _guardianSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(guardian.uid)
        .snapshots()
        .listen((snapshot) {
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
        return;
      }

      // Prevent automatically opening the dashboard again
      // every time the guardian document changes.
      if (_hasHandledExistingConnection) {
        return;
      }

      _hasHandledExistingConnection = true;

      _openDashboard();
    });
  }

  Future<void> _openDashboard() async {
    if (!mounted || _openingDashboard) {
      return;
    }

    _openingDashboard = true;

    // Give Firestore/UI a moment to finish updating.
    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) {
      return;
    }

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const GuardianDashboard(),
      ),
    );
  }

  @override
  void dispose() {
    _guardianSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guardian = FirebaseAuth.instance.currentUser;

    if (guardian == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please log in again.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SafeStride Caregiver',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(guardian.uid)
            .snapshots(),
        builder: (context, snapshot) {
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

          final data = snapshot.data?.data();

          final patientIds =
              (data?['patientIds'] as List?)
                      ?.whereType<String>()
                      .toList() ??
                  [];

          final connectedCount = patientIds.length;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 30),

                  const Icon(
                    Icons.family_restroom,
                    size: 80,
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Caregiver Home',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Connect with a SafeStride user and monitor their safety information.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            connectedCount > 0
                                ? Icons.check_circle
                                : Icons.person_add,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            connectedCount == 0
                                ? 'No Family Members Connected'
                                : '$connectedCount Family Member'
                                    '${connectedCount == 1 ? '' : 's'} Connected',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            connectedCount == 0
                                ? 'Connect using a Family ID to begin monitoring.'
                                : 'Connection approved. Opening live monitoring...',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
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
                        Icons.family_restroom,
                      ),
                      label: const Text(
                        'Connect to Family',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: connectedCount == 0
                          ? null
                          : _openDashboard,
                      icon: const Icon(
                        Icons.dashboard,
                      ),
                      label: const Text(
                        'Open Caregiver Dashboard',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: const [
                          Icon(
                            Icons.privacy_tip_outlined,
                            size: 32,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Privacy & Safety',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Patient safety information is shared only after the patient approves the caregiver access request.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}