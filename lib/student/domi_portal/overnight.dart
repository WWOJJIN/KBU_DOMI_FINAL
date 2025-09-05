import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../student_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 외출/외박 신청 페이지
/// - 외출: 당일 복귀하는 외출 신청
/// - 외박: 여러 날짜에 걸친 외박 신청
class OutingRequestPage extends StatefulWidget {
  const OutingRequestPage({super.key});

  @override
  _OutingRequestPageState createState() => _OutingRequestPageState();
}

class _OutingRequestPageState extends State<OutingRequestPage> {
  // ===== 기본 정보 설정 =====
  final String selectedYear = DateTime.now().year.toString();
  final String selectedSemester =
      (DateTime.now().month >= 3 && DateTime.now().month <= 8) ? '1학기' : '2학기';

  // ===== 입력 필드 컨트롤러 =====
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController placeController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController guardianContactController =
      TextEditingController();

  // ===== 유효성 검사 에러 메시지 =====
  String? placeError;
  String? reasonError;
  String? contactError;
  String? guardianContactError;
  String? guardianAgreeError;
  String? returnTimeError;
  String? dateError;

  // ===== 날짜 관련 변수 =====
  DateTime? rangeStart;
  DateTime? rangeEnd;
  bool guardianAgree = false;

  // ===== 신청 목록 관리 =====
  List<Map<String, dynamic>> requests = [];

  // ===== 신청 목록 필터링 =====
  String selectedFilter = '전체';
  final List<String> filterOptions = ['전체', '대기', '승인', '반려'];

  // ===== 복귀 시간 설정 =====
  // 30분 간격으로 05:00 ~ 23:30 설정 (통금시간 00:00~04:59 제외)
  final List<String> returnTimes = List.generate(38, (i) {
    final totalIndex = i + 10; // 05:00부터 시작하므로 10개 시간대 건너뛰기
    final hour = totalIndex ~/ 2;
    final minute = (totalIndex % 2) * 30;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  });
  late final List<DropdownMenuItem<String>> returnTimeItems;
  String selectedReturnTime = '';

  // ===== 사유 입력 필드 포커스 관리 =====
  final FocusNode reasonFocusNode = FocusNode();
  final FocusNode placeFocusNode = FocusNode();

  // ===== 공지사항 관련 변수 추가 =====
  String _noticeContent = '외박 신청은 월 단위로 가능하며, 납부 후 환불 불가합니다.';

  // ===== 현재 선택된 신청 유형 반환 =====
  String get outingType => '외박';

  bool _isFirst = true;

