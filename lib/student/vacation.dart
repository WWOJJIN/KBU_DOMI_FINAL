// 파일명: vacation_page.dart (수정 완료)
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 금액 포맷을 위해 추가
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../student_provider.dart';

class VacationPage extends StatefulWidget {
  const VacationPage({super.key});

  @override
  State<VacationPage> createState() => _VacationPageState();
}

class _VacationPageState extends State<VacationPage> {
  // --- 상태 변수 및 컨트롤러 (기존과 동일) ---
  DateTime _focusedDay = DateTime.utc(2024, 6, 1);
  final DateTime _firstDay = DateTime.utc(2024, 6, 1);
  final DateTime _lastDay = DateTime.utc(2024, 8, 31);
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  int _guestCount = 0;
  String? _selectedBuilding;
  String? _selectedRoomType;

  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _studentPhoneController = TextEditingController();
  final TextEditingController _reserverNameController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  final TextEditingController _reserverPhoneController =
      TextEditingController();

  bool _isLoading = false;
  final currencyFormat = NumberFormat('#,###');

  // --- initState, dispose, 로직 함수들 (기존과 동일) ---
  @override
  void initState() {
    super.initState();
    _loadStudentInfo();
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _studentIdController.dispose();
    _studentPhoneController.dispose();
    _reserverNameController.dispose();
    _relationController.dispose();
    _reserverPhoneController.dispose();
    super.dispose();
  }

  void _loadStudentInfo() {
    final studentProvider = StudentProvider();

    setState(() {
      _studentNameController.text = studentProvider.name ?? '';
      _studentIdController.text = studentProvider.studentId?.toString() ?? '';
      _studentPhoneController.text = studentProvider.phoneNum ?? '';
    });
  }

