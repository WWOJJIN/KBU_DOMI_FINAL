// 파일명: application_data_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer';

class ApplicationDataService {
  // 캐시된 데이터를 저장할 변수들
  static List<Map<String, dynamic>> applications = [];
  static List<Map<String, dynamic>> dormRooms = [];

  // 데이터 로딩 상태 관리
  static bool _isInitialized = false;
  static bool _isLoading = false;

  static bool get isDataInitialized =>
      _isInitialized && applications.isNotEmpty;
  static bool get isLoading => _isLoading;

  ApplicationDataService._();

  // 서버 API 기본 URL
  static const String _baseUrl = 'http://localhost:5050';

  /// 데이터 초기화 함수 - 실제 API에서 데이터를 가져옴
  static Future<void> initializeData({bool forceRefresh = false}) async {
    // 이미 로딩 중이면 대기
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    // 이미 초기화되었고 강제 새로고침이 아니면 리턴
    if (_isInitialized && !forceRefresh) return;

    _isLoading = true;

    try {
      log('📡 API에서 데이터 로딩 시작...');

      // 병렬로 두 API 호출
      final futures = await Future.wait([_fetchApplications(), _fetchRooms()]);

      applications = futures[0];
      dormRooms = futures[1];

      log(
        '✅ 데이터 로딩 완료 - 신청서: ${applications.length}개, 방: ${dormRooms.length}개',
      );

      _isInitialized = true;
    } catch (e) {
      log('❌ 데이터 로딩 실패: $e');
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  /// 입실신청 데이터 가져오기
  static Future<List<Map<String, dynamic>>> _fetchApplications() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/admin/in/requests'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // 디버깅: 첫 번째 항목의 documents 필드 출력
        if (data.isNotEmpty) {
          print('🔍 ApplicationDataService - 첫 번째 학생 데이터:');
          print('  - 이름: ${data[0]['name']}');
          print('  - documents 필드: ${data[0]['documents']}');
          if (data[0]['documents'] != null) {
            print('  - documents 개수: ${data[0]['documents'].length}');
          }
        }

        // 서버 데이터를 앱에서 사용하는 형식으로 변환
        return data.map<Map<String, dynamic>>((item) {
          // 상태에 따른 배정 정보 처리
          final String status = item['status']?.toString() ?? '미확인';
          final bool isAssigned = status == '배정완료' || status == '입실완료';

          final mappedItem = {
            'id': item['checkin_id']?.toString() ?? '',
            'checkin_id': item['checkin_id']?.toString() ?? '',
            'studentId': item['student_id']?.toString() ?? '',
            'studentName': item['name']?.toString() ?? '',
            'department': item['department']?.toString() ?? '',
            'gender': item['gender']?.toString() ?? '남',
            'smokingStatus': item['smoking'] == 1 ? '흡연' : '비흡연',
            'nationality':
                item['recruit_type']?.toString() == '외국인' ? '외국인' : '내국인',
            'dormBuilding': item['building']?.toString() ?? '', // 희망 건물
            'roomType': item['room_type']?.toString() ?? '',
            'status': status,
            'adminMemo': item['admin_memo']?.toString() ?? '',
            'submissionDate': item['reg_dt']?.toString() ?? '',
            'academicYear': item['year']?.toString() ?? '',
            'semester': item['semester']?.toString() ?? '',
            'recruitmentType': item['recruit_type']?.toString() ?? '',
            'applicantType': item['recruit_type']?.toString() ?? '',
            // 배정 정보: 상태가 배정완료일 때만 실제 배정 정보 사용
            'assignedBuilding':
                isAssigned ? item['dorm_building']?.toString() : null,
            'assignedRoomNumber':
                isAssigned
                    ? (item['assigned_room_num']?.toString() ??
                        item['room_num']?.toString())
                    : null,
            'pairId': null, // 룸메이트 정보는 별도 API에서 가져와야 함
            'roommateType': null,
            // 서류 정보 추가
            'documents': item['documents'] ?? [],
            // 학생 상세 정보 추가
            'birth_date': item['birth_date']?.toString() ?? '',
            'phoneNumber': item['phone_num']?.toString() ?? '',
            'grade': item['grade']?.toString() ?? '',
            'paybackBank': item['payback_bank']?.toString() ?? '',
            'paybackName': item['payback_name']?.toString() ?? '',
            'paybackNumber': item['payback_num']?.toString() ?? '',
            'academicStatus': item['academic_status']?.toString() ?? '',
            // 지원생구분 추가 (recruit_type 기반으로 설정)
            'applicant_type': item['recruit_type']?.toString() ?? '',
            // 국적 정보 (외국인/내국인 기반)
            'nationality':
                item['recruit_type']?.toString() == '외국인' ? '외국인' : '대한민국',
            // 여권번호 (외국인만)
            'passport_num': item['passport_num']?.toString() ?? '',
            // 기타 개인정보
            'basic_living_support': item['is_basic_living'] == 1,
            'disabled': item['is_disabled'] == 1,
            // 주소 정보 (ad_room_status.dart 호환)
            'postal_code': item['postal_code']?.toString() ?? '',
            'address_basic': item['address_basic']?.toString() ?? '',
            'address_detail': item['address_detail']?.toString() ?? '',
            'region_type': item['region_type']?.toString() ?? '',
            // 보호자 정보 (ad_room_status.dart 호환)
            'guardian_name':
                item['firstin_par_name']?.toString() ??
                item['par_name']?.toString() ??
                '',
            'guardian_relation': item['par_relation']?.toString() ?? '',
            'guardian_phone':
                item['firstin_par_phone']?.toString() ??
                item['par_phone']?.toString() ??
                '',
            // 연락처 정보 (ad_room_status.dart 호환)
            'tel_mobile':
                item['firstin_tel_mobile']?.toString() ??
                item['phone_num']?.toString() ??
                '',
            'tel_home': item['tel_home']?.toString() ?? '',
            // 환불 정보 (ad_room_status.dart 호환)
            'bank': item['payback_bank']?.toString() ?? '',
            'account_num': item['payback_num']?.toString() ?? '',
            'account_holder': item['payback_name']?.toString() ?? '',
          };

          // 디버깅: 매핑된 documents 필드 출력
          if (item['name'] == '김선민') {
            print('🔍 ApplicationDataService - 김선민 매핑 결과:');
            print('  - documents: ${mappedItem['documents']}');
            print('  - assignedBuilding: ${mappedItem['assignedBuilding']}');
            print(
              '  - assignedRoomNumber: ${mappedItem['assignedRoomNumber']}',
            );
          }

          return mappedItem;
        }).toList();
      } else {
        throw Exception('입실신청 데이터 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      log('입실신청 데이터 가져오기 실패: $e');
      throw Exception('입실신청 데이터를 가져올 수 없습니다: $e');
    }
  }

  /// 방 정보 데이터 가져오기 (실제 배정 현황 포함)
  static Future<List<Map<String, dynamic>>> _fetchRooms() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/admin/room-assignments'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> data = responseData['room_assignments'] ?? [];

        // 서버 데이터를 앱에서 사용하는 형식으로 변환
        return data.map<Map<String, dynamic>>((item) {
          return {
            'building': item['building']?.toString() ?? '',
            'floor': item['floor'] ?? 0, // 정수로 저장
            'roomNumber': item['room_number']?.toString() ?? '',
            'roomType': item['room_type']?.toString() ?? '',
            'capacity': item['capacity'] ?? 1,
            'currentOccupancy': item['current_occupancy'] ?? 0,
            'gender': item['gender']?.toString() ?? '',
            'isSmokingRoom': item['smoking_allowed'] == 1,
            'isAvailable':
                (item['current_occupancy'] ?? 0) < (item['capacity'] ?? 1),
            'occupants': item['occupants']?.toString() ?? '',
            'occupantIds': item['occupant_ids']?.toString() ?? '',
            'occupancyRate': item['occupancy_rate'] ?? 0.0,
            'isFull': item['is_full'] ?? false,
            'availableSpots': item['available_spots'] ?? 0,
          };
        }).toList();
      } else {
        throw Exception('방 정보 데이터 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      log('방 정보 데이터 가져오기 실패: $e');
      throw Exception('방 정보 데이터를 가져올 수 없습니다: $e');
    }
  }

