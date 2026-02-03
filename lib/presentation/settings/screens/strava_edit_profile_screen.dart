import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

const Color _stravaOrange = Color(0xFFFC4C02);

/// Strava-style edit profile screen using Supabase
class StravaEditProfileScreen extends HookConsumerWidget {
  const StravaEditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseUser = Supabase.instance.client.auth.currentUser;
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: _stravaOrange,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: supabaseUser == null
          ? const Center(child: Text('Not signed in'))
          : FutureBuilder<Map<String, dynamic>?>(
              future: SupabaseService().getUserProfile(supabaseUser.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profile = snapshot.data;
                final fullName =
                    profile?['full_name'] as String? ?? supabaseUser.email ?? '';

                return _EditProfileForm(
                  formKey: formKey,
                  initialFullName: fullName,
                  userId: supabaseUser.id,
                );
              },
            ),
    );
  }
}

class _EditProfileForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final String initialFullName;
  final String userId;

  const _EditProfileForm({
    required this.formKey,
    required this.initialFullName,
    required this.userId,
  });

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  late TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialFullName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!widget.formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await SupabaseService().updateUserProfile(
        userId: widget.userId,
        fullName: _nameController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter your name';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _stravaOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
