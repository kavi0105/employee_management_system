import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  String _search = '';
  _HistoryFilter _filter = _HistoryFilter.all;

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

  Stream<QuerySnapshot<Map<String, dynamic>>> get _recordsStream =>
      FirebaseFirestore.instance
          .collection('attendance')
          .doc(_dateKey)
          .collection('records')
          .orderBy('name') // safe if name exists for most; remove if not indexed
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History • $_dateKey'),
        actions: [
          IconButton(
            tooltip: 'Pick date',
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDate,
          ),
          IconButton(
            tooltip: 'Export (coming soon)',
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export coming soon')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _recordsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return _EmptyState(
              title: 'No records for $_dateKey',
              subtitle: 'Pick another date to view attendance.',
              onPickDate: _pickDate,
            );
          }

          // Normalize records
          final records = docs.map((d) {
            final data = d.data();
            final name = (data['name'] ?? '').toString();
            final employeeId = (data['employeeId'] ?? d.id).toString();
            final present = (data['present'] ?? false) == true;
            final updatedAt = data['updatedAt']; // Timestamp? (optional)
            return _HistoryRow(
              employeeId: employeeId,
              name: name,
              present: present,
              updatedAt: updatedAt,
            );
          }).toList();

          // Summary
          final presentCount = records.where((r) => r.present).length;
          final absentCount = records.length - presentCount;

          // Apply filter + search
          final s = _search.trim().toLowerCase();
          final filtered = records.where((r) {
            final matchesFilter = switch (_filter) {
              _HistoryFilter.all => true,
              _HistoryFilter.present => r.present,
              _HistoryFilter.absent => !r.present,
            };

            final matchesSearch = s.isEmpty ||
                r.name.toLowerCase().contains(s) ||
                r.employeeId.toLowerCase().contains(s);

            return matchesFilter && matchesSearch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Column(
                  children: [
                    _SummaryCard(
                      total: records.length,
                      present: presentCount,
                      absent: absentCount,
                    ),
                    const SizedBox(height: 10),
                    Row(
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
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _FilterMenu(
                          filter: _filter,
                          onChanged: (f) => setState(() => _filter = f),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // StreamBuilder auto-updates; this is UX sugar.
                    await Future<void>.delayed(const Duration(milliseconds: 300));
                  },
                  child: filtered.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Center(child: Text('No results')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final r = filtered[index];
                            return _HistoryTile(row: r);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ---------------- UI pieces ---------------- */

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.present,
    required this.absent,
  });

  final int total;
  final int present;
  final int absent;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: _Metric(label: 'Total', value: '$total')),
            Expanded(child: _Metric(label: 'Present', value: '$present')),
            Expanded(child: _Metric(label: 'Absent', value: '$absent')),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({required this.filter, required this.onChanged});

  final _HistoryFilter filter;
  final ValueChanged<_HistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_HistoryFilter>(
      tooltip: 'Filter',
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: _HistoryFilter.all, child: Text('All')),
        PopupMenuItem(value: _HistoryFilter.present, child: Text('Present')),
        PopupMenuItem(value: _HistoryFilter.absent, child: Text('Absent')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.filter_list, size: 18),
            const SizedBox(width: 8),
            Text(
              switch (filter) {
                _HistoryFilter.all => 'All',
                _HistoryFilter.present => 'Present',
                _HistoryFilter.absent => 'Absent',
              },
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row});
  final _HistoryRow row;

  @override
  Widget build(BuildContext context) {
    final display = row.name.isEmpty ? row.employeeId : row.name;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        child: Text(
          display.trim().characters.take(2).toString().toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      title: Text(display, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: row.name.isEmpty ? null : Text('ID: ${row.employeeId}'),
      trailing: _StatusPill(present: row.present),
      
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.present});
  final bool present;

  @override
  Widget build(BuildContext context) {
    final icon = present ? Icons.check_circle : Icons.cancel;
    final text = present ? 'Present' : 'Absent';

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
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.onPickDate,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 44),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_month),
              label: const Text('Pick a date'),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- models ---------------- */

enum _HistoryFilter { all, present, absent }

class _HistoryRow {
  _HistoryRow({
    required this.employeeId,
    required this.name,
    required this.present,
    required this.updatedAt,
  });

  final String employeeId;
  final String name;
  final bool present;
  final dynamic updatedAt;
}
