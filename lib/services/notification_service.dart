import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class SafeStrideNotificationService {
  final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Future<void> initialize() async {
    try {
      final settings =
          await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        debugPrint(
          'Notification permission: '
          '${settings.authorizationStatus}',
        );
      }

      await saveToken();

      FirebaseMessaging.instance.onTokenRefresh.listen(
        (newToken) async {
          await _saveTokenToFirestore(newToken);

          if (kDebugMode) {
            debugPrint(
              'SafeStride FCM token refreshed.',
            );
          }
        },
      );

      FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          if (kDebugMode) {
            debugPrint(
              'SafeStride notification received.',
            );
            debugPrint(
              'Title: ${message.notification?.title}',
            );
            debugPrint(
              'Body: ${message.notification?.body}',
            );
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Notification initialization failed: $e',
        );
      }
    }
  }

  Future<void> saveToken() async {
    try {
      final token = await _messaging.getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      await _saveTokenToFirestore(token);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Unable to save FCM token: $e',
        );
      }
    }
  }

  Future<void> _saveTokenToFirestore(
    String token,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(
      {
        'fcmToken': token,
        'fcmTokenUpdatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Unable to get FCM token: $e',
        );
      }

      return null;
    }
  }
}