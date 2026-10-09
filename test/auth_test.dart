import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friendify/providers/auth_provider.dart';
import 'package:friendify/screens/auth_screen.dart';

void main() {
  group('Sprint 1: Auth & Identity Tests', () {
    test('AuthNotifier initial state is guest and unauthenticated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.isGuest, true);
      expect(state.user, isNull);
    });

    test('AuthNotifier offline sign in creates mock user', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      final ok = await notifier.signInWithEmail(
        email: 'alex@example.com',
        password: 'password123',
      );

      expect(ok, true);
      final state = container.read(authProvider);
      expect(state.isAuthenticated, true);
      expect(state.user?.email, 'alex@example.com');
      expect(state.user?.displayName, 'alex');
    });

    testWidgets('AuthScreen renders login form elements', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign In'), findsWidgets);
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Continue as Guest to Explore'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // Email & Password
    });
  });
}
