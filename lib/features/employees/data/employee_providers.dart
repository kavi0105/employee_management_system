import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'employee_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final employeeRepoProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.read(firestoreProvider));
});
