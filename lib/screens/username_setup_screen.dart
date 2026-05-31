import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class UsernameSetupScreen extends StatefulWidget {
  final AuthService authService;
  final UserService userService;
  final VoidCallback onComplete;

  const UsernameSetupScreen({
    super.key,
    required this.authService,
    required this.userService,
    required this.onComplete,
  });

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  String? _error;
  String? _existingUsername;

  @override
  void initState() {
    super.initState();
    _loadExistingUsername();
  }

  Future<void> _loadExistingUsername() async {
    final uid = widget.authService.currentUser?.uid;
    if (uid == null) { setState(() => _isLoading = false); return; }
    final username = await widget.userService.getUsername(uid);
    if (mounted) {
      setState(() {
        _existingUsername = username;
        if (username != null) _controller.text = username;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isValidUsername(String username) {
    if (username.length < 3 || username.length > 20) return false;
    return RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username);
  }

  Future<void> _submit() async {
    final username = _controller.text.trim().toLowerCase();

    if (!_isValidUsername(username)) {
      setState(() => _error = 'Username must be 3–20 chars: letters, numbers, underscore only.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Only check availability if the username actually changed
    if (username != _existingUsername) {
      final taken = await widget.userService.isUsernameTaken(username);
      if (taken) {
        setState(() {
          _error = 'That username is already taken.';
          _isLoading = false;
        });
        return;
      }
    }

    final user = widget.authService.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not signed in.';
        _isLoading = false;
      });
      return;
    }

    await widget.userService.setUsername(
      user.uid,
      username,
      displayName: user.displayName,
      photoURL: user.photoURL,
    );

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isUpdating = _existingUsername != null;
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.person_outline, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                isUpdating ? 'Update your username' : 'Choose a username',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your username is how other people find you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. johndoe',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isUpdating ? 'Update' : 'Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
