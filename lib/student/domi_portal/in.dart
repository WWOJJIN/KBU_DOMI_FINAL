// 파일명: InPage.dart
// [수정] 기본, 보호자, 주소, 환불 정보 섹션을 하나의 카드로 통합했습니다.
// - _buildInfoCard: 4개의 정보 섹션을 포함하는 새로운 카드 위젯
// - build 메서드에서 기존 4개의 카드 생성 함수 호출을 _buildInfoCard()로 교체했습니다.
// - 불필요해진 _buildBasicInfoCard, _buildGuardianInfoCard, _buildAddressCard, _buildRefundInfoCard 함수를 삭제했습니다.

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:kbu_domi/student_provider.dart';
import 'dart:io';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class InPage extends StatefulWidget {
  const InPage({super.key});

  @override
  State<InPage> createState() => _InPageState();
}

class _InPageState extends State<InPage> {
  final _formKey = GlobalKey<FormState>();

  // 컨트롤러들
  final Map<String, TextEditingController> controllers = {
    '성명': TextEditingController(),
    '학번': TextEditingController(),
    '학과': TextEditingController(),
    '호실': TextEditingController(),
    '계좌번호': TextEditingController(),
    '예금주명': TextEditingController(),
    '은행': TextEditingController(),
    '기본주소': TextEditingController(),
    '상세주소': TextEditingController(),
    '보호자성명': TextEditingController(),
    '보호자관계': TextEditingController(),
    '보호자전화번호': TextEditingController(),
    '흡연여부': TextEditingController(),
    '성별': TextEditingController(),
    '내국인외국인': TextEditingController(),
    '환불은행': TextEditingController(),
    '예금주': TextEditingController(),
    '생년월일': TextEditingController(),
    '학년': TextEditingController(),
    '우편번호': TextEditingController(),
    '집전화': TextEditingController(),
    '핸드폰': TextEditingController(),
  };

  // 상태 변수들
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSubmitted = false; // 제출 완료 상태
  bool _isEditMode = false; // 수정 모드 상태
  String? selectedBuilding;
  String? selectedRoomType;
  String? selectedSmokingStatus;
  List<Map<String, dynamic>> _attachedFiles = [];
  List<Map<String, dynamic>> _savedFiles = [];
  bool _isUploading = false;
  Map<String, dynamic>? _existingApplication;
  String _noticeContent = '입실신청 관련 공지사항을 확인해주세요.';

  // 드롭다운 옵션들
  final List<String> _roomTypes = ['1인실', '2인실', '3인실', '룸메이트'];
  final List<String> _banks = [
    '국민은행',
    '신한은행',
    '우리은행',
    '하나은행',
    '기업은행',
    '농협은행',
    '새마을금고',
    '신협',
    '우체국',
    '카카오뱅크',
    '토스뱅크',
  ];

  // 기숙사 건물 옵션
  final List<String> buildingOptions = ['숭례원', '양덕원'];

  // 방 타입 옵션
  final List<String> roomTypeOptions = ['1인실', '2인실', '3인실', '룸메이트'];

