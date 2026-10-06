import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'guardian_dashboard.dart';

class GuardianFamilyScreen extends StatefulWidget {
  const GuardianFamilyScreen({super.key});

  @override
  State<GuardianFamilyScreen> createState() =>
      _GuardianFamilyScreenState();
}

class _GuardianFamilyScreenState
    extends State<GuardianFamilyScreen> {
  final TextEditingController _familyIdController =
      TextEditingController();

  bool _loading = false;
  String? _errorMessage;
  String? _successMessage;

  DocumentSnapshot<Map<String, dynamic>>? _patient;

  @override
  void dispose() {
    _familyIdController.dispose();
    super.dispose();
  }

  Future<void> _findPatient() async {
    final familyId =
        _familyIdController.text.trim().toUpperCase();

    if (familyId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a Family ID.';
        _successMessage = null;
        _patient = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
      _patient = null;
    });

    try {
      final guardian =
          FirebaseAuth.instance.currentUser;

      if (guardian == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Please log in again.';
          });
        }
        return;
      }

      final query = await FirebaseFirestore.instance
          .collection('users')
          .where(
            'familyId',
            isEqualTo: familyId,
          )
          .where(
            'role',
            isEqualTo: 'patient',
          )
          .limit(1)
          .get();

      if (!mounted) return;

      if (query.docs.isEmpty) {
        setState(() {
          _errorMessage =
              'No SafeStride patient was found with this Family ID.';
        });
        return;
      }

      final patient = query.docs.first;

      if (patient.id == guardian.uid) {
        setState(() {
          _errorMessage =
              'You cannot connect to your own account.';
        });
        return;
      }

      final guardianDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(guardian.uid)
              .get();

      if (!mounted) return;

      final guardianData = guardianDoc.data();

      final patientIds =
          (guardianData?['patientIds'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              [];

      if (patientIds.contains(patient.id)) {
        setState(() {
          _patient = patient;
          _successMessage =
              'This patient is already connected to your account.';
        });
        return;
      }

      setState(() {
        _patient = patient;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Unable to search right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _requestAccess() async {
    final patient = _patient;

    if (patient == null) {
      return;
    }

    final guardian =
        FirebaseAuth.instance.currentUser;

    if (guardian == null) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Please log in again.';
        _successMessage = null;
      });

      return;
    }

    try {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _successMessage = null;
      });

      final firestore = FirebaseFirestore.instance;

      // Check whether this patient is already connected.
      final guardianDoc = await firestore
          .collection('users')
          .doc(guardian.uid)
          .get();

      final guardianData = guardianDoc.data();

      final patientIds =
          (guardianData?['patientIds'] as List?)
                  ?.whereType<String>()
                  .toList() ??
              [];

      if (patientIds.contains(patient.id)) {
        if (!mounted) return;

        // Already connected, so go directly to dashboard.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const GuardianDashboard(),
          ),
        );

        return;
      }

      // Check for an existing pending request.
      final existingRequests = await firestore
          .collection('accessRequests')
          .where(
            'patientId',
            isEqualTo: patient.id,
          )
          .where(
            'guardianId',
            isEqualTo: guardian.uid,
          )
          .where(
            'status',
            isEqualTo: 'pending',
          )
          .limit(1)
          .get();

      if (!mounted) return;

      if (existingRequests.docs.isNotEmpty) {
        // Request already exists.
        // Return to dashboard where the caregiver can wait
        // for patient approval.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const GuardianDashboard(),
          ),
        );

        return;
      }

      // Create the access request.
      await firestore
          .collection('accessRequests')
          .add({
        'patientId': patient.id,
        'guardianId': guardian.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Return to Guardian Dashboard.
      //
      // GuardianDashboard listens to:
      // users/{guardianUid}.patientIds
      //
      // When the patient approves the request,
      // patientIds will change and the dashboard will
      // automatically rebuild and show the patient.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const GuardianDashboard(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Could not send the access request.\n\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientData = _patient?.data();

    final isAlreadyConnected =
        _successMessage?.contains(
              'already connected',
            ) ??
            false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Connect to Family',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              const Icon(
                Icons.family_restroom,
                size: 70,
              ),

              const SizedBox(height: 24),

              const Text(
                'Connect to a SafeStride User',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Enter the Family ID shared by the patient '
                'to find their SafeStride account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 32),

              TextField(
                controller: _familyIdController,
                textCapitalization:
                    TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Family ID',
                  hintText: 'Example: SS-7K4P92',
                  prefixIcon: const Icon(
                    Icons.family_restroom,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      _loading ? null : _findPatient,
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child:
                              CircularProgressIndicator(),
                        )
                      : const Text(
                          'Find Patient',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 20),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                  ),
                ),
              ],

              if (_successMessage != null) ...[
                const SizedBox(height: 20),
                Text(
                  _successMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              if (_patient != null) ...[
                const SizedBox(height: 30),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 55,
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          'Patient Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          patientData?['name'] ??
                              'SafeStride User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 6),

                        const Text(
                          'SafeStride Walker',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Family ID: '
                          '${patientData?['familyId'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (!isAlreadyConnected)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child:
                                ElevatedButton.icon(
                              onPressed:
                                  _loading
                                      ? null
                                      : _requestAccess,
                              icon: const Icon(
                                Icons.person_add,
                              ),
                              label: const Text(
                                'Request Access',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              const Text(
                'Privacy & Safety',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'The patient will need to approve access '
                'before their location and safety information '
                'is shared with you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}