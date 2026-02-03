import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:run_flutter_run/core/services/supabase_service.dart';

/// Provider for Supabase service
final supabaseProvider = Provider((ref) {
  return SupabaseService();
});

/// State for authentication
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? userId;
  final String? email;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.userId,
    this.email,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? userId,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier for authentication state
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseService supabaseService;

  AuthNotifier(this.supabaseService) : super(AuthState()) {
    _checkAuthStatus();
  }

  /// Check if user is already authenticated
  void _checkAuthStatus() {
    final user = supabaseService.currentUser;
    if (user != null) {
      debugPrint('[Supabase Auth] Session restored: ${user.email}');
      state = state.copyWith(
        isAuthenticated: true,
        userId: user.id,
        email: user.email,
      );
    }
  }

  /// Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await supabaseService.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (response.user != null) {
        debugPrint('[Supabase Auth] Registered: ${response.user!.email}');
        // Create user profile
        await supabaseService.createUserProfile(
          userId: response.user!.id,
          email: email,
          fullName: fullName,
        );

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          userId: response.user!.id,
          email: response.user!.email,
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
    return false;
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await supabaseService.signIn(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('[Supabase Auth] Signed in: ${response.user!.email}');
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          userId: response.user!.id,
          email: response.user!.email,
        );
        return true;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
    return false;
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      debugPrint('[Supabase Auth] Signed out');
      await supabaseService.signOut();
      state = AuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }
}

/// Provider for authentication state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final supabaseService = ref.watch(supabaseProvider);
  return AuthNotifier(supabaseService);
});
