import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'providers/theme_provider.dart';
import 'screens/account_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_details_screen.dart';
import 'screens/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        publishableKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialization error: $e');
    }
  }
  runApp(const ProviderScope(child: FriendifyApp()));
}

const coral = Color(0xFFFF6F61);
const slate = Color(0xFF1E1E2C);
const offWhite = Color(0xFFFAFAFC);

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: coral, brightness: b).copyWith(
    primary: coral,
    onPrimary: Colors.white,
    surface: dark ? slate : offWhite,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(backgroundColor: scheme.surface, elevation: 0, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
  );
}

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/explore',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => ScaffoldWithNav(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/chat', builder: (_, __) => const ChatInboxScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/host', builder: (_, __) => const OnboardingScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/account', builder: (_, __) => const AccountScreen())]),
          ],
        ),
        GoRoute(path: '/explore/companion/:id', parentNavigatorKey: _rootKey,
            builder: (_, s) => ProfileDetailsScreen(id: s.pathParameters['id']!)),
        GoRoute(path: '/chat/:id', parentNavigatorKey: _rootKey,
            builder: (_, s) => ChatRoomScreen(companionId: s.pathParameters['id']!)),
        GoRoute(path: '/auth', parentNavigatorKey: _rootKey,
            builder: (_, __) => const AuthScreen()),
      ],
    ));

class FriendifyApp extends ConsumerWidget {
  const FriendifyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        title: 'Friendify',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: ref.watch(routerProvider),
      );
}

class ScaffoldWithNav extends StatelessWidget {
  final StatefulNavigationShell shell;
  const ScaffoldWithNav({super.key, required this.shell});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Chat'),
            NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Host'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
          ],
        ),
      );
}
