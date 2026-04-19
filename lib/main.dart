import 'package:flutter/material.dart';
import 'package:sweptie/screens/home_screen.dart';
import 'package:sweptie/screens/search_screen.dart';
import 'package:sweptie/screens/suggestions_screen.dart';
import 'package:sweptie/services/database_service.dart';

// Exposed so any widget can toggle the theme without a state-management package.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
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
          home: const _MainNavigator(),
        );
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
