import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../student_provider.dart';
import 'package:kbu_domi/app/env_app.dart';
//import 'package:kbu_domi/app/app_bar.dart';

// --- 앱 공통 테마 ---
class AppColors {
  static const primary = Color(0xFF4A69E2);
  static const accent = Color(0xFF4A69E2);
  static const background = Colors.white;
  static const card = Colors.white;
  static const textPrimary = Color(0xFF34495E);
  static const textSecondary = Color(0xFF7F8C8D);
  static const success = Color(0xFF27AE60);
  static const warning = Color(0xFFF2994A);
  static const danger = Color(0xFFE74C3C);
}

// --- 외박 신청 화면 위젯 ---
class OverNight extends StatefulWidget {
  const OverNight({super.key});
  @override
  State<OverNight> createState() => _OverNightState();
}

class _OverNightState extends State<OverNight>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _placeController = TextEditingController();
  final _reasonController = TextEditingController();
  final _contactController = TextEditingController();
  final _guardianContactController = TextEditingController();

  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  DateTime _focusedDay = DateTime.now();
  String? _selectedReturnTime;
  bool _guardianAgree = false;

  List<Map<String, dynamic>> _requestHistory = [];
  bool _isHistoryLoading = true;

  // 학생 정보 변수 추가
  String _studentName = '';
  String _studentId = '';
  String _dormBuilding = '';
  String _roomNumber = '';

  // 복귀시간 리스트 (11:00 ~ 29:00)
  final List<String> _returnTimes = List.generate(37, (i) {
    final index = i + 11;
    final hour = index ~/ 2;
    final minute = (index % 2) * 30;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  });

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ko_KR');
    _tabController = TabController(length: 2, vsync: this);
    // 하드코딩된 연락처 정보 제거
    // _contactController.text = '010-1234-5678';
    // _guardianContactController.text = '010-8765-4321';
    _loadStudentInfo(); // 학생 정보 로드 추가
    _loadOvernightRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _placeController.dispose();
    _reasonController.dispose();
    _contactController.dispose();
    _guardianContactController.dispose();
    super.dispose();
  }

  // 학생 정보 로드 함수 추가
  Future<void> _loadStudentInfo() async {
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );

    print(
      '🏠 외박 - _loadStudentInfo 시작, studentId: ${studentProvider.studentId}',
    );

    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/student/${studentProvider.studentId}'),
      );

      print('🏠 외박 - 학생 정보 API 응답: ${response.statusCode}');
      print('🏠 외박 - 학생 정보 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🏠 외박 - 파싱된 학생 정보: $data');

        if (mounted) {
          // 서버 응답 형식 확인: {success: true, user: {...}} 형태
          Map<String, dynamic> userData;
          if (data is Map && data.containsKey('user')) {
            userData = data['user'] as Map<String, dynamic>;
            print('🏠 외박 - user 객체에서 데이터 추출: $userData');
          } else {
            userData = data as Map<String, dynamic>;
            print('🏠 외박 - 직접 데이터 사용: $userData');
          }

          setState(() {
            // 서버 응답의 실제 필드명 사용
            _studentName = userData['name'] ?? '';
            _studentId = userData['student_id'] ?? '';
            _dormBuilding = userData['dorm_building'] ?? userData['dept'] ?? '';
            _roomNumber = userData['room_num'] ?? '';

            // 학생 정보에서 연락처 자동 입력
            _contactController.text = userData['phone_num'] ?? '';
            _guardianContactController.text = userData['par_phone'] ?? '';
          });

          print('✅ 외박 - 학생 정보 설정 완료:');
          print('  - 이름: $_studentName');
          print('  - 학번: $_studentId');
          print('  - 기숙사: $_dormBuilding');
          print('  - 호실: $_roomNumber');
          print('  - 연락처: ${_contactController.text}');
          print('  - 보호자 연락처: ${_guardianContactController.text}');
        }
      } else {
        print('❌ 외박 - 학생 정보 API 오류: ${response.statusCode}');
        print('❌ 외박 - 오류 응답: ${response.body}');
      }
    } catch (e) {
      print('❌ 외박 - 학생 정보 로딩 오류: $e');
      print('❌ 외박 - 스택 트레이스: ${StackTrace.current}');
    }
  }

  // 실제 신청내역 불러오기
  Future<void> _loadOvernightRequests() async {
    setState(() => _isHistoryLoading = true);
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );

    try {
      final response = await http.get(
        Uri.parse(
          '$apiBase/api/overnight/student/requests?student_id=${studentProvider.studentId}',
        ),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('🏠 외박 신청 내역 데이터: $data');

          if (data is List<dynamic>) {
            // 직접 배열을 반환하는 경우
            _requestHistory = List<Map<String, dynamic>>.from(data);
            print('✅ 외박 신청 내역 로드 완료: ${_requestHistory.length}건');
          } else if (data is Map<String, dynamic> && data['success'] == true) {
            // success 키가 있는 형식
            _requestHistory = List<Map<String, dynamic>>.from(
              data['requests'] ?? [],
            );
            print('✅ 외박 신청 내역 로드 완료: ${_requestHistory.length}건');
          } else {
            print('❌ 외박 신청 내역 형식이 올바르지 않습니다: ${data.runtimeType}');
            _requestHistory = [];
          }
        } else {
          print('❌ 외박 신청 내역 API 오류: ${response.statusCode}');
          _requestHistory = [];
          _showSnackBar('신청 내역을 불러올 수 없습니다.', isError: true);
        }
        setState(() => _isHistoryLoading = false);
      }
    } catch (e) {
      print('❌ 외박 신청 내역 로딩 오류: $e');
      if (mounted) {
        setState(() {
          _requestHistory = [];
          _isHistoryLoading = false;
        });
        _showSnackBar('네트워크 오류: $e', isError: true);
      }
    }
  }

  // 외박 신청 제출
  Future<void> _submitRequest() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackBar('모든 항목을 올바르게 입력해주세요.', isError: true);
      return;
    }
    if (_rangeStart == null || _rangeEnd == null) {
      _showSnackBar('외박 기간을 선택해주세요.', isError: true);
      return;
    }
    if (!_guardianAgree) {
      _showSnackBar('보호자 동의를 체크해주세요.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );

    try {
      final response = await http.post(
        Uri.parse('$apiBase/api/overnight/request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': studentProvider.studentId,
          'out_start': DateFormat('yyyy-MM-dd').format(_rangeStart!),
          'out_end': DateFormat('yyyy-MM-dd').format(_rangeEnd!),
          'out_time': _selectedReturnTime ?? '22:00',
          'place': _placeController.text,
          'reason': _reasonController.text,
          'contact': _contactController.text,
          'guardian_contact': _guardianContactController.text,
          'guardian_agree': _guardianAgree ? 'Y' : 'N',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _showSnackBar('외박 신청이 완료되었습니다.');
          _resetForm();
          _tabController.animateTo(1);
          await _loadOvernightRequests(); // 신청 목록 새로고침
        } else {
          _showSnackBar(
            data['message'] ?? '신청 처리 중 오류가 발생했습니다.',
            isError: true,
          );
        }
      } else {
        _showSnackBar(
          '서버와 통신할 수 없습니다. (코드: ${response.statusCode})',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('네트워크 오류: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 외박 신청 취소
  Future<void> _cancelRequest(String uuid) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBase/api/overnight/request/$uuid'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          await _loadOvernightRequests(); // 목록 새로고침
          _showSnackBar('신청이 취소되었습니다.');
        } else {
          _showSnackBar(
            data['message'] ?? '취소 처리 중 오류가 발생했습니다.',
            isError: true,
          );
        }
      } else {
        _showSnackBar('서버와 통신할 수 없습니다.', isError: true);
      }
    } catch (e) {
      _showSnackBar('네트워크 오류: $e', isError: true);
    }
  }

  // 외박 신청 취소 다이얼로그
  void _cancelOvernightRequest(String uuid) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.danger.withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '신청 취소',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 긴 텍스트를 위한 유연한 레이아웃
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 280, // 다이얼로그 내부 최대 너비 설정
                    ),
                    child: const Column(
                      children: [
                        // 첫 번째 줄: 취소 질문
                        Text(
                          '정말로 신청을 취소하시겠습니까?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 8),
                        // 두 번째 줄: 주의사항
                        Text(
                          '취소된 내역은 복구할 수 없습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('닫기'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _cancelRequest(uuid);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            elevation: 0,
                          ),
                          child: const Text(
                            '취소하기',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _placeController.clear();
    _reasonController.clear();
    setState(() {
      _selectedReturnTime = null;
      _rangeStart = null;
      _rangeEnd = null;
      _focusedDay = DateTime.now();
      _guardianAgree = false;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            // TabBar를 화면 최상단에 배치 (팀 스타일 적용)
            const Divider(height: 1, thickness: 1, color: Color(0xFFE6E8EC)),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  child: Text(
                    '신청하기',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Tab(
                  child: Text(
                    '신청내역',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE6E8EC)),
            // TabBarView가 남은 공간을 모두 차지하도록 Expanded로 감싸기
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildRequestForm(), _buildRequestHistory()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 신청 폼 (팀 스타일 적용) ---
  Widget _buildRequestForm() {
    final inputDecorationTheme = const InputDecorationTheme(
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 2.0),
      ),
      floatingLabelStyle: TextStyle(color: AppColors.primary),
    );

    return Container(
      color: AppColors.background,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: inputDecorationTheme,
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('외박 기간 선택', Icons.calendar_today_outlined),
                  const SizedBox(height: 16),
                  _buildCalendar(),
                  const SizedBox(height: 32),
                  _buildSectionTitle('상세 정보 입력', Icons.edit_note_outlined),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _placeController,
                    decoration: const InputDecoration(labelText: '외박 장소'),
                    validator:
                        (value) =>
                            (value?.isEmpty ?? true) ? '장소를 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedReturnTime,
                    decoration: const InputDecoration(labelText: '복귀 예정 시간'),
                    menuMaxHeight: 300.0,
                    dropdownColor: AppColors.card,
                    items:
                        _returnTimes
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() => _selectedReturnTime = value),
                    validator:
                        (value) => value == null ? '복귀 시간을 선택해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonController,
                    minLines: 4,
                    maxLines: 4,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      labelText: '외박 사유',
                      contentPadding: EdgeInsets.only(top: 16),
                    ),
                    validator:
                        (value) =>
                            (value?.isEmpty ?? true) ? '사유를 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle(
                    '학생 정보 및 연락처',
                    Icons.contact_phone_outlined,
                  ),
                  const SizedBox(height: 16),
                  // 학생 정보 표시 카드 추가
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '학생 정보',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '이름: ${_studentName.isNotEmpty ? _studentName : "로딩 중..."}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '학번: ${_studentId.isNotEmpty ? _studentId : "로딩 중..."}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '기숙사: ${_dormBuilding.isNotEmpty ? _dormBuilding : "로딩 중..."}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '호실: ${_roomNumber.isNotEmpty ? _roomNumber : "로딩 중..."}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _contactController,
                    decoration: const InputDecoration(
                      labelText: '본인 연락처',
                      hintText: '학생 정보에서 자동으로 입력됩니다',
                    ),
                    validator:
                        (value) =>
                            (value?.isEmpty ?? true) ? '연락처를 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _guardianContactController,
                    decoration: const InputDecoration(
                      labelText: '보호자 연락처',
                      hintText: '학생 정보에서 자동으로 입력됩니다',
                    ),
                    validator:
                        (value) =>
                            (value?.isEmpty ?? true)
                                ? '보호자 연락처를 입력해주세요.'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  FormField<bool>(
                    initialValue: _guardianAgree,
                    validator:
                        (value) =>
                            (value == null || !value) ? '보호자 동의가 필요합니다.' : null,
                    builder: (state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _guardianAgree,
                                onChanged: (value) {
                                  setState(() => _guardianAgree = value!);
                                  state.didChange(value);
                                },
                                activeColor: AppColors.accent,
                              ),
                              GestureDetector(
                                onTap: () {
                                  final newValue = !_guardianAgree;
                                  setState(() => _guardianAgree = newValue);
                                  state.didChange(newValue);
                                },
                                child: const Text('보호자 동의를 받았습니다.'),
                              ),
                            ],
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16.0,
                                top: 4.0,
                              ),
                              child: Text(
                                state.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon:
                          _isLoading
                              ? Container()
                              : const Icon(Icons.check_circle_outline),
                      label:
                          _isLoading
                              ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                              : const Text(
                                '신청하기',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 신청 내역 리스트 (팀 스타일 적용) ---
  Widget _buildRequestHistory() {
    if (_isHistoryLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_requestHistory.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '외박 신청 내역이 없습니다.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Container(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _loadOvernightRequests,
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: _requestHistory.length,
          itemBuilder:
              (context, index) => _buildHistoryCard(_requestHistory[index]),
        ),
      ),
    );
  }

  // --- 소제목 (팀 스타일) ---
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // --- 달력 위젯 (팀 스타일) ---
  Widget _buildCalendar() {
    return Card(
      elevation: 0,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: TableCalendar(
        locale: 'ko_KR',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        rangeStartDay: _rangeStart,
        rangeEndDay: _rangeEnd,
        rangeSelectionMode: RangeSelectionMode.toggledOn,
        onRangeSelected: (start, end, focusedDay) {
          setState(() {
            _rangeStart = start;
            _rangeEnd = end ?? start;
            _focusedDay = focusedDay;
          });
        },
        enabledDayPredicate: (day) {
          final today = DateTime.now();
          return !day.isBefore(DateTime(today.year, today.month, today.day));
        },
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          selectedDecoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          rangeStartDecoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          rangeEndDecoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
          ),
          withinRangeDecoration: const BoxDecoration(shape: BoxShape.circle),
          rangeHighlightColor: AppColors.accent.withOpacity(0.2),
          weekendTextStyle: const TextStyle(color: AppColors.danger),
          disabledTextStyle: TextStyle(color: Colors.grey.shade400),
        ),
      ),
    );
  }

  // --- 신청 내역 카드 위젯 (팀 스타일) ---
  Widget _buildHistoryCard(Map<String, dynamic> request) {
    final status = request['stat'] ?? '대기';

    String formattedDateRange(String start, String end) {
      final startDate = DateTime.parse(start);
      final endDate = DateTime.parse(end);
      if (isSameDay(startDate, endDate)) {
        return DateFormat('M.d(E)', 'ko_KR').format(startDate);
      }
      return '${DateFormat('M.d(E)', 'ko_KR').format(startDate)} ~ ${DateFormat('M.d(E)', 'ko_KR').format(endDate)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    request['place'] ?? '장소 정보 없음',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    _StatusChip(status: status),
                    if (status == '대기')
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            splashRadius: 16,
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed:
                                () => _cancelOvernightRequest(
                                  request['out_uuid'],
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              formattedDateRange(request['out_start'], request['out_end']),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              request['reason'] ?? '사유 없음',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// --- 상태 칩 위젯 ---
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    switch (status) {
      case '승인':
        chipColor = AppColors.success;
        break;
      case '대기':
        chipColor = AppColors.warning;
        break;
      case '반려':
        chipColor = AppColors.danger;
        break;
      default:
        chipColor = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
