import 'package:flutter/material.dart';
import '../../student_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class DinnerRequestPage extends StatefulWidget {
  final VoidCallback? onDinnerUpdated; // 석식 신청 업데이트 콜백

  const DinnerRequestPage({super.key, this.onDinnerUpdated});

  @override
  _DinnerRequestPageState createState() => _DinnerRequestPageState();
}

class _DinnerRequestPageState extends State<DinnerRequestPage> {
  String selectedYear = '2025';
  String selectedSemester = '1학기';
  final Set<String> selectedMonths = {};

  final List<String> years = ['2024', '2025', '2026'];
  final List<String> semesters = ['1학기', '2학기'];

  // 학기별 월 자동 설정을 위한 getter
  List<String> get months {
    if (selectedSemester == '1학기') {
      return ['3월', '4월', '5월', '6월', '7월', '8월'];
    } else {
      return ['9월', '10월', '11월', '12월', '1월', '2월'];
    }
  }

  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  // 석식 기간 정보 저장 변수 추가
  Map<String, dynamic>? _periodInfo;

  String get paymentDateRange {
    if (_periodInfo != null) {
      final startDay = _periodInfo!['start_day'] ?? 1;
      final endDay = _periodInfo!['end_day'] ?? 15;
      return _periodInfo!['period_display'] ?? '매월 ${startDay}일 ~ ${endDay}일';
    }
    return '매월 1일 ~ 15일';
  }

  String get refundDateRange {
    return paymentDateRange; // 결제와 환불 기간이 동일
  }

  bool isRefundPeriod = false;

  String paymentFilter = '전체';
  final List<String> paymentFilterOptions = ['전체', '결제됨', '환불됨'];

  List<Map<String, dynamic>> dinnerRequests = [];
  List<Map<String, dynamic>> paymentHistory = [];

  bool _isFirst = true;

  // 지난 월인지 확인하는 함수
  bool _isMonthPassed(String month) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // 월 문자열에서 숫자 추출
    final monthNumber = int.tryParse(month.replaceAll('월', ''));
    if (monthNumber == null) return false;

    // 선택된 년도와 현재 년도 비교
    final selectedYearInt = int.tryParse(selectedYear) ?? currentYear;

    if (selectedYearInt < currentYear) {
      return true; // 지난 년도는 모두 지난 월
    } else if (selectedYearInt > currentYear) {
      return false; // 미래 년도는 모두 미래 월
    }

