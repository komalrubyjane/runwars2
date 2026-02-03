import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../main.dart';
import '../../common/core/providers/auth_provider.dart';
import '../../home/screens/home_screen.dart';
import 'state/login_state.dart';

/// Provides the view model for the login screen.
final loginViewModelProvider =
    StateNotifierProvider.autoDispose<LoginViewModel, LoginState>(
  (ref) => LoginViewModel(ref),
);

/// The view model class for the login screen.
/// Uses Supabase for authentication.
class LoginViewModel extends StateNotifier<LoginState> {
  final Ref ref;

  LoginViewModel(this.ref) : super(LoginState.initial());

  /// Sets the username (email) in the state.
  void setUsername(String? username) {
    state = state.copyWith(username: username ?? '');
  }

  /// Sets the password in the state.
  void setPassword(String? password) {
    state = state.copyWith(password: password ?? '');
  }

  /// Submits the login form via Supabase.
  Future<void> submitForm(
      BuildContext context, GlobalKey<FormState> formKey) async {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();

      state = state.copyWith(isLogging: true);

      final authNotifier = ref.read(authProvider.notifier);

      try {
        final success = await authNotifier.signIn(
          email: state.username.trim(),
          password: state.password,
        );

        state = state.copyWith(isLogging: false);

        if (success && context.mounted) {
          navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else if (authNotifier.state.errorMessage != null) {
          _showError(context, authNotifier.state.errorMessage!);
        }
      } catch (error) {
        state = state.copyWith(isLogging: false);
        _showError(context, error.toString());
      }
    }
  }

  void _showError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }
}
