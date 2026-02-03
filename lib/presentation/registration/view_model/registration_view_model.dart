import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../main.dart';
import '../../common/core/providers/auth_provider.dart';
import 'state/registration_state.dart';

final registrationViewModelProvider =
    StateNotifierProvider.autoDispose<RegistrationViewModel, RegistrationState>(
  (ref) => RegistrationViewModel(ref),
);

/// Registration via Supabase.
class RegistrationViewModel extends StateNotifier<RegistrationState> {
  Ref ref;

  RegistrationViewModel(this.ref) : super(RegistrationState.initial());

  void setFirstname(String? firstname) {
    state = state.copyWith(firstname: firstname);
  }

  void setLastname(String? lastname) {
    state = state.copyWith(lastname: lastname);
  }

  void setUsername(String? username) {
    state = state.copyWith(username: username);
  }

  void setPassword(String? password) {
    state = state.copyWith(password: password);
  }

  void setCheckPassword(String? checkPassword) {
    state = state.copyWith(checkPassword: checkPassword);
  }

  /// Submits the registration form via Supabase.
  Future<void> submitForm(
      BuildContext context, GlobalKey<FormState> formKey) async {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();

      state = state.copyWith(isLogging: true);

      final authNotifier = ref.read(authProvider.notifier);
      final fullName = '${state.firstname} ${state.lastname}'.trim();
      if (fullName.isEmpty) {
        state = state.copyWith(isLogging: false);
        _showError(context, 'Please enter your name');
        return;
      }

      try {
        final success = await authNotifier.signUp(
          email: state.username.trim(),
          password: state.password,
          fullName: fullName,
        );

        state = state.copyWith(isLogging: false);

        if (success && context.mounted) {
          navigatorKey.currentState?.pop();
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
