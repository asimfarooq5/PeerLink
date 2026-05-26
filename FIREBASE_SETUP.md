# Firebase Setup Guide for PeerLink

## Current Issues & Fixes

### 1. Phone Authentication Error: "CONFIGURATION_NOT_FOUND"

**Fix:** You need to enable Phone Authentication in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: `p2pchatapp-c16b8`
3. Go to **Build** → **Authentication** → **Get Started**
4. Click **Sign-in method** tab
5. Enable **Phone** provider
6. Save

### 2. Google Sign-In Failed

**Fix:** Add SHA-1 fingerprint to Firebase

Run this command to get your SHA-1:
```bash
cd /home/asim/scm/garbage/p2p_chat_app/android
./gradlew signingReport
```

Look for the SHA1 under `Variant: debug` → `Config: debug`.

Then in Firebase Console:
1. Go to **Project Settings** (gear icon)
2. Under **Your apps**, find your Android app
3. Click **Add fingerprint**
4. Paste your SHA-1
5. Save

### 3. Download Updated google-services.json

After making changes above:
1. In Firebase Console → Project Settings
2. Click **Download google-services.json**
3. Replace the file at:
   `/home/asim/scm/garbage/p2p_chat_app/android/app/google-services.json`

## Complete Firebase Configuration Checklist

### Authentication Providers
- [ ] Phone (for OTP login)
- [ ] Google (for Google Sign-In)
- [ ] Facebook (optional, for Facebook login)

### Firestore Database
- [ ] Create Firestore database
- [ ] Set rules for development:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Cloud Messaging (FCM)
- [ ] Enable Cloud Messaging
- [ ] Note the Server Key for push notifications

## Test Users

Add test phone numbers for development (no SMS charges):
1. Firebase Console → Authentication → Sign-in method → Phone
2. Add test numbers like:
   - +923001234567
   - Code: 123456

## After Configuration

Clean and rebuild:
```bash
cd /home/asim/scm/garbage/p2p_chat_app
flutter clean
flutter pub get
flutter run
```

## Troubleshooting

**Error: "An internal error has occurred [CONFIGURATION_NOT_FOUND]"**
→ Phone Auth not enabled in Firebase Console

**Error: "Google sign in failed"**
→ SHA-1 fingerprint not added to Firebase

**Error: "Developer Error" with Google Sign-In**
→ OAuth consent screen not configured or app not properly registered

**Error: "API key not valid"**
→ Restrictions on API key in Google Cloud Console

## Important Notes

1. **Firebase Project**: `p2pchatapp-c16b8`
2. **Package Name**: `io.peerlink.chat`
3. **Current SHA-1**: You need to add your debug and release SHA-1

## Optional: Facebook Login Setup

1. Create app at [Facebook Developers](https://developers.facebook.com)
2. Add Android platform
3. Package name: `io.peerlink.chat`
4. Add Facebook App ID to:
   - `android/app/src/main/res/values/strings.xml`
5. Enable Facebook Login in Firebase Console
