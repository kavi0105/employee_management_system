import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  String _search = '';
  String? _deptFilter; // null = all

  String get _dateKey {
    final y = _selectedDate.year.toString().padLeft(4, '0');
    final m = _selectedDate.month.toString().padLeft(2, '0');
    final d = _selectedDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  CollectionReference<Map<String, dynamic>> get _employeesCol =>
      FirebaseFirestore.instance.collection('employees');

  CollectionReference<Map<String, dynamic>> get _recordsCol =>
      FirebaseFirestore.instance.collection('attendance').doc(_dateKey).collection('records');

  Future<void> _setPresent({
    required String employeeId,
    required String name,
    required bool present,
  }) async {
    final docRef = _recordsCol.doc(employeeId);

    await docRef.set({
      'employeeId': employeeId,
      'name': name,
      'present': present,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _bulkMarkAll(List<_Emp> emps, bool present) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final e in emps) {
      final ref = _recordsCol.doc(e.employeeId);
      batch.set(
        ref,
        {
          'employeeId': e.employeeId,
          'name': e.name,
          'present': present,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final employeesStream = _employeesCol.snapshots();
    final recordsStream = _recordsCol.snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance • $_dateKey'),
        actions: [
          IconButton(
            tooltip: 'Pick date',
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: employeesStream,
        builder: (context, empSnap) {
          if (empSnap.hasError) {
            return Center(child: Text('Employees error: ${empSnap.error}'));
          }
          if (!empSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final employees = empSnap.data!.docs.map((d) {
            final data = d.data();
            final employeeId = (data['employeeId'] ?? d.id).toString();
            final name = (data['name'] ?? '').toString();
            final dept = (data['department'] ?? '').toString(); // optional
            final role = (data['role'] ?? '').toString(); // optional
            final photoUrl = (data['photoUrl'] ?? '').toString(); // optional
            return _Emp(
              employeeId: employeeId,
              name: name,
              dept: dept,
              role: role,
              photoUrl: photoUrl,
            );
          }).toList();

          final allDepts = employees
              .map((e) => e.dept)
              .where((d) => d.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: recordsStream,
            builder: (context, recSnap) {
              if (recSnap.hasError) {
                return Center(child: Text('Attendance error: ${recSnap.error}'));
              }
              if (!recSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              // employeeId -> record
              final records = <String, _Record>{};
              for (final d in recSnap.data!.docs) {
                final data = d.data();
                final present = (data['present'] ?? false) == true;
                final updatedAt = data['updatedAt'];
                records[d.id] = _Record(present: present, updatedAt: updatedAt);
              }

              // Apply filters
              final filtered = employees.where((e) {
                final s = _search.trim().toLowerCase();
                final matchesSearch = s.isEmpty ||
                    e.name.toLowerCase().contains(s) ||
                    e.employeeId.toLowerCase().contains(s);

                final matchesDept =
                    _deptFilter == null || _deptFilter == e.dept;

                return matchesSearch && matchesDept;
              }).toList();

              // Summary counts (based on filtered list so it feels consistent)
              int presentCount = 0;
              int absentCount = 0;
              int unmarkedCount = 0;

              for (final e in filtered) {
                final r = records[e.employeeId];
                if (r == null) {
                  unmarkedCount++;
                } else if (r.present) {
                  presentCount++;
                } else {
                  absentCount++;
                }
              }

              return Column(
                children: [
                  _TopBar(
                    search: _search,
                    onSearchChanged: (v) => setState(() => _search = v),
                    departments: allDepts,
                    deptFilter: _deptFilter,
                    onDeptChanged: (v) => setState(() => _deptFilter = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: _SummaryCard(
                      total: filtered.length,
                      present: presentCount,
                      absent: absentCount,
                      unmarked: unmarkedCount,
                      onMarkAllPresent: filtered.isEmpty
                          ? null
                          : () => _bulkMarkAll(filtered, true),
                      onMarkAllAbsent: filtered.isEmpty
                          ? null
                          : () => _bulkMarkAll(filtered, false),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No employees match filters'))
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final e = filtered[i];
                              final r = records[e.employeeId];

                              return Dismissible(
                                key: ValueKey('${_dateKey}_${e.employeeId}'),
                                background: _SwipeBg(
                                  icon: Icons.check_circle,
                                  label: 'Present',
                                  alignLeft: true,
                                ),
                                secondaryBackground: _SwipeBg(
                                  icon: Icons.cancel,
                                  label: 'Absent',
                                  alignLeft: false,
                                ),
                                confirmDismiss: (dir) async {
                                  if (dir == DismissDirection.startToEnd) {
                                    await _setPresent(
                                      employeeId: e.employeeId,
                                      name: e.name,
                                      present: true,
                                    );
                                  } else {
                                    await _setPresent(
                                      employeeId: e.employeeId,
                                      name: e.name,
                                      present: false,
                                    );
                                  }
                                  return false; // keep item
                                },
                                child: _EmployeeRow(
                                  emp: e,
                                  record: r,
                                  onPresent: () => _setPresent(
                                    employeeId: e.employeeId,
                                    name: e.name,
                                    present: true,
                                  ),
                                  onAbsent: () => _setPresent(
                                    employeeId: e.employeeId,
                                    name: e.name,
                                    present: false,
                                  ),
                                  onClear: r == null
                                      ? null
                                      : () => _recordsCol
                                          .doc(e.employeeId)
                                          .delete(),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/* ---------- UI widgets ---------- */

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.search,
    required this.onSearchChanged,
    required this.departments,
    required this.deptFilter,
    required this.onDeptChanged,
  });

  final String search;
  final ValueChanged<String> onSearchChanged;
  final List<String> departments;
  final String? deptFilter;
  final ValueChanged<String?> onDeptChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search name or ID',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                isDense: true,
              ),
              onChanged: onSearchChanged,
            ),
          ),
          const SizedBox(width: 10),
          if (departments.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: deptFilter,
                hint: const Text('Dept'),
                borderRadius: BorderRadius.circular(14),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All'),
                  ),
                  ...departments.map(
                    (d) => DropdownMenuItem<String?>(
                      value: d,
                      child: Text(d),
                    ),
                  ),
                ],
                onChanged: onDeptChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.present,
    required this.absent,
    required this.unmarked,
    required this.onMarkAllPresent,
    required this.onMarkAllAbsent,
  });

  final int total;
  final int present;
  final int absent;
  final int unmarked;
  final VoidCallback? onMarkAllPresent;
  final VoidCallback? onMarkAllAbsent;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today’s Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Pill(label: 'Total', value: total.toString()),
                _Pill(label: 'Present', value: present.toString()),
                _Pill(label: 'Absent', value: absent.toString()),
                _Pill(label: 'Unmarked', value: unmarked.toString()),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onMarkAllPresent,
                    icon: const Icon(Icons.check),
                    label: const Text('Mark all present'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onMarkAllAbsent,
                    icon: const Icon(Icons.close),
                    label: const Text('Mark all absent'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  const _EmployeeRow({
    required this.emp,
    required this.record,
    required this.onPresent,
    required this.onAbsent,
    required this.onClear,
  });

  final _Emp emp;
  final _Record? record;
  final VoidCallback onPresent;
  final VoidCallback onAbsent;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final status = record == null
        ? _Status.unmarked
        : (record!.present ? _Status.present : _Status.absent);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundImage:
            (emp.photoUrl.isNotEmpty) ? NetworkImage(emp.photoUrl) : null,
        child: emp.photoUrl.isNotEmpty
            ? null
            : Text(
                (emp.name.isNotEmpty ? emp.name : emp.employeeId)
                    .trim()
                    .characters
                    .take(2)
                    .toString()
                    .toUpperCase(),
              ),
      ),
      title: Text(
        emp.name.isEmpty ? emp.employeeId : emp.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text([
        if (emp.role.isNotEmpty) emp.role,
        if (emp.dept.isNotEmpty) emp.dept,
        if (emp.name.isNotEmpty) 'ID: ${emp.employeeId}',
      ].join(' • ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusChip(status: status),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            onSelected: (v) {
              if (v == 'present') onPresent();
              if (v == 'absent') onAbsent();
              if (v == 'clear' && onClear != null) onClear!();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'present', child: Text('Mark Present')),
              const PopupMenuItem(value: 'absent', child: Text('Mark Absent')),
              if (onClear != null)
                const PopupMenuItem(value: 'clear', child: Text('Clear Mark')),
            ],
          ),
        ],
      ),
      onTap: () {
        // quick toggle like real apps
        if (record == null) {
          onPresent();
        } else {
          record!.present ? onAbsent() : onPresent();
        }
      },
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.icon,
    required this.label,
    required this.alignLeft,
  });

  final IconData icon;
  final String label;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment:
            alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (alignLeft) Icon(icon),
          if (alignLeft) const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (!alignLeft) const SizedBox(width: 8),
          if (!alignLeft) Icon(icon),
        ],
      ),
    );
  }
}

enum _Status { present, absent, unmarked }

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final _Status status;

  @override
  Widget build(BuildContext context) {
    late final String text;
    late final IconData icon;

    switch (status) {
      case _Status.present:
        text = 'Present';
        icon = Icons.check_circle;
        break;
      case _Status.absent:
        text = 'Absent';
        icon = Icons.cancel;
        break;
      case _Status.unmarked:
        text = 'Unmarked';
        icon = Icons.help;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/* ---------- models ---------- */

class _Emp {
  _Emp({
    required this.employeeId,
    required this.name,
    required this.dept,
    required this.role,
    required this.photoUrl,
  });

  final String employeeId;
  final String name;
  final String dept;
  final String role;
  final String photoUrl;
}

class _Record {
  _Record({required this.present, required this.updatedAt});
  final bool present;
  final dynamic updatedAt;
}
