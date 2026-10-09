import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/user_profile.dart';

class AuthState {
  final bool isLoading;
  final UserProfile? user;
  final String? errorMessage;
  final bool isGuest;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
    this.isGuest = true,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    UserProfile? user,
    String? errorMessage,
    bool? isGuest,
    bool clearUser = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: errorMessage,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<dynamic>? _authSubscription;

  @override
  AuthState build() {
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    _initAuthListener();
    return const AuthState(isLoading: false, isGuest: true);
  }

  void _initAuthListener() {
    final client = SupabaseConfig.client;
    if (client == null) return;

    // Check existing session
    final currentSession = client.auth.currentSession;
    if (currentSession != null) {
      _loadProfile(currentSession.user.id, currentSession.user.email ?? '');
    }

    // Listen to changes
    _authSubscription = client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _loadProfile(session.user.id, session.user.email ?? '');
      } else {
        state = state.copyWith(clearUser: true, isGuest: true, isLoading: false);
      }
    });
  }

  Future<void> _loadProfile(String userId, String email) async {
    final client = SupabaseConfig.client;
    if (client == null) return;

    try {
      final res = await client.from('profiles').select().eq('id', userId).maybeSingle();
      if (res != null) {
        final profile = UserProfile.fromMap(res);
        state = state.copyWith(user: profile, isGuest: false, isLoading: false, errorMessage: null);
      } else {
        // Create initial profile if missing
        final newProfile = UserProfile(
          id: userId,
          email: email,
          displayName: email.split('@').first,
          createdAt: DateTime.now(),
        );
        await client.from('profiles').upsert(newProfile.toMap());
        state = state.copyWith(user: newProfile, isGuest: false, isLoading: false, errorMessage: null);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      // Create fallback profile from auth user
      state = state.copyWith(
        user: UserProfile(
          id: userId,
          email: email,
          displayName: email.split('@').first,
          createdAt: DateTime.now(),
        ),
        isGuest: false,
        isLoading: false,
      );
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final client = SupabaseConfig.client;

    if (client == null) {
      // Offline/Mock simulation
      await Future.delayed(const Duration(milliseconds: 600));
      final mockUser = UserProfile(
        id: 'mock-user-123',
        email: email,
        displayName: email.split('@').first,
        createdAt: DateTime.now(),
        walletBalance: 248.50,
      );
      state = state.copyWith(isLoading: false, user: mockUser, isGuest: false);
      return true;
    }

    try {
      final res = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (res.user != null) {
        await _loadProfile(res.user!.id, res.user!.email ?? email);
        return true;
      }
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String role = 'client',
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final client = SupabaseConfig.client;

    if (client == null) {
      // Offline/Mock simulation
      await Future.delayed(const Duration(milliseconds: 600));
      final mockUser = UserProfile(
        id: 'mock-user-${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        displayName: displayName,
        role: role,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(isLoading: false, user: mockUser, isGuest: false);
      return true;
    }

    try {
      final res = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName, 'role': role},
      );
      if (res.user != null) {
        final profile = UserProfile(
          id: res.user!.id,
          email: email.trim(),
          displayName: displayName.trim(),
          role: role,
          createdAt: DateTime.now(),
        );
        try {
          await client.from('profiles').upsert(profile.toMap());
        } catch (_) {}
        state = state.copyWith(user: profile, isGuest: false, isLoading: false);
        return true;
      }
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    final client = SupabaseConfig.client;
    if (client != null) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
    state = const AuthState(isLoading: false, isGuest: true, user: null);
  }

  void continueAsGuest() {
    state = const AuthState(isLoading: false, isGuest: true, user: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
