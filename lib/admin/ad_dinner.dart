// 파일명: ad_dinner.dart
// [오류 수정] package.intl/intl.dart -> package:intl/intl.dart 로 수정

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart'; // [오류 수정] 올바른 경로로 변경
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

// --- AppColors 클래스 (ad_in_page.dart 스타일 참조하여 재구성) ---
class AppColors {
  static const Color primary = Color(0xFF0D47A1); // Main Blue
  static const Color primaryLight = Color(
    0xFFE3F2FD,
  ); // Light Blue for backgrounds
  static const Color accent = Color(0xFFFFA000); // Accent Orange for highlights
  static const Color fontPrimary = Color(0xFF212121); // Darker Primary Font
  static const Color fontSecondary = Color(
    0xFF757575,
  ); // Lighter Secondary Font
  static const Color border = Color(0xFFE0E0E0); // Border color
  static const Color statusSuccess = Color(
    0xFF388E3C,
  ); // Green for success, payment
  static const Color statusWarning = Color(0xFFFBC02D); // Yellow for pending
  static const Color statusError = Color(0xFFD32F2F); // Red for error, refund
  static const Color background = Colors.white;
  static const Color cardBackground = Colors.white; // Card background
  static const Color disabledBackground = Color(
    0xFFF5F5F5,
  ); // ad_in_page의 disabledBackground 참조
}

// --- 텍스트 스타일 정의 ---
TextStyle headingStyle(double size, FontWeight weight, Color color) {
  return TextStyle(
    fontSize: size.sp,
    fontWeight: weight,
    color: color,
    letterSpacing: -0.5,
  );
}

class AdDinnerPage extends StatefulWidget {
  const AdDinnerPage({super.key});

  @override
  State<AdDinnerPage> createState() => _AdDinnerPageState();
}

class _AdDinnerPageState extends State<AdDinnerPage> {
  DinnerDataSource? _dinnerDataSource;
  final List<AdminDinnerRequest> _dinnerRequests = [];
  List<AdminDinnerRequest> _filteredRequests = [];
  bool _isLoading = true;
  String _selectedStatus = '전체';
  final TextEditingController _searchController = TextEditingController();

  Map<int, int> _monthlyCounts = {};
  Map<String, dynamic>? _periodInfo;
  Map<String, dynamic>? _notice;

