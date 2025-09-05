import 'package:flutter/material.dart';

class StudentProvider with ChangeNotifier {
  String? studentId;
  String? name;
  String? department;
  String? phoneNum;
  String? parPhone;
  String? roomNum;
  String? year;
  String? semester;
  String? paybackBank;
  String? paybackName;
  String? paybackNum;
  String? smoking;
  String? roommate;
  String? roommateDept;

  void setStudentInfo(Map<String, dynamic> info) {
    print('StudentProvider - 받은 정보: $info');

    // API 응답 형태 처리: {success: true, user: {...}} 형태인 경우 user 데이터 추출
    Map<String, dynamic> userData = info;
    if (info.containsKey('success') && info.containsKey('user')) {
      userData = info['user'] as Map<String, dynamic>;
      print('StudentProvider - user 데이터 추출: $userData');
    }

    // 필수 필드 검증
    if (userData['student_id'] == null) {
      print('경고: student_id가 없습니다!');
    }

    studentId = userData['student_id']?.toString();
    name = userData['name'];
    department = userData['dept'];
    phoneNum = userData['phone_num'];
    parPhone = userData['par_phone'];
    roomNum = userData['room_num']?.toString();
    year = userData['year']?.toString();
    semester = userData['semester']?.toString();
    paybackBank = userData['payback_bank'];
    paybackName = userData['payback_name'];
    paybackNum = userData['payback_num'];
    smoking = userData['smoking'];
    roommate = null;
    roommateDept = null;

    print('StudentProvider - 설정된 정보:');
    print('studentId: $studentId');
    print('name: $name');
    print('roomNum: $roomNum');
    print('department: $department');

    notifyListeners();
  }

  void clear() {
    studentId = null;
    name = null;
    department = null;
    phoneNum = null;
    parPhone = null;
    roomNum = null;
    year = null;
    semester = null;
    paybackBank = null;
    paybackName = null;
    paybackNum = null;
    smoking = null;
    roommate = null;
    roommateDept = null;
    notifyListeners();
  }
}
