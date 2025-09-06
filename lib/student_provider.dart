import 'package:flutter/material.dart';
import 'services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kbu_domi/env.dart';

class StudentProvider with ChangeNotifier {
  String? studentId;
  String? name;
  String? department;
  String? phoneNum;
  String? parPhone;
  String? roomNum;
  String? dormBuilding;
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
    dormBuilding = userData['dorm_building'];
    year = userData['year']?.toString();
    semester = userData['semester']?.toString();
    paybackBank = userData['payback_bank'];
    paybackName = userData['payback_name'];
    paybackNum = userData['payback_num'];
    smoking = userData['smoking'];
    roommate = userData['roommate_name'];
    roommateDept = userData['roommate_dept'];

    print('StudentProvider - 설정된 정보:');
    print('studentId: $studentId');
    print('name: $name');
    print('roomNum: $roomNum');
    print('dormBuilding: $dormBuilding');
    print('department: $department');
    print('🔍 룸메이트 관련 필드 상세:');
    print('  - userData[\"roommate_id\"]: ${userData["roommate_id"]}');
    print('  - userData[\"roommate_name\"]: ${userData["roommate_name"]}');
    print('  - userData[\"roommate_dept\"]: ${userData["roommate_dept"]}');
    print('  - 최종 roommate: $roommate');
    print('  - 최종 roommateDept: $roommateDept');

    // 🔧 룸메이트 정보가 없으면 Roommate_Requests에서 찾기
    if ((roommate == null || roommate == 'null') && studentId != null) {
      print('🔍 룸메이트 정보가 없어서 Roommate_Requests에서 조회 시도...');
      await _fetchRoommateFromRequests(studentId!);
    }

    // 로컬 저장소에 저장 (룸메이트 정보 포함)
    final updatedUserData = Map<String, dynamic>.from(userData);
    updatedUserData['roommate_name'] = roommate;
    updatedUserData['roommate_dept'] = roommateDept;
    await StorageService.saveStudentInfo(updatedUserData);

    notifyListeners();
  }

  void clear() async {
    studentId = null;
    name = null;
    department = null;
    phoneNum = null;
    parPhone = null;
    roomNum = null;
    dormBuilding = null;
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
        dormBuilding = savedInfo['dorm_building'];
        year = savedInfo['year']?.toString();
        semester = savedInfo['semester']?.toString();
        paybackBank = savedInfo['payback_bank'];
        paybackName = savedInfo['payback_name'];
        paybackNum = savedInfo['payback_num'];
        smoking = savedInfo['smoking'];
        roommate = savedInfo['roommate_name'];
        roommateDept = savedInfo['roommate_dept'];

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

  /// Roommate_Requests 테이블에서 승인된 룸메이트 정보 조회
  Future<void> _fetchRoommateFromRequests(String studentId) async {
    try {
      print('🔍 _fetchRoommateFromRequests 호출: studentId=$studentId');

      // 내가 신청한 룸메이트 요청 조회
      final myRequestsResponse = await http.get(
        Uri.parse('$apiBase/api/roommate/my-requests?student_id=$studentId'),
      );

      print('🔍 내 신청 API 응답: ${myRequestsResponse.statusCode}');

      if (myRequestsResponse.statusCode == 200) {
        final List<dynamic> myRequests = json.decode(myRequestsResponse.body);
        print('🔍 내 신청 목록: $myRequests');

        for (var request in myRequests) {
          if (request['status'] == 'accepted' &&
              request['roommate_type'] == 'mutual') {
            // 승인된 상호 신청 발견
            final roommateId = request['requested_id'];
            final roommateName = request['roommate_name'];

            print('🎯 승인된 룸메이트 발견 (내가 신청): $roommateName ($roommateId)');

            // 룸메이트의 학과 정보 조회
            await _fetchRoommateDepartment(roommateId, roommateName);
            return;
          }
        }
      }

      // 나에게 온 룸메이트 요청 조회
      final requestsForMeResponse = await http.get(
        Uri.parse(
          '$apiBase/api/roommate/requests-for-me?student_id=$studentId',
        ),
      );

      print('🔍 나에게 온 신청 API 응답: ${requestsForMeResponse.statusCode}');

      if (requestsForMeResponse.statusCode == 200) {
        final List<dynamic> requestsForMe = json.decode(
          requestsForMeResponse.body,
        );
        print('🔍 나에게 온 신청 목록: $requestsForMe');

        for (var request in requestsForMe) {
          if (request['status'] == 'accepted' &&
              request['roommate_type'] == 'mutual') {
            // 승인된 상호 신청 발견
            final roommateId = request['requester_id'];
            final roommateName = request['requester_name'];

            print('🎯 승인된 룸메이트 발견 (나에게 신청): $roommateName ($roommateId)');

            // 룸메이트의 학과 정보 조회
            await _fetchRoommateDepartment(roommateId, roommateName);
            return;
          }
        }
      }

      print('❌ 승인된 룸메이트 관계를 찾을 수 없습니다.');
    } catch (e) {
      print('❌ 룸메이트 정보 조회 실패: $e');
    }
  }

  /// 룸메이트의 학과 정보 조회 및 설정
  Future<void> _fetchRoommateDepartment(
    String roommateId,
    String roommateName,
  ) async {
    try {
      final roommateInfoResponse = await http.get(
        Uri.parse('$apiBase/api/student/$roommateId'),
      );

      if (roommateInfoResponse.statusCode == 200) {
        final roommateData = json.decode(roommateInfoResponse.body);
        final roommateDeptValue = roommateData['user']['dept'];

        print('🎯 룸메이트 학과 정보 조회 성공: $roommateName ($roommateDeptValue)');

        // 룸메이트 정보 설정
        roommate = roommateName;
        roommateDept = roommateDeptValue;

        print('✅ 룸메이트 정보 최종 설정: $roommate ($roommateDept)');

        notifyListeners(); // UI 업데이트
      } else {
        print('❌ 룸메이트 학과 정보 조회 실패: ${roommateInfoResponse.statusCode}');
      }
    } catch (e) {
      print('❌ 룸메이트 학과 정보 조회 중 오류: $e');
    }
  }
}
