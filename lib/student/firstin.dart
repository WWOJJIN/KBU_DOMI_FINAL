import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:html' as html; // ⭐️ Flutter Web에서 팝업, postMessage
import 'dart:convert';
import 'package:http/http.dart' as http; // ⭐️ API 호출을 위해 추가
import 'package:kbu_domi/env.dart';

// 페이지 이동을 위해 import 추가
import 'first.dart';
import 'domi_portal/login.dart';

/*
  [사전 준비사항]
  이 코드는 카카오 주소 API를 팝업으로 사용합니다.
  프로젝트의 web 폴더 안에 아래 경로와 이름으로 html 파일을 생성하고,
  카카오에서 제공하는 공식 코드를 붙여넣어야 합니다.
  - 경로: web/assets/daum_postcode_popup.html
*/

class FirstInPage extends StatefulWidget {
  final String? studentId;
  final String? studentName;
  final String? userType; // 재학생/신입생 구분

  const FirstInPage({
    super.key,
    this.studentId,
    this.studentName,
    this.userType,
  });

  @override
  State<FirstInPage> createState() => _FirstInPageState();
}

class _FirstInPageState extends State<FirstInPage> {
  // --- 1. 상태 변수 및 컨트롤러 ---
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 5; // 총 5단계

  // ⭐️ 고정값을 사용자 입력 가능한 필드로 변경
  String _selectedRecruitmentType = '신입생';
  final String _academicYear = DateTime.now().year.toString(); // ⭐️ 시스템에서 자동 설정
  String _selectedSemester = '1학기';
  String _selectedApplicantType = '내국인';

  // ⭐️ 컨트롤러 추가 (고정값을 입력 가능하게)
  final _studentIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _departmentController = TextEditingController();

  // 입력값
  String _selectedGrade = '1학년';
  String _selectedGender = '남자'; // ⭐️ 고정값 제거
  String _selectedNationality = '대한민국';
  String _selectedSmoking = '비흡연';
  String _selectedRoomType = '2인실';
  bool _isBasicSupport = false;
  bool _isDisabledStudent = false;
  bool _noHomePhone = false;

  final _birthDateController = TextEditingController();
  final _passportController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _regionController = TextEditingController();
  final _homePhoneController = TextEditingController();
  final _mobilePhoneController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianRelController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();

  // ⭐️ 로딩 상태 추가
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 로그인에서 전달받은 arguments 처리
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final loginStudentId = args['studentId'] as String?;
      final loginStudentName = args['studentName'] as String?;
      final loginUserType = args['userType'] as String?;

      print(
        '🔍 FirstInPage - 받은 로그인 정보: studentId=$loginStudentId, name=$loginStudentName, userType=$loginUserType',
      );

