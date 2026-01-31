import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/attendance_record.dart';

class AttendanceRepository {
  final FirebaseFirestore _db;

  AttendanceRepository(this._db);

  Future<void> markAttendance({
    required String date,
    required AttendanceRecord record,
  }) async {
    await _db
        .collection('attendance')
        .doc(date)
        .collection('records')
        .doc(record.employeeId)
        .set(record.toMap());
  }
}
