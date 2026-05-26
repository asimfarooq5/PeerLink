# PeerLink Login Debugging Guide

## Current Errors & Solutions

### Error 1: "CONFIGURATION_NOT_FOUND" (Phone Auth)
```
Failed to initialize reCAPTCHA config: An internal error has occurred. [ CONFIGURATION_NOT_FOUND ]
```
**Solution**: Enable Phone Authentication in Firebase Console

### Error 2: "ApiException: 10" (Google Sign-In)
```
Google sign in error: PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)
```
**Solution**: Add SHA-1 fingerprint to Firebase Console

## Your Configuration Details

**Package Name**: `io.peerlink.chat`
**SHA-1 Fingerprint**: `C7:77:BE:E3:8D:CB:DA:C3:28:72:84:61:A0:82:AD:28:5C:DE:B0:75`
**Firebase Project**: `p2pchatapp-c16b8`

## Firebase Console Setup Checklist

### Authentication Providers
- [ ] Phone (Enable for OTP login)
- [ ] Google (Enable for Google Sign-In)
- [ ] Facebook (Optional)

### Required Configuration
1. **SHA-1 Certificate Fingerprint** added
2. **Phone Auth** enabled
3. **Google Auth** enabled with support email
4. **OAuth consent screen** configured (Google Cloud Console)

## Test Phone Numbers (Optional)

Add these test numbers in Firebase Console to avoid SMS charges during testing:
- Phone: `+923001234567`
- Code: `123456`

## After Configuration

1. Download new `google-services.json`
2. Replace file in `android/app/`
3. Run:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Still Not Working?

### Check API Restrictions
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select project: `p2pchatapp-c16b8`
3. APIs & Services → Credentials
4. Check if API key has restrictions

### Check OAuth Consent Screen
1. Google Cloud Console → APIs & Services → OAuth consent screen
2. Make sure it's configured (External or Internal)
3. Add test users if in Testing mode

### Verify Package Name
Ensure your app's package name matches exactly:
- `io.peerlink.chat`

## Common Error Codes

| Error Code | Meaning | Fix |
|------------|---------|-----|
| 10 | DEVELOPER_ERROR | Add SHA-1, enable OAuth |
| 12501 | CANCELED | User canceled sign-in |
| 12500 | ERROR | Unknown error |
| CONFIGURATION_NOT_FOUND | Auth not enabled | Enable in Firebase Console |
