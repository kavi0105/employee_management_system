import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'attendance_repository.dart';

final attendanceRepoProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(FirebaseFirestore.instance);
});
