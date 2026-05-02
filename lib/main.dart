import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sweptie/models/user_model.dart';
import 'package:sweptie/screens/home_screen.dart';
import 'package:sweptie/screens/login_screen.dart';
import 'package:sweptie/screens/search_screen.dart';
import 'package:sweptie/screens/suggestions_screen.dart';
import 'package:sweptie/services/auth_service.dart';
import 'package:sweptie/services/database_service.dart';

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

// Holds the current signed-in user's model so any screen can read isPremium.
final userModelNotifier = ValueNotifier<UserModel?>(null);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await DatabaseService.instance.init();

  // Keep userModelNotifier in sync with auth state.
  AuthService.instance.userModelStream().listen((model) {
    userModelNotifier.value = model;
  });

  runApp(const SweptieApp());
}

class SweptieApp extends StatelessWidget {
  const SweptieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Sweptie',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1565C0),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF42A5F5),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: mode,
          home: const _AuthGate(),
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) return const LoginScreen();
        return const _MainNavigator();
      },
    );
  }
}

class _MainNavigator extends StatefulWidget {
  const _MainNavigator();

  @override
  State<_MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<_MainNavigator> {
  int _currentIndex = 0;

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    SuggestionsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_delete_outlined),
            selectedIcon: Icon(Icons.auto_delete),
            label: 'Cleanup',
          ),
        ],
      ),
    );
  }
}
