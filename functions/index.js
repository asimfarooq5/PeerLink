const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

/**
 * Sends an FCM push notification whenever a wakeup or offer signaling
 * message is written for a user.  This wakes the receiving device so it
 * can answer the WebRTC offer and establish the data channel.
 */
exports.sendChatNotification = onDocumentCreated(
  'signaling/{userId}/messages/{messageId}',
  async (event) => {
    const message = event.data.data();
    const receiverId = event.params.userId;

    // Only react to wakeup signals — the initial knock from the caller
    if (message.type !== 'wakeup') return null;

    try {
      // Fetch receiver FCM token
      const userSnap = await getFirestore().collection('users').doc(receiverId).get();
      const fcmToken = userSnap.data()?.fcmToken;
      if (!fcmToken) return null;

      // Fetch sender display name
      const senderSnap = await getFirestore()
        .collection('users')
        .doc(message.senderId)
        .get();
      const senderName =
        senderSnap.data()?.displayName ||
        senderSnap.data()?.username ||
        'Someone';

      await getMessaging().send({
        token: fcmToken,
        notification: {
          title: `${senderName} wants to chat`,
          body: 'Tap to open PeerLink',
        },
        data: {
          type: 'chat_request',
          senderId: message.senderId,
          senderName: senderName,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'peerlink_chat',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
      });

      return null;
    } catch (err) {
      console.error('sendChatNotification error:', err);
      return null;
    }
  }
);
