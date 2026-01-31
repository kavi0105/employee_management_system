import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/employee.dart';

class EmployeeRepository {
  final FirebaseFirestore _db;

  EmployeeRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _employees =>
      _db.collection('employees');

  Future<void> addEmployee(Employee employee) async {
    final doc = _employees.doc(employee.employeeId);

    // Prevent duplicate Employee IDs
    final existing = await doc.get();
    if (existing.exists) {
      throw Exception('Employee ID already exists');
    }

    await doc.set(employee.toMap());
  }
}
