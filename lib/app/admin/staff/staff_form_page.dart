import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:routefly/routefly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../main.dart';
import '../../../models/staff_member.dart';
import '../../../services/auth_service.dart';
import '../../../services/staff_service.dart';
import '../../../layouts/admin_layout.dart';

class StaffFormPage extends StatefulWidget {
  static StaffMember? pendingStaff;

  const StaffFormPage({super.key});

  @override
  State<StaffFormPage> createState() => _StaffFormPageState();
}

class _StaffFormPageState extends State<StaffFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _staffService = StaffService();
  final _authService = AuthService();

  StaffMember? _editingStaff;
  StaffRole _selectedRole = StaffRole.cleaner;
  bool _loading = false;
  bool _isFullAdmin = false;

  bool get _isEditing => _editingStaff != null;

  @override
  void initState() {
    super.initState();
    _detectRole();
    _editingStaff = StaffFormPage.pendingStaff;
    StaffFormPage.pendingStaff = null;

    if (_isEditing) {
      _nameController.text = _editingStaff!.name;
      _accountNameController.text = _editingStaff!.accountName ?? '';
      _phoneController.text = _editingStaff!.phone ?? '';
      _selectedRole = _editingStaff!.role;
    }
  }

  Future<void> _detectRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final data = await Supabase.instance.client
        .from('staff')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    if (mounted && data != null) {
      final isManager = data['role'] == 'manager';
      setState(() => _isFullAdmin = isManager);
      if (!isManager) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Routefly.navigate('/admin/overview');
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNameController.dispose();
    _phoneController.dispose();
    _staffService.dispose();
    _authService.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    if (_isEditing) {
      final success = await _staffService.updateStaff(
        _editingStaff!.id,
        name: _nameController.text.trim(),
        accountName: _accountNameController.text.trim(),
        role: _selectedRole,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );

      setState(() => _loading = false);

      if (mounted && success) {
        showTimedSnackBar(
          SnackBar(content: Text(localizations.tr('staffUpdatedSuccessfully'))),
        );
        Routefly.navigate('/admin/staff');
      }
    } else {
      if (!_staffService.canAddMore) {
        setState(() => _loading = false);
        if (mounted) {
          showTimedSnackBar(
            SnackBar(
              content: Text(
                  localizations.tr('staffLimitReached').replaceAll('{count}', '${StaffService.maxAccounts}')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      try {
        final member = await _staffService.addStaff(
          name: _nameController.text.trim(),
          accountName: _accountNameController.text.trim(),
          role: _selectedRole,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        );

        final authResult = await _authService.createStaffAuth(
          staffId: member.id,
          name: member.accountName ?? member.name,
          role: _selectedRole,
        );

        setState(() => _loading = false);

        if (mounted) {
          if (_selectedRole == StaffRole.cleaner) {
            showTimedSnackBar(
              SnackBar(
                content: Text(localizations.tr('cleanerAccountCreated')),
              ),
            );
            Routefly.navigate('/admin/staff');
          } else {
            _showCredentialsDialog(
              name: member.name,
              email: authResult.email,
              tempPassword: authResult.tempPassword,
            );
          }
        }
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          showTimedSnackBar(
            SnackBar(
              content: Text(localizations.tr('failedToCreateStaff').replaceAll('{error}', '$e')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _showCredentialsDialog({
    required String name,
    required String email,
    required String tempPassword,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.check_circle_outline,
          color: Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        title: Text(localizations.tr('accountCreated')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.tr('accountCreatedSuccess').replaceAll('{name}', name)),
            const SizedBox(height: 16),
            Text(
              localizations.tr('giveCredentials'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(localizations.tr('accountLabel'),
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(email)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: email));
                          showTimedSnackBar(
                            SnackBar(
                                content: Text(localizations.tr('accountNameCopied'))),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(localizations.tr('passwordLabel'),
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(tempPassword)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: tempPassword));
                          showTimedSnackBar(
                            SnackBar(
                                content: Text(localizations.tr('passwordCopied'))),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              localizations.tr('changePasswordAfterLogin'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Routefly.navigate('/admin/staff');
            },
            child: Text(localizations.tr('done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isFullAdmin) {
      return const SizedBox();
    }
    return AdminLayout(
      currentRoute: '/admin/staff',
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? localizations.tr('editProfile') : localizations.tr('addStaff')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Routefly.navigate('/admin/staff'),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: localizations.tr('fullName'),
                        hintText: localizations.tr('nameHint'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizations.tr('pleaseEnterName');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountNameController,
                      enabled: !_isEditing,
                      decoration: InputDecoration(
                        labelText: localizations.tr('accountNameField'),
                        hintText: localizations.tr('accountNameHint'),
                        prefixIcon: const Icon(Icons.alternate_email),
                        border: const OutlineInputBorder(),
                        helperText: _isEditing
                            ? localizations.tr('accountNameCannotBeChanged')
                            : localizations.tr('lettersNumbersOnly'),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return localizations.tr('pleaseEnterAccountName');
                        }
                        if (value.trim().length < 3) {
                          return localizations.tr('mustBeAtLeast3');
                        }
                        if (!RegExp(r'^[a-zA-Z0-9_]+$')
                            .hasMatch(value.trim())) {
                          return localizations.tr('onlyLettersNumbersUnderscores');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: localizations.tr('phoneNumberOptional'),
                        hintText: '+1234567890',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<StaffRole>(
                      initialValue: _selectedRole,
                      decoration: InputDecoration(
                        labelText: localizations.tr('role'),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.work_outline),
                      ),
                      items: StaffRole.values
                          .where((role) => role != StaffRole.manager || (_isEditing && _editingStaff?.role == StaffRole.manager))
                          .map((role) {
                        return DropdownMenuItem(
                          value: role,
                          child: Text(role.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedRole = value);
                        }
                      },
                    ),
                    if (!_isEditing) ...[
                      const SizedBox(height: 12),
                      Text(
                        _staffService.canAddMore
                            ? localizations.tr('accountsUsed')
                                .replaceAll('{used}', '${_staffService.staffCount}')
                                .replaceAll('{max}', '${StaffService.maxAccounts}')
                            : localizations.tr('accountsLimitReached')
                                .replaceAll('{max}', '${StaffService.maxAccounts}'),
                        style: TextStyle(
                          color: _staffService.canAddMore
                              ? Colors.grey[600]
                              : Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_isEditing) ...[
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _resetPassword,
                        icon: const Icon(Icons.lock_reset),
                        label: Text(localizations.tr('resetPassword')),
                      ),
                    ],
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: (_loading ||
                              (!_isEditing &&
                                  !_staffService.canAddMore))
                          ? null
                          : _save,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isEditing ? localizations.tr('saveChanges') : localizations.tr('addStaff')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (_editingStaff == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.tr('resetPasswordTitle')),
        content: Text(
          localizations.tr('resetPasswordConfirm').replaceAll('{name}', _editingStaff!.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations.tr('resetPassword')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);

    final result =
        await _authService.resetStaffPassword(_editingStaff!.id);

    setState(() => _loading = false);

    if (mounted) {
      if (result != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 48),
            title: Text(localizations.tr('resetPasswordTitle')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    localizations.tr('newPasswordFor').replaceAll('{name}', _editingStaff!.name)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          result.tempPassword,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(
                              text: result.tempPassword));
                          showTimedSnackBar(
                            SnackBar(
                                content: Text(localizations.tr('passwordCopied'))),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(localizations.tr('done')),
              ),
            ],
          ),
        );
      } else {
        showTimedSnackBar(
          SnackBar(
            content: Text(localizations.tr('failedToResetPassword')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
