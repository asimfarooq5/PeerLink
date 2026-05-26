import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/security_service.dart';

class SettingsScreen extends StatefulWidget {
  final AuthService authService;
  final LocalStorageService localStorage;

  const SettingsScreen({
    super.key,
    required this.authService,
    required this.localStorage,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SecurityService _securityService;
  bool _isLoading = true;
  LockType _lockType = LockType.none;
  bool _flipToLock = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _securityService = SecurityService(widget.localStorage);
    await _securityService.initialize();
    
    final biometricAvailable = await _securityService.isBiometricAvailable();
    
    setState(() {
      _lockType = _securityService.lockType;
      _flipToLock = _securityService.flipToLockEnabled;
      _biometricAvailable = biometricAvailable;
      _isLoading = false;
    });
  }

  Future<void> _setLockType(LockType type) async {
    if (type == LockType.pin || type == LockType.both) {
      final pin = await _showPinDialog();
      if (pin == null || pin.length < 4) return;
      
      await _securityService.setLockType(type, pin: pin);
    } else {
      await _securityService.setLockType(type);
    }
    
    setState(() {
      _lockType = type;
    });
  }

  Future<String?> _showPinDialog() async {
    final controller = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Set PIN'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Enter 4-6 digit PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.length >= 4) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Set PIN'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFlipToLock(bool value) async {
    await _securityService.setFlipToLock(value);
    setState(() {
      _flipToLock = value;
    });
  }

  Future<void> _clearAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This will delete all your chats, messages, and files. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await widget.localStorage.clearAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('You will need to sign in again to use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await widget.authService.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSectionHeader('Security'),
                _buildLockTypeTile(),
                if (_biometricAvailable)
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Flip to Lock'),
                    subtitle: const Text('Lock app when phone is flipped face down'),
                    value: _flipToLock,
                    onChanged: _toggleFlipToLock,
                  ),
                const Divider(),
                _buildSectionHeader('Account'),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profile'),
                  subtitle: Text(
                    widget.authService.currentUser?.displayName ??
                        widget.authService.currentUser?.phoneNumber ??
                        'Anonymous',
                  ),
                  onTap: () {
                    // Navigate to profile
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'Clear All Data',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _clearAllData,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _signOut,
                ),
                const Divider(),
                _buildSectionHeader('About'),
                const ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Version'),
                  subtitle: Text('1.0.0'),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text('Privacy Policy'),
                  onTap: () {
                    // Open privacy policy
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildLockTypeTile() {
    return ListTile(
      leading: const Icon(Icons.lock),
      title: const Text('App Lock'),
      subtitle: Text(_getLockTypeText()),
      onTap: () => _showLockTypeDialog(),
    );
  }

  String _getLockTypeText() {
    switch (_lockType) {
      case LockType.none:
        return 'Disabled';
      case LockType.pin:
        return 'PIN';
      case LockType.biometric:
        return 'Biometric';
      case LockType.both:
        return 'PIN + Biometric';
    }
  }

  void _showLockTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('App Lock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<LockType>(
              title: const Text('Disabled'),
              value: LockType.none,
              groupValue: _lockType,
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) _setLockType(value);
              },
            ),
            RadioListTile<LockType>(
              title: const Text('PIN'),
              value: LockType.pin,
              groupValue: _lockType,
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) _setLockType(value);
              },
            ),
            if (_biometricAvailable)
              RadioListTile<LockType>(
                title: const Text('Biometric'),
                value: LockType.biometric,
                groupValue: _lockType,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) _setLockType(value);
                },
              ),
            if (_biometricAvailable)
              RadioListTile<LockType>(
                title: const Text('PIN + Biometric'),
                value: LockType.both,
                groupValue: _lockType,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) _setLockType(value);
                },
              ),
          ],
        ),
      ),
    );
  }
}
