import 'package:flutter/material.dart';
import 'services/storage_service.dart';

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

  void setStudentInfo(Map<String, dynamic> info) async {
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

    // 로컬 저장소에 저장
    await StorageService.saveStudentInfo(userData);

    notifyListeners();
  }

  void clear() async {
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

    // 로컬 저장소에서도 삭제
    await StorageService.logout();

    notifyListeners();
  }

  /// 저장된 정보에서 학생 데이터 복원
  Future<bool> loadFromStorage() async {
    try {
      final savedInfo = await StorageService.getStudentInfo();
      if (savedInfo != null) {
        studentId = savedInfo['student_id']?.toString();
        name = savedInfo['name'];
        department = savedInfo['dept'];
        phoneNum = savedInfo['phone_num'];
        parPhone = savedInfo['par_phone'];
        roomNum = savedInfo['room_num']?.toString();
        year = savedInfo['year']?.toString();
        semester = savedInfo['semester']?.toString();
        paybackBank = savedInfo['payback_bank'];
        paybackName = savedInfo['payback_name'];
        paybackNum = savedInfo['payback_num'];
        smoking = savedInfo['smoking'];
        roommate = null;
        roommateDept = null;

        print('StudentProvider - 저장된 정보에서 복원 완료: $studentId');
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('StudentProvider - 저장된 정보 복원 실패: $e');
    }
    return false;
  }

  /// 로그인 상태 확인
  Future<bool> isLoggedIn() async {
    return await StorageService.isLoggedIn();
  }
}