  // 흡연 여부 옵션
  final List<String> smokingOptions = ['비흡연', '흡연'];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadNotice();
    _checkExistingApplication();
  }

  // 데이터 초기화 - 입주신청 데이터 우선, 없으면 학생 데이터
  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    // 1단계: 먼저 입주신청 데이터 확인
    bool hasFirstinData = await _loadFirstinDataWithReturn();

    // 2단계: 입주신청 데이터가 없으면 학생 데이터로 채우기
    if (!hasFirstinData) {
      _loadStudentDataForFallback();
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  // 학생 데이터 로드 (자동입력용)
  void _loadStudentData() async {
    final student = Provider.of<StudentProvider>(context, listen: false);
    if (student.studentId != null) {
      try {
        // 학생 상세 정보 API 호출
        final response = await http.get(
          Uri.parse('http://localhost:5050/api/student/${student.studentId}'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final userInfo = data['user'];

          print('DEBUG: userInfo = $userInfo');

          // 기본 정보 자동입력
          controllers['학번']!.text =
              userInfo['student_id']?.toString() ?? student.studentId!;
          controllers['성명']!.text =
              userInfo['name']?.toString() ?? student.name ?? '';
          controllers['학과']!.text =
              userInfo['dept']?.toString() ?? student.department ?? '';
          controllers['예금주명']!.text =
              userInfo['payback_name']?.toString() ??
              userInfo['name']?.toString() ??
              '';
          controllers['계좌번호']!.text = userInfo['payback_num']?.toString() ?? '';
          controllers['은행']!.text = userInfo['payback_bank']?.toString() ?? '';
          controllers['환불은행']!.text =
              userInfo['payback_bank']?.toString() ?? '';
          controllers['예금주']!.text = userInfo['payback_name']?.toString() ?? '';

          // 추가 정보
          controllers['성별']!.text = userInfo['gender']?.toString() ?? '';
          controllers['학년']!.text = userInfo['grade']?.toString() ?? '';
          controllers['핸드폰']!.text = userInfo['phone_num']?.toString() ?? '';
          controllers['보호자성명']!.text = userInfo['par_name']?.toString() ?? '';
          controllers['보호자전화번호']!.text =
              userInfo['par_phone']?.toString() ?? '';

          // 생년월일 설정
          if (userInfo['birth_date'] != null) {
            String birthDateStr = userInfo['birth_date'].toString();
            print('🔍 [학생정보] 생년월일 원본: $birthDateStr');
            try {
              // GMT 형식 처리: "Sat, 01 Jan 2005 00:00:00 GMT"
              if (birthDateStr.contains('GMT')) {
                // "01 Jan 2005" 패턴 찾기 (1자리 또는 2자리 날짜 지원)
                RegExp regExp = RegExp(r'(\d{1,2}) (\w{3}) (\d{4})');
                Match? match = regExp.firstMatch(birthDateStr);
                if (match != null) {
                  String day = match.group(1)!.padLeft(2, '0');
                  String monthName = match.group(2)!;
                  String year = match.group(3)!;
                  String month = _monthToNumber(monthName);
                  String formattedDate = '$year-$month-$day';
                  print(
                    '🔍 [학생정보] GMT 파싱 결과: $formattedDate (원본: ${match.group(0)})',
                  );
                  controllers['생년월일']!.text = formattedDate;
                } else {
                  print('🔍 [학생정보] GMT 정규식 매치 실패');
                  controllers['생년월일']!.text = '2000-01-01';
                }
              } else {
                // 일반 형식 처리
                DateTime birthDate = DateTime.parse(birthDateStr);
                controllers['생년월일']!.text =
                    '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
                print('🔍 [학생정보] 일반 형식 파싱 완료: ${controllers['생년월일']!.text}');
              }
            } catch (e) {
              controllers['생년월일']!.text = '2000-01-01';
              print('❌ [학생정보] 생년월일 파싱 오류: $e, 원본 데이터: $birthDateStr');
            }
          } else {
            controllers['생년월일']!.text = '2000-01-01';
          }

          // 기숙사 건물 설정 (성별 기반)
          if (userInfo['gender']?.toString() == '남') {
            selectedBuilding = '숭례원';
          } else if (userInfo['gender']?.toString() == '여') {
            selectedBuilding = '양덕원';
          } else {
            selectedBuilding = buildingOptions.first;
          }

          // 기본값 설정
          selectedRoomType = _roomTypes.first;
          selectedSmokingStatus = smokingOptions.first;
          controllers['내국인외국인']!.text = '내국인';
          controllers['보호자관계']!.text = '부모';

          // 빈 필드들에 기본값 설정
          if (controllers['우편번호']!.text.isEmpty)
            controllers['우편번호']!.text = '12345';
          if (controllers['기본주소']!.text.isEmpty)
            controllers['기본주소']!.text = '서울특별시 강남구';
          if (controllers['상세주소']!.text.isEmpty)
            controllers['상세주소']!.text = '테헤란로 123';
          if (controllers['집전화']!.text.isEmpty)
            controllers['집전화']!.text = '02-1234-5678';
        } else {
          // API 호출 실패 시 기본값만 설정
          _setDefaultValues();
        }
      } catch (e) {
        print('학생 정보 로딩 오류: $e');
        _setDefaultValues();
      }

      setState(() => _isLoading = false);
    }
  }

  // 기본값 설정 함수
  void _setDefaultValues() {
    final student = Provider.of<StudentProvider>(context, listen: false);
    controllers['학번']!.text = student.studentId ?? '';
    controllers['성명']!.text = student.name ?? '';
    controllers['학과']!.text = student.department ?? '';
    controllers['예금주명']!.text = student.name ?? '';
    controllers['성별']!.text = '남';
    controllers['학년']!.text = '1';
    controllers['내국인외국인']!.text = '내국인';
    controllers['보호자관계']!.text = '부모';
    controllers['생년월일']!.text = '2000-01-01';
    controllers['우편번호']!.text = '12345';
    controllers['기본주소']!.text = '서울특별시 강남구';
    controllers['상세주소']!.text = '테헤란로 123';
    controllers['집전화']!.text = '02-1234-5678';
    controllers['핸드폰']!.text = '010-1234-5678';
    controllers['보호자성명']!.text = '홍길동';
    controllers['보호자전화번호']!.text = '010-9876-5432';

    selectedBuilding = buildingOptions.first;
    selectedRoomType = _roomTypes.first;
    selectedSmokingStatus = smokingOptions.first;
  }

  // 입주신청 정보 로드 (Firstin 테이블에서) - bool 반환
  Future<bool> _loadFirstinDataWithReturn() async {
    final student = Provider.of<StudentProvider>(context, listen: false);
    if (student.studentId == null) return false;

    try {
      final response = await http.get(
        Uri.parse(
          'http://localhost:5050/api/firstin/my-applications?student_id=${student.studentId}',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final firstinData = data[0]; // 가장 최근 입주신청 정보
          print('🏠 입주신청 정보 로드: $firstinData');

          // 입주신청 정보로 폼 필드 채우기
          _fillFormFromFirstinData(firstinData);

          // 생년월일을 마지막에 한 번 더 확실하게 설정
          if (firstinData['birth_date'] != null) {
            String birthDateStr = firstinData['birth_date'].toString();
            print('🚀 최종 생년월일 설정: $birthDateStr');
            if (birthDateStr.contains('GMT')) {
              RegExp regExp = RegExp(r'(\d{1,2}) (\w{3}) (\d{4})');
              Match? match = regExp.firstMatch(birthDateStr);
              if (match != null) {
                String day = match.group(1)!.padLeft(2, '0');
                String monthName = match.group(2)!;
                String year = match.group(3)!;
                String month = _monthToNumber(monthName);
                controllers['생년월일']!.text = '$year-$month-$day';
                print('🚀 최종 설정 완료: ${controllers['생년월일']!.text}');
              }
            } else if (birthDateStr.contains('-')) {
              controllers['생년월일']!.text = birthDateStr;
              print('🚀 최종 설정 완료 (일반): ${controllers['생년월일']!.text}');
            }
          }
          return true;
        }
      }
    } catch (e) {
      print('입주신청 정보 로딩 오류: $e');
    }
    return false;
  }

  // fallback용 학생 데이터 로드 (setState 없음)
  void _loadStudentDataForFallback() {
    final student = Provider.of<StudentProvider>(context, listen: false);
    if (student.studentId != null) {
      // 기본값 설정만 수행
      _setDefaultValues();
    }
  }

  // 월 이름을 숫자로 변환하는 헬퍼 함수
  String _monthToNumber(String monthName) {
    const months = {
      'Jan': '01',
      'Feb': '02',
      'Mar': '03',
      'Apr': '04',
      'May': '05',
      'Jun': '06',
      'Jul': '07',
      'Aug': '08',
      'Sep': '09',
      'Oct': '10',
      'Nov': '11',
      'Dec': '12',
    };
    return months[monthName] ?? '01';
  }

  // 입주신청 정보로 폼 채우기
  void _fillFormFromFirstinData(Map<String, dynamic> firstinData) {
    // 기본 정보
    if (firstinData['student_id'] != null) {
      controllers['학번']!.text = firstinData['student_id'].toString();
    }
    if (firstinData['name'] != null) {
      controllers['성명']!.text = firstinData['name'].toString();
      controllers['예금주명']!.text = firstinData['name'].toString();
      controllers['예금주']!.text = firstinData['name'].toString();
    }
    if (firstinData['department'] != null) {
      controllers['학과']!.text = firstinData['department'].toString();
    }
    if (firstinData['gender'] != null) {
      controllers['성별']!.text = firstinData['gender'].toString();

      // 성별에 따른 기숙사 건물 자동 설정
      if (firstinData['gender'].toString() == '남자') {
        selectedBuilding = '숭례원';
      } else if (firstinData['gender'].toString() == '여자') {
        selectedBuilding = '양덕원';
      }
    }
    if (firstinData['grade'] != null) {
      String gradeStr = firstinData['grade'].toString();
      // "1학년" -> "1"로 변환
      if (gradeStr.contains('학년')) {
        gradeStr = gradeStr.replaceAll('학년', '');
      }
      controllers['학년']!.text = gradeStr;
    }

    // 연락처 정보
    if (firstinData['tel_mobile'] != null) {
      controllers['핸드폰']!.text = firstinData['tel_mobile'].toString();
    }
    if (firstinData['tel_home'] != null) {
      controllers['집전화']!.text = firstinData['tel_home'].toString();
    }

    // 주소 정보
    if (firstinData['address_basic'] != null) {
      controllers['기본주소']!.text = firstinData['address_basic'].toString();
    }
    if (firstinData['address_detail'] != null) {
      controllers['상세주소']!.text = firstinData['address_detail'].toString();
    }
    if (firstinData['postal_code'] != null) {
      controllers['우편번호']!.text = firstinData['postal_code'].toString();
    }

    // 보호자 정보
    if (firstinData['par_name'] != null) {
      controllers['보호자성명']!.text = firstinData['par_name'].toString();
    }
    if (firstinData['par_relation'] != null) {
      controllers['보호자관계']!.text = firstinData['par_relation'].toString();
    }
    if (firstinData['par_phone'] != null) {
      controllers['보호자전화번호']!.text = firstinData['par_phone'].toString();
    }

    // 생년월일
    if (firstinData['birth_date'] != null) {
      String birthDateStr = firstinData['birth_date'].toString();
      print('🔍 [입주신청] 생년월일 원본: $birthDateStr');
      try {
        // GMT 형식 처리: "Sat, 01 Jan 2005 00:00:00 GMT"
        if (birthDateStr.contains('GMT')) {
          // "01 Jan 2005" 패턴 찾기 (1자리 또는 2자리 날짜 지원)
          RegExp regExp = RegExp(r'(\d{1,2}) (\w{3}) (\d{4})');
          Match? match = regExp.firstMatch(birthDateStr);
          if (match != null) {
            String day = match.group(1)!.padLeft(2, '0');
            String monthName = match.group(2)!;
            String year = match.group(3)!;
            String month = _monthToNumber(monthName);
            String formattedDate = '$year-$month-$day';
            print(
              '🔍 [입주신청] GMT 파싱 결과: $formattedDate (원본: ${match.group(0)})',
            );
            controllers['생년월일']!.text = formattedDate;
          } else {
            print('🔍 [입주신청] GMT 정규식 매치 실패');
            controllers['생년월일']!.text = '2000-01-01';
          }
        } else {
          // 일반 형식 처리
          DateTime birthDate = DateTime.parse(birthDateStr);
          controllers['생년월일']!.text =
              '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
          print('🔍 [입주신청] 일반 형식 파싱 완료: ${controllers['생년월일']!.text}');
        }
      } catch (e) {
        // 파싱 실패 시 기본값 사용
        controllers['생년월일']!.text = '2000-01-01';
        print('❌ [입주신청] 생년월일 파싱 오류: $e, 원본 데이터: $birthDateStr');
      }
    }

    // 국적
    if (firstinData['applicant_type'] != null) {
      controllers['내국인외국인']!.text = firstinData['applicant_type'].toString();
    }

    // 기숙사 관련 정보
    if (firstinData['room_type'] != null &&
        _roomTypes.contains(firstinData['room_type'])) {
      selectedRoomType = firstinData['room_type'].toString();
    }
    if (firstinData['smoking_status'] != null &&
        smokingOptions.contains(firstinData['smoking_status'])) {
      selectedSmokingStatus = firstinData['smoking_status'].toString();
    }

    // 은행 정보
    if (firstinData['bank'] != null) {
      controllers['은행']!.text = firstinData['bank'].toString();
      controllers['환불은행']!.text = firstinData['bank'].toString();
    }
    if (firstinData['account_num'] != null) {
      controllers['계좌번호']!.text = firstinData['account_num'].toString();
    }
    if (firstinData['account_holder'] != null) {
      controllers['예금주명']!.text = firstinData['account_holder'].toString();
      controllers['예금주']!.text = firstinData['account_holder'].toString();
    }

    print('✅ 입주신청 정보로 폼 채우기 완료');
    setState(() {}); // UI 업데이트
  }

  // 공지사항 로드
  Future<void> _loadNotice() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/notice?category=checkin'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _noticeContent = data['content'] ?? _noticeContent;
        });
      }
    } catch (e) {
      print('공지사항 로딩 중 에러: $e');
    }
  }

  // 기존 입실신청 조회
  Future<void> _checkExistingApplication() async {
    final student = Provider.of<StudentProvider>(context, listen: false);
    if (student.studentId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          'http://localhost:5050/api/checkin/requests?student_id=${student.studentId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _existingApplication = data[0];
            _isSubmitted = true; // 기존 신청이 있으면 제출 완료 상태
            _isEditMode = false; // 수정 모드 비활성화
            _loadExistingData(data[0]);
          });
        }
      }
    } catch (e) {
      log('기존 입실신청 조회 오류: $e');
    }
  }

  // 기존 데이터 로드
  void _loadExistingData(Map<String, dynamic> application) {
    // 디버깅: 받아온 데이터 전체 출력
    print('DEBUG: application = ' + application.toString());

    // null 방어: 컨트롤러에 안전하게 값 할당
    controllers['성명']!.text = (application['name'] ?? '').toString();
    controllers['학번']!.text = (application['student_id'] ?? '').toString();
    controllers['학과']!.text = (application['department'] ?? '').toString();
    controllers['호실']!.text = (application['room_num'] ?? '').toString();
    controllers['계좌번호']!.text = (application['payback_num'] ?? '').toString();
    controllers['예금주명']!.text = (application['payback_name'] ?? '').toString();
    controllers['은행']!.text = (application['payback_bank'] ?? '').toString();

    // 추가 필드들 매핑
    controllers['흡연여부']!.text = (application['smoking'] ?? '비흡연').toString();
    controllers['성별']!.text = (application['gender'] ?? '남').toString();
    controllers['내국인외국인']!.text =
        (application['applicant_type'] ?? '내국인').toString();
    controllers['환불은행']!.text = (application['payback_bank'] ?? '').toString();
    controllers['예금주']!.text = (application['payback_name'] ?? '').toString();
    // 생년월일 처리
    if (application['birth_date'] != null) {
      String birthDateStr = application['birth_date'].toString();
      print('🔍 [기존신청] 생년월일 원본: $birthDateStr');
      try {
        // GMT 형식 처리: "Sat, 01 Jan 2005 00:00:00 GMT"
        if (birthDateStr.contains('GMT')) {
          // "01 Jan 2005" 패턴 찾기 (1자리 또는 2자리 날짜 지원)
          RegExp regExp = RegExp(r'(\d{1,2}) (\w{3}) (\d{4})');
          Match? match = regExp.firstMatch(birthDateStr);
          if (match != null) {
            String day = match.group(1)!.padLeft(2, '0');
            String monthName = match.group(2)!;
            String year = match.group(3)!;
            String month = _monthToNumber(monthName);
            String formattedDate = '$year-$month-$day';
            print(
              '🔍 [기존신청] GMT 파싱 결과: $formattedDate (원본: ${match.group(0)})',
            );
            controllers['생년월일']!.text = formattedDate;
          } else {
            print('🔍 [기존신청] GMT 정규식 매치 실패');
            controllers['생년월일']!.text = '2000-01-01';
          }
        } else {
          // 일반 형식 처리
          DateTime birthDate = DateTime.parse(birthDateStr);
          controllers['생년월일']!.text =
              '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}';
          print('🔍 [기존신청] 일반 형식 파싱 완료: ${controllers['생년월일']!.text}');
        }
      } catch (e) {
        controllers['생년월일']!.text = '2000-01-01';
        print('❌ [기존신청] 생년월일 파싱 오류: $e, 원본 데이터: $birthDateStr');
      }
    } else {
      controllers['생년월일']!.text = '2000-01-01';
    }
    controllers['학년']!.text = (application['grade'] ?? '1').toString();

    // 주소 및 연락처 정보 - 빈 값이면 기본값 설정
    controllers['우편번호']!.text =
        (application['postal_code'] ?? '12345').toString();
    controllers['기본주소']!.text =
        (application['address_basic'] ?? '서울특별시 강남구').toString();
    controllers['상세주소']!.text =
        (application['address_detail'] ?? '테헤란로 123').toString();
    controllers['집전화']!.text =
        (application['tel_home'] ?? '02-1234-5678').toString();
    controllers['핸드폰']!.text =
        (application['tel_mobile'] ?? '010-1234-5678').toString();

    // 보호자 정보 - 빈 값이면 기본값 설정
    controllers['보호자성명']!.text =
        (application['guardian_name'] ?? '홍길동').toString();
    controllers['보호자관계']!.text =
        (application['guardian_relation'] ?? '부모').toString();
    controllers['보호자전화번호']!.text =
        (application['guardian_phone'] ?? '010-9876-5432').toString();

    // Dropdown 값 방어: null이거나 옵션에 없으면 첫 번째 값으로 대체
    final roomTypeValue = application['room_type']?.toString();
    selectedRoomType =
        (roomTypeValue != null && _roomTypes.contains(roomTypeValue))
            ? roomTypeValue
            : _roomTypes.first;

    final buildingValue = application['building']?.toString();
    selectedBuilding =
        (buildingValue != null && buildingOptions.contains(buildingValue))
            ? buildingValue
            : buildingOptions.first;

    // 흡연 상태 매핑 (API에서 "N", "Y" 또는 "비흡연", "흡연"으로 올 수 있음)
    final smokingValue = application['smoking']?.toString();
    if (smokingValue == 'N' || smokingValue == '비흡연') {
      selectedSmokingStatus = '비흡연';
    } else if (smokingValue == 'Y' || smokingValue == '흡연') {
      selectedSmokingStatus = '흡연';
    } else {
      selectedSmokingStatus = smokingOptions.first;
    }

    // 디버깅: 각 값 출력
    print('DEBUG: selectedRoomType = ' + selectedRoomType.toString());
    print('DEBUG: selectedBuilding = ' + selectedBuilding.toString());
    print('DEBUG: selectedSmokingStatus = ' + selectedSmokingStatus.toString());

    // 첨부된 서류 로드 - null 방어 추가
    if (application['documents'] != null) {
      final documents = List<Map<String, dynamic>>.from(
        application['documents'],
      );
      // null 값 필터링
      final validDocuments =
          documents
              .where(
                (doc) =>
                    doc['file_name'] != null &&
                    doc['file_name'].toString().isNotEmpty,
              )
              .map(
                (doc) => {
                  'name': doc['file_name']?.toString() ?? 'Unknown File',
                  'size': doc['size'] ?? 0,
                  'uploadDate': doc['uploaded_at'] ?? DateTime.now(),
                  'id':
                      doc['doc_id']?.toString() ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  'isNew': false,
                },
              )
              .toList();

      setState(() {
        _savedFiles = validDocuments; // _attachedFiles 대신 _savedFiles에 저장
      });
    }
  }

  // 수정 모드 토글
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  // 파일 첨부 (AS신청과 동일한 방식)
  Future<void> _pickFiles() async {
    // 제출 완료 상태이고 수정 모드가 아니면 파일 선택 불가
    if (_isSubmitted && !_isEditMode) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('수정 모드에서만 파일을 선택할 수 있습니다.')));
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
        withData: true, // 항상 bytes를 가져오도록 설정
      );

      if (result != null) {
        setState(() {
          _attachedFiles =
              result.files.map((file) {
                // 웹 환경에서 안전하게 파일 정보 추출
                return {
                  'name': file.name,
                  'path': kIsWeb ? null : file.path, // 웹에서는 path 사용 안함
                  'bytes': file.bytes, // 웹과 모바일 모두에서 사용
                  'size': file.size,
                  'extension': file.extension ?? '',
                  'isNew': true,
                };
              }).toList();
        });

        print('파일 선택 완료: ${_attachedFiles.length}개 파일');
        for (var file in _attachedFiles) {
          print('- ${file['name']} (${file['size']} bytes)');
        }
      }
    } catch (e) {
      print('파일 선택 중 에러: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 선택 중 오류가 발생했습니다: $e')));
    }
  }

  // 파일 저장 (서버 업로드)
  Future<void> _saveFiles() async {
    if (_attachedFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('첨부할 파일을 선택해주세요.')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      for (var file in _attachedFiles) {
        Uint8List? fileBytes;

        // 웹과 모바일 환경 구분
        if (kIsWeb) {
          // 웹: bytes 사용
          fileBytes = file['bytes'] as Uint8List?;
        } else {
          // 모바일: path 사용
          if (file['path'] != null) {
            fileBytes = await File(file['path']!).readAsBytes();
          }
        }

        if (fileBytes != null) {
          // 실제 구현에서는 서버에 파일 업로드
          // 여기서는 시뮬레이션
          await Future.delayed(const Duration(milliseconds: 500));

          setState(() {
            _savedFiles.add({
              'name': file['name'] ?? 'Unknown File', // null 방어
              'size': file['size'] ?? 0, // null 방어
              'uploadDate': DateTime.now(),
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'isNew': false,
              'bytes': fileBytes, // bytes 정보 보존
              'path': file['path'], // path 정보도 보존
              'extension': file['extension'], // extension 정보도 보존
            });
          });
        }
      }

      setState(() {
        _attachedFiles.clear();
        _isUploading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('파일이 성공적으로 업로드되었습니다.')));
    } catch (e) {
      setState(() => _isUploading = false);
      print('파일 업로드 중 에러: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 업로드 중 오류가 발생했습니다: $e')));
    }
  }

  // 파일 미리보기
  void _previewFile(Map<String, dynamic> file) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('파일 미리보기'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('파일명: ${file['name'] ?? 'Unknown File'}'), // null 방어
                Text(
                  '크기: ${((file['size'] ?? 0) / 1024).toStringAsFixed(1)} KB',
                ), // null 방어
                Text(
                  '업로드일: ${(file['uploadDate'] ?? DateTime.now()).toString().split('.')[0]}',
                ), // null 방어
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }

  // 파일 수정
  void _editFile(Map<String, dynamic> file) {
    setState(() {
      _savedFiles.removeWhere((f) => f['id'] == file['id']);
    });
    _pickFiles();
  }

  // 입실신청 제출
  Future<void> _submitApplication() async {
    print('=== _submitApplication 시작 ===');
    print('수정 모드: $_isEditMode, 제출 완료: $_isSubmitted');
    print('첨부파일 수: ${_attachedFiles.length}');
    print('저장된파일 수: ${_savedFiles.length}');

    if (!_formKey.currentState!.validate()) {
      print('폼 검증 실패');
      return;
    }

    if (_attachedFiles.isEmpty && _savedFiles.isEmpty) {
      print('파일이 없어서 제출 중단');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('최소 1개 이상의 서류를 첨부해주세요.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. 입실신청 데이터 제출
      final applicationData = {
        'student_id': controllers['학번']!.text,
        'name': controllers['성명']!.text,
        'department': controllers['학과']!.text,
        'building': selectedBuilding,
        'room_type': selectedRoomType,
        'smoking': selectedSmokingStatus,
        'bank': controllers['은행']!.text,
        'account_holder': controllers['예금주명']!.text,
        'account_num': controllers['계좌번호']!.text,
      };

      http.Response response;
      int? checkinId;

      if (_isSubmitted && _isEditMode && _existingApplication != null) {
        // 수정 모드: 기존 신청 업데이트
        print('기존 신청 업데이트 API 호출 중...');
        final existingId = _existingApplication!['checkin_id'];
        response = await http.put(
          Uri.parse('http://localhost:5050/api/checkin/update/$existingId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(applicationData),
        );
        checkinId = existingId;
        print('기존 신청 업데이트 API 응답: ${response.statusCode}');
      } else {
        // 새 신청: 새로운 신청 생성
        print('새 입실신청 API 호출 중...');
        response = await http.post(
          Uri.parse('http://localhost:5050/api/checkin/apply'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(applicationData),
        );
        print('새 입실신청 API 응답: ${response.statusCode}');

        if (response.statusCode == 201) {
          final result = jsonDecode(response.body);
          checkinId = result['checkin_id'];
          print('새 입실신청 성공 - checkinId: $checkinId');
        }
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (checkinId != null) {
          // 2. 파일 업로드
          print('파일 업로드 시작...');
          await _uploadFiles(checkinId);
          print('파일 업로드 완료');
        }

        // 3. 메시지 준비 (상태 변경 전에)
        final message =
            (_isSubmitted && _isEditMode)
                ? '입실신청이 성공적으로 수정되었습니다.'
                : '입실신청이 성공적으로 제출되었습니다.';

        // 4. 제출 완료 상태로 변경
        setState(() {
          _isSubmitted = true;
          _isEditMode = false;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        _checkExistingApplication(); // 목록 새로고침
      } else {
        final error = jsonDecode(response.body);
        print('입실신청 실패: ${error}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('제출 실패: ${error['error']}')));
      }
    } catch (e) {
      print('입실신청 제출 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('제출 중 오류가 발생했습니다.')));
    } finally {
      setState(() => _isSubmitting = false);
      print('=== _submitApplication 완료 ===');
    }
  }

  // 파일 업로드
  Future<void> _uploadFiles(int checkinId) async {
    print(
      '_uploadFiles 시작 - checkinId: $checkinId, 첨부파일 수: ${_attachedFiles.length}, 저장된파일 수: ${_savedFiles.length}',
    );

    // 1. 새로 선택한 파일들 (_attachedFiles) 업로드
    for (var file in _attachedFiles) {
      print('새 파일 처리 중: ${file['name']}, isNew: ${file['isNew']}');

      if (file['isNew'] == true) {
        await _uploadSingleFile(checkinId, file);
      }
    }

    // 2. 저장된 파일들 (_savedFiles) 업로드
    for (var file in _savedFiles) {
      print('저장된 파일 처리 중: ${file['name']}');

      // _savedFiles의 파일들은 실제로는 아직 서버에 업로드되지 않았으므로 업로드 필요
      if (file['bytes'] != null) {
        await _uploadSingleFile(checkinId, file);
      }
    }

    print('_uploadFiles 완료');
  }

  // 단일 파일 업로드 함수
  Future<void> _uploadSingleFile(
    int checkinId,
    Map<String, dynamic> file,
  ) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://localhost:5050/api/checkin/upload'),
      );

      request.fields['checkin_id'] = checkinId.toString();
      request.fields['recruit_type'] = '1차';

      print('업로드 요청 준비 완료 - checkinId: ${checkinId}, recruit_type: 1차');

      if (kIsWeb) {
        // 웹에서는 bytes로 업로드
        if (file['bytes'] != null) {
          print(
            '웹 환경 - bytes로 파일 추가: ${file['name']}, 크기: ${file['bytes'].length}',
          );
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              file['bytes'],
              filename: file['name'] ?? 'unknown_file', // null 방어
            ),
          );
        } else {
          print('웹 환경 - bytes가 null입니다: ${file['name']}');
          return;
        }
      } else {
        // 모바일/데스크탑은 path로 업로드
        if (file['path'] != null) {
          print('모바일 환경 - path로 파일 추가: ${file['path']}');
          request.files.add(
            await http.MultipartFile.fromPath(
              'file',
              file['path'],
              filename: file['name'] ?? 'unknown_file', // null 방어
            ),
          );
        } else {
          print('모바일 환경 - path가 null입니다: ${file['name']}');
          return;
        }
      }

      print('파일 업로드 요청 전송 중...');
      final response = await request.send();
      print('파일 업로드 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        print('파일 업로드 성공: ${file['name']}, 응답: $responseBody');
      } else {
        final responseBody = await response.stream.bytesToString();
        print(
          '파일 업로드 실패: ${file['name']}, 상태코드: ${response.statusCode}, 응답: $responseBody',
        );
      }
    } catch (e) {
      print('파일 업로드 오류: ${file['name']}, 에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(32.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mainTitle('입실신청'),
            SizedBox(height: 10.h),
            _buildNoticeCard(),
            SizedBox(height: 16.h),
            _buildInfoCard(), // ▼▼▼▼▼ [수정] 통합된 정보 카드로 교체 ▼▼▼▼▼
            SizedBox(height: 16.h),
            _buildDormitoryCard(),
            SizedBox(height: 16.h),
            _buildDocumentCard(),
            SizedBox(height: 24.h),
            _buildSubmitButton(),
            SizedBox(height: 10.h),
          ],
        ),
      ),
    );
  }

  // ▼▼▼▼▼ [신규] 스타일이 적용된 TextField 빌더 ▼▼▼▼▼
  Widget _buildStyledTextField(
    String controllerKey,
    String label, {
    bool isRequired = false,
    bool isNumber = false,
    bool readOnly = false,
  }) {
    // 제출 완료 상태이고 수정 모드가 아닐 때 readOnly 적용
    final bool isReadOnlyState = readOnly || (_isSubmitted && !_isEditMode);

    return SizedBox(
      height: 52.h, // 높이 고정
      child: TextFormField(
        controller: controllers[controllerKey],
        readOnly: isReadOnlyState,
        keyboardType: isNumber ? TextInputType.number : null,
        inputFormatters:
            isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: TextStyle(
          fontSize: 14.sp,
          color:
              isReadOnlyState
                  ? const Color(0xFF9E9E9E)
                  : const Color(0xFF333333),
        ),
        validator: (value) {
          if (isRequired && (value == null || value.isEmpty)) {
            return '$label 항목은 필수입니다.';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 12.sp,
            color:
                isReadOnlyState
                    ? const Color(0xFF9E9E9E)
                    : const Color(0xFF757575),
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: EdgeInsets.fromLTRB(12.w, 20.h, 12.w, 8.h),
          filled: isReadOnlyState,
          fillColor: isReadOnlyState ? const Color(0xFFF5F5F5) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(
              color:
                  isReadOnlyState
                      ? const Color(0xFFE0E0E0)
                      : const Color(0xFFE0E0E0),
              width: 1.0,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(
              color:
                  isReadOnlyState
                      ? const Color(0xFFE0E0E0)
                      : const Color(0xFFE0E0E0),
              width: 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(
              color:
                  isReadOnlyState
                      ? const Color(0xFFE0E0E0)
                      : const Color(0xFF0D47A1),
              width: isReadOnlyState ? 1.0 : 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ▼▼▼▼▼ [신규] 스타일이 적용된 Dropdown 빌더 ▼▼▼▼▼
  Widget _buildStyledDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?)? onChanged,
    String? hint,
    bool isRequired = false,
  }) {
    // 제출 완료 상태이고 수정 모드가 아닐 때 비활성화
    final bool isDisabled = _isSubmitted && !_isEditMode;

    return SizedBox(
      height: 60.h, // validator 메시지 공간 포함
      child: DropdownButtonFormField2<T>(
        isExpanded: true,
        value: value,
        items:
            items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(
                  item.toString(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color:
                        isDisabled
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF333333),
                  ),
                ),
              );
            }).toList(),
        onChanged: isDisabled ? null : onChanged,
        validator: (value) {
          if (isRequired && value == null) {
            return '$label 항목은 필수입니다.';
          }
          return null;
        },
        hint:
            hint != null
                ? Text(
                  hint,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color:
                        isDisabled
                            ? const Color(0xFF9E9E9E)
                            : const Color(0xFF757575),
                  ),
                )
                : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 12.sp,
            color:
                isDisabled ? const Color(0xFF9E9E9E) : const Color(0xFF757575),
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: 12.h,
          ),
          filled: isDisabled,
          fillColor: isDisabled ? const Color(0xFFF5F5F5) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(
              color:
                  isDisabled
                      ? const Color(0xFFE0E0E0)
                      : const Color(0xFF0D47A1),
              width: isDisabled ? 1.0 : 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: const BorderSide(color: Colors.red, width: 1.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
        ),
        buttonStyleData: ButtonStyleData(
          height: 20.h,
          padding: EdgeInsets.only(left: 0, right: 0),
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 200.h,
          padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
  // ▲▲▲▲▲ [신규] 스타일 적용 위젯들 ▲▲▲▲▲

  Widget _mainTitle(String title) => Row(
    children: [
      Container(
        width: 4.w,
        height: 24.h,
        color: Colors.blue[900],
        margin: EdgeInsets.only(right: 8.w),
      ),
      Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.sp),
      ),
    ],
  );

  Widget _buildNoticeCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20.w, color: Colors.blue[600]),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공지사항',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _noticeContent,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ▼▼▼▼▼ [신규] 모든 정보 섹션을 포함하는 통합 카드 ▼▼▼▼▼
  Widget _buildInfoCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 기본 정보 섹션 ---
            _sectionTitle('기본 정보'),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _buildStyledTextField('성명', '성명', isRequired: true),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStyledTextField('학번', '학번', isRequired: true),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStyledTextField('학과', '학과', isRequired: true),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildStyledTextField('성별', '성별', isRequired: true),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStyledTextField(
                    '내국인외국인',
                    '내국인/외국인',
                    isRequired: true,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStyledTextField(
                    '생년월일',
                    '생년월일',
                    isRequired: true,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildStyledTextField('학년', '학년', isRequired: true),
                ),
                SizedBox(width: 16.w),
                Expanded(child: _buildStyledTextField('집전화', '집전화')),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStyledTextField('핸드폰', '핸드폰', isRequired: true),
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // --- 보호자, 주소, 환불 정보 섹션 (Row로 묶음) ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 보호자 정보 ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('보호자 정보'),
                      SizedBox(height: 16.h),
                      _buildStyledTextField(
                        '보호자성명',
                        '보호자 성명',
                        isRequired: true,
                      ),
                      SizedBox(height: 12.h),
                      _buildStyledTextField(
                        '보호자관계',
                        '보호자 관계',
                        isRequired: true,
                      ),
                      SizedBox(height: 12.h),
                      _buildStyledTextField(
                        '보호자전화번호',
                        '보호자 전화번호',
                        isRequired: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),

                // --- 주소 정보 ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('주소 정보'),
                      SizedBox(height: 16.h),
                      _buildStyledTextField('우편번호', '우편번호', isRequired: true),
                      SizedBox(height: 12.h),
                      _buildStyledTextField('기본주소', '기본주소', isRequired: true),
                      SizedBox(height: 12.h),
                      _buildStyledTextField('상세주소', '상세주소'),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),

                // --- 환불 정보 ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('환불 정보'),
                      SizedBox(height: 16.h),
                      _buildStyledDropdown<String>(
                        label: '환불은행',
                        value:
                            controllers['은행']!.text.isNotEmpty &&
                                    _banks.contains(controllers['은행']!.text)
                                ? controllers['은행']!.text
                                : null,
                        items: _banks,
                        onChanged: (value) {
                          setState(() {
                            controllers['은행']!.text = value ?? '';
                            controllers['환불은행']!.text = value ?? '';
                          });
                        },
                        hint: '은행 선택',
                        isRequired: true,
                      ),
                      SizedBox(height: 12.h),
                      _buildStyledTextField('계좌번호', '계좌번호', isRequired: true),
                      SizedBox(height: 12.h),
                      _buildStyledTextField('예금주명', '예금주', isRequired: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  // ▲▲▲▲▲ [신규] 통합 카드 위젯 ▲▲▲▲▲

  Widget _buildDormitoryCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('기숙사 정보'),
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: _buildStyledTextField('건물', '기숙사 건물', readOnly: true),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStyledDropdown<String>(
                    label: '방 타입',
                    value:
                        (selectedRoomType != null &&
                                _roomTypes.contains(selectedRoomType))
                            ? selectedRoomType
                            : null,
                    items: _roomTypes,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedRoomType = value);
                      }
                    },
                    isRequired: true,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: _buildStyledDropdown<String>(
                    label: '흡연여부',
                    value:
                        (selectedSmokingStatus != null &&
                                smokingOptions.contains(selectedSmokingStatus))
                            ? selectedSmokingStatus
                            : null,
                    items: smokingOptions,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedSmokingStatus = value);
                      }
                    },
                    isRequired: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('제출서류'),
            SizedBox(height: 16.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽: 파일 첨부 시스템
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '파일 첨부',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        height: 120.h,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                (_isSubmitted && !_isEditMode)
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade400,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(8.r),
                          color:
                              (_isSubmitted && !_isEditMode)
                                  ? const Color(0xFFF5F5F5)
                                  : Colors.white,
                        ),
                        child: InkWell(
                          onTap:
                              (_isSubmitted && !_isEditMode)
                                  ? null
                                  : _pickFiles,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_upload,
                                size: 32.w,
                                color:
                                    (_isSubmitted && !_isEditMode)
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                (_isSubmitted && !_isEditMode)
                                    ? '수정 모드에서 파일 선택 가능'
                                    : '클릭하여 파일을 선택하세요',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color:
                                      (_isSubmitted && !_isEditMode)
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                ),
                              ),
                              Text(
                                '(JPG, PNG, PDF, DOC, DOCX)',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color:
                                      (_isSubmitted && !_isEditMode)
                                          ? Colors.grey[400]
                                          : Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_attachedFiles.isNotEmpty) ...[
                        SizedBox(height: 12.h),
                        Text(
                          '선택된 파일:',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ...(_attachedFiles
                            .where((file) => file['name'] != null) // null 값 필터링
                            .map(
                              (file) => Container(
                                margin: EdgeInsets.only(bottom: 4.h),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        file['name']?.toString() ??
                                            'Unknown File', // null 방어
                                        style: TextStyle(fontSize: 12.sp),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        size: 16.w,
                                        color:
                                            (_isSubmitted && !_isEditMode)
                                                ? Colors.grey[400]
                                                : null,
                                      ),
                                      onPressed:
                                          (_isSubmitted && !_isEditMode)
                                              ? null
                                              : () {
                                                setState(() {
                                                  _attachedFiles.remove(file);
                                                });
                                              },
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList()),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed:
                                  (_isUploading ||
                                          (_isSubmitted && !_isEditMode))
                                      ? null
                                      : _saveFiles,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    (_isSubmitted && !_isEditMode)
                                        ? Colors.grey[400]
                                        : Colors.blue[600],
                                foregroundColor: Colors.white,
                              ),
                              child:
                                  _isUploading
                                      ? SizedBox(
                                        width: 16.w,
                                        height: 16.h,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('저장'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 24.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '저장된 파일',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        height: 200.h,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child:
                            _savedFiles.isEmpty
                                ? Center(
                                  child: Text(
                                    '저장된 파일이 없습니다.',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: _savedFiles.length,
                                  itemBuilder: (context, index) {
                                    final file = _savedFiles[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(
                                        file['name']?.toString() ??
                                            'Unknown File', // null 방어
                                        style: TextStyle(fontSize: 12.sp),
                                      ),
                                      subtitle: Text(
                                        '${((file['size'] ?? 0) / 1024).toStringAsFixed(1)} KB', // null 방어
                                        style: TextStyle(fontSize: 10.sp),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.visibility,
                                              size: 16.w,
                                            ),
                                            onPressed: () => _previewFile(file),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.edit,
                                              size: 16.w,
                                              color:
                                                  (_isSubmitted && !_isEditMode)
                                                      ? Colors.grey[400]
                                                      : null,
                                            ),
                                            onPressed:
                                                (_isSubmitted && !_isEditMode)
                                                    ? null
                                                    : () => _editFile(file),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: ElevatedButton(
        onPressed:
            _isSubmitting
                ? null
                : _isSubmitted && !_isEditMode
                ? _toggleEditMode
                : _isSubmitted && _isEditMode
                ? _submitApplication
                : _submitApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _isSubmitted && !_isEditMode
                  ? Colors.grey[600]
                  : Colors.blue[900],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 48.w, vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
        ),
        child:
            _isSubmitting
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    const Text('제출 중...'),
                  ],
                )
                : Text(
                  _isSubmitted && !_isEditMode
                      ? '수정하기'
                      : _isSubmitted && _isEditMode
                      ? '수정 완료'
                      : '입실신청 제출',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
  );
}