  /// 룸메이트 정보 업데이트 (별도 API 호출)
  static Future<void> updateRoommateInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/admin/roommate/requests'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // 룸메이트 관계 정보를 applications에 업데이트
        for (var roommateData in data) {
          if (roommateData['status'] == 'accepted') {
            final requesterId = roommateData['requester_id']?.toString();
            final targetId = roommateData['target_id']?.toString();
            final pairId = '${requesterId}_${targetId}';

            // 신청자와 대상자 모두 업데이트
            for (var app in applications) {
              if (app['studentId'] == requesterId ||
                  app['studentId'] == targetId) {
                app['pairId'] = pairId;
                app['roommateType'] = 'mutual';
              }
            }
          }
        }
      }
    } catch (e) {
      log('룸메이트 정보 업데이트 실패: $e');
    }
  }

  /// 방 점유율 업데이트 (서버에서 최신 데이터 가져오기)
  static Future<void> updateRoomOccupancy() async {
    try {
      // 서버에서 최신 방 배정 현황을 가져와서 업데이트
      dormRooms = await _fetchRooms();
    } catch (e) {
      log('방 점유율 업데이트 실패: $e');
      // 에러가 발생해도 기존 데이터는 유지
    }
  }

  /// 자동배정 실행
  static Future<Map<String, dynamic>> executeAutoAssignment({
    bool dryRun = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/auto-assign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'dry_run': dryRun}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        // 실제 배정이 실행된 경우 데이터 새로고침
        if (!dryRun && result['success'] == true) {
          await initializeData(forceRefresh: true);
        }

        return result;
      } else {
        throw Exception('자동배정 실행 실패: ${response.statusCode}');
      }
    } catch (e) {
      log('자동배정 실행 실패: $e');
      throw Exception('자동배정을 실행할 수 없습니다: $e');
    }
  }

  /// 학생 상태 업데이트 (서버 API 호출)
  static Future<void> updateStudentStatus(
    String studentId,
    String newStatus, {
    String? adminMemo,
  }) async {
    try {
      // checkin_id를 찾기
      final student = applications.firstWhere(
        (app) => app['studentId'] == studentId,
        orElse: () => {},
      );

      if (student.isEmpty) {
        throw Exception('학생을 찾을 수 없습니다.');
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/api/admin/in/request/${student['id']}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': newStatus,
          if (adminMemo != null) 'admin_memo': adminMemo,
        }),
      );

      if (response.statusCode == 200) {
        // 로컬 데이터 업데이트
        student['status'] = newStatus;
        if (adminMemo != null) {
          student['adminMemo'] = adminMemo;
        }
      } else {
        throw Exception('상태 업데이트 실패: ${response.statusCode}');
      }
    } catch (e) {
      log('학생 상태 업데이트 실패: $e');
      throw Exception('학생 상태를 업데이트할 수 없습니다: $e');
    }
  }

  /// 배정 취소
  static Future<void> cancelAssignment(String studentId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/cancel-assignment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'student_id': studentId}),
      );

      if (response.statusCode == 200) {
        // 로컬 데이터 업데이트
        final student = applications.firstWhere(
          (app) => app['studentId'] == studentId,
          orElse: () => {},
        );
        if (student.isNotEmpty) {
          student['assignedBuilding'] = null;
          student['assignedRoomNumber'] = null;
          student['status'] = '확인';
        }

        // 방 점유율 업데이트
        await updateRoomOccupancy();
      } else {
        throw Exception('배정 취소 실패: ${response.statusCode}');
      }
    } catch (e) {
      log('배정 취소 실패: $e');
      throw Exception('배정을 취소할 수 없습니다: $e');
    }
  }

  /// 데이터 새로고침
  static Future<void> refreshData() async {
    _isInitialized = false;
    applications.clear();
    dormRooms.clear();
    await initializeData(forceRefresh: true);
  }

  /// 캐시 초기화
  static void clearCache() {
    applications.clear();
    dormRooms.clear();
    _isInitialized = false;
  }
}