  // ===== 학생 데이터 로드 =====
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirst) {
      _loadStudentData();
      _loadRequests();
      _loadNotice(); // 공지사항 로드 추가
      _isFirst = false;
    }
  }

  // ===== 프로바이더에서 학생 정보 가져오기 =====
  void _loadStudentData() {
    final student = Provider.of<StudentProvider>(context, listen: true);
    print('학생 데이터 로드: ${student.studentId}, ${student.name}');
    if (student.studentId != null) {
      studentIdController.text = student.studentId!;
      nameController.text = student.name ?? '';
      contactController.text = student.phoneNum ?? '';
      guardianContactController.text = student.parPhone ?? '';
    } else {
      print('경고: 학생 데이터가 없습니다!');
    }
  }

  // ===== 신청 목록 로드 =====
  Future<void> _loadRequests() async {
    final student = Provider.of<StudentProvider>(context, listen: false);
    if (student.studentId == null) {
      print('경고: 학생 ID가 없어서 외박 신청 목록을 로드할 수 없습니다.');
      return;
    }

    print('외박 신청 목록 로드 시작 - 학생 ID: ${student.studentId}');

    try {
      final url =
          'http://localhost:5050/api/overnight/student/requests?student_id=${student.studentId}';
      print('API 호출 URL: $url');

      final response = await http.get(Uri.parse(url));
      print('API 응답 상태 코드: ${response.statusCode}');
      print('API 응답 헤더: ${response.headers}');
      print('API 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          print('경고: API 응답이 비어있습니다.');
          setState(() {
            requests = [];
          });
          return;
        }

        final dynamic rawData = json.decode(responseBody);
        print('디코딩된 응답 데이터 타입: ${rawData.runtimeType}');
        print('디코딩된 응답 데이터: $rawData');

        // 응답이 에러 객체인지 확인
        if (rawData is Map && rawData.containsKey('error')) {
          throw Exception(rawData['error']);
        }

        final List<dynamic> data = rawData is List ? rawData : [];
        print('처리할 데이터 개수: ${data.length}');

        setState(() {
          requests =
              data.map((item) {
                print('처리 중인 항목: $item');
                return {
                  'out_uuid': item['out_uuid'] ?? '',
                  'student_id': item['student_id'] ?? '',
                  'out_type': item['out_type'] ?? '',
                  'place': item['place'] ?? '',
                  'reason': item['reason'] ?? '',
                  'return_time': item['return_time'] ?? '',
                  'out_start': item['out_start'] ?? '',
                  'out_end': item['out_end'] ?? '',
                  'par_agr': item['par_agr'] ?? 0,
                  'stat': item['stat'] ?? '대기',
                  'rejection_reason':
                      item['rejection_reason'], // 서버에서 제공하는 필드명 사용
                  'date': _formatDateRange(
                    DateTime.parse(
                      item['out_start'] ?? DateTime.now().toString(),
                    ),
                    DateTime.parse(
                      item['out_end'] ?? DateTime.now().toString(),
                    ),
                  ),
                };
              }).toList();
        });
        print('신청 목록 로드 완료: ${requests.length}건');
      } else {
        throw Exception('서버 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('외박 신청 목록 로드 중 오류 발생: $e');
      print('스택 트레이스: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('신청 목록을 불러오는데 실패했습니다: $e')));
      }
    }
  }

  // ===== 공지사항 로드 =====
  Future<void> _loadNotice() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/notice?category=overnight'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _noticeContent =
              data['content'] ?? '외박 신청은 월 단위로 가능하며, 납부 후 환불 불가합니다.';
        });
        print('외박 공지사항 로드 완료: $_noticeContent');
      } else {
        print('외박 공지사항 로딩 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('외박 공지사항 로딩 중 에러: $e');
    }
  }

  // ===== 초기화 =====
  @override
  void initState() {
    super.initState();
    returnTimeItems =
        returnTimes
            .map((time) => DropdownMenuItem(value: time, child: Text(time)))
            .toList();
    reasonFocusNode.addListener(() {
      setState(() {});
    });
    placeFocusNode.addListener(() {
      setState(() {});
    });
  }

  // ===== 리소스 해제 =====
  @override
  void dispose() {
    studentIdController.dispose();
    nameController.dispose();
    placeController.dispose();
    reasonController.dispose();
    contactController.dispose();
    guardianContactController.dispose();
    reasonFocusNode.dispose();
    placeFocusNode.dispose();
    super.dispose();
  }

  // ===== 입력 필드 유효성 검사 =====
  bool _checkValidation() {
    placeError = placeController.text.isEmpty ? '필수 입력' : null;
    reasonError = reasonController.text.isEmpty ? '필수 입력' : null;
    contactError = contactController.text.isEmpty ? '필수 입력' : null;
    guardianContactError =
        guardianContactController.text.isEmpty ? '필수 입력' : null;
    guardianAgreeError = !guardianAgree ? '보호자 동의 필요' : null;
    returnTimeError = selectedReturnTime.isEmpty ? '필수 입력' : null;
    dateError = (rangeStart == null || rangeEnd == null) ? '날짜를 선택하세요' : null;

    return [
      placeError,
      reasonError,
      contactError,
      guardianContactError,
      guardianAgreeError,
      returnTimeError,
      dateError,
    ].every((e) => e == null);
  }

  // ===== 폼 유효성 검사 및 상태 업데이트 (신청하기 버튼 클릭 시에만 호출) =====
  bool _isFormValid() {
    final isValid = _checkValidation();
    setState(() {}); // 에러 상태 업데이트
    return isValid;
  }

  // ===== 유효성 검사 없이 현재 상태만 확인 (UI 표시용) =====
  bool _hasValidationErrors() {
    return [
      placeError,
      reasonError,
      contactError,
      guardianContactError,
      guardianAgreeError,
      returnTimeError,
      dateError,
    ].any((e) => e != null);
  }

  // ===== 신청 항목 추가 =====
  Future<void> _addRequest() async {
    if (_isFormValid()) {
      final uuid = const Uuid().v4();
      final requestData = {
        'out_uuid': uuid,
        'student_id': studentIdController.text,
        'out_type': '외박',
        'place': placeController.text,
        'reason': reasonController.text,
        'return_time': selectedReturnTime,
        'out_start': DateFormat('yyyy-MM-dd').format(rangeStart!),
        'out_end': DateFormat('yyyy-MM-dd').format(rangeEnd!),
        'par_agr': guardianAgree ? 1 : 0,
        'stat': '대기',
        'date': _formatDateRange(rangeStart!, rangeEnd!),
      };

      try {
        final response = await http.post(
          Uri.parse('http://localhost:5050/api/overnight/request'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestData),
        );

        if (response.statusCode == 200) {
          // 신청 목록 새로고침
          await _loadRequests();

          // 입력 필드 초기화
          setState(() {
            placeController.clear();
            reasonController.clear();
            guardianAgree = false;
            rangeStart = null;
            rangeEnd = null;
            selectedReturnTime = '';
          });

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('신청이 추가되었습니다.')));
        } else {
          throw Exception('Failed to add request');
        }
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('필수 항목을 모두 입력해주세요.')));
    }
  }

  // ===== 전체 신청 제출 =====
  Future<void> _submitAllRequests() async {
    if (requests.isNotEmpty) {
      try {
        // TODO: 전체 신청을 처리하는 API 호출 추가
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${requests.length}건 신청이 완료되었습니다.')),
        );
        setState(() => requests.clear());
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('추가된 신청이 없습니다.')));
    }
  }

  // ===== 신청 항목 삭제 =====
  Future<void> _deleteRequest(Map<String, dynamic> request) async {
    try {
      final response = await http.delete(
        Uri.parse(
          'http://localhost:5050/api/overnight/request/${request['out_uuid']}',
        ),
      );

      if (response.statusCode == 200) {
        // 신청 목록 새로고침
        await _loadRequests();

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('신청이 삭제되었습니다.')));
      } else {
        throw Exception('Failed to delete request');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    }
  }

  // ===== 필터링된 신청 목록 반환 =====
  List<Map<String, dynamic>> _getFilteredRequests() {
    List<Map<String, dynamic>> filteredList;
    if (selectedFilter == '전체') {
      filteredList = requests;
    } else {
      filteredList =
          requests
              .where((request) => request['stat'] == selectedFilter)
              .toList();
    }

    // 더미 데이터 삽입 제거 - 실제 DB 데이터만 사용
    print('필터링된 신청 목록: ${filteredList.length}건');
    for (var request in filteredList) {
      print('신청 항목: ${request['stat']} - ${request['reason']}');
    }

    return filteredList;
  }

  // ===== 전체 사유 보기 다이얼로그 =====
  void _showFullReason(String reason) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '외박 사유',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            content: Text(reason, style: TextStyle(fontSize: 14.sp)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('확인', style: TextStyle(fontSize: 14.sp)),
              ),
            ],
          ),
    );
  }

  // ===== 전체 반려 사유 보기 다이얼로그 =====
  void _showFullComment(String rejectionReason) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '반려 사유',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            content: Text(rejectionReason, style: TextStyle(fontSize: 14.sp)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('확인', style: TextStyle(fontSize: 14.sp)),
              ),
            ],
          ),
    );
  }

  // ===== 1열 리스트 배치 위젯 =====
  Widget _buildRequestsGrid() {
    final requests = _getFilteredRequests();
    if (requests.isEmpty) {
      return Center(
        child: Text(
          '신청 내역이 없습니다.',
          style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children:
            requests.map((request) => _buildRequestCard(request)).toList(),
      ),
    );
  }

  // ===== UI 구성 =====
  @override
  Widget build(BuildContext context) {
    final student = Provider.of<StudentProvider>(context, listen: true);

    if (student.studentId == null) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(32.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mainTitle('외박 신청'),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(flex: 2, child: _fixedField('년도', selectedYear)),
              SizedBox(width: 8.w),
              Expanded(flex: 2, child: _fixedField('학기', selectedSemester)),
              Container(
                height: 40.h,
                width: 1.w,
                color: Colors.grey[300],
                margin: EdgeInsets.symmetric(horizontal: 8.w),
              ),
              Expanded(
                flex: 2,
                child: _fixedField('학번', studentIdController.text),
              ),
              SizedBox(width: 8.w),
              Expanded(flex: 2, child: _fixedField('이름', nameController.text)),
            ],
          ),
          SizedBox(height: 16.h),
          _buildNoticeCard(),
          Divider(height: 22.h, thickness: 1),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 영역: 외박날짜선택 + 외박정보입력
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Card(
                      elevation: 1,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        side: BorderSide(color: Colors.grey.shade400, width: 1),
                      ),
                      child: Container(
                        height: 380.h,
                        padding: EdgeInsets.all(12.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('외박날짜선택'),
                            SizedBox(height: 8.h),
                            Expanded(child: _calendar()),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    flex: 2,
                    child: Card(
                      elevation: 1,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        side: BorderSide(color: Colors.grey.shade400, width: 1),
                      ),
                      child: Container(
                        height: 380.h,
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('외박정보입력'),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: _textField(
                                    '장소',
                                    placeController,
                                    errorText: placeError,
                                    isRequired: false,
                                    focusNode: placeFocusNode,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(flex: 1, child: _returnTimeDropdown()),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            _largeTextField(errorText: reasonError),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Expanded(
                                  child: _textField(
                                    '본인 연락처',
                                    contactController,
                                    isNumber: true,
                                    errorText: contactError,
                                    isRequired: true,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: _textField(
                                    '보호자 연락처',
                                    guardianContactController,
                                    isNumber: true,
                                    errorText: guardianContactError,
                                    isRequired: true,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Transform.scale(
                                  scale: 0.7, // 체크박스 크기를 80%로 축소
                                  child: Checkbox(
                                    value: guardianAgree,
                                    onChanged:
                                        (val) => setState(() {
                                          guardianAgree = val!;
                                          guardianAgreeError =
                                              null; // 체크박스 변경 시 에러 상태 초기화
                                        }),
                                  ),
                                ),
                                Text(
                                  '보호자 동의 여부',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color:
                                        guardianAgreeError != null
                                            ? Colors.red
                                            : Colors.black, // 에러 시 빨간 텍스트
                                  ),
                                ),
                              ],
                            ),
                            Spacer(),
                            // 필수값 입력 메시지와 신청하기 버튼을 우측에 배치
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // 필수값 입력 메시지
                                if (_hasValidationErrors()) ...[
                                  Text(
                                    '필수값을 입력하세요',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                ],
                                // 신청하기 버튼
                                GestureDetector(
                                  onTap: _addRequest,
                                  child: Container(
                                    width: 150.w,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 6.h,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24.r),
                                      color: Colors.blue[900],
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blueGrey.withOpacity(
                                            0.3,
                                          ),
                                          blurRadius: 6.r,
                                          offset: Offset(0, 3.h),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '신청하기',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Divider(height: 22.h, thickness: 1),
              // 하단 영역: 신청목록
              Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  side: BorderSide(color: Colors.grey.shade400, width: 1),
                ),
                child: Container(
                  height: 400.h,
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionTitle('신청 목록'),
                          SizedBox(
                            width: 150.w, // 드롭다운 너비 고정
                            child: DropdownButtonFormField2<String>(
                              isExpanded: true,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 6.w,
                                  vertical: 4.h,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                              hint: Text(
                                '필터 선택',
                                style: TextStyle(fontSize: 13.sp),
                              ),
                              value: selectedFilter,
                              items:
                                  filterOptions
                                      .map(
                                        (filter) => DropdownMenuItem(
                                          value: filter,
                                          child: Text(
                                            filter,
                                            style: TextStyle(fontSize: 13.sp),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedFilter = value!;
                                });
                              },
                              buttonStyleData: ButtonStyleData(
                                height: 40.h,
                                padding: EdgeInsets.only(left: 0, right: 0),
                              ),
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 200.h,
                                padding: EdgeInsets.symmetric(
                                  vertical: 4.h,
                                  horizontal: 2.w,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8.r),
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5.h),
                      Expanded(child: _buildRequestsGrid()),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  // ===== 캘린더 위젯 =====
  Widget _calendar() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(
        color:
            dateError != null
                ? Colors.red
                : Colors.grey.shade300, // 에러 시 빨간 테두리
        width: dateError != null ? 2 : 1,
      ),
      borderRadius: BorderRadius.circular(8.r),
    ),
    child: TableCalendar(
      firstDay: DateTime(DateTime.now().year, 1, 1), // 올해 1월 1일부터
      lastDay: DateTime(DateTime.now().year, 12, 31), // 올해 12월 31일까지
      focusedDay: rangeStart ?? DateTime.now(),
      rangeStartDay: rangeStart,
      rangeEndDay: rangeEnd,
      rangeSelectionMode: RangeSelectionMode.toggledOn,
      // 캘린더 크기 조절 속성들
      daysOfWeekHeight: 30.h, // 요일 헤더 높이
      rowHeight: 40.h, // 각 주(row)의 높이
      onRangeSelected: (start, end, focusedDay) {
        setState(() {
          rangeStart = start;
          rangeEnd = end;
          dateError = null;
        });
      },
      headerStyle: HeaderStyle(
        titleTextStyle: TextStyle(fontSize: 17.sp),
        leftChevronIcon: Icon(Icons.chevron_left, size: 17.w),
        rightChevronIcon: Icon(Icons.chevron_right, size: 17.w),
        headerPadding: EdgeInsets.symmetric(vertical: 3.h), // 헤더 패딩
        formatButtonVisible: false, // 형식 전환 버튼(2 weeks) 숨기기
      ),
      calendarStyle: CalendarStyle(
        cellMargin: EdgeInsets.all(1.w),
        cellPadding: EdgeInsets.all(2.w), // 셀 내부 패딩
        defaultTextStyle: TextStyle(fontSize: 12.sp),
        weekendTextStyle: TextStyle(fontSize: 12.sp),
        outsideTextStyle: TextStyle(fontSize: 12.sp),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(fontSize: 12.sp), // 평일 요일 글씨 크기
        weekendStyle: TextStyle(fontSize: 12.sp), // 주말 요일 글씨 크기
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, date, _) {
          if (date.weekday == DateTime.saturday) {
            return Container(
              margin: EdgeInsets.all(2.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Text(
                '${date.day}',
                style: TextStyle(color: Colors.indigo, fontSize: 12.sp),
              ),
            );
          }
          return null;
        },
        outsideBuilder: (context, date, _) {
          if (date.weekday == DateTime.saturday) {
            return Container(
              margin: EdgeInsets.all(2.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: Colors.indigo.withOpacity(0.5),
                  fontSize: 12.sp,
                ),
              ),
            );
          }
          if (date.weekday == DateTime.sunday) {
            return Container(
              margin: EdgeInsets.all(2.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: Colors.red.withOpacity(0.5),
                  fontSize: 12.sp,
                ),
              ),
            );
          }
          return null;
        },
      ),
    ),
  );

  // ===== 복귀 시간 선택 드롭다운 =====
  Widget _returnTimeDropdown() => DropdownButtonFormField2(
    isExpanded: true,
    decoration: InputDecoration(
      labelText: '복귀 예정 시간',
      labelStyle: TextStyle(fontSize: 13.sp),
      errorText: null, // 에러 텍스트 제거
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      // 전역 테마 사용하되, 에러 상태일 때만 빨간색 오버라이드
      enabledBorder:
          returnTimeError != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8.r),
              )
              : null, // null이면 전역 테마 사용
      focusedBorder:
          returnTimeError != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8.r),
              )
              : null, // null이면 전역 테마 사용
    ),
    hint: Text('시간 선택', style: TextStyle(fontSize: 13.sp)),
    value: selectedReturnTime.isEmpty ? null : selectedReturnTime,
    items:
        returnTimeItems
            .map(
              (item) => DropdownMenuItem(
                value: item.value,
                child: Text(item.value!, style: TextStyle(fontSize: 13.sp)),
              ),
            )
            .toList(),
    onChanged: (value) {
      setState(() {
        selectedReturnTime = value as String;
        returnTimeError = null; // 선택 시 에러 상태 초기화
      });
    },
    buttonStyleData: ButtonStyleData(
      height: 20.h,
      padding: EdgeInsets.only(left: 0, right: 0),
    ),
    dropdownStyleData: DropdownStyleData(
      maxHeight: 310.h,
      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
    ),
  );

  // ===== 신청 카드 위젯 =====
  Widget _buildRequestCard(Map<String, dynamic> request) {
    final String status = request['stat'] ?? '대기';
    final String reason = request['reason'] ?? '';
    final String place = request['place'] ?? '';
    final String rejectionReason = request['rejection_reason'] ?? '';
    final String dateRange = request['date'] ?? '';
    final String returnTime = request['return_time'] ?? '';

    // 상태별 색상 설정
    Color statusColor =
        status == '승인'
            ? Colors.green[600]!
            : status == '반려'
            ? Colors.red[600]!
            : Colors.orange[600]!;

    Color statusBgColor =
        status == '승인'
            ? Colors.green[50]!
            : status == '반려'
            ? Colors.red[50]!
            : Colors.orange[50]!;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      margin: EdgeInsets.symmetric(vertical: 4.h),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 좌측: 날짜/장소/복귀시간 정보 (캘린더 아이콘 추가)
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14.w,
                        color: Colors.blue[600],
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        dateRange,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12.w,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          place,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12.w,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '복귀: $returnTime',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              height: 60.h,
              width: 1.w,
              color: Colors.grey[300],
              margin: EdgeInsets.symmetric(horizontal: 8.w),
            ),

            // 중앙1: 내가 쓴 사유
            Expanded(
              flex: 7, // 사유 영역
              child: Row(
                children: [
                  SizedBox(width: 4.w),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey[800],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 60.h,
              width: 1.w,
              color: Colors.grey[300],
              margin: EdgeInsets.symmetric(horizontal: 8.w),
            ),

            // 중앙2: 반려사유 (반려시만 표시)
            if (status == '반려') ...[
              Expanded(
                flex: 5, // 반려사유 영역
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 반려 사유 제목
                    Row(
                      children: [
                        Icon(Icons.cancel, size: 14.w, color: Colors.red[600]),
                        SizedBox(width: 4.w),
                        Text(
                          '반려사유',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3.h),
                    // 반려 사유 내용
                    Text(
                      rejectionReason.isNotEmpty ? rejectionReason : '사유 없음',
                      style: TextStyle(fontSize: 13.sp, color: Colors.red[800]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // 반려가 아닐 때는 빈 공간으로 처리
              Expanded(flex: 5, child: SizedBox()),
            ],

            // 우측: 상태 + 삭제버튼
            Expanded(
              flex: 1, // 상태 영역
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 상태 태그
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                        ),
                      ),
                      // 대기중일 때 삭제 버튼
                      if (status == '대기') ...[
                        SizedBox(width: 8.w),
                        GestureDetector(
                          onTap: () => _deleteRequest(request),
                          child: Icon(
                            Icons.delete_outline,
                            color: Colors.red[600],
                            size: 20.w,
                          ),
                        ),
                      ],
                      SizedBox(width: 10.w),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 커스텀 버튼 위젯 =====
  Widget _customButton(String label, VoidCallback onPressed) => Align(
    alignment: Alignment.centerRight, // 우측 정렬
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 30.h,
        width: 150.w, // 버튼 너비를 150.w로 고정
        padding: EdgeInsets.symmetric(vertical: 6.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r),
          color: Colors.blue[900],
          boxShadow: [
            BoxShadow(
              color: Colors.blueGrey.withOpacity(0.3),
              blurRadius: 6.r,
              offset: Offset(0, 3.h),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );

  // ===== 날짜 범위 포맷팅 =====
  String _formatDateRange(DateTime start, DateTime end) {
    if (start.month == end.month) {
      return '${start.month}.${start.day}~${end.day}';
    } else {
      return '${start.month}.${start.day}~${end.month}.${end.day}';
    }
  }

  // ===== 공지사항 카드 위젯 =====
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

  // ===== 제목 위젯들 =====
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

  Widget _sectionTitle(String title) => Text(
    title,
    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
  );

  // ===== 읽기 전용 필드 위젯 =====
  Widget _fixedField(String label, String value) => TextField(
    controller: TextEditingController(text: value),
    readOnly: true,
    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: OutlineInputBorder(),
      filled: true,
      fillColor: Colors.grey[100],
    ),
  );

  // ===== 텍스트 입력 필드 위젯 =====
  Widget _textField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    String? errorText,
    bool isRequired = false,
    FocusNode? focusNode,
  }) => Stack(
    children: [
      TextField(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(fontSize: 13.sp),
        keyboardType: isNumber ? TextInputType.number : null,
        inputFormatters:
            isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
        onChanged: (_) {
          // 입력 시 해당 필드의 에러 상태 초기화
          setState(() {
            if (label == '장소') placeError = null;
            if (label == '본인 연락처') contactError = null;
            if (label == '보호자 연락처') guardianContactError = null;
          });
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13.sp),
          errorText: null, // 에러 텍스트 제거
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: 12.h,
          ),
          // 전역 테마 사용하되, 에러 상태일 때만 빨간색 오버라이드
          enabledBorder:
              errorText != null
                  ? OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(8.r),
                  )
                  : null, // null이면 전역 테마 사용
          focusedBorder:
              errorText != null
                  ? OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(8.r),
                  )
                  : null, // null이면 전역 테마 사용
        ),
      ),
      if (isRequired &&
          !(focusNode?.hasFocus ?? false) &&
          controller.text.isEmpty)
        Positioned(
          right: 16.w,
          top: 8.h,
          child: Text(
            '*', // "필수입력"을 "*"로 변경
            style: TextStyle(fontSize: 13.sp, color: Colors.red),
          ),
        ),
    ],
  );

  // ===== 큰 텍스트 입력 필드 위젯 =====
  Widget _largeTextField({String? errorText}) {
    return TextField(
      controller: reasonController,
      focusNode: reasonFocusNode,
      maxLines: 5,
      style: TextStyle(fontSize: 13.sp),
      decoration: InputDecoration(
        labelText: '사유',
        labelStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[800]),
        errorText: null, // 에러 텍스트 제거
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        // 전역 테마 사용하되, 에러 상태일 때만 빨간색 오버라이드
        enabledBorder:
            errorText != null
                ? OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(8.r),
                )
                : null, // null이면 전역 테마 사용
        focusedBorder:
            errorText != null
                ? OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                  borderRadius: BorderRadius.circular(8.r),
                )
                : null, // null이면 전역 테마 사용
        alignLabelWithHint: true,
      ),
      onChanged: (_) {
        // 입력 시 사유 에러 상태 초기화
        setState(() {
          reasonError = null;
        });
      },
    );
  }
}
