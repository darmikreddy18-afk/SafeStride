const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

exports.sendEmergencyNotification = onDocumentCreated(
    "alerts/{alertId}",
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        return;
      }

      const alert = snapshot.data();

      const patientId = alert.patientId;
      const alertType = alert.type;
      const message =
      alert.message || "SafeStride safety alert.";

      if (!patientId) {
        console.log("Alert has no patientId.");
        return;
      }

      if (alertType !== "SOS" && alertType !== "FALL") {
        console.log(
            `Ignoring non-emergency alert: ${alertType}`,
        );
        return;
      }

      const patientSnapshot = await db
          .collection("users")
          .doc(patientId)
          .get();

      if (!patientSnapshot.exists) {
        console.log("Patient account not found.");
        return;
      }

      const patientData = patientSnapshot.data() || {};

      const guardianIds =
      Array.isArray(patientData.guardianIds) ?
        patientData.guardianIds :
        [];

      if (guardianIds.length === 0) {
        console.log("No approved caregivers found.");
        return;
      }

      const tokens = [];

      for (const guardianId of guardianIds) {
        const guardianSnapshot = await db
            .collection("users")
            .doc(guardianId)
            .get();

        if (!guardianSnapshot.exists) {
          continue;
        }

        const guardianData =
        guardianSnapshot.data() || {};

        const token = guardianData.fcmToken;

        if (typeof token === "string" && token.length > 0) {
          tokens.push(token);
        }
      }

      if (tokens.length === 0) {
        console.log(
            "No caregiver FCM tokens available.",
        );
        return;
      }

      const title =
      alertType === "SOS" ?
        "🚨 SafeStride Emergency SOS" :
        "⚠️ SafeStride Fall Alert";

      const response =
      await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title,
          body: message,
        },
        data: {
          alertType: alertType,
          patientId: patientId,
          alertId: event.params.alertId,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "safestride_alerts",
            sound: "default",
          },
        },
      });

      console.log(
          `Notifications sent: ${response.successCount}`,
      );

      console.log(
          `Notifications failed: ${response.failureCount}`,
      );
    },
);