      if (loginStudentId != null && loginStudentName != null) {
        // 신입생인 경우 수험번호를 그대로 사용, 재학생인 경우 학번을 그대로 사용
        _studentIdController.text = loginStudentId;
        _nameController.text = loginStudentName;

        // 모집구분을 로그인 타입에 맞게 설정
        if (loginUserType == '신입생') {
          _selectedRecruitmentType = '신입생';
        } else {
          _selectedRecruitmentType = '재학생';
        }

        print(
          '✅ FirstInPage - 설정완료: student_id=${_studentIdController.text}, name=${_nameController.text}, type=$_selectedRecruitmentType',
        );
      }
    }
  }

  // ⭐️ 모든 필수값 에러 상태 관리
  // 1페이지 에러 상태
  bool _recruitmentTypeError = false;
  bool _semesterError = false;
  bool _studentIdError = false;
  bool _nameError = false;
  bool _departmentError = false;
  bool _applicantTypeError = false;
  bool _genderError = false;
  bool _gradeError = false;
  bool _birthDateError = false;
  bool _nationalityError = false;
  bool _passportError = false;
  bool _smokingError = false;

  // 2페이지 에러 상태
  bool _postalCodeError = false;
  bool _address1Error = false;
  bool _regionError = false;
  bool _mobilePhoneError = false;

  // 3페이지 에러 상태
  bool _guardianNameError = false;
  bool _guardianRelError = false;
  bool _guardianPhoneError = false;

  // 4페이지 에러 상태
  bool _roomTypeError = false;

  // 5페이지 에러 상태
  bool _bankNameError = false;
  bool _accountNumberError = false;
  bool _accountHolderError = false;

  @override
  void initState() {
    super.initState();
    if (_selectedApplicantType == '내국인') {
      _selectedNationality = '대한민국';
    }

    // ⭐️ 카카오/다음 주소 팝업에서 온 postMessage 수신 (수정)
    html.window.onMessage.listen((event) {
      print('메시지 수신됨: ${event.data}'); // 디버깅용
      print('데이터 타입: ${event.data.runtimeType}'); // 디버깅용

      if (event.data != null) {
        try {
          // 안전한 방법으로 Map 변환
          Map<String, dynamic> data;

          if (event.data is Map) {
            // LinkedMap이나 다른 Map 타입을 안전하게 변환
            data = Map<String, dynamic>.from(event.data);
          } else {
            print('지원하지 않는 데이터 형식: ${event.data.runtimeType}');
            return;
          }

          print('변환된 데이터: $data'); // 디버깅용

          // zonecode 키가 있는지 확인하고 UI 업데이트
          if (data.containsKey('zonecode') && data['zonecode'] != null) {
            setState(() {
              _postalCodeController.text = data['zonecode']?.toString() ?? '';
              _address1Controller.text = data['roadAddress']?.toString() ?? '';

              // 지역구분 조합 (시도 + 시군구)
              String region = '';
              if (data['sido'] != null) {
                region = data['sido'].toString();
                if (data['sigungu'] != null) {
                  region += ' ${data['sigungu'].toString()}';
                }
              }
              _regionController.text = region;
            });

            print('주소 정보 업데이트 완료'); // 디버깅용
            print('우편번호: ${_postalCodeController.text}');
            print('기본주소: ${_address1Controller.text}');
            print('지역구분: ${_regionController.text}');
          } else {
            print('zonecode가 없거나 null입니다: $data');
          }
        } catch (e) {
          print('주소 데이터 처리 오류: $e');
          print('스택 트레이스: ${e.toString()}');
        }
      }
    });
  }

  // --- 2. 페이지 및 로직 ---
  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _submitApplication();
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _findAddress() {
    html.window.open(
      'daum_postcode_popup.html',
      'daum_postcode_popup',
      'width=500,height=600,scrollbars=yes',
    );
  }

  // ⭐️ 완전히 새로운 필수값 검증 로직
  Future<void> _submitApplication() async {
    // 모든 에러 상태 초기화
    setState(() {
      // 1페이지
      _recruitmentTypeError = false;
      _semesterError = false;
      _studentIdError = false;
      _nameError = false;
      _departmentError = false;
      _applicantTypeError = false;
      _genderError = false;
      _gradeError = false;
      _birthDateError = false;
      _nationalityError = false;
      _passportError = false;
      _smokingError = false;

      // 2페이지
      _postalCodeError = false;
      _address1Error = false;
      _regionError = false;
      _mobilePhoneError = false;

      // 3페이지
      _guardianNameError = false;
      _guardianRelError = false;
      _guardianPhoneError = false;

      // 4페이지
      _roomTypeError = false;

      // 5페이지
      _bankNameError = false;
      _accountNumberError = false;
      _accountHolderError = false;
    });

    bool hasError = false;
    int errorPage = -1; // -1로 초기화

    // ⭐️ 1페이지(0번) 필수값 검증
    if (_selectedRecruitmentType.isEmpty) {
      _recruitmentTypeError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 0;
    }
    if (_selectedSemester.isEmpty) {
      _semesterError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 0;
    }
    if (_studentIdController.text.isEmpty) {
      _studentIdError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 0;
    }
    if (_nameController.text.isEmpty) {
      _nameError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 0;
    }
    if (_departmentController.text.isEmpty) {
      _departmentError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 0;
    }
    if (_selectedApplicantType.isEmpty) {
      _applicantTypeError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 0;
    }
    if (_selectedGender.isEmpty) {
      _genderError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 0;
    }
    if (_selectedGrade.isEmpty) {
      _gradeError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 0;
    }
    if (_birthDateController.text.isEmpty) {
      _birthDateError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 0;
    }

    // 외국인일 경우만 체크
    if (_selectedApplicantType == '외국인') {
      if (_selectedNationality.isEmpty || _selectedNationality == '대한민국') {
        _nationalityError = true;
        hasError = true;
        if (errorPage == -1) errorPage = 0;
      }
      if (_passportController.text.isEmpty) {
        _passportError = true;
        hasError = true;
        if (errorPage == -1) errorPage = 0;
      }
    }

    if (_selectedSmoking.isEmpty) {
      _smokingError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 0;
    }

    // ⭐️ 2페이지(1번) 필수값 검증
    if (_postalCodeController.text.isEmpty) {
      _postalCodeError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 1;
    }
    if (_address1Controller.text.isEmpty) {
      _address1Error = true;
      hasError = true;
      if (errorPage == -1) errorPage = 1;
    }
    if (_regionController.text.isEmpty) {
      _regionError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 1;
    }
    if (_mobilePhoneController.text.isEmpty) {
      _mobilePhoneError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 1;
    }

    // ⭐️ 3페이지(2번) 필수값 검증
    if (_guardianNameController.text.isEmpty) {
      _guardianNameError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 2;
    }
    if (_guardianRelController.text.isEmpty) {
      _guardianRelError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 2;
    }
    if (_guardianPhoneController.text.isEmpty) {
      _guardianPhoneError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 2;
    }

    // ⭐️ 4페이지(3번) 필수값 검증
    if (_selectedRoomType.isEmpty) {
      _roomTypeError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 3;
    }

    // ⭐️ 5페이지(4번) 필수값 검증
    if (_bankNameController.text.isEmpty) {
      _bankNameError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 4;
    }
    if (_accountNumberController.text.isEmpty) {
      _accountNumberError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 4;
    }
    if (_accountHolderController.text.isEmpty) {
      _accountHolderError = true;
      hasError = true;
      if (errorPage == -1) errorPage = 4;
    }

    if (hasError) {
      setState(() {}); // 에러 상태 UI 업데이트

      // 첫 번째 에러 페이지로 이동
      _pageController.animateToPage(
        errorPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );

      _showErrorDialog('필수 정보를 모두 입력해주세요.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // API 호출용 데이터 준비
      final requestData = {
        'recruit_type': _selectedRecruitmentType,
        'year': _academicYear,
        'semester': _selectedSemester,
        'student_id': _studentIdController.text,
        'name': _nameController.text,
        'birth_date': _birthDateController.text,
        'gender': _selectedGender,
        'nationality': _selectedNationality,
        'grade': _selectedGrade,
        'department': _departmentController.text,
        'passport_num':
            _passportController.text.isNotEmpty
                ? _passportController.text
                : null,
        'applicant_type': _selectedApplicantType,
        'address_basic': _address1Controller.text,
        'address_detail': _address2Controller.text,
        'postal_code': _postalCodeController.text,
        'region_type': _regionController.text,
        'tel_home': _noHomePhone ? null : _homePhoneController.text,
        'tel_mobile': _mobilePhoneController.text,
        'par_name': _guardianNameController.text,
        'par_relation': _guardianRelController.text,
        'par_phone': _guardianPhoneController.text,
        'is_basic_living': _isBasicSupport,
        'is_disabled': _isDisabledStudent,
        'room_type': _selectedRoomType,
        'smoking_status': _selectedSmoking,
        'bank': _bankNameController.text,
        'account_num': _accountNumberController.text,
        'account_holder': _accountHolderController.text,
      };

      // API 호출
      print('🚀 입주신청 API 호출 시작 - studentId: ${_studentIdController.text}');
      final response = await http.post(
        Uri.parse('$apiBase/api/firstin/apply'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      print('📡 서버 응답: StatusCode=${response.statusCode}');
      print('📡 서버 응답 Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 성공 (200 또는 201 모두 성공으로 처리)
        final responseData = json.decode(response.body);
        _showSuccessDialog(
          responseData['message'] ?? '입주 신청이 성공적으로 제출되었습니다.',
          isSuccess: true,
        );
      } else if (response.statusCode == 409) {
        // 중복 신청
        final responseData = json.decode(response.body);
        _showErrorDialog(
          responseData['error'] ??
              '이미 신청이 완료되었습니다.\n기존 신청 내용을 확인하시거나 관리자에게 문의하세요.',
        );
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        // 클라이언트 오류 (잘못된 요청)
        final responseData = json.decode(response.body);
        _showErrorDialog(
          responseData['error'] ?? '입력 정보에 오류가 있습니다. 다시 확인해주세요.',
        );
      } else if (response.statusCode >= 500) {
        // 서버 오류
        _showErrorDialog('서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
      } else {
        // 기타 예상치 못한 응답
        final responseData = json.decode(response.body);
        _showErrorDialog(
          responseData['error'] ??
              '알 수 없는 오류가 발생했습니다. (응답코드: ${response.statusCode})',
        );
      }
    } catch (e) {
      _showErrorDialog('네트워크 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
          title: const Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text(
                '확인',
                style: TextStyle(color: Color(0xFF033762)),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessDialog(String message, {bool isSuccess = false}) {
    showDialog(
      context: context,
      barrierDismissible: false, // 배경 터치로 닫기 방지
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24.sp),
              SizedBox(width: 8.w),
              const Text('신청 완료'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 다음 단계 안내',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '• 신청서 검토 후 승인 여부가 결정됩니다\n'
                      '• 승인 결과는 기숙사 포털에서 확인하세요\n'
                      '• 승인 후 자동 방배정이 진행됩니다',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.blue.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text(
                '기숙사 포털로 이동',
                style: TextStyle(color: Color(0xFF033762)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                // 기숙사 포털 로그인 페이지로 이동
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(redirectTo: 'portal'),
                  ),
                );
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF033762),
                foregroundColor: Colors.white,
              ),
              child: const Text('메인으로'),
              onPressed: () {
                Navigator.of(context).pop();
                // 첫 페이지로 이동
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DormIntroPage(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // --- 3. UI 빌드 ---
  static Widget _topMenuBtn(
    String label, {
    bool highlight = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.grey.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.0.w, vertical: 8.h),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16.sp,
            color:
                highlight ? const Color(0xFF1766AE) : const Color(0xFF222222),
            fontWeight: highlight ? FontWeight.bold : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKorean = _selectedApplicantType == '내국인';
    final String buildingName = _selectedGender == '남자' ? '숭례원' : '양덕원';

    List<Widget> pages = [
      _buildStepPage(
        children: [
          _buildSectionTitle('신청자 정보'),
          _buildReadOnlyGrid([
            _buildDropdown(
              '모집구분',
              ['신입생', '재학생'],
              _selectedRecruitmentType,
              (v) => setState(() => _selectedRecruitmentType = v!),
              hasError: _recruitmentTypeError,
            ),
            _buildReadOnlyField('학년도', _academicYear), // ⭐️ 읽기전용으로 변경
            _buildDropdown(
              '학기',
              ['1학기', '2학기'],
              _selectedSemester,
              (v) => setState(() => _selectedSemester = v!),
              hasError: _nameError,
            ),
          ]),
          _buildReadOnlyGrid([
            _buildTextField(
              '학번',
              _studentIdController,
              hasError: _studentIdError,
            ),
            _buildTextField('성명', _nameController, hasError: _nameError),
            _buildTextField(
              '학과',
              _departmentController,
              hasError: _departmentError,
            ),
          ]),
          _buildReadOnlyGrid([
            _buildDropdown(
              '지원생구분',
              ['내국인', '외국인'],
              _selectedApplicantType,
              (v) => setState(() {
                _selectedApplicantType = v!;
                if (v == '내국인') {
                  _selectedNationality = '대한민국';
                }
              }),
              hasError: _applicantTypeError,
            ),
            _buildDropdown(
              '성별',
              ['남자', '여자'],
              _selectedGender,
              (v) => setState(() => _selectedGender = v!),
              hasError: _genderError,
            ),
            const Spacer(),
          ]),
          _buildSectionTitle('기본 인적사항'),
          _buildDropdown(
            '학년',
            ['1학년', '2학년', '3학년', '4학년'],
            _selectedGrade,
            (v) => setState(() => _selectedGrade = v!),
            hasError: _gradeError,
          ),
          _buildDateField(
            '생년월일',
            _birthDateController,
            hasError: _birthDateError,
          ),
          _buildDropdown(
            '국적',
            ['대한민국', '중국', '베트남', '일본', '기타'],
            _selectedNationality,
            (v) => setState(() => _selectedNationality = v!),
            enabled: !isKorean,
            hasError: _nationalityError,
          ),
          _buildTextField(
            '여권번호',
            _passportController,
            enabled: !isKorean,
            hint: isKorean ? '외국인만 해당' : '',
            hasError: _passportError,
          ),
          _buildDropdown(
            '흡연여부',
            ['비흡연', '흡연'],
            _selectedSmoking,
            (v) => setState(() => _selectedSmoking = v!),
            hasError: _smokingError,
          ),
          Row(
            children: [
              _buildCheckbox(
                '국민기초생활수급자',
                _isBasicSupport,
                (v) => setState(() => _isBasicSupport = v!),
              ),
              SizedBox(width: 20.w),
              _buildCheckbox(
                '장애학생',
                _isDisabledStudent,
                (v) => setState(() => _isDisabledStudent = v!),
              ),
            ],
          ),
        ],
      ),
      _buildStepPage(
        children: [
          _buildSectionTitle("주소 및 연락처"),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _buildTextField(
                  '우편번호',
                  _postalCodeController,
                  enabled: false,
                  hasError: _postalCodeError,
                ),
              ),
              SizedBox(width: 8.w),
              SizedBox(
                height: 40.h,
                child: ElevatedButton(
                  onPressed: _findAddress,
                  child: const Text('주소찾기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D6675),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          _buildTextField(
            '기본주소',
            _address1Controller,
            enabled: false,
            hasError: _address1Error,
          ),
          _buildTextField('상세주소', _address2Controller),
          _buildTextField(
            '지역구분',
            _regionController,
            enabled: false,
            hasError: _regionError,
          ),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  '집전화',
                  _homePhoneController,
                  enabled: !_noHomePhone,
                ),
              ),
              SizedBox(width: 8.w),
              _buildCheckbox(
                '없음',
                _noHomePhone,
                (v) => setState(() => _noHomePhone = v!),
              ),
            ],
          ),
          _buildTextField(
            '핸드폰번호',
            _mobilePhoneController,
            hint: '010-0000-0000',
            formatters: [_HyphenInputFormatter()],
            hasError: _mobilePhoneError,
          ),
        ],
      ),
      _buildStepPage(
        children: [
          _buildSectionTitle("보호자 정보"),
          _buildTextField(
            '보호자 성명',
            _guardianNameController,
            hasError: _guardianNameError,
          ),
          _buildTextField(
            '보호자 관계',
            _guardianRelController,
            hasError: _guardianRelError,
          ),
          _buildTextField(
            '보호자 전화번호',
            _guardianPhoneController,
            formatters: [_HyphenInputFormatter()],
            hasError: _guardianPhoneError,
          ),
        ],
      ),
      _buildStepPage(
        children: [
          _buildSectionTitle("희망 호실 정보"),
          _buildReadOnlyField('건물', buildingName),
          _buildDropdown(
            '방 타입',
            ['1인실', '2인실', '3인실', '룸메이트 신청예정'],
            _selectedRoomType,
            (v) => setState(() => _selectedRoomType = v!),
            hasError: _roomTypeError,
          ),
          Container(
            alignment: Alignment.centerLeft,
            height: 40.h,
            child: Text(
              '※ 배정호실은 자동배정 예정입니다.',
              style: TextStyle(color: Colors.red, fontSize: 13.sp),
            ),
          ),
        ],
      ),
      _buildStepPage(
        children: [
          _buildSectionTitle("환불 계좌 정보"),
          _buildTextField('은행', _bankNameController, hasError: _bankNameError),
          _buildTextField(
            '계좌번호',
            _accountNumberController,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            hasError: _accountNumberError,
          ),
          _buildTextField(
            '예금주',
            _accountHolderController,
            hasError: _accountHolderError,
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          // ==================== 기존 상단 UI 부분 ====================
          Container(
            color: const Color(0xFFF6F6F6),
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 4.h),
            child: Row(
              children: [
                Text(
                  '경복대학교  |  입학홈페이지',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 18.h),
            child: Row(
              children: [
                Image.asset(
                  'imgs/kbu_logo1.png',
                  height: 50.h,
                  fit: BoxFit.fitHeight,
                ),
                const Spacer(),
                Row(
                  children: [
                    _topMenuBtn('생활관소개'),
                    _topMenuBtn('시설안내'),
                    _topMenuBtn('입사/퇴사/생활안내'),
                    _topMenuBtn('커뮤니티'),
                    _topMenuBtn(
                      '기숙사 입주신청',
                      highlight: true,
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const LoginPage(
                                    redirectTo: 'application',
                                  ),
                            ),
                          ),
                    ),
                    _topMenuBtn(
                      '기숙사 포털시스템',
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      const LoginPage(redirectTo: 'portal'),
                            ),
                          ),
                    ),
                    IconButton(
                      icon: Icon(Icons.menu, size: 28.sp),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          // [팀원 UI 구조 유지] 파란색 헤더 영역
          Stack(
            children: [
              Container(
                height: 80.h,
                width: double.infinity,
                color: const Color(0xFF033762),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 56.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '기숙사 입주신청',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Challenge Your Dream!',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 36.w,
                            height: 36.h,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Icon(
                              Icons.share,
                              color: const Color(0xFF033762),
                              size: 20.sp,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Container(
                            width: 36.w,
                            height: 36.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFF002F55),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Icon(
                              Icons.print,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // ==================== 팀원 UI 구조 유지: 중앙 정렬된 컴팩트 폼 ====================
          Expanded(
            child: Center(
              child: Container(
                width: 800.w,
                margin: EdgeInsets.symmetric(vertical: 40.h),
                child: Column(
                  children: [
                    // --- 진행률 표시 바 ---
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      child: Row(
                        children: List.generate(_totalPages, (index) {
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.symmetric(horizontal: 4.w),
                              height: 6.h,
                              decoration: BoxDecoration(
                                color:
                                    index <= _currentPage
                                        ? const Color(0xFF033762)
                                        : Colors.grey[300],
                                borderRadius: BorderRadius.circular(3.r),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // --- 페이지 뷰 ---
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged:
                            (int page) => setState(() => _currentPage = page),
                        physics: const NeverScrollableScrollPhysics(),
                        children: pages,
                      ),
                    ),
                    // --- 네비게이션 버튼 ---
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.h),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentPage > 0)
                            ElevatedButton(
                              onPressed: _previousPage,
                              child: const Text('이전'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                                foregroundColor: Colors.white,
                                minimumSize: Size(120.w, 45.h),
                              ),
                            )
                          else
                            SizedBox(width: 120.w),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _nextPage,
                            child:
                                _isSubmitting
                                    ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : Text(
                                      _currentPage == _totalPages - 1
                                          ? '제출'
                                          : '다음',
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF033762),
                              foregroundColor: Colors.white,
                              minimumSize: Size(120.w, 45.h),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. UI 헬퍼 위젯들 (팀원 버전 유지) ---
  Widget _buildStepPage({required List<Widget> children}) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children.map(
            (child) =>
                Padding(padding: EdgeInsets.only(bottom: 16.h), child: child),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, top: 12.h),
      child: Text(
        title,
        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildReadOnlyGrid(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          children.map((child) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 12.w, 12.h),
                child: child,
              ),
            );
          }).toList(),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13.sp, color: Colors.grey[700])),
        SizedBox(height: 4.h),
        Container(
          width: double.infinity,
          height: 40.h,
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Text(value, style: TextStyle(fontSize: 14.sp)),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    String? hint,
    List<TextInputFormatter>? formatters,
    bool hasError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: hasError ? Colors.red : Colors.grey[700],
          ),
        ),
        SizedBox(height: 4.h),
        SizedBox(
          height: 40.h,
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            inputFormatters: formatters,
            style: TextStyle(fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: hint,
              filled: !enabled,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.r),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey,
                  width: hasError ? 2.0 : 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.r),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey,
                  width: hasError ? 2.0 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.r),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : const Color(0xFF033762),
                  width: 2.0,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 8.h,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String value,
    void Function(String?)? onChanged, {
    bool enabled = true,
    bool hasError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: hasError ? Colors.red : Colors.grey[700],
          ),
        ),
        SizedBox(height: 4.h),
        SizedBox(
          height: 40.h,
          child: DropdownButtonFormField<String>(
            value: value,
            items:
                items
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: TextStyle(fontSize: 14.sp)),
                      ),
                    )
                    .toList(),
            onChanged: enabled ? onChanged : null,
            dropdownColor: Colors.white,
            style: TextStyle(fontSize: 14.sp, color: Colors.black87),
            decoration: InputDecoration(
              filled: !enabled,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.r),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey,
                  width: hasError ? 2.0 : 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.r),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey,
                  width: hasError ? 2.0 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.r),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : const Color(0xFF033762),
                  width: 2.0,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 8.h,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(
    String label,
    TextEditingController controller, {
    bool hasError = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: hasError ? Colors.red : Colors.grey[700],
          ),
        ),
        SizedBox(height: 4.h),
        SizedBox(
          height: 40.h,
          child: TextFormField(
            controller: controller,
            readOnly: true,
            style: TextStyle(fontSize: 14.sp),
            decoration: InputDecoration(
              hintText: 'YYYY-MM-DD',
              suffixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.r),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey,
                  width: hasError ? 2.0 : 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.r),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey,
                  width: hasError ? 2.0 : 1.0,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4.r),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : const Color(0xFF033762),
                  width: 2.0,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 8.h,
              ),
            ),
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime(2005),
                firstDate: DateTime(1980),
                lastDate: DateTime.now(),
                builder:
                    (context, child) => Theme(
                      data: ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF033762),
                          onPrimary: Colors.white,
                          surface: Colors.white,
                        ),
                        dialogBackgroundColor: Colors.white,
                      ),
                      child: child!,
                    ),
              );
              if (picked != null) {
                controller.text =
                    "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                if (hasError) {
                  setState(() {
                    _birthDateError = false;
                  });
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    void Function(bool?)? onChanged,
  ) {
    return InkWell(
      onTap: () => onChanged!(!value),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF033762),
          ),
          Text(label, style: TextStyle(fontSize: 14.sp)),
        ],
      ),
    );
  }
}

class _HyphenInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll('-', '');
    if (newValue.selection.baseOffset == 0) return newValue;
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if ((nonZeroIndex == 3 || nonZeroIndex == 7) &&
          nonZeroIndex != text.length) {
        buffer.write('-');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
