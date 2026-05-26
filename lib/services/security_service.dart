import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'local_storage_service.dart';

enum LockType {
  none,
  pin,
  biometric,
  both,
}

class SecurityService {
  final LocalStorageService _localStorage;
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  StreamSubscription? _accelerometerSubscription;
  
  final _lockController = StreamController<bool>.broadcast();
  Stream<bool> get lockStream => _lockController.stream;
  
  bool _isLocked = false;
  bool _isScreenDown = false;
  bool _flipToLockEnabled = false;
  LockType _lockType = LockType.none;
  String? _pinCode;

  SecurityService(this._localStorage);

  Future<void> initialize() async {
    await _loadSettings();
    
    if (_flipToLockEnabled) {
      _startFlipDetection();
    }
  }

  Future<void> _loadSettings() async {
    final lockTypeIndex = _localStorage.getSetting<int>('lock_type');
    if (lockTypeIndex != null) {
      _lockType = LockType.values[lockTypeIndex];
    }
    
    _pinCode = _localStorage.getSetting<String>('pin_code');
    _flipToLockEnabled = _localStorage.getSetting<bool>('flip_to_lock') ?? false;
  }

  Future<void> _saveSettings() async {
    await _localStorage.setSetting('lock_type', _lockType.index);
    await _localStorage.setSetting('pin_code', _pinCode);
    await _localStorage.setSetting('flip_to_lock', _flipToLockEnabled);
  }

  // Lock Type Configuration
  LockType get lockType => _lockType;
  bool get isLocked => _isLocked;
  bool get flipToLockEnabled => _flipToLockEnabled;

  Future<void> setLockType(LockType type, {String? pin}) async {
    _lockType = type;
    if (pin != null) {
      _pinCode = _hashPin(pin);
    }
    await _saveSettings();
  }

  Future<void> setFlipToLock(bool enabled) async {
    _flipToLockEnabled = enabled;
    await _saveSettings();
    
    if (enabled) {
      _startFlipDetection();
    } else {
      _stopFlipDetection();
    }
  }

  // PIN Management
  String _hashPin(String pin) {
    // Simple hash - in production use proper hashing like bcrypt
    return pin; // Placeholder - implement proper hashing
  }

  bool verifyPin(String pin) {
    if (_pinCode == null) return false;
    return _hashPin(pin) == _pinCode;
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (!verifyPin(oldPin)) return false;
    
    _pinCode = _hashPin(newPin);
    await _saveSettings();
    return true;
  }

  // Biometric Authentication
  Future<bool> isBiometricAvailable() async {
    final isAvailable = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    return isAvailable && isDeviceSupported;
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    return await _localAuth.getAvailableBiometrics();
  }

  Future<bool> authenticateWithBiometric({String? reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason ?? 'Authenticate to access the app',
        authMessages: [
          AndroidAuthMessages(
            signInTitle: 'Authentication Required',
            cancelButton: 'Cancel',
          ),
          IOSAuthMessages(
            cancelButton: 'Cancel',
          ),
        ],
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('Biometric auth error: $e');
      return false;
    }
  }

  // App Lock
  Future<void> lockApp() async {
    if (_isLocked) return;
    
    _isLocked = true;
    _lockController.add(true);
  }

  Future<void> unlockApp() async {
    if (!_isLocked) return;
    
    _isLocked = false;
    _lockController.add(false);
  }

  Future<bool> attemptUnlock({String? pin, bool useBiometric = false}) async {
    bool unlocked = false;
    
    switch (_lockType) {
      case LockType.pin:
        if (pin != null && verifyPin(pin)) {
          unlocked = true;
        }
        break;
        
      case LockType.biometric:
        if (useBiometric) {
          unlocked = await authenticateWithBiometric();
        }
        break;
        
      case LockType.both:
        if (useBiometric) {
          unlocked = await authenticateWithBiometric();
        } else if (pin != null && verifyPin(pin)) {
          unlocked = true;
        }
        break;
        
      case LockType.none:
        unlocked = true;
        break;
    }
    
    if (unlocked) {
      await unlockApp();
    }
    
    return unlocked;
  }

  // Flip Detection
  void _startFlipDetection() {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      // Detect if phone is face down (screen facing down)
      // Z axis will be negative when screen is facing down
      final isFaceDown = event.z < -8.0;
      
      if (isFaceDown && !_isScreenDown) {
        _isScreenDown = true;
        // Small delay to confirm it's intentional
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_isScreenDown && _flipToLockEnabled) {
            lockApp();
          }
        });
      } else if (!isFaceDown && _isScreenDown) {
        _isScreenDown = false;
      }
    });
  }

  void _stopFlipDetection() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  // Show Lock Screen
  Future<void> showLockScreen(BuildContext context, {VoidCallback? onUnlocked}) async {
    if (_lockType == LockType.none) return;
    
    if (_lockType == LockType.biometric || _lockType == LockType.both) {
      // Try biometric first
      final didAuthenticate = await authenticateWithBiometric();
      if (didAuthenticate) {
        await unlockApp();
        onUnlocked?.call();
        return;
      }
    }
    
    if (_lockType == LockType.pin || _lockType == LockType.both) {
      // Show PIN screen
      screenLock(
        context: context,
        correctString: _pinCode ?? '',
        canCancel: false,
        onUnlocked: () async {
          await unlockApp();
          onUnlocked?.call();
          Navigator.pop(context);
        },
        onValidate: (pin) async {
          return verifyPin(pin);
        },
        config: const ScreenLockConfig(
          backgroundColor: Colors.black87,
        ),
        secretsConfig: SecretsConfig(
          spacing: 15,
          padding: const EdgeInsets.all(15),
          secretConfig: SecretConfig(
            borderColor: Colors.white,
            enabledColor: Colors.white,
            disabledColor: Colors.white24,
            size: 15,
          ),
        ),
        keyPadConfig: KeyPadConfig(
          buttonConfig: KeyPadButtonConfig(
            foregroundColor: Colors.white,
            backgroundColor: Colors.white10,
          ),
        ),
      );
    }
  }

  // Encrypt sensitive data
  Future<String> encryptSensitiveData(String data) async {
    // Use the same encryption as local storage
    return data; // Placeholder - implement proper encryption
  }

  Future<String> decryptSensitiveData(String encryptedData) async {
    return encryptedData; // Placeholder - implement proper decryption
  }

  Future<void> dispose() {
    _stopFlipDetection();
    return _lockController.close();
  }
}