  Future<void> _submitReservation() async {
    // 필수 필드 검증
    if (_studentNameController.text.trim().isEmpty ||
        _studentIdController.text.trim().isEmpty ||
        _studentPhoneController.text.trim().isEmpty ||
        _reserverNameController.text.trim().isEmpty ||
        _relationController.text.trim().isEmpty ||
        _reserverPhoneController.text.trim().isEmpty ||
        _selectedBuilding == null ||
        _selectedRoomType == null ||
        _guestCount == 0 ||
        _rangeStart == null ||
        _rangeEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 필수 정보를 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      const String baseUrl = 'http://localhost:5050';

      final response = await http.post(
        Uri.parse('$baseUrl/api/vacation/apply'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': _studentIdController.text.trim(),
          'student_name': _studentNameController.text.trim(),
          'student_phone': _studentPhoneController.text.trim(),
          'reserver_name': _reserverNameController.text.trim(),
          'reserver_relation': _relationController.text.trim(),
          'reserver_phone': _reserverPhoneController.text.trim(),
          'building': _selectedBuilding,
          'room_type': _selectedRoomType,
          'guest_count': _guestCount,
          'check_in_date': _formatDate(_rangeStart!),
          'check_out_date': _formatDate(_rangeEnd!),
          'total_amount': totalAmount,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = json.decode(response.body);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? '예약 신청이 완료되었습니다.'),
              backgroundColor: Colors.green,
            ),
          );

          // 성공 후 폼 리셋
          _resetForm();
        }
      } else {
        final errorData = json.decode(response.body);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? '예약 신청에 실패했습니다.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('네트워크 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _resetForm() {
    setState(() {
      _reserverNameController.clear();
      _relationController.clear();
      _reserverPhoneController.clear();
      _selectedBuilding = null;
      _selectedRoomType = null;
      _guestCount = 0;
      _rangeStart = null;
      _rangeEnd = null;
    });
  }

  int get totalAmount {
    // 총 금액 계산 로직 (생략)
    if (_rangeStart != null &&
        _rangeEnd != null &&
        _selectedRoomType != null &&
        _guestCount > 0) {
      final days = _rangeEnd!.difference(_rangeStart!).inDays + 1;
      int baseRate = switch (_selectedRoomType) {
        '1인' => 9900,
        '2인' => 8900,
        '3인' => 7900,
        _ => 0,
      };
      int includedGuests =
          _selectedRoomType == '1인'
              ? 1
              : _selectedRoomType == '2인'
              ? 2
              : 3;
      int extraGuests =
          (_guestCount > includedGuests) ? (_guestCount - includedGuests) : 0;
      int extraChargePerNight = extraGuests * 5000;
      return (baseRate + extraChargePerNight) * days;
    }
    return 0;
  }

  // --- 상단 메뉴 위젯 (기존과 동일) ---
  static Widget _topMenuBtn(
    String label, {
    bool highlight = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
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
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Column(
        children: [
          // 상단 헤더 부분 (생략)
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
                    _topMenuBtn('기숙사 입주신청'),
                    _topMenuBtn('기숙사 포털시스템'),
                    IconButton(
                      icon: Icon(Icons.menu, size: 28.sp),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                            '방학 이용 신청',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '편안하고 안전한 방학 생활을 즐겨보세요!',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.white70,
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
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: Container(
                    width: 1000.w,
                    padding: EdgeInsets.all(32.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Image.asset(
                            'imgs/bbogi_and_friend.png',
                            height: 120.h,
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // ❗️❗️❗️ 요청하신 제목 추가 ❗️❗️❗️
                        Center(
                          child: Text(
                            '방학 이용 예약 신청서',
                            style: TextStyle(
                              fontSize: 35.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF333333),
                            ),
                          ),
                        ),
                        SizedBox(height: 40.h),

                        // ❗️❗️❗️ 여기까지 ❗️❗️❗️
                        Text(
                          '학생 정보',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                '이름',
                                controller: _studentNameController,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildField(
                                '학번',
                                controller: _studentIdController,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildField(
                                '전화번호',
                                controller: _studentPhoneController,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32.h),
                        Text(
                          '예약자 정보',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildField(
                                '이름',
                                controller: _reserverNameController,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildField(
                                '관계',
                                controller: _relationController,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: _buildField(
                                '전화번호',
                                controller: _reserverPhoneController,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 32.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TableCalendar(
                                locale: 'ko_KR',
                                firstDay: _firstDay,
                                lastDay: _lastDay,
                                focusedDay: _focusedDay,
                                rangeStartDay: _rangeStart,
                                rangeEndDay: _rangeEnd,
                                rangeSelectionMode: RangeSelectionMode.enforced,
                                onRangeSelected:
                                    (start, end, focusedDay) => setState(() {
                                      _rangeStart = start;
                                      _rangeEnd = end;
                                      _focusedDay = focusedDay;
                                    }),
                                calendarFormat: CalendarFormat.month,
                                headerStyle: const HeaderStyle(
                                  titleCentered: true,
                                  formatButtonVisible: false,
                                ),
                              ),
                            ),
                            SizedBox(width: 32.w),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 16.h),
                                  Text(
                                    '건물 / 인실 / 인원 선택',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _buildDropdown(
                                          '건물 선택',
                                          ['숭례원', '양덕원'],
                                          _selectedBuilding,
                                          (val) => setState(
                                            () => _selectedBuilding = val,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16.w),
                                      Expanded(
                                        child: _buildDropdown(
                                          '인실 선택',
                                          ['1인', '2인', '3인'],
                                          _selectedRoomType,
                                          (val) => setState(
                                            () => _selectedRoomType = val,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),
                                  _buildGuestCountDropdown(),
                                  SizedBox(height: 32.h),
                                  Text(
                                    '선택한 기간',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    '입실: ${_rangeStart != null ? _formatDate(_rangeStart!) : "미선택"}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    '퇴실: ${_rangeEnd != null ? _formatDate(_rangeEnd!) : "미선택"}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  SizedBox(height: 24.h),
                                  Text(
                                    '총 금액: ${currencyFormat.format(totalAmount)}원',
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    '입금 계좌: 국민 48372615274632',
                                    style: TextStyle(fontSize: 16.sp),
                                  ),
                                  SizedBox(height: 32.h),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52.h,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading
                                              ? null
                                              : _submitReservation,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF033762,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12.r,
                                          ),
                                        ),
                                      ),
                                      child:
                                          _isLoading
                                              ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                              : Text(
                                                '예약 신청',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16.sp,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---
  InputDecoration _getStyledInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.r),
        borderSide: const BorderSide(color: Color(0xFF033762), width: 1.5),
      ),
    );
  }

  Widget _buildField(String label, {TextEditingController? controller}) {
    return SizedBox(
      height: 48.h,
      child: TextFormField(
        controller: controller,
        style: TextStyle(fontSize: 14.sp),
        decoration: _getStyledInputDecoration(label),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    return SizedBox(
      height: 48.h,
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
        onChanged: onChanged,
        decoration: _getStyledInputDecoration(label),
      ),
    );
  }

  Widget _buildGuestCountDropdown() {
    List<String> guestCountItems = List.generate(
      10,
      (index) => (index + 1).toString(),
    );

    return SizedBox(
      height: 48.h,
      child: DropdownButtonFormField<String>(
        value: _guestCount == 0 ? null : _guestCount.toString(),
        items:
            guestCountItems.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text('$value명', style: TextStyle(fontSize: 14.sp)),
              );
            }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _guestCount = int.tryParse(newValue ?? '0') ?? 0;
          });
        },
        decoration: _getStyledInputDecoration('입실 인원'),
      ),
    );
  }
}
