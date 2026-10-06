import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FamilyRequestsScreen extends StatelessWidget {
  const FamilyRequestsScreen({super.key});

  Future<void> _approveRequest(
    BuildContext context,
    String requestId,
    String guardianId,
  ) async {
    final patient = FirebaseAuth.instance.currentUser;

    if (patient == null) {
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      final batch = firestore.batch();

      final requestRef =
          firestore.collection('accessRequests').doc(requestId);

      final familyRef =
          firestore.collection('families').doc();

      batch.set(familyRef, {
        'patientId': patient.uid,
        'guardianId': guardianId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      batch.update(requestRef, {
        'status': 'approved',
        'familyLinkId': familyRef.id,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      batch.set(
        firestore.collection('users').doc(patient.uid),
        {
          'guardianIds': FieldValue.arrayUnion([guardianId]),
        },
        SetOptions(merge: true),
      );

      batch.set(
        firestore.collection('users').doc(guardianId),
        {
          'patientIds': FieldValue.arrayUnion([patient.uid]),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Caregiver access approved.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to approve this request.',
          ),
        ),
      );
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    String requestId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('accessRequests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Caregiver request rejected.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to reject this request.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = FirebaseAuth.instance.currentUser;

    if (patient == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in again.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Requests'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('accessRequests')
            .where(
              'patientId',
              isEqualTo: patient.uid,
            )
            .where(
              'status',
              isEqualTo: 'pending',
            )
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
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load family requests.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.family_restroom,
                      size: 70,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'No Pending Requests',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'When a caregiver requests access using your Family ID, the request will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final data = request.data();

              final guardianId =
                  data['guardianId'] as String? ?? '';

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 16,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.person_add,
                        size: 50,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Caregiver Access Request',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Guardian ID: $guardianId',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _rejectRequest(
                                  context,
                                  request.id,
                                );
                              },
                              child: const Text(
                                'Reject',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                _approveRequest(
                                  context,
                                  request.id,
                                  guardianId,
                                );
                              },
                              child: const Text(
                                'Approve',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}