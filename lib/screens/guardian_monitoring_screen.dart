import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class GuardianMonitoringScreen extends StatelessWidget {
  final String patientId;
  final String patientName;

  const GuardianMonitoringScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  Stream<DocumentSnapshot<Map<String, dynamic>>>
      _walkerStatusStream() {
    return FirebaseFirestore.instance
        .collection('walkerStatus')
        .doc(patientId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      _alertsStream() {
    return FirebaseFirestore.instance
        .collection('alerts')
        .where(
          'patientId',
          isEqualTo: patientId,
        )
        .orderBy(
          'createdAt',
          descending: true,
        )
        .limit(10)
        .snapshots();
  }

  Future<void> _openLocation(
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open Google Maps.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open location.',
          ),
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'SAFE':
        return Colors.green;

      case 'DARK':
      case 'LOW LIGHT':
        return Colors.orange;

      case 'FALL':
      case 'FALL DETECTED':
      case 'SOS':
      case 'SOS ALERT':
        return Colors.red;

      default:
        return Colors.blue;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'SAFE':
        return Icons.shield;

      case 'DARK':
      case 'LOW LIGHT':
        return Icons.light_mode;

      case 'FALL':
      case 'FALL DETECTED':
        return Icons.personal_injury;

      case 'SOS':
      case 'SOS ALERT':
        return Icons.emergency;

      default:
        return Icons.info;
    }
  }

  String _formatLastSeen(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    return 'Not available';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Safety Monitoring',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: _walkerStatusStream(),
        builder: (context, statusSnapshot) {
          if (statusSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (statusSnapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load walker status.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final document = statusSnapshot.data;

          if (document == null || !document.exists) {
            return _NoWalkerData(
              patientName: patientName,
            );
          }

          final data = document.data() ?? {};

          final status =
              data['status']?.toString() ?? 'UNKNOWN';

          final lastEvent =
              data['lastEvent']?.toString() ??
                  'No recent events';

          final battery =
              data['battery']?.toString() ?? 'Unknown';

          final deviceConnected =
              data['deviceConnected'] == true;

          final latitude =
              (data['latitude'] as num?)?.toDouble();

          final longitude =
              (data['longitude'] as num?)?.toDouble();

          final lastSeen =
              _formatLastSeen(data['lastSeen']);

          final statusColor =
              _statusColor(status);

          return StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: _alertsStream(),
            builder: (context, alertSnapshot) {
              final alerts =
                  alertSnapshot.data?.docs ?? [];

              return RefreshIndicator(
                onRefresh: () async {},
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 8),

                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'SafeStride Patient',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 20),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor:
                                  statusColor.withValues(
                                alpha: 0.12,
                              ),
                              child: Icon(
                                _statusIcon(status),
                                size: 48,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              lastEvent,
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

                    if (alerts.isNotEmpty)
                      _LatestAlertBanner(
                        alert: alerts.first.data(),
                      ),

                    if (alerts.isNotEmpty)
                      const SizedBox(height: 16),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.notifications_active,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Safety Alerts',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (alertSnapshot.hasError)
                              const Text(
                                'Unable to load alert history.',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              )
                            else if (alerts.isEmpty)
                              const Text(
                                'No safety alerts recorded.',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              )
                            else
                              ...alerts.map(
                                (alertDocument) {
                                  return _AlertTile(
                                    alert: alertDocument.data(),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _StatusCard(
                            icon: Icons.battery_full,
                            title: 'Battery',
                            value: battery == 'Unknown'
                                ? 'Unknown'
                                : '$battery%',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatusCard(
                            icon: Icons.bluetooth,
                            title: 'Walker',
                            value: deviceConnected
                                ? 'Connected'
                                : 'Offline',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _StatusCard(
                      icon: Icons.access_time,
                      title: 'Last Seen',
                      value: lastSeen,
                    ),

                    const SizedBox(height: 16),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Current Location',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (latitude == null ||
                                longitude == null)
                              const Text(
                                'GPS location is not available.',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              )
                            else ...[
                              Text(
                                'Latitude: $latitude',
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Longitude: $longitude',
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _openLocation(
                                      context,
                                      latitude,
                                      longitude,
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.map,
                                  ),
                                  label: const Text(
                                    'Open in Google Maps',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Card(
                      child: ListTile(
                        leading: Icon(
                          _statusIcon(status),
                          color: statusColor,
                        ),
                        title: const Text(
                          'Latest Safety Event',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          lastEvent,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.security,
                        ),
                        title: const Text(
                          'Private Monitoring',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'You can see this information because the patient approved caregiver access.',
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LatestAlertBanner extends StatelessWidget {
  final Map<String, dynamic> alert;

  const _LatestAlertBanner({
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    final type =
        alert['type']?.toString() ?? 'ALERT';

    final message =
        alert['message']?.toString() ??
            'Safety alert received.';

    final color =
        type == 'SOS' ? Colors.red : Colors.orange;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              type == 'SOS'
                  ? Icons.emergency
                  : Icons.warning_rounded,
              size: 50,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              type == 'SOS'
                  ? 'EMERGENCY SOS'
                  : 'FALL ALERT',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final Map<String, dynamic> alert;

  const _AlertTile({
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    final type =
        alert['type']?.toString() ?? 'ALERT';

    final message =
        alert['message']?.toString() ??
            'Safety alert received.';

    final timestamp =
        alert['createdAt'];

    final color =
        type == 'SOS' ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(
          alpha: 0.08,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            type == 'SOS'
                ? Icons.emergency
                : Icons.warning_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    }

    return 'Just now';
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoWalkerData extends StatelessWidget {
  final String patientName;

  const _NoWalkerData({
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.directions_walk,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              patientName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Walker monitoring data has not been received yet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}