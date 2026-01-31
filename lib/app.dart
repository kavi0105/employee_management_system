import 'package:flutter/material.dart';

// screens
import 'features/employees/presentation/add_employee_screen.dart';
import 'features/attendance/presentation/attendance_screen.dart';
import 'features/attendance/presentation/attendance_history_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Employee Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateText =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Attendance'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: "Attendance History",
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AttendanceHistoryScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(dateText: dateText),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: "Mark Attendance",
                    subtitle: "Quick check-in/out",
                    icon: Icons.how_to_reg,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AttendanceScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    title: "Add Employee",
                    subtitle: "New staff member",
                    icon: Icons.person_add_alt_1,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddEmployeeScreen()),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _SectionTitle(
              title: "Quick Access",
              trailing: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AttendanceHistoryScreen()),
                ),
                child: const Text("View History"),
              ),
            ),

            const SizedBox(height: 8),

            _QuickTile(
              icon: Icons.calendar_month,
              title: "Attendance History",
              subtitle: "Check previous dates",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AttendanceHistoryScreen()),
              ),
            ),

            const SizedBox(height: 16),

            _SectionTitle(title: "Today Overview"),

            const SizedBox(height: 8),

            // These are UI placeholders; later you can connect them to Firestore
            Row(
              children: const [
                Expanded(child: _StatCard(title: "Total Employees", value: "--")),
                SizedBox(width: 12),
                Expanded(child: _StatCard(title: "Present", value: "--")),
                SizedBox(width: 12),
                Expanded(child: _StatCard(title: "Absent", value: "--")),
              ],
            ),

            const SizedBox(height: 16),

            _SectionTitle(title: "Recent Activity"),

            const SizedBox(height: 8),

            _EmptyStateCard(
              title: "No recent activity",
              subtitle: "Mark attendance to see latest updates here.",
              buttonText: "Mark Attendance",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AttendanceScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String dateText;
  const _HeaderCard({required this.dateText});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Icon(
                Icons.badge,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome 👋",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Today: $dateText",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
        
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        elevation: 0,
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;

  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onPressed,
              child: Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
