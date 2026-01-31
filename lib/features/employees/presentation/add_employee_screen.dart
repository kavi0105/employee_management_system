import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/employee_providers.dart';
import '../domain/employee.dart';

class AddEmployeeScreen extends ConsumerStatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  ConsumerState<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends ConsumerState<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  // Dropdown value
  String? _selectedDepartment;

  // Focus nodes (nice "Next" flow)
  final _idFocus = FocusNode();
  final _deptFocus = FocusNode();
  final _phoneFocus = FocusNode();

  bool _saving = false;
  bool _dirty = false;

  // Replace with your real departments (or load from provider)
  final List<String> _departments = const [
    'Engineering',
    'HR',
    'Finance',
    'Sales',
    'Operations',
    'Support',
    'Marketing',
  ];

  // Allow common phone characters while typing; validate on digits-only later
  final _phoneTypingFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[0-9+\-\s()]'),
  );

  @override
  void initState() {
    super.initState();
    void markDirty() {
      if (!_dirty) setState(() => _dirty = true);
    }

    _nameCtrl.addListener(markDirty);
    _idCtrl.addListener(markDirty);
    _contactCtrl.addListener(markDirty);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _contactCtrl.dispose();

    _idFocus.dispose();
    _deptFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  // --- Validators ---
  String? _required(String? v, {String msg = 'Required'}) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  String? _validateEmployeeId(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Required';
    // Real-world: allow EMP-1023, emp_1023, 1023, etc.
    if (!RegExp(r'^[A-Za-z0-9_-]{3,20}$').hasMatch(s)) {
      return '3–20 chars: letters, numbers, _ or -';
    }
    return null;
  }

  String? _validatePhone(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return 'Required';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) return 'Enter a valid number';
    return null;
  }

  // Normalize phone before saving
  String _normalizePhone(String input) =>
      input.trim().replaceAll(RegExp(r'\D'), '');

  Future<void> _submit() async {
    if (_saving) return;

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (_selectedDepartment == null) {
      // Dropdown is part of Form, but if you want extra guard:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final employee = Employee(
        employeeId: _idCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        department: _selectedDepartment!, // from dropdown
        contactNumber: _normalizePhone(_contactCtrl.text),
      );

      await ref.read(employeeRepoProvider).addEmployee(employee);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee added successfully ✅')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!_dirty || _saving) return true;

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Do you want to discard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final canLeave = await _confirmDiscardChanges();
        if (!mounted) return;
        if (canLeave) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Employee'),
          bottom: _saving
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(),
                )
              : null,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Employee Name',
                      hintText: 'e.g., Kasun Perera',
                    ),
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (v) => _required(v),
                    onFieldSubmitted: (_) => _idFocus.requestFocus(),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _idCtrl,
                    focusNode: _idFocus,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      hintText: 'e.g., EMP-1023',
                    ),
                    textInputAction: TextInputAction.next,
                    validator: _validateEmployeeId,
                    onFieldSubmitted: (_) => _deptFocus.requestFocus(),
                  ),
                  const SizedBox(height: 12),

                  // Department dropdown (FormField so it validates like others)
                  DropdownButtonFormField<String>(
                    focusNode: _deptFocus,
                    value: _selectedDepartment,
                    items: _departments
                        .map(
                          (d) => DropdownMenuItem<String>(
                            value: d,
                            child: Text(d),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) {
                            setState(() {
                              _selectedDepartment = v;
                              _dirty = true;
                            });
                            _phoneFocus.requestFocus();
                          },
                    decoration: const InputDecoration(
                      labelText: 'Department',
                    ),
                    validator: (v) => v == null ? 'Select a department' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _contactCtrl,
                    focusNode: _phoneFocus,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Contact Number',
                      hintText: '+94 77 123 4567',
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [_phoneTypingFormatter],
                    textInputAction: TextInputAction.done,
                    validator: _validatePhone,
                    onFieldSubmitted: (_) => _saving ? null : _submit(),
                  ),

                  const SizedBox(height: 20),

                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