    // 같은 년도인 경우 월 비교
    if (selectedSemester == '1학기') {
      // 1학기: 3월~8월
      return monthNumber < currentMonth;
    } else {
      // 2학기: 9월~12월, 1월~2월
      if (monthNumber >= 9) {
        // 9월~12월의 경우
        return monthNumber < currentMonth;
      } else {
        // 1월~2월의 경우 (다음 해)
        if (currentMonth >= 9) {
          return false; // 현재가 9월 이후면 1-2월은 아직 미래
        } else {
          return monthNumber < currentMonth; // 현재가 1-8월이면 월 비교
        }
      }
    }
  }

  // 결제 가능한 기간인지 확인하는 함수 (관리자 설정 반영)
  bool _canApplyForMonth(String month) {
    final now = DateTime.now();

    // 관리자가 설정한 기간 정보가 없으면 기본값 사용
    if (_periodInfo == null) return true;

    final startDay = _periodInfo!['start_day'] ?? 1;
    final endDay = _periodInfo!['end_day'] ?? 15;
    final currentDay = now.day;

    // 현재 날짜가 결제 가능 기간 내인지 확인
    final isInPaymentPeriod = currentDay >= startDay && currentDay <= endDay;

    if (!isInPaymentPeriod) {
      print(
        '🔍 석식신청 - 결제 기간이 아님: 현재 ${currentDay}일, 허용 기간: ${startDay}일~${endDay}일',
      );
      return false;
    }

    // 지난 월은 신청 불가
    if (_isMonthPassed(month)) {
      return false;
    }

    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isFirst) {
      _loadStudentData();
      _fetchDinnerRequests();
      _fetchPaymentHistoryByStudent();
      _loadNotice(); // 공지사항 로드
      _loadPeriodInfo(); // 석식 기간 정보 로드 추가
      _isFirst = false;
    }
  }

  void _loadStudentData() {
    final student = Provider.of<StudentProvider>(context, listen: true);
    print('🔍 웹 석식신청 - _loadStudentData 호출:');
    print('  - student.studentId: ${student.studentId}');
    print('  - student.name: ${student.name}');

    if (student.studentId != null) {
      studentIdController.text = student.studentId!;
      nameController.text = student.name ?? '';
      print('✅ 웹 석식신청 - 학생 데이터 설정 완료');
    } else {
      print('❌ 웹 석식신청 - 학생 데이터가 없습니다!');
    }
  }

  @override
  void initState() {
    super.initState();
    print('🔍 웹 석식신청 - DinnerRequestPage initState 시작');
  }

  Future<void> _fetchDinnerRequests() async {
    print('🔍 웹 석식신청 - _fetchDinnerRequests 시작');
    final studentId = studentIdController.text;
    print('🔍 웹 석식신청 - 현재 studentId: "$studentId"');

    if (studentId.isEmpty) {
      print('❌ 웹 석식신청 - studentId가 비어있습니다!');
      return;
    }

    final url = Uri.parse(
      'http://localhost:5050/api/dinner/requests?student_id=$studentId',
    );
    print('🔍 웹 석식신청 - 요청 URL: $url');
    try {
      print('🔍 웹 석식신청 - API 요청 시도');
      final response = await http.get(url);
      print('🔍 웹 석식신청 - API 응답 받음: ${response.statusCode}');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('🔍 웹 석식신청 - 응답 데이터: $responseData');

        // 새로운 API 형식 처리
        if (responseData is Map && responseData['success'] == true) {
          final List<dynamic> data = responseData['requests'] ?? [];
          setState(() {
            dinnerRequests = List<Map<String, dynamic>>.from(data);
          });
          print('✅ 웹 석식신청 - 데이터 설정 완료 (새 형식): ${dinnerRequests.length}건');
        } else if (responseData is List) {
          // 기존 형식 호환성
          setState(() {
            dinnerRequests = List<Map<String, dynamic>>.from(responseData);
          });
          print('✅ 웹 석식신청 - 데이터 설정 완료 (기존 형식): ${dinnerRequests.length}건');
        }
      } else {
        print('❌ 웹 석식신청 - API 호출 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 웹 석식신청 - API 호출 중 에러 발생: $e');
    }
  }

  Future<void> _fetchPaymentHistory(int dinnerId) async {
    print('_fetchPaymentHistory 시작 - dinnerId: $dinnerId');
    final url = Uri.parse(
      'http://localhost:5050/api/dinner/payments?dinner_id=$dinnerId',
    );
    try {
      final response = await http.get(url);
      print('결제 내역 API 응답: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          paymentHistory = List<Map<String, dynamic>>.from(data);
          payments =
              data.map((item) {
                final key =
                    '${item['year']}-${item['semester']}-${item['month']}';
                print('결제내역 row: key=$key');
                final payDt = DateTime.parse(item['pay_dt']);
                return PaymentRow(
                  key,
                  '${item['year']}-${item['semester']} ${item['month']}',
                  '${item['amount']}원',
                  DateFormat('yyyy-MM-dd').format(payDt),
                  refundDate:
                      item['pay_type'] == '환불'
                          ? DateFormat('yyyy-MM-dd').format(payDt)
                          : null,
                  dinnerId: item['dinner_id'],
                  payType: item['pay_type'],
                  payDt: payDt,
                );
              }).toList();
        });
        print('결제 내역 설정 완료: $payments');
      }
    } catch (e) {
      print('결제 내역 조회 중 에러: $e');
    }
  }

  Future<void> _fetchPaymentHistoryByStudent() async {
    final studentId = studentIdController.text;
    if (studentId.isEmpty) {
      print('학생 ID가 비어있습니다.');
      return;
    }

    final url = Uri.parse(
      'http://localhost:5050/api/dinner/payments?student_id=$studentId',
    );
    print('결제 내역 조회 URL: $url');

    try {
      final response = await http.get(url);
      print('결제 내역 API 응답 코드: ${response.statusCode}');
      print('결제 내역 API 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          print('API 응답 본문이 비어있습니다.');
          setState(() {
            payments = [];
          });
          return;
        }

        final dynamic decodedData = json.decode(responseBody);
        if (decodedData is! List) {
          print('API 응답이 리스트 형태가 아닙니다: $decodedData');
          setState(() {
            payments = [];
          });
          return;
        }

        final List<dynamic> data = decodedData;
        setState(() {
          // 1. 모든 결제/환불 row를 PaymentRow로 만든다
          List<PaymentRow> allPayments = [];

          for (final item in data) {
            try {
              final key =
                  '${item['year']}-${item['semester']}-${item['month']}';
              final payDtString = item['pay_dt'];
              if (payDtString == null) {
                print('pay_dt가 null입니다: $item');
                continue;
              }

              final payDt = DateTime.parse(payDtString);
              allPayments.add(
                PaymentRow(
                  key,
                  '${item['year']}-${item['semester']} ${item['month']}',
                  '${item['amount']}원',
                  DateFormat('yyyy-MM-dd').format(payDt),
                  refundDate:
                      item['pay_type'] == '환불'
                          ? DateFormat('yyyy-MM-dd').format(payDt)
                          : null,
                  dinnerId: item['dinner_id'],
                  payType: item['pay_type'],
                  payDt: payDt,
                ),
              );
            } catch (e) {
              print('결제 데이터 처리 중 에러: $e, 데이터: $item');
            }
          }

          // 2. monthKey별로 payDt가 가장 최신인 row만 남긴다
          Map<String, PaymentRow> latestByMonth = {};
          for (final p in allPayments) {
            if (!latestByMonth.containsKey(p.monthKey) ||
                p.payDt.isAfter(latestByMonth[p.monthKey]!.payDt)) {
              latestByMonth[p.monthKey] = p;
            }
          }
          payments = latestByMonth.values.toList();

          // 디버깅: payments 리스트 상태 출력
          print('=== payments(최신상태만) 리스트 ===');
          for (final p in payments) {
            print(
              'monthKey: \'${p.monthKey}\', refundDate: \'${p.refundDate}\', status: \'${p.status}\'',
            );
          }
          print('========================');
        });
      } else if (response.statusCode == 404) {
        print('결제 내역이 없습니다.');
        setState(() {
          payments = [];
        });
      } else {
        print('API 호출 실패: ${response.statusCode} - ${response.body}');
        setState(() {
          payments = [];
        });
      }
    } catch (e) {
      print('결제 내역 조회 중 에러: $e');
      setState(() {
        payments = [];
      });
    }
  }

  // 공지사항 로드 함수 추가
  Future<void> _loadNotice() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/notice?category=dinner'),
      );
      print('공지사항 API 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data is Map<String, dynamic>) {
          setState(() {
            _noticeTitle = data['title'] ?? '';
            _noticeContent =
                data['content'] ?? '석식 신청은 월 단위로 가능하며, 납부 후 환불 불가입니다.';
          });
          print('공지사항 로드 완료: 제목=${_noticeTitle}, 내용=${_noticeContent}');
        }
      } else {
        print('공지사항 로딩 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('공지사항 로딩 중 에러: $e');
    }
  }

  // 석식 기간 정보 로드 함수 추가
  Future<void> _loadPeriodInfo() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/admin/dinner/period-info'),
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

  Future<void> _applyDinner(String year, String semester, String month) async {
    final url = Uri.parse('http://localhost:5050/api/dinner/apply');
    final mealDays = _calculateMealDays(month);
    final amount = mealDays * 4500;

    final data = {
      'student_id': studentIdController.text,
      'year': year,
      'semester': semester,
      'month': month,
      'amount': amount,
    };

    print('석식 신청 데이터: $data');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      print('석식 신청 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        await _fetchDinnerRequests();
        await _fetchPaymentHistoryByStudent();

        // 대시보드 새로고침 콜백 호출
        if (widget.onDinnerUpdated != null) {
          widget.onDinnerUpdated!();
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('석식 신청 및 결제가 완료되었습니다.')));
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이미 해당 월에 신청한 내역이 있습니다.')));
      } else {
        final responseData = json.decode(response.body);
        final errorMessage = responseData['error'] ?? '신청 실패';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      print('석식 신청 중 에러: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신청 중 오류가 발생했습니다.')));
    }
  }

  Future<void> _payDinner(int dinnerId, int amount, {String? note}) async {
    final url = Uri.parse('http://localhost:5050/api/dinner/payment');
    final data = {
      'dinner_id': dinnerId,
      'pay_type': '결제',
      'amount': amount,
      'note': note ?? '',
    };
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      await _fetchPaymentHistoryByStudent();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('결제 완료')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('결제 실패')));
    }
  }

  Future<void> _refundDinner(int dinnerId, int amount, {String? note}) async {
    final url = Uri.parse('http://localhost:5050/api/dinner/payment');
    final data = {
      'dinner_id': dinnerId,
      'pay_type': '환불',
      'amount': amount,
      'note': note ?? '',
    };
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      await _fetchPaymentHistoryByStudent();

      // 대시보드 새로고침 콜백 호출
      if (widget.onDinnerUpdated != null) {
        widget.onDinnerUpdated!();
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('환불 완료')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('환불 실패')));
    }
  }

  List<Map<String, String>> get applications {
    List<Map<String, String>> result = [];
    for (final month in months) {
      if (selectedMonths.contains(month)) {
        // 월 문자열에서 숫자 추출
        int monthIndex = int.tryParse(month.replaceAll('월', '')) ?? 1;

        // 년도 계산 (2학기의 1-2월은 다음 해)
        int year = int.tryParse(selectedYear) ?? DateTime.now().year;
        if (selectedSemester == '2학기' && monthIndex <= 2) {
          year += 1; // 2학기의 1-2월은 다음 해
        }

        DateTime firstDay = DateTime.parse(
          '$year-${monthIndex.toString().padLeft(2, '0')}-01',
        );
        DateTime lastDay = DateTime(firstDay.year, firstDay.month + 1, 0);
        int mealDays = 0;
        for (int i = 0; i < lastDay.day; i++) {
          DateTime day = firstDay.add(Duration(days: i));
          if (day.weekday >= 1 && day.weekday <= 4) {
            mealDays++;
          }
        }
        result.add({
          'period': '$selectedYear-$selectedSemester $month',
          'price': '${mealDays * 4500}',
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        });
      }
    }
    return result;
  }

  Set<String> selectedRefunds = {};
  List<PaymentRow> payments = [];

  // 공지사항 데이터
  String _noticeTitle = '';
  String _noticeContent = '석식 신청은 월 단위로 가능하며, 납부 후 환불 불가합니다.';

  // 환불 가능 여부를 확인하는 함수
  bool _canRefund(String monthKey) {
    final now = DateTime.now();

    if (_periodInfo == null) return false;

    final startDay = _periodInfo!['start_day'] ?? 1;
    final endDay = _periodInfo!['end_day'] ?? 15;
    final currentDay = now.day;

    // 현재 설정된 기간 내인지 확인 (매월 반복되는 기간)
    final isInRefundPeriod = currentDay >= startDay && currentDay <= endDay;

    // 환불 기간이 아니면 환불 불가
    if (!isInRefundPeriod) {
      return false;
    }

    // monthKey에서 년도, 학기, 월 추출
    final parts = monthKey.split('-');
    if (parts.length != 3) return false;

    final year = int.tryParse(parts[0]) ?? 0;
    final monthStr = parts[2].replaceAll('월', '');
    final month = int.tryParse(monthStr) ?? 0;

    final currentYear = now.year;
    final currentMonth = now.month;

    // 과거 월은 환불 불가 (이미 지나간 달)
    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      return false;
    }

    // 현재 진행 중인 월도 환불 불가 (이미 서비스가 시작된 월)
    if (year == currentYear && month == currentMonth) {
      return false;
    }

    // 미래 월만 환불 가능 (환불 기간 내라면)
    return true;
  }

  @override
  Widget build(BuildContext context) {
    double cardHeight = 320.h;
    return SingleChildScrollView(
      padding: EdgeInsets.all(32.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mainTitle('석식신청'),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  '년도',
                  selectedYear,
                  years,
                  (val) => setState(() {
                    selectedYear = val!;
                    selectedMonths.clear(); // 년도 변경 시 선택된 월 초기화
                  }),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _dropdown(
                  '학기',
                  selectedSemester,
                  semesters,
                  (val) => setState(() {
                    selectedSemester = val!;
                    selectedMonths.clear(); // 학기 변경 시 선택된 월 초기화
                  }),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(child: _textField('학번', studentIdController)),
              SizedBox(width: 8.w),
              Expanded(child: _textField('이름', nameController)),
            ],
          ),
          SizedBox(height: 10.h),
          Card(
            elevation: 1,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
              side: BorderSide(color: Colors.grey.shade400, width: 1),
            ),
            child: Container(
              padding: EdgeInsets.all(20.w),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공지사항',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(_noticeContent, style: TextStyle(fontSize: 14.sp)),
                  if (_periodInfo != null &&
                      _periodInfo!['is_custom'] == true) ...[
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚙️ 관리자 커스텀 설정',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                              color: Colors.orange[700],
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            _periodInfo!['message'] ?? '',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.orange[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Divider(height: 22.h, thickness: 1),
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
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('신청 내역'),
                        SizedBox(height: 12.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Wrap(
                                spacing: 8.w,
                                children:
                                    months.map((month) {
                                      final String monthKey =
                                          '$selectedYear-$selectedSemester-$month';
                                      final paid = payments.any(
                                        (p) =>
                                            p.monthKey == monthKey &&
                                            p.refundDate == null,
                                      );
                                      final isPassed = _isMonthPassed(month);
                                      final canApply = _canApplyForMonth(month);
                                      final isDisabled =
                                          paid || isPassed || !canApply;

                                      // 디버깅용 로그
                                      print('🔍 석식신청 - $month 상태 확인:');
                                      print('  - paid: $paid');
                                      print('  - isPassed: $isPassed');
                                      print('  - canApply: $canApply');
                                      print('  - isDisabled: $isDisabled');

                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Checkbox(
                                            value: selectedMonths.contains(
                                              month,
                                            ),
                                            onChanged:
                                                isDisabled
                                                    ? null
                                                    : (val) {
                                                      setState(() {
                                                        if (val == true) {
                                                          selectedMonths.add(
                                                            month,
                                                          );
                                                        } else {
                                                          selectedMonths.remove(
                                                            month,
                                                          );
                                                        }
                                                      });
                                                    },
                                          ),
                                          Text(
                                            month,
                                            style: TextStyle(
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  isDisabled
                                                      ? Colors.grey
                                                      : Colors.black,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '결제/환불 기간: $paymentDateRange',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildSfDataGrid(
                              context,
                              constraints.maxWidth,
                            );
                          },
                        ),
                        SizedBox(height: 8.h),
                        _customButton('결제하기', () async {
                          if (selectedMonths.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('결제할 월을 선택해주세요.')),
                            );
                            return;
                          }

                          // 선택된 월들이 모두 결제 가능한지 확인
                          final invalidMonths =
                              selectedMonths
                                  .where((month) => !_canApplyForMonth(month))
                                  .toList();
                          if (invalidMonths.isNotEmpty) {
                            final startDay = _periodInfo?['start_day'] ?? 1;
                            final endDay = _periodInfo?['end_day'] ?? 15;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '결제 기간이 아닙니다. (매월 ${startDay}일~${endDay}일만 결제 가능)\n결제 불가 월: ${invalidMonths.join(', ')}',
                                ),
                                duration: Duration(seconds: 4),
                              ),
                            );
                            return;
                          }

                          // 결제하기 버튼 비활성화 (중복 클릭 방지)
                          bool isProcessing = false;
                          if (isProcessing) return;
                          isProcessing = true;

                          try {
                            for (final month in selectedMonths.toList()) {
                              print('$month 신청 및 결제 시작');
                              await _applyDinner(
                                selectedYear,
                                selectedSemester,
                                month,
                              );
                            }
                            setState(() {
                              selectedMonths.clear();
                            });
                          } catch (e) {
                            print('결제 처리 중 에러: $e');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('결제 처리 중 오류가 발생했습니다.'),
                              ),
                            );
                          } finally {
                            isProcessing = false;
                          }
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 24.w),
              Expanded(
                flex: 1,
                child: Card(
                  elevation: 1,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    side: BorderSide(color: Colors.grey.shade400, width: 1),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('결제 내역'),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '환불 기간: $refundDateRange',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                            DropdownButton<String>(
                              value: paymentFilter,
                              items:
                                  paymentFilterOptions
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(
                                            e,
                                            style: TextStyle(fontSize: 14.sp),
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => paymentFilter = val);
                              },
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return _buildPaymentDataGrid(
                              context,
                              constraints.maxWidth,
                            );
                          },
                        ),
                        SizedBox(height: 8.h),
                        _customButton('환불하기', () async {
                          if (selectedRefunds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('환불할 항목을 선택해주세요.')),
                            );
                            return;
                          }

                          // 환불 가능 여부 체크
                          bool hasInvalidRefund = false;
                          List<String> invalidMonths = [];

                          for (final monthKey in selectedRefunds) {
                            if (!_canRefund(monthKey)) {
                              hasInvalidRefund = true;
                              invalidMonths.add(monthKey.split('-').last);
                            }
                          }

                          if (hasInvalidRefund) {
                            final startDay = _periodInfo?['start_day'] ?? 1;
                            final endDay = _periodInfo?['end_day'] ?? 15;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '환불 기간이 아닙니다. (매월 ${startDay}일~${endDay}일만 환불 가능)\n환불 불가 월: ${invalidMonths.join(', ')}',
                                ),
                                duration: Duration(seconds: 4),
                              ),
                            );
                            return;
                          }

                          for (final monthKey in selectedRefunds) {
                            final payment =
                                payments
                                        .where(
                                          (p) =>
                                              p.monthKey == monthKey &&
                                              p.refundDate == null,
                                        )
                                        .isNotEmpty
                                    ? payments.firstWhere(
                                      (p) =>
                                          p.monthKey == monthKey &&
                                          p.refundDate == null,
                                    )
                                    : null;
                            if (payment != null && payment.dinnerId != null) {
                              // 금액 파싱
                              final amount =
                                  int.tryParse(
                                    payment.price
                                        .replaceAll('원', '')
                                        .replaceAll(',', ''),
                                  ) ??
                                  0;
                              await _refundDinner(payment.dinnerId!, amount);
                            }
                          }
                          selectedRefunds.clear();
                          await _fetchPaymentHistoryByStudent();
                          setState(() {
                            selectedMonths.clear(); // 환불 후 신청내역 월 선택 꼬임 방지
                          });
                        }, backgroundColor: Colors.redAccent),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
    );
  }

  // ===== 커스텀 버튼 위젯 (외박신청과 동일한 디자인) =====
  Widget _customButton(
    String label,
    VoidCallback onPressed, {
    Color? backgroundColor,
  }) => Align(
    alignment: Alignment.centerRight, // 우측 정렬
    child: GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 150.w, // 외박신청과 동일한 고정 너비
        padding: EdgeInsets.symmetric(vertical: 6.h), // 외박신청과 동일한 패딩
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24.r), // 외박신청과 동일한 더 둥근 모서리
          color: backgroundColor ?? Colors.indigo, // 외박신청과 동일한 단색 배경
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
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        border: OutlineInputBorder(),
      ),
      isExpanded: true,
      value: value,
      onChanged: onChanged,
      items:
          options
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, style: TextStyle(fontSize: 14.sp)),
                ),
              )
              .toList(),
    );
  }

  Widget _textField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 14.sp),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSfDataGrid(BuildContext context, double tableWidth) {
    final List<DinnerRow> rows = [];
    for (final month in months) {
      if (selectedMonths.contains(month)) {
        int mealDays = _calculateMealDays(month);
        rows.add(
          DinnerRow(
            month,
            '$selectedYear-$selectedSemester $month',
            '${mealDays * 4500}원',
            '신청됨',
            DateFormat('yyyy-MM-dd').format(DateTime.now()),
          ),
        );
      }
    }
    final DinnerDataSource dataSource = DinnerDataSource(rows, selectedMonths, (
      month,
      checked,
    ) {
      setState(() {
        if (checked) {
          selectedMonths.add(month);
        } else {
          selectedMonths.remove(month);
        }
      });
    });
    return Container(
      width: double.infinity,
      child: SfDataGrid(
        source: dataSource,
        columnWidthMode: ColumnWidthMode.fill,
        columns: [
          GridColumn(
            columnName: 'select',
            width: tableWidth * 0.10,
            label: Center(
              child: Text(
                '',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'period',
            width: tableWidth * 0.225,
            label: Center(
              child: Text(
                '식사 기간',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'price',
            width: tableWidth * 0.225,
            label: Center(
              child: Text(
                '식비',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'status',
            width: tableWidth * 0.225,
            label: Center(
              child: Text(
                '신청여부',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'date',
            width: tableWidth * 0.225,
            label: Center(
              child: Text(
                '신청일자',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
        ],
        gridLinesVisibility: GridLinesVisibility.horizontal,
        headerGridLinesVisibility: GridLinesVisibility.horizontal,
        rowHeight: 44.h,
        headerRowHeight: 40.h,
        allowSorting: false,
      ),
    );
  }

  Widget _buildPaymentDataGrid(BuildContext context, double tableWidth) {
    List<PaymentRow> filtered = payments;
    if (paymentFilter == '결제됨') {
      filtered = payments.where((p) => p.refundDate == null).toList();
    } else if (paymentFilter == '환불됨') {
      filtered = payments.where((p) => p.refundDate != null).toList();
    }
    filtered.sort((a, b) {
      int aMonth = int.tryParse(a.monthKey.replaceAll('월', '')) ?? 0;
      int bMonth = int.tryParse(b.monthKey.replaceAll('월', '')) ?? 0;
      return aMonth.compareTo(bMonth);
    });
    final PaymentDataSource dataSource = PaymentDataSource(
      filtered,
      selectedRefunds,
      (month, checked) {
        setState(() {
          if (checked) {
            selectedRefunds.add(month);
          } else {
            selectedRefunds.remove(month);
          }
        });
      },
      _canRefund,
    );
    return Container(
      width: double.infinity,
      child: SfDataGrid(
        source: dataSource,
        columnWidthMode: ColumnWidthMode.fill,
        columns: [
          GridColumn(
            columnName: 'select',
            width: tableWidth * 0.09,
            label: Center(
              child: Text(
                '',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'period',
            width: tableWidth * 0.18,
            label: Center(
              child: Text(
                '식사 기간',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'price',
            width: tableWidth * 0.18,
            label: Center(
              child: Text(
                '식비',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'payDate',
            width: tableWidth * 0.18,
            label: Center(
              child: Text(
                '결제일자',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'refundDate',
            width: tableWidth * 0.18,
            label: Center(
              child: Text(
                '환불일자',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'status',
            width: tableWidth * 0.19,
            label: Center(
              child: Text(
                '상태',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
              ),
            ),
          ),
        ],
        gridLinesVisibility: GridLinesVisibility.horizontal,
        headerGridLinesVisibility: GridLinesVisibility.horizontal,
        rowHeight: 44.h,
        headerRowHeight: 40.h,
        allowSorting: false,
      ),
    );
  }

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

  int _calculateMealDays(String month) {
    // 월 문자열에서 숫자 추출
    int monthIndex = int.tryParse(month.replaceAll('월', '')) ?? 1;

    // 년도 계산 (2학기의 1-2월은 다음 해)
    int year = int.tryParse(selectedYear) ?? DateTime.now().year;
    if (selectedSemester == '2학기' && monthIndex <= 2) {
      year += 1; // 2학기의 1-2월은 다음 해
    }

    DateTime firstDay = DateTime.parse(
      '$year-${monthIndex.toString().padLeft(2, '0')}-01',
    );
    DateTime lastDay = DateTime(firstDay.year, firstDay.month + 1, 0);
    int mealDays = 0;
    for (int i = 0; i < lastDay.day; i++) {
      DateTime day = firstDay.add(Duration(days: i));
      if (day.weekday >= 1 && day.weekday <= 4) {
        mealDays++;
      }
    }
    return mealDays;
  }
}

class DinnerRow {
  final String monthKey;
  final String period;
  final String price;
  final String status;
  final String date;
  DinnerRow(this.monthKey, this.period, this.price, this.status, this.date);
}

class DinnerDataSource extends DataGridSource {
  final Set<String> selectedMonths;
  final Function(String, bool) onRowCheck;
  List<DataGridRow> _rows = [];
  DinnerDataSource(List<DinnerRow> data, this.selectedMonths, this.onRowCheck) {
    _rows =
        data
            .map(
              (e) => DataGridRow(
                cells: [
                  DataGridCell<String>(
                    columnName: 'monthKey',
                    value: e.monthKey,
                  ),
                  DataGridCell<String>(columnName: 'period', value: e.period),
                  DataGridCell<String>(columnName: 'price', value: e.price),
                  DataGridCell<String>(columnName: 'status', value: e.status),
                  DataGridCell<String>(columnName: 'date', value: e.date),
                ],
              ),
            )
            .toList();
  }
  @override
  List<DataGridRow> get rows => _rows;
  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final String monthKey = row.getCells()[0].value;
    final bool checked = selectedMonths.contains(monthKey);
    return DataGridRowAdapter(
      cells: [
        Center(
          child: Checkbox(
            value: checked,
            onChanged: (val) => onRowCheck(monthKey, val ?? false),
          ),
        ),
        ...row
            .getCells()
            .skip(1)
            .map(
              (cell) => Center(
                child: Text(
                  cell.value.toString(),
                  style: TextStyle(fontSize: 15.sp),
                ),
              ),
            )
            .toList(),
      ],
    );
  }
}

class PaymentRow {
  final String monthKey;
  final String period;
  final String price;
  final String payDate;
  String? refundDate;
  final int? dinnerId;
  final String payType;
  final DateTime payDt;
  PaymentRow(
    this.monthKey,
    this.period,
    this.price,
    this.payDate, {
    this.refundDate,
    this.dinnerId,
    required this.payType,
    required this.payDt,
  });
  String get status => refundDate == null ? '결제됨' : '환불됨';
}

class PaymentDataSource extends DataGridSource {
  final Set<String> selectedRefunds;
  final Function(String, bool) onRowCheck;
  final Function(String) canRefund;
  List<DataGridRow> _rows = [];
  List<PaymentRow> _data = [];
  PaymentDataSource(
    List<PaymentRow> data,
    this.selectedRefunds,
    this.onRowCheck,
    this.canRefund,
  ) {
    _data = data;
    _rows =
        data
            .map(
              (e) => DataGridRow(
                cells: [
                  DataGridCell<String>(
                    columnName: 'monthKey',
                    value: e.monthKey,
                  ),
                  DataGridCell<String>(columnName: 'period', value: e.period),
                  DataGridCell<String>(columnName: 'price', value: e.price),
                  DataGridCell<String>(columnName: 'payDate', value: e.payDate),
                  DataGridCell<String>(
                    columnName: 'refundDate',
                    value: e.refundDate ?? '',
                  ),
                  DataGridCell<String>(columnName: 'status', value: e.status),
                ],
              ),
            )
            .toList();
  }
  @override
  List<DataGridRow> get rows => _rows;
  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final String monthKey = row.getCells()[0].value;
    final bool checked = selectedRefunds.contains(monthKey);
    final String status = row.getCells()[5].value;
    final bool refunded = status == '환불됨';
    final bool canRefundThis = canRefund(monthKey);
    final bool isDisabled = refunded || !canRefundThis;

    final textStyle = TextStyle(
      fontSize: 15.sp,
      color: isDisabled ? Colors.grey : Colors.black,
    );

    return DataGridRowAdapter(
      cells: [
        Center(
          child: Checkbox(
            value: checked,
            onChanged:
                isDisabled ? null : (val) => onRowCheck(monthKey, val ?? false),
          ),
        ),
        ...row
            .getCells()
            .skip(1)
            .take(4)
            .map(
              (cell) =>
                  Center(child: Text(cell.value.toString(), style: textStyle)),
            )
            .toList(),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(status, style: textStyle),
              if (!canRefundThis && !refunded) ...[
                SizedBox(width: 4.w),
                Icon(Icons.schedule, size: 12.sp, color: Colors.orange),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
