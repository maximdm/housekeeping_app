import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:routefly/routefly.dart';

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

  bool get _isEditing => _editingStaff != null;

  @override
  void initState() {
    super.initState();
    _editingStaff = StaffFormPage.pendingStaff;
    StaffFormPage.pendingStaff = null;

    if (_isEditing) {
      _nameController.text = _editingStaff!.name;
      _accountNameController.text = _editingStaff!.accountName ?? '';
      _phoneController.text = _editingStaff!.phone ?? '';
      _selectedRole = _editingStaff!.role;
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
          const SnackBar(content: Text('Staff updated successfully')),
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
                  'Staff limit of ${StaffService.maxAccounts} reached'),
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
        );

        setState(() => _loading = false);

        if (mounted) {
          _showCredentialsDialog(
            name: member.name,
            email: authResult.email,
            tempPassword: authResult.tempPassword,
          );
        }
      } catch (e) {
        setState(() => _loading = false);
        if (mounted) {
          showTimedSnackBar(
            SnackBar(
              content: Text('Failed to create staff: $e'),
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
        title: const Text('Account Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$name" has been created successfully.'),
            const SizedBox(height: 16),
            const Text(
              'Give these credentials to the staff member:',
              style: TextStyle(fontWeight: FontWeight.bold),
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
                      const Text('Account: ',
                          style:
                              TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(email)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: email));
                          showTimedSnackBar(
                            const SnackBar(
                                content: Text('Account name copied')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Password: ',
                          style:
                              TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(tempPassword)),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: tempPassword));
                          showTimedSnackBar(
                            const SnackBar(
                                content:
                                    Text('Password copied')),
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
              'The staff member should change their password after first login.',
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
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      currentRoute: '/admin/staff',
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Staff' : 'Add Staff'),
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
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'e.g. John Smith',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accountNameController,
                      enabled: !_isEditing,
                      decoration: InputDecoration(
                        labelText: 'Account Name',
                        hintText: 'e.g. staff001',
                        prefixIcon: const Icon(Icons.alternate_email),
                        border: const OutlineInputBorder(),
                        helperText: _isEditing
                            ? 'Account name cannot be changed'
                            : 'Letters, numbers, and underscores only',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an account name';
                        }
                        if (value.trim().length < 3) {
                          return 'Must be at least 3 characters';
                        }
                        if (!RegExp(r'^[a-zA-Z0-9_]+$')
                            .hasMatch(value.trim())) {
                          return 'Only letters, numbers and underscores';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (optional)',
                        hintText: '+1234567890',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<StaffRole>(
                      initialValue: _selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Role',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                      items: StaffRole.values.map((role) {
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
                            ? '${_staffService.staffCount} / ${StaffService.maxAccounts} accounts used'
                            : 'Limit of ${StaffService.maxAccounts} accounts reached',
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
                        label: const Text('Reset Password'),
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
                              _isEditing ? 'Save Changes' : 'Add Staff'),
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
        title: const Text('Reset Password'),
        content: Text(
          'Generate a new temporary password for ${_editingStaff!.name}? '
          'They will need to use the new password on their next login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
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
            title: const Text('Password Reset'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'New temporary password for ${_editingStaff!.name}:'),
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
                            const SnackBar(
                                content: Text('Password copied')),
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
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } else {
        showTimedSnackBar(
          SnackBar(
            content: const Text('Failed to reset password'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
