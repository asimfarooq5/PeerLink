import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/local_storage_service.dart';
import 'services/security_service.dart';
import 'services/user_service.dart';
import 'screens/login_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/username_setup_screen.dart';
import 'widgets/app_lock_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  
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

class MyApp extends StatelessWidget {
  final AuthService authService;
  final LocalStorageService localStorage;

  const MyApp({
    super.key,
    required this.authService,
    required this.localStorage,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
        securityService: SecurityService(localStorage),
        child: AuthWrapper(
          authService: authService,
          localStorage: localStorage,
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
  bool _checkingUsername = false;
  bool? _hasUsername;

  @override
  void initState() {
    super.initState();
    _checkUsername();
  }

  Future<void> _checkUsername() async {
    final user = widget.authService.currentUser;
    if (user == null) return;

    setState(() => _checkingUsername = true);

    try {
      final username = await _userService.getUsername(user.uid);

      if (mounted) {
        setState(() {
          _hasUsername = username != null && username.isNotEmpty;
          _checkingUsername = false;
        });
      }
    } catch (e) {
      // If Firestore is unavailable, assume username is needed
      // This prevents app from getting stuck on loading
      if (mounted) {
        setState(() {
          _hasUsername = false;
          _checkingUsername = false;
        });
      }

    }
  }

  void _onUsernameSet() {
    setState(() => _hasUsername = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: widget.authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _checkingUsername) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
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
        }

        return LoginScreen(authService: widget.authService);
      },
    );
  }
}
