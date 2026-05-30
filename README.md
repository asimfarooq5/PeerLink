# PeerLink

A secure peer-to-peer messaging app built with Flutter and WebRTC. No dedicated chat server required - messages flow directly between devices after initial signaling via Firebase.

## Features

### Core Messaging
- **P2P Text Messages** - Direct peer-to-peer communication via WebRTC data channels
- **Media Sharing** - Send images, videos, audio, and files
- **Offline Support** - Messages stored locally with Hive database
- **End-to-End Encryption** - Local storage encryption for all messages

### Authentication
- **Phone Login** - OTP-based authentication
- **Social Login** - Google and Facebook sign-in
- **Anonymous Login** - Quick testing mode

### Security
- **App Lock** - PIN or biometric authentication
- **Flip-to-Lock** - Auto-lock when phone is flipped face down
- **Encrypted Storage** - All local data encrypted with AES
- **No Server Storage** - Messages never touch a central server

### Social Features
- **Friend Requests** - Add contacts by phone number
- **Contact Discovery** - Find friends via phone contacts
- **Typing Indicators** - Real-time typing status
- **Read Receipts** - Message delivery confirmation

## Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Device A      │◄───►│   Device B      │
│  (Flutter App)  │ WebRTC│  (Flutter App)  │
└────────┬────────┘     └────────┬────────┘
         │                       │
         │   P2P Connection      │
         │   (Data Channel)      │
         │◄─────────────────────►│
         │                       │
         │    Signaling Only     │
         └──────────┬────────────┘
                    │
           ┌────────▼────────┐
           │    Firebase     │
           │  (Signaling +   │
           │   Push Notifs)  │
           └─────────────────┘
```

## Setup Instructions

### Prerequisites
- Flutter SDK 3.0+
- Firebase account
- Android Studio / Xcode

### 1. Firebase Setup

1. Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)

2. Add Android app:
   - Package name: `com.example.p2p_chat_app`
   - Download `google-services.json`
   - Place in `android/app/`

3. Add iOS app:
   - Bundle ID: `com.example.p2pChatApp`
   - Download `GoogleService-Info.plist`
   - Place in `ios/Runner/`

4. Enable Firebase services:
   - **Authentication**: Enable Phone, Google, and Facebook providers
   - **Firestore**: Create database in test mode
   - **Cloud Messaging**: Enable for push notifications

5. Update `lib/firebase_options.dart` with your configuration

### 2. Social Login Setup

#### Google Sign-In
1. Add SHA-1 fingerprint in Firebase console (Android)
2. Configure OAuth consent screen in Google Cloud Console
3. No additional setup needed for iOS

#### Facebook Login
1. Create app at [developers.facebook.com](https://developers.facebook.com)
2. Add Android/iOS platforms
3. Add Facebook App ID to:
   - Android: `strings.xml`
   - iOS: `Info.plist`
4. Configure OAuth redirect URIs

### 3. Build & Run

```bash
# Get dependencies
flutter pub get

# Generate Hive adapters
flutter packages pub run build_runner build

# Run on Android
flutter run

# Run on iOS (macOS only)
flutter run -d ios
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/
│   ├── user_model.dart       # User data
│   ├── message_model.dart    # Message data
│   ├── chat_session_model.dart # Chat sessions
│   └── friend_request_model.dart # Friend requests
├── services/
│   ├── auth_service.dart     # Authentication
│   ├── webrtc_service.dart   # P2P WebRTC
│   ├── signaling_service.dart # Firebase signaling
│   ├── chat_service.dart      # Chat logic
│   ├── local_storage_service.dart # Hive storage
│   ├── friend_service.dart   # Friend management
│   └── security_service.dart # App lock & encryption
├── screens/
│   ├── login_screen.dart     # Authentication UI
│   ├── chat_list_screen.dart # Chat list
│   ├── chat_screen.dart      # Chat conversation
│   ├── contacts_screen.dart  # Contacts/friends
│   └── settings_screen.dart  # App settings
└── widgets/
    ├── message_bubble.dart   # Message UI
    └── app_lock_wrapper.dart # Security wrapper
```

## How It Works

### Connection Flow
1. User A opens chat with User B
2. App sends "wakeup" signal via Firebase FCM
3. Both apps establish WebRTC connection
4. Signaling exchanged via Firestore
5. P2P data channel established
6. Messages flow directly between devices

### Message Flow
```
Send Message:
  UI → ChatService → WebRTCService → DataChannel → Peer

Receive Message:
  Peer → DataChannel → WebRTCService → LocalStorage → UI
```

### File Transfer
Files are chunked (16KB) and sent via WebRTC data channels:
1. File saved to local encrypted storage
2. File chunked and streamed to peer
3. Peer receives chunks and reconstructs
4. File saved to peer's local storage

## Security Considerations

- **No Message History on Server**: Firebase only handles signaling
- **Local Encryption**: AES-256 encryption for all stored data
- **P2P Only**: Messages travel directly between devices
- **No Cloud Backups**: Data stays on device unless manually exported

## Limitations

- Both users must be online for real-time messaging
- File transfer limited by WebRTC data channel (~1GB theoretical max)
- No message sync across multiple devices
- Requires internet for initial connection setup

## Future Enhancements

- [ ] Message queuing for offline peers
- [ ] Group chats (mesh P2P)
- [ ] Voice/video calls
- [ ] Self-destructing messages
- [ ] Blockchain-based identity
- [ ] Tor/I2P routing option

## License

MIT License - See LICENSE file