  static const List<String> _statusList = ['전체', '결제완료', '환불완료'];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.wait([
      _loadDinnerRequests(),
      _loadPeriodInfo(),
      _loadNotice(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _calculateMonthlyStatistics() {
    _monthlyCounts.clear();
    final semesterMonths = _getSemesterMonths();
    for (var month in semesterMonths) {
      _monthlyCounts[month] = 0;
    }

    for (final request in _dinnerRequests) {
      String monthStr = request.month.replaceAll('월', '').trim();
      final monthInt = int.tryParse(monthStr);
      if (monthInt != null) {
        _monthlyCounts.update(
          monthInt,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }
  }

  List<int> _getSemesterMonths() {
    final now = DateTime.now();
    return (now.month >= 3 && now.month <= 8)
        ? [3, 4, 5, 6, 7, 8]
        : [9, 10, 11, 12, 1, 2];
  }

  Future<void> _loadDinnerRequests() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/admin/dinner/all-requests'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _dinnerRequests
          ..clear()
          ..addAll(data.map((item) => AdminDinnerRequest.fromJson(item)));
        _calculateMonthlyStatistics();
        _applyFilter();
      } else {
        throw Exception('Failed to load dinner requests');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터를 불러오는데 실패했습니다: $e')));
      }
    }
  }

  Future<void> _loadPeriodInfo() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/admin/dinner/period-info'),
      );
      if (response.statusCode == 200) {
        if (mounted) setState(() => _periodInfo = json.decode(response.body));
      }
    } catch (e) {
      print('석식 기간 정보 로딩 실패: $e');
    }
  }

  Future<void> _loadNotice() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/admin/notice?category=dinner'),
      );
      if (response.statusCode == 200) {
        if (mounted) setState(() => _notice = json.decode(response.body));
      }
    } catch (e) {
      print('공지사항 로딩 실패: $e');
    }
  }

  void _applyFilter() {
    final search = _searchController.text.trim().toLowerCase();
    _filteredRequests =
        _dinnerRequests.where((req) {
          final matchesStatus =
              _selectedStatus == '전체' || req.status == _selectedStatus;
          final matchesSearch =
              search.isEmpty ||
              req.studentId.toLowerCase().contains(search) ||
              req.studentName.toLowerCase().contains(search);
          return matchesStatus && matchesSearch;
        }).toList();

    setState(() {
      _dinnerDataSource = DinnerDataSource(
        context: context,
        requests: _filteredRequests,
      );
    });
  }

  void _showNoticeDialog() {
    final TextEditingController contentController = TextEditingController(
      text: _notice?['content'] ?? '',
    );
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            title: Text(
              '공지사항 편집',
              style: headingStyle(18, FontWeight.bold, AppColors.fontPrimary),
            ),
            content: SizedBox(
              width: 500.w,
              child: TextField(
                controller: contentController,
                maxLines: 5,
                style: TextStyle(fontSize: 14.sp),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  hintText: '공지 내용을 입력하세요.',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '취소',
                  style: TextStyle(color: AppColors.fontSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _saveNotice('석식 공지사항', contentController.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text('저장'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveNotice(String title, String content) async {
    try {
      final isUpdate = _notice != null && _notice!['id'] != null;
      final url =
          isUpdate
              ? 'http://localhost:5050/api/admin/notice/${_notice!['id']}'
              : 'http://localhost:5050/api/admin/notice';
      final body = json.encode({
        'title': title,
        'content': content,
        'category': 'dinner',
        'is_active': true,
      });
      final response =
          isUpdate
              ? await http.put(
                Uri.parse(url),
                headers: {'Content-Type': 'application/json'},
                body: body,
              )
              : await http.post(
                Uri.parse(url),
                headers: {'Content-Type': 'application/json'},
                body: body,
              );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadNotice();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('공지사항이 저장되었습니다.'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
      } else {
        throw Exception('공지사항 저장 실패: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('공지사항 저장 중 오류 발생: $e'),
          backgroundColor: AppColors.statusError,
        ),
      );
    }
  }

  Future<void> _savePeriodSettings({
    required bool isCustom,
    int? startDay,
    int? endDay,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5050/api/admin/dinner/period-settings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'is_custom': isCustom,
          'start_day': isCustom ? startDay : 1,
          'end_day': isCustom ? endDay : 15,
        }),
      );
      if (response.statusCode == 200) {
        await _loadPeriodInfo();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('결제/환불 기간 설정이 업데이트되었습니다.'),
            backgroundColor: AppColors.statusSuccess,
          ),
        );
      } else {
        throw Exception('설정 저장 실패');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('기간 설정 저장에 실패했습니다: $e'),
          backgroundColor: AppColors.statusError,
        ),
      );
    }
  }

  void _showPeriodSettingsDialog() {
    bool isCustomMode = _periodInfo?['is_custom'] ?? false;
    final startDayController = TextEditingController(
      text: (_periodInfo?['start_day'] ?? 1).toString(),
    );
    final endDayController = TextEditingController(
      text: (_periodInfo?['end_day'] ?? 15).toString(),
    );
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: AppColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                title: Text(
                  '기간 설정',
                  style: headingStyle(
                    18,
                    FontWeight.bold,
                    AppColors.fontPrimary,
                  ),
                ),
                content: SizedBox(
                  width: 400.w,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        title: Text(
                          '커스텀 기간 설정',
                          style: TextStyle(fontSize: 16.sp),
                        ),
                        value: isCustomMode,
                        onChanged:
                            (value) =>
                                setDialogState(() => isCustomMode = value),
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (isCustomMode) ...[
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: startDayController,
                                decoration: InputDecoration(
                                  labelText: '시작일',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: TextField(
                                controller: endDayController,
                                decoration: InputDecoration(
                                  labelText: '종료일',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '취소',
                      style: TextStyle(color: AppColors.fontSecondary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final startDay = int.tryParse(startDayController.text);
                      final endDay = int.tryParse(endDayController.text);
                      if (isCustomMode &&
                          (startDay == null ||
                              endDay == null ||
                              startDay > endDay)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('유효한 기간을 입력해주세요.'),
                            backgroundColor: AppColors.statusError,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      _savePeriodSettings(
                        isCustom: isCustomMode,
                        startDay: startDay,
                        endDay: endDay,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: const Text('저장'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: EdgeInsets.all(24.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _buildHeader(),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.all(20.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildNoticeSection(),
                                    SizedBox(height: 24.h),
                                    _buildMonthlyStats(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 24.w),
                    Expanded(
                      flex: 7,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _buildFilterBar(),
                            Expanded(
                              child:
                                  _dinnerDataSource == null
                                      ? const Center(child: Text("데이터가 없습니다."))
                                      : _buildDataGrid(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1.h)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '석식관리',
            style: headingStyle(24, FontWeight.bold, AppColors.fontPrimary),
          ),
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh, color: AppColors.fontSecondary),
            tooltip: '새로고침',
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '월별 신청 현황',
          style: headingStyle(16, FontWeight.bold, AppColors.fontPrimary),
        ),
        SizedBox(height: 16.h),
        _buildCardView(),
      ],
    );
  }

  Widget _buildCardView() {
    final semesterMonths = _getSemesterMonths();
    final dataMonths = _monthlyCounts.keys.toSet();
    final allMonths = {...semesterMonths, ...dataMonths}.toList()..sort();
    return Column(
      children: [
        SizedBox(height: 32.h),
        GridView.builder(
          key: const ValueKey('cardView'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16.w,
            mainAxisSpacing: 16.h,
            childAspectRatio: 2 / 1.3,
          ),
          itemCount: allMonths.length,
          itemBuilder: (context, index) {
            final month = allMonths[index];
            final count = _monthlyCounts[month] ?? 0;
            return _buildMonthCard(
              month,
              count,
              semesterMonths.contains(month),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMonthCard(int month, int count, bool isCurrentSemester) {
    final monthNames = {
      1: '1월',
      2: '2월',
      3: '3월',
      4: '4월',
      5: '5월',
      6: '6월',
      7: '7월',
      8: '8월',
      9: '9월',
      10: '10월',
      11: '11월',
      12: '12월',
    };
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          if (count > 0)
            BoxShadow(
              color: AppColors.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${monthNames[month]}',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.fontPrimary,
                ),
              ),
              if (!isCurrentSemester)
                Padding(
                  padding: EdgeInsets.only(left: 4.w),
                  child: Tooltip(
                    message: '현재 학기 데이터가 아님',
                    child: Icon(
                      Icons.info_outline,
                      size: 14.sp,
                      color: AppColors.fontSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w900,
                  color:
                      count > 0 ? AppColors.primary : AppColors.fontSecondary,
                ),
              ),
              SizedBox(width: 4.w),
              Text(
                '명',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.fontSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildNoticeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '공지사항',
              style: headingStyle(16, FontWeight.bold, AppColors.fontPrimary),
            ),
            TextButton.icon(
              onPressed: _showNoticeDialog,
              icon: Icon(Icons.edit_outlined, size: 16.sp),
              label: const Text('편집'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Text(
            _notice?['content'] ?? '등록된 공지사항이 없습니다.',
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.fontPrimary.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataGrid() {
    return SfDataGridTheme(
      data: SfDataGridThemeData(
        headerColor: AppColors.disabledBackground,
        gridLineColor: AppColors.border,
        frozenPaneLineColor: AppColors.border,
        headerHoverColor: Colors.grey.shade200,
        rowHoverColor: AppColors.primaryLight.withOpacity(0.5),
      ),
      child: SfDataGrid(
        source: _dinnerDataSource!,
        columns: _getColumns(),
        columnWidthMode: ColumnWidthMode.fill,
        rowHeight: 52.h,
        headerRowHeight: 48.h,
        gridLinesVisibility: GridLinesVisibility.horizontal,
        headerGridLinesVisibility: GridLinesVisibility.horizontal,
        allowSorting: false,
      ),
    );
  }

  List<GridColumn> _getColumns() {
    TextStyle headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 14.sp,
      color: AppColors.fontPrimary,
    );
    return [
      GridColumn(
        columnName: 'yearSemester',
        label: _buildHeaderCell('년도/학기', headerStyle),
        allowSorting: false,
      ),
      GridColumn(
        columnName: 'month',
        label: _buildHeaderCell('신청월', headerStyle),
        allowSorting: false,
      ),
      GridColumn(
        columnName: 'studentId',
        label: _buildHeaderCell('학번', headerStyle),
        allowSorting: false,
      ),
      GridColumn(
        columnName: 'studentName',
        label: _buildHeaderCell('이름', headerStyle),
        allowSorting: false,
      ),
      GridColumn(
        columnName: 'dormInfo',
        label: _buildHeaderCell('건물/호실', headerStyle),
        allowSorting: false,
      ),
      GridColumn(
        columnName: 'amount',
        label: _buildHeaderCell(
          '금액',
          headerStyle,
          alignment: Alignment.centerRight,
        ),
        allowSorting: false,
      ),
      GridColumn(
        columnName: 'status',
        label: _buildHeaderCell('상태', headerStyle),
        allowSorting: false,
      ),
      GridColumn(
        columnName: 'processedDate',
        label: _buildHeaderCell('처리일자', headerStyle),
        allowSorting: false,
      ),
    ];
  }

  Widget _buildHeaderCell(
    String text,
    TextStyle style, {
    Alignment alignment = Alignment.center,
  }) {
    return Container(
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Text(text, style: style, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildFilterBar() {
    final message = _periodInfo?['message'] ?? '';
    final isCustom = _periodInfo?['is_custom'] ?? false;
    final periodDisplay = _periodInfo?['period_display'] ?? '매월 1일 ~ 15일';
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.disabledBackground,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(
                  isCustom
                      ? Icons.edit_calendar_outlined
                      : Icons.event_available,
                  color: AppColors.fontSecondary,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '결제/환불 기간: $periodDisplay',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.fontPrimary,
                        ),
                      ),
                      if (message.isNotEmpty)
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.fontSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                ElevatedButton.icon(
                  onPressed: _showPeriodSettingsDialog,
                  icon: Icon(Icons.settings, size: 16.sp),
                  label: const Text('기간 설정'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: TextStyle(fontSize: 13.sp),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              SizedBox(width: 180.w, height: 40.h, child: _statusFilter()),
              SizedBox(width: 16.w),
              Expanded(child: SizedBox(height: 40.h, child: _searchField())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusFilter() {
    return DropdownButtonFormField2<String>(
      isExpanded: true,
      decoration: InputDecoration(
        contentPadding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
      ),
      dropdownStyleData: DropdownStyleData(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          color: AppColors.cardBackground,
        ),
      ),
      value: _selectedStatus,
      items:
          _statusList
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.fontPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
      onChanged: (value) {
        if (value != null) {
          _selectedStatus = value;
          _applyFilter();
        }
      },
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => _applyFilter(),
      decoration: InputDecoration(
        hintText: '학번 또는 이름으로 검색',
        hintStyle: TextStyle(fontSize: 14.sp),
        prefixIcon: const Icon(Icons.search, color: AppColors.fontSecondary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: AppColors.border),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 8.h),
      ),
    );
  }
}

// 데이터 모델 클래스
class AdminDinnerRequest {
  final int dinnerId;
  final String year;
  final String semester;
  final String month;
  final DateTime registeredAt;
  final String studentId;
  final String studentName;
  final String? building;
  final String? roomNumber;
  final int? paymentAmount;
  final DateTime? paymentDate;
  final int? refundAmount;
  final DateTime? refundDate;
  final String status;

  AdminDinnerRequest({
    required this.dinnerId,
    required this.year,
    required this.semester,
    required this.month,
    required this.registeredAt,
    required this.studentId,
    required this.studentName,
    this.building,
    this.roomNumber,
    this.paymentAmount,
    this.paymentDate,
    this.refundAmount,
    this.refundDate,
    required this.status,
  });

  DateTime? get processedDate {
    if (status == '환불완료') return refundDate ?? registeredAt;
    if (status == '결제완료') return paymentDate ?? registeredAt;
    return registeredAt;
  }

  factory AdminDinnerRequest.fromJson(Map<String, dynamic> json) {
    return AdminDinnerRequest(
      dinnerId: json['dinner_id'],
      year: json['year'],
      semester: json['semester'],
      month: json['month'].toString(),
      registeredAt: DateTime.parse(json['reg_dt']),
      studentId: json['student_id'],
      studentName: json['student_name'],
      building: json['dorm_building'],
      roomNumber: json['room_num'],
      paymentAmount: json['payment_amount'],
      paymentDate:
          json['payment_date'] != null
              ? DateTime.parse(json['payment_date'])
              : null,
      refundAmount: json['refund_amount'],
      refundDate:
          json['refund_date'] != null
              ? DateTime.parse(json['refund_date'])
              : null,
      status: json['status'] ?? '결제완료',
    );
  }
}

class DinnerDataSource extends DataGridSource {
  DinnerDataSource({
    required this.context,
    required List<AdminDinnerRequest> requests,
  }) {
    _requests =
        requests
            .map<DataGridRow>(
              (e) => DataGridRow(
                cells: [
                  DataGridCell<AdminDinnerRequest>(
                    columnName: 'request',
                    value: e,
                  ),
                ],
              ),
            )
            .toList();
  }

  final BuildContext context;
  late List<DataGridRow> _requests;

  @override
  List<DataGridRow> get rows => _requests;

  Widget _buildCell(dynamic value, {Alignment alignment = Alignment.center}) {
    return Container(
      alignment: alignment,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Text(
        value.toString(),
        style: TextStyle(fontSize: 13.sp, color: AppColors.fontPrimary),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color textColor;
    switch (status) {
      case '결제완료':
        textColor = AppColors.statusSuccess;
        break;
      case '환불완료':
        textColor = AppColors.statusError;
        break;
      default:
        textColor = AppColors.fontSecondary;
    }
    return Center(
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final AdminDinnerRequest request = row.getCells()[0].value;
    return DataGridRowAdapter(
      cells: [
        _buildCell('${request.year} / ${request.semester}'),
        _buildCell(
          request.month.endsWith('월') ? request.month : '${request.month}월',
        ),
        _buildCell(request.studentId),
        _buildCell(request.studentName),
        _buildCell('${request.building ?? '-'} / ${request.roomNumber ?? '-'}'),
        _buildCell(
          request.paymentAmount != null
              ? '${NumberFormat('#,###').format(request.paymentAmount)}원'
              : '-',
          alignment: Alignment.centerRight,
        ),
        _buildStatusChip(request.status),
        _buildCell(
          request.processedDate != null
              ? DateFormat('yy-MM-dd').format(request.processedDate!)
              : '-',
        ),
      ],
    );
  }

  @override
  int compare(DataGridRow? a, DataGridRow? b, SortColumnDetails sortColumn) {
    final AdminDinnerRequest requestA = a!.getCells()[0].value;
    final AdminDinnerRequest requestB = b!.getCells()[0].value;
    dynamic valueA, valueB;

    switch (sortColumn.name) {
      case 'yearSemester':
        valueA = '${requestA.year}-${requestA.semester}';
        valueB = '${requestB.year}-${requestB.semester}';
        break;
      case 'month':
        valueA = int.tryParse(requestA.month.replaceAll('월', ''));
        valueB = int.tryParse(requestB.month.replaceAll('월', ''));
        break;
      case 'studentId':
        valueA = requestA.studentId;
        valueB = requestB.studentId;
        break;
      case 'studentName':
        valueA = requestA.studentName;
        valueB = requestB.studentName;
        break;
      case 'dormInfo':
        valueA = '${requestA.building}-${requestA.roomNumber}';
        valueB = '${requestB.building}-${requestB.roomNumber}';
        break;
      case 'amount':
        valueA = requestA.paymentAmount ?? 0;
        valueB = requestB.paymentAmount ?? 0;
        break;
      case 'status':
        valueA = requestA.status;
        valueB = requestB.status;
        break;
      case 'processedDate':
        valueA = requestA.processedDate;
        valueB = requestB.processedDate;
        break;
      default:
        return 0;
    }

    if (valueA == null || valueB == null) return 0;

    if (sortColumn.sortDirection == DataGridSortDirection.ascending) {
      return valueA.compareTo(valueB);
    } else {
      return valueB.compareTo(valueA);
    }
  }
}
