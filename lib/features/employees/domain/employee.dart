class Employee {
  final String employeeId;
  final String name;
  final String department;
  final String contactNumber;

  const Employee({
    required this.employeeId,
    required this.name,
    required this.department,
    required this.contactNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'name': name,
      'department': department,
      'contactNumber': contactNumber,
      'createdAt': DateTime.now(),
    };
  }

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      employeeId: map['employeeId'] ?? '',
      name: map['name'] ?? '',
      department: map['department'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
    );
  }
}
