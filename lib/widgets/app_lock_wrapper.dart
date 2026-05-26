import 'package:flutter/material.dart';
import '../services/security_service.dart';

class AppLockWrapper extends StatefulWidget {
  final SecurityService securityService;
  final Widget child;

  const AppLockWrapper({
    super.key,
    required this.securityService,
    required this.child,
  });

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper>
    with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    await widget.securityService.initialize();
    
    // Listen for lock events
    widget.securityService.lockStream.listen((isLocked) {
      if (mounted) {
        setState(() {
          _isLocked = isLocked;
        });
        
        if (isLocked) {
          _showLockScreen();
        }
      }
    });
    
    setState(() {
      _isInitialized = true;
    });
    
    // Check if app should be locked on startup
    if (widget.securityService.lockType != LockType.none) {
      widget.securityService.lockApp();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - lock if needed
      if (widget.securityService.lockType != LockType.none) {
        widget.securityService.lockApp();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground - check if locked
      if (widget.securityService.isLocked) {
        _showLockScreen();
      }
    }
  }

  Future<void> _showLockScreen() async {
    if (!_isInitialized) return;
    
    // Small delay to ensure UI is ready
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      await widget.securityService.showLockScreen(
        context,
        onUnlocked: () {
          setState(() {
            _isLocked = false;
          });
        },
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.securityService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    
    return widget.child;
  }
}
