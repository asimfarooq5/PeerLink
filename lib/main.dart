import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/local_storage_service.dart';
import 'services/notification_service.dart';
import 'services/security_service.dart';
import 'services/user_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/username_setup_screen.dart';
import 'widgets/app_lock_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  // Initialize notifications (permissions + local notification channel)
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermission();

  // Initialize local storage
  final localStorage = LocalStorageService();
  await localStorage.initialize();

  // Initialize auth service
  final authService = AuthService();
  await authService.initialize();

  runApp(MyApp(
    authService: authService,
    localStorage: localStorage,
  ));
}

class MyApp extends StatefulWidget {
  final AuthService authService;
  final LocalStorageService localStorage;

  const MyApp({
    super.key,
    required this.authService,
    required this.localStorage,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    NotificationService.navigatorKey = _navigatorKey;
    // Navigate to the relevant chat when a notification is tapped
    NotificationService.instance.notificationTapStream.listen((senderId) {
      // TODO: resolve peer name from Firestore and push ChatScreen
      // For now just log — navigation wiring can be added once the
      // user model lookup is in place.
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'PeerLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      themeMode: ThemeMode.system,
      home: AppLockWrapper(
        securityService: SecurityService(widget.localStorage),
        child: AuthWrapper(
          authService: widget.authService,
          localStorage: widget.localStorage,
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final AuthService authService;
  final LocalStorageService localStorage;

  const AuthWrapper({
    super.key,
    required this.authService,
    required this.localStorage,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final UserService _userService = UserService();
  bool? _hasUsername; // null = still checking
  String? _checkedUid;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = widget.authService.authStateChanges.listen((user) {
      if (user == null) {
        if (mounted) setState(() { _hasUsername = null; _checkedUid = null; });
      } else if (user.uid != _checkedUid) {
        _checkedUid = user.uid;
        _checkUsername(user.uid);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _checkUsername(String uid) async {
    if (mounted) setState(() => _hasUsername = null);
    try {
      final username = await _userService.getUsername(uid);
      if (mounted) setState(() => _hasUsername = username != null && username.isNotEmpty);
    } catch (_) {
      if (mounted) setState(() => _hasUsername = false);
    }
  }

  void _onUsernameSet() => setState(() => _hasUsername = true);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(authService: widget.authService);
        }

        // Still checking whether this user has a username
        if (_hasUsername == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (_hasUsername == false) {
          return UsernameSetupScreen(
            authService: widget.authService,
            userService: _userService,
            onComplete: _onUsernameSet,
          );
        }

        return ChatListScreen(
          localStorage: widget.localStorage,
          authService: widget.authService,
        );
      },
    );
  }
}
