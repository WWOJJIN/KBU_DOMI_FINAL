import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // 반응형 패키지
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../student_provider.dart';
import 'package:kbu_domi/env.dart';

// --- 앱 공통 테마 ---
class AppColors {
  static const primary = Color(0xFF4A69E2);
  static const accent = Color(0xFF4A69E2);
  static const background = Colors.white;
  static const card = Colors.white;
  static const textPrimary = Color(0xFF34495E);
  static const textSecondary = Color(0xFF7F8C8D);
  static const success = Color(0xFF27AE60);
  static const danger = Color(0xFFE74C3C);
  static const noticeBackground = Color(0xFFE9ECF8);
  static const disabledCard = Color(0xFFF3F3F3);
}

// 석식 신청 항목 모델
class DinnerApplication {
  final String year;
  final String semester;
  final String month;
  final int price;

  DinnerApplication({
    required this.year,
    required this.semester,
    required this.month,
    required this.price,
  });

  String get period => '$year-$semester $month';
}

class AppDinner extends StatefulWidget {
  const AppDinner({super.key});
  @override
  State<AppDinner> createState() => _AppDinnerState();
}

class _AppDinnerState extends State<AppDinner>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  late int _currentYear;
  late int _currentSemester;
  late List<String> _semesterMonths;
  final List<DinnerApplication> _applications = [];

  List<Map<String, dynamic>> _paymentHistory = [];
  final Set<String> _paidMonths = {};
  bool _isHistoryLoading = true;

  // 석식 기간 정보 저장 변수 추가
  Map<String, dynamic>? _periodInfo;

  final DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ko_KR');
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _tabController.index == 1) {
        _refreshPaymentHistory();
      }
    });

    _initializeDateAndSemester();
    _loadPeriodInfo(); // 석식 기간 정보 로드 추가
    _loadInitialPaymentHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _calculateTotalPrice() {
    return _applications.fold(0, (sum, item) => sum + item.price);
  }

  void _initializeDateAndSemester() {
    _currentYear = _now.year;
    if (_now.month >= 3 && _now.month <= 8) {
      _currentSemester = 1;
      _semesterMonths = ['3월', '4월', '5월', '6월', '7월', '8월'];
    } else {
      _currentSemester = 2;
      _semesterMonths = ['9월', '10월', '11월', '12월', '1월', '2월'];
      if (_now.month < 3) _currentYear = _now.year - 1;
    }
  }

  void _loadInitialPaymentHistory() {
    _refreshPaymentHistory();
  }

  // 석식 기간 정보 로드 함수 추가
  Future<void> _loadPeriodInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/admin/dinner/period-info'),
      );
      print('석식 기간 정보 API 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data is Map<String, dynamic>) {
          setState(() {
            _periodInfo = data;
          });
          print('석식 기간 정보 로드 완료: $_periodInfo');
        }
      } else {
        print('석식 기간 정보 로딩 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('석식 기간 정보 로딩 중 에러: $e');
    }
  }

  Future<void> _refreshPaymentHistory() async {
    setState(() => _isHistoryLoading = true);
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );
    final studentId = studentProvider.studentId;

    print('🍽️ 석식 신청 내역 로딩 시작...');

    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/dinner/requests?student_id=$studentId'),
      );

      print('🍽️ 석식 API 응답 상태: ${response.statusCode}');
      print('🍽️ 석식 API 응답 본문: ${response.body}');

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('🍽️ 파싱된 데이터: $data');

          if (data['success'] == true) {
            final allRequests = List<Map<String, dynamic>>.from(
              data['requests'] ?? [],
            );

            // 각 월별로 최신 기록만 필터링
            Map<String, Map<String, dynamic>> latestRequests = {};
            for (var request in allRequests) {
              final monthKey =
                  '${request['target_year']}-${request['target_semester']}-${request['target_month']}';
              final regDate = DateTime.parse(request['reg_dt']);

              if (!latestRequests.containsKey(monthKey) ||
                  regDate.isAfter(
                    DateTime.parse(latestRequests[monthKey]!['reg_dt']),
                  )) {
                latestRequests[monthKey] = request;
              }
            }

            // 최신 기록들만 리스트로 변환 (최신 순 정렬)
            _paymentHistory =
                latestRequests.values.toList()..sort(
                  (a, b) => DateTime.parse(
                    b['reg_dt'],
                  ).compareTo(DateTime.parse(a['reg_dt'])),
                );

            print('🍽️ 석식 신청 내역 데이터: $_paymentHistory');

            // 각 월별로 최신 상태만 추출하여 판단
            _paidMonths.clear();
            Map<String, Map<String, dynamic>> latestByMonth = {};

            // 각 월별로 가장 최근 기록 찾기
            for (var h in _paymentHistory) {
              final monthKey =
                  '${h['target_year']}-${h['target_semester']}-${h['target_month']}';
              final regDate = DateTime.parse(h['reg_dt']);

              if (!latestByMonth.containsKey(monthKey) ||
                  regDate.isAfter(
                    DateTime.parse(latestByMonth[monthKey]!['reg_dt']),
                  )) {
                latestByMonth[monthKey] = h;
              }
            }

            print('🍽️ 각 월별 최신 상태:');
            for (var entry in latestByMonth.entries) {
              final monthKey = entry.key;
              final data = entry.value;
              final stat = data['stat'];

              print('🍽️ $monthKey: $stat');

              // 승인된 것만 결제 완료로 판단
              if (stat == '승인') {
                final period =
                    '${data['target_year']}_${data['target_semester']}_${data['target_month']}';
                _paidMonths.add(period);
                print('🍽️ ✅ 결제 완료된 월: $period');
              } else if (stat == '환불') {
                print('🍽️ 💰 환불된 월 (재신청 가능): $monthKey');
              } else if (stat == '대기') {
                print('🍽️ ⏳ 대기 중인 월: $monthKey');
              }
            }
            print('🍽️ 최종 결제 완료된 월 목록: $_paidMonths');
          } else {
            _paymentHistory = [];
            print('🍽️ API 응답 success: false');
          }
        } else {
          _paymentHistory = [];
          _showSnackBar('신청 내역을 불러올 수 없습니다.', isError: true);
          print('🍽️ API 응답 오류: ${response.statusCode}');
        }
        setState(() => _isHistoryLoading = false);
      }
    } catch (e) {
      print('🍽️ 네트워크 오류: $e');
      if (mounted) {
        setState(() {
          _paymentHistory = [];
          _isHistoryLoading = false;
        });
        _showSnackBar('네트워크 오류: $e', isError: true);
      }
    }
  }

  void _addMonthToCart(String month) {
    if (_applications.any((app) => app.month == month)) {
      _showSnackBar('$month은(는) 이미 신청 바구니에 있습니다.', isError: true);
      return;
    }

    // 이미 결제한 월인지 확인 (_currentSemester는 숫자만 있으므로 "학기" 추가)
    final periodKey = '${_currentYear}_${_currentSemester}학기_$month';
    print('🍽️ 신청하려는 월 키: $periodKey');
    print('🍽️ 현재 결제 완료된 월들: $_paidMonths');

    if (_paidMonths.contains(periodKey)) {
      _showSnackBar('$month은(는) 이미 신청 완료된 월입니다.', isError: true);
      return;
    }

    int monthInt = int.parse(month.replaceAll('월', ''));
    int year = _currentYear;
    if (_currentSemester == 2 && monthInt < 3) year++;
    DateTime firstDay = DateTime(year, monthInt, 1);
    DateTime lastDay = DateTime(year, monthInt + 1, 0);
    int mealDays = 0;
    for (int i = 0; i < lastDay.day; i++) {
      if (firstDay.add(Duration(days: i)).weekday <= 5) mealDays++;
    }
    int price = mealDays * 4500;
    setState(() {
      _applications.add(
        DinnerApplication(
          year: _currentYear.toString(),
          semester: '${_currentSemester}학기',
          month: month,
          price: price,
        ),
      );
    });
  }

  void _removeFromCart(DinnerApplication appToRemove) {
    setState(() {
      _applications.removeWhere((app) => app.period == appToRemove.period);
    });
  }

  // 석식 신청 및 결제 처리 함수 - 실제 서버에 신청과 결제 요청 전송
  Future<void> _submitPayment() async {
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );
    final studentId = studentProvider.studentId;

    if (studentId == null) {
      _showSnackBar('학생 정보를 찾을 수 없습니다. 다시 로그인해주세요.', isError: true);
      return;
    }

    if (_applications.isEmpty) {
      _showSnackBar('신청할 월을 선택해주세요.', isError: true);
      return;
    }

    // 결제 확인 다이얼로그 표시 - 커스텀 디자인 적용
    final totalAmount = _applications.fold(0, (sum, app) => sum + app.price);
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(24.0.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72.w,
                    height: 72.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.payment,
                      color: AppColors.primary,
                      size: 36.sp,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    '결제 확인',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // 긴 텍스트를 위한 유연한 레이아웃
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 280.w, // 다이얼로그 내부 최대 너비 설정
                    ),
                    child: Text(
                      '선택하신 월의 석식을\n신청하시겠습니까?',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: AppColors.textSecondary,
                        height: 1.4, // 줄 간격 조정
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // 선택된 월 목록 표시
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      children: [
                        for (DinnerApplication app in _applications)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 2.h),
                            child: Text(
                              app.period,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            backgroundColor: Colors.grey[100],
                          ),
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            '결제하기',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      print('🍽️ 석식 신청 시작 - 선택된 월: $_applications');

      // 각 월별로 개별 신청
      for (DinnerApplication app in _applications) {
        final requestData = {
          'student_id': studentId,
          'year': app.year,
          'semester': app.semester,
          'month': app.month,
          'amount': app.price, // 결제 금액 추가
        };

        print('🍽️ 석식 신청 데이터: $requestData');

        final response = await http.post(
          Uri.parse('$apiBase/api/dinner/apply'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestData),
        );

        print('🍽️ 석식 신청 응답: ${response.statusCode}');
        print('🍽️ 석식 신청 응답 본문: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            print('✅ 석식 신청 성공: ${app.period}');
          } else {
            throw Exception('서버 오류: ${data['message'] ?? '알 수 없는 오류'}');
          }
        } else {
          throw Exception('HTTP 오류: ${response.statusCode}');
        }
      }

      // 성공 후 UI 업데이트
      if (mounted) {
        setState(() {
          _applications.clear();
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('석식 신청이 완료되었습니다.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );

        // 신청 내역 새로고침
        await _refreshPaymentHistory();

        // 결제내역 탭으로 이동
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _tabController.length > 1) {
            _tabController.animateTo(1);
          }
        });
      }
    } catch (e) {
      print('❌ 석식 신청 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('석식 신청 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  // 환불 신청 처리 함수 - 실제 서버에 환불 요청 전송
  Future<void> _refundPayment(Map<String, dynamic> payment) async {
    try {
      // 환불 확인 다이얼로그 표시 - 커스텀 디자인 적용
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => Dialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(24.0.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72.w,
                      height: 72.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.danger.withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        size: 40.sp,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Text(
                      '환불 신청',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // 긴 텍스트를 위한 유연한 레이아웃
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 280.w, // 다이얼로그 내부 최대 너비 설정
                      ),
                      child: Column(
                        children: [
                          // 첫 번째 줄: 환불 대상 정보
                          Text(
                            '${payment['target_year']}-${payment['target_semester']} ${payment['target_month']} 석식을',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          // 두 번째 줄: 환불 질문
                          Text(
                            '환불하시겠습니까?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          // 세 번째 줄: 주의사항
                          Text(
                            '환불된 내역은 복구할 수 없습니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              '취소',
                              style: TextStyle(fontSize: 15.sp),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              elevation: 0,
                            ),
                            child: Text(
                              '환불신청',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15.sp,
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
      );

      if (confirm != true) return;

      // 로딩 상태 표시
      setState(() => _isHistoryLoading = true);

      final dinnerId = payment['dinner_id'];
      final response = await http.put(
        Uri.parse('$apiBase/api/admin/dinner/$dinnerId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'refund',
          'amount': payment['payment_amount'] ?? 0,
          'note': '학생 환불 신청',
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        _showSnackBar('환불 신청이 완료되었습니다.');
        // 결제 내역 새로고침
        await _refreshPaymentHistory();
      } else {
        _showSnackBar(data['error'] ?? '환불 신청 중 오류가 발생했습니다.', isError: true);
      }
    } catch (e) {
      print('🍽️ 환불 신청 오류: $e');
      _showSnackBar('환불 신청 중 오류가 발생했습니다.', isError: true);
    } finally {
      setState(() => _isHistoryLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            // TabBar
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border(
                  top: BorderSide(color: Color(0xFFE6E8EC), width: 1.w),
                  bottom: BorderSide(color: Color(0xFFE6E8EC), width: 1.w),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3.h,
                tabs: [
                  Tab(
                    child: Text(
                      '신청하기',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Tab(
                    child: Text(
                      '결제내역',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildApplicationTab(), _buildPaymentHistoryTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplicationTab() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodSelector(),
                SizedBox(height: 24.h),
                _buildSectionTitle('신청할 월 선택', Icons.calendar_month_outlined),
                SizedBox(height: 16.h),
                _buildMonthSelector(),
                SizedBox(height: 24.h),
                _buildSectionTitle('신청 바구니', Icons.shopping_cart_outlined),
                SizedBox(height: 16.h),
                _buildCartSection(),
              ],
            ),
          ),
        ),
        if (_applications.isNotEmpty) _buildPaymentButton(),
      ],
    );
  }

  Widget _buildPaymentHistoryTab() {
    if (_isHistoryLoading) {
      return Center(
        child: SizedBox(
          height: 48.h,
          width: 48.h,
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_paymentHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 60.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              '결제 내역이 없습니다.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16.sp),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshPaymentHistory,
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: _paymentHistory.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildNoticeBox();
          final item = _paymentHistory[index - 1];
          return _buildHistoryCard(item);
        },
        separatorBuilder: (context, index) => SizedBox(height: 12.h),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        Expanded(child: _buildDisabledDropdown('$_currentYear년')),
        SizedBox(width: 16.w),
        Expanded(child: _buildDisabledDropdown('$_currentSemester학기')),
      ],
    );
  }

  Widget _buildDisabledDropdown(String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Icon(Icons.arrow_drop_down, color: Colors.grey[700], size: 22.sp),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20.sp),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelector() {
    return Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      children:
          _semesterMonths.map((month) {
            final isSelected = _applications.any((app) => app.month == month);
            int monthInt = int.parse(month.replaceAll('월', ''));
            int year = _currentYear;
            if (_currentSemester == 2 && monthInt < 3) year++;

            // 관리자 설정 기간 정보 반영
            bool canApply = true;
            if (_periodInfo != null) {
              final currentDay = _now.day;
              final startDay = _periodInfo!['start_day'] ?? 1;
              final endDay = _periodInfo!['end_day'] ?? 15;

              // 현재 날짜가 결제/환불 기간 내인지 확인
              final isInPaymentPeriod =
                  currentDay >= startDay && currentDay <= endDay;

              // 해당 월이 현재 월보다 미래인지 확인
              final isCurrentOrFutureMonth =
                  year > _now.year ||
                  (year == _now.year && monthInt >= _now.month);

              // 결제 가능 조건: 결제 기간 내 + 현재 또는 미래 월
              canApply = isInPaymentPeriod && isCurrentOrFutureMonth;
            } else {
              // 기본 로직 (관리자 설정이 없는 경우)
              DateTime paymentDeadline = DateTime(
                year,
                monthInt - 1,
                15,
                23,
                59,
                59,
              );
              canApply = _now.isBefore(paymentDeadline);
            }

            final paidKey = "${_currentYear}_${_currentSemester}학기_${month}";
            final isPaid = _paidMonths.contains(paidKey);
            print(
              '🍽️ 월 선택 UI - $month 키: $paidKey, 결제됨: $isPaid, 신청가능: $canApply',
            );
            final isDisabled = !canApply || isPaid;
            return ChoiceChip(
              label: Text(month, style: TextStyle(fontSize: 15.sp)),
              selected: isSelected,
              onSelected:
                  isDisabled
                      ? null
                      : (selected) {
                        if (selected) {
                          _addMonthToCart(month);
                        } else {
                          final appToRemove = _applications.firstWhere(
                            (app) => app.month == month,
                          );
                          _removeFromCart(appToRemove);
                        }
                      },
              labelStyle: TextStyle(
                color:
                    isDisabled
                        ? Colors.grey[500]
                        : isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: AppColors.card,
              selectedColor: AppColors.primary.withOpacity(0.15),
              disabledColor: Colors.grey[200],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : Colors.grey[300]!,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
              showCheckmark: false,
            );
          }).toList(),
    );
  }

  Widget _buildCartSection() {
    if (_applications.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: Text(
            '신청할 월을 선택해주세요.',
            style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _applications.length,
      itemBuilder: (context, index) {
        final app = _applications[index];
        return Card(
          color: AppColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            title: Text(
              app.period,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 16.sp,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${NumberFormat('#,###').format(app.price)}원',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.remove_circle,
                    color: AppColors.danger,
                    size: 22.sp,
                  ),
                  onPressed: () => _removeFromCart(app),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
    );
  }

  Widget _buildPaymentButton() {
    final numberFormat = NumberFormat('#,###');
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10.r,
            offset: Offset(0, -5.h),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '총 결제 금액',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${numberFormat.format(_calculateTotalPrice())}원',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              icon: _isLoading ? Container() : Icon(Icons.payment, size: 20.sp),
              label:
                  _isLoading
                      ? SizedBox(
                        height: 24.h,
                        width: 24.h,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                      : Text(
                        '결제하기',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBox() {
    return Container(
      padding: EdgeInsets.all(16.w),
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.noticeBackground,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              '석식 신청 및 환불 규정은 기숙사 운영 지침을 확인하세요.\n(환불/결제는 결제월 전달 15일 23:59까지 신청만 가능)',
              style: TextStyle(
                color: AppColors.textPrimary,
                height: 1.4,
                fontWeight: FontWeight.w500,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> payment) {
    final now = DateTime.now();

    // 서버 데이터 구조에 맞게 수정
    final year = payment['year'] ?? payment['target_year'] ?? 0;
    final semester = payment['semester'] ?? payment['target_semester'] ?? 0;
    final monthStr = payment['target_month'] ?? '${payment['month'] ?? 0}월';
    final month = int.tryParse(monthStr.toString().replaceAll('월', '')) ?? 0;

    // semester에 이미 "학기"가 포함되어 있는지 확인
    final semesterStr = semester.toString();
    final period =
        semesterStr.endsWith('학기')
            ? '$year-$semester $monthStr' // 이미 "학기"가 포함된 경우
            : '$year-${semester}학기 $monthStr'; // "학기"가 없는 경우
    final dateStr = payment['reg_dt'] ?? '';
    final stat = payment['stat'] ?? '대기';

    // 결제 금액 계산 (평일 기준 4500원 * 일수)
    int refundYear = year is int ? year : int.tryParse(year.toString()) ?? 0;
    if (semester == 2 && month < 3) refundYear++;

    DateTime firstDay = DateTime(refundYear, month, 1);
    DateTime lastDay = DateTime(refundYear, month + 1, 0);
    int mealDays = 0;
    for (int i = 0; i < lastDay.day; i++) {
      if (firstDay.add(Duration(days: i)).weekday <= 5) mealDays++;
    }
    final priceInt = mealDays * 4500;

    // 환불 가능 여부 판단 (현재 진행 중인 월은 환불 불가)
    final refundDeadline = DateTime(refundYear, month - 1, 15, 23, 59, 59);
    final isCurrentMonth = refundYear == now.year && month == now.month;
    bool canRefund =
        now.isBefore(refundDeadline) && stat == '승인' && !isCurrentMonth;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      color: canRefund ? AppColors.card : AppColors.disabledCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 상단 타이틀 + 상태칩 (환불신청/불가)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    period,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                      color:
                          canRefund ? AppColors.textPrimary : Colors.grey[500],
                    ),
                  ),
                ),
                if (canRefund)
                  SizedBox(
                    height: 28.h,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 0,
                        ),
                        minimumSize: Size(10.w, 28.h),
                      ),
                      onPressed: () {
                        _refundPayment(payment);
                      },
                      child: Text(
                        '환불신청',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ),
                if (!canRefund)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h, left: 4.w),
                    child: Text(
                      '환불불가',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 4.h),
            // 2. 상태 및 결제일
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color:
                        stat == '승인'
                            ? AppColors.success.withOpacity(0.1)
                            : stat == '환불'
                            ? AppColors.danger.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    stat,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color:
                          stat == '승인'
                              ? AppColors.success
                              : stat == '환불'
                              ? AppColors.danger
                              : Colors.orange,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '신청일: $dateStr',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color:
                        canRefund ? AppColors.textSecondary : Colors.grey[400],
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            // 3. 금액
            Text(
              '${NumberFormat('#,###').format(priceInt)}원',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.bold,
                color: canRefund ? AppColors.primary : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
