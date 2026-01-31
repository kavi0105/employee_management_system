class AttendanceRecord {
  final String employeeId;
  final String name;
  final bool present;

  AttendanceRecord({
    required this.employeeId,
    required this.name,
    required this.present,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'name': name,
      'present': present,
      'markedAt': DateTime.now(),
    };
  }
}
