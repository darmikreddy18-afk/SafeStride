import 'package:cloud_firestore/cloud_firestore.dart';

class WalkerFirestoreService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> updateWalkerStatus({
    required String patientId,
    required String status,
    String? lastEvent,
    double? latitude,
    double? longitude,
    int? battery,
    bool? deviceConnected,
  }) async {
    final data = <String, dynamic>{
      'patientId': patientId,
      'status': status,
      'lastSeen': FieldValue.serverTimestamp(),
    };

    if (lastEvent != null) {
      data['lastEvent'] = lastEvent;
    }

    if (latitude != null) {
      data['latitude'] = latitude;
    }

    if (longitude != null) {
      data['longitude'] = longitude;
    }

    if (battery != null) {
      data['battery'] = battery;
    }

    if (deviceConnected != null) {
      data['deviceConnected'] = deviceConnected;
    }

    await _firestore
        .collection('walkerStatus')
        .doc(patientId)
        .set(
          data,
          SetOptions(merge: true),
        );
  }

  Future<void> updateLocation({
    required String patientId,
    required double latitude,
    required double longitude,
  }) async {
    await _firestore
        .collection('walkerStatus')
        .doc(patientId)
        .set(
          {
            'patientId': patientId,
            'latitude': latitude,
            'longitude': longitude,
            'lastSeen': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  Future<void> updateConnection({
    required String patientId,
    required bool connected,
  }) async {
    await _firestore
        .collection('walkerStatus')
        .doc(patientId)
        .set(
          {
            'patientId': patientId,
            'deviceConnected': connected,
            'lastSeen': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  Future<void> createAlert({
    required String patientId,
    required String alertType,
    required String message,
    double? latitude,
    double? longitude,
  }) async {
    await _firestore.collection('alerts').add({
      'patientId': patientId,
      'type': alertType,
      'message': message,
      'latitude': latitude,
      'longitude': longitude,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}