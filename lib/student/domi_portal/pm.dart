import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../student_provider.dart';
import 'dart:io'; // HttpDate 사용
import 'package:kbu_domi/env.dart';

class PointHistoryPage extends StatefulWidget {
  const PointHistoryPage({super.key});

  @override
  State<PointHistoryPage> createState() => _PointHistoryPageState();
}

class _PointHistoryPageState extends State<PointHistoryPage> {
  String _viewType = '전체';
  String _selectedPeriod = '전체';
  DateTime? _startDate;
  DateTime? _endDate;

  final DateFormat _dateFormatter = DateFormat('yyyy.MM.dd');

  List<Map<String, dynamic>> pointHistory = [];
  bool isLoading = false;

  // API 호출 함수
  Future<void> loadPointHistory() async {
    setState(() => isLoading = true);
    try {
      final studentId =
          Provider.of<StudentProvider>(context, listen: false).studentId ?? '';

      print('🔍 웹 상벌점 - loadPointHistory 호출, studentId: $studentId');

      if (studentId.isEmpty) {
        print('❌ 웹 상벌점 - studentId가 비어있습니다!');
        setState(() {
          pointHistory = [];
          isLoading = false;
        });
        return;
      }

      final from =
          _startDate != null
              ? DateFormat('yyyy-MM-dd').format(_startDate!)
              : null;
      final to =
          _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null;
      final type = _viewType == '전체' ? null : _viewType;

      final queryParams = <String, String>{'student_id': studentId};
      if (type != null) queryParams['type'] = type;
      if (from != null) queryParams['from'] = from;
      if (to != null) queryParams['to'] = to;

      final uri = Uri.parse(
        '$apiBase/api/point/history',
      ).replace(queryParameters: queryParams);
      print('🔍 웹 상벌점 - API 호출: $uri');

      final response = await http.get(uri);
      print('🔍 웹 상벌점 - API 응답: ${response.statusCode}');
      print('🔍 웹 상벌점 - 응답 데이터: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);

        List<Map<String, dynamic>> historyList = [];

        // API 응답 형식 확인
        if (responseData is Map && responseData.containsKey('points')) {
          // 새로운 형식: {points: [...]}
          final List<dynamic> points = responseData['points'] ?? [];
          historyList = List<Map<String, dynamic>>.from(points);
          print('✅ 웹 상벌점 - 데이터 로드 완료 (새 형식): ${historyList.length}건');
        } else if (responseData is List) {
          // 기존 형식: [...]
          historyList = List<Map<String, dynamic>>.from(responseData);
          print('✅ 웹 상벌점 - 데이터 로드 완료 (기존 형식): ${historyList.length}건');
        }

        setState(() {
          pointHistory = historyList;
        });
      } else {
        print('❌ 웹 상벌점 - API 호출 실패: ${response.statusCode}');
        throw Exception('상벌점 내역 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 웹 상벌점 - 조회 중 오류: $e');
      setState(() {
        pointHistory = [];
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    loadPointHistory();
  }

  // 필터 변경 시 loadPointHistory() 호출
  void _onFilterChanged([String? _]) {
    loadPointHistory();
  }

  @override
  Widget build(BuildContext context) {
    // 기존 filtered 대신 pointHistory 사용
    final filtered = pointHistory;

    // 점수 및 건수 합산
    int plusSum = filtered
        .where((e) => e['point_type'] == '상점')
        .fold(0, (sum, item) => sum + (item['score'] as int));
    int minusSum = filtered
        .where((e) => e['point_type'] == '벌점')
        .fold(0, (sum, item) => sum + (item['score'] as int));
    int totalSum = plusSum + minusSum;

    int plusCount = filtered.where((e) => e['point_type'] == '상점').length;
    int minusCount = filtered.where((e) => e['point_type'] == '벌점').length;

    // 팀원의 원래 레이아웃을 유지하면서 home.dart와 호환되도록 SingleChildScrollView로 감쌈
    return isLoading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 8.h),
                child: Text(
                  '상벌점 조회',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF212529),
                  ),
                ),
              ),
              _buildSummaryCard(
                plusSum,
                minusSum,
                totalSum,
                plusCount,
                minusCount,
              ),
              _buildTypeFilter(onChanged: (val) => _onFilterChanged(val)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child:
                    filtered.isEmpty
                        ? Container(
                          height: 300.h, // 고정 높이로 빈 상태 표시
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  color: Colors.grey[300],
                                  size: 60.sp,
                                ),
                                SizedBox(height: 16.h),
                                Text(
                                  '해당 기간의 내역이 없습니다.',
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : Column(
                          children:
                              filtered
                                  .map(
                                    (item) => Padding(
                                      padding: EdgeInsets.only(bottom: 12.h),
                                      child: _buildHistoryListItem(item),
                                    ),
                                  )
                                  .toList(),
                        ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        );
  }

  // 상단 요약 카드
  Widget _buildSummaryCard(
    int plusSum,
    int minusSum,
    int totalSum,
    int plusCount,
    int minusCount,
  ) {
    return Padding(
      padding: EdgeInsets.all(20.w),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSummaryItem(
              '상점',
              '+$plusSum',
              Colors.blue.shade600,
              plusCount,
              Icons.arrow_upward_rounded,
            ),
            Container(width: 1.w, height: 50.h, color: Colors.grey[300]),
            _buildSummaryItem(
              '벌점',
              '$minusSum',
              Colors.red.shade500,
              minusCount,
              Icons.arrow_downward_rounded,
            ),
            Container(width: 1.w, height: 50.h, color: Colors.grey[300]),
            _buildSummaryItem(
              '총점',
              totalSum >= 0 ? '+$totalSum' : '$totalSum',
              const Color(0xFF495057),
              plusCount + minusCount,
              Icons.calculate_rounded,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String score,
    Color color,
    int count,
    IconData icon, {
    bool isTotal = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey.shade700, size: 16.sp),
            SizedBox(width: 4.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          score,
          style: TextStyle(
            fontSize: isTotal ? 24.sp : 22.sp,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '총 ${count}건',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // 유형 필터
  Widget _buildTypeFilter({Function(String)? onChanged}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: '전체',
              label: Text('전체'),
              icon: Icon(Icons.list_alt_rounded),
            ),
            ButtonSegment<String>(
              value: '상점',
              label: Text('상점'),
              icon: Icon(Icons.sentiment_satisfied_alt_rounded),
            ),
            ButtonSegment<String>(
              value: '벌점',
              label: Text('벌점'),
              icon: Icon(Icons.sentiment_very_dissatisfied_rounded),
            ),
          ],
          selected: {_viewType},
          onSelectionChanged: (newSelection) {
            setState(() {
              _viewType = newSelection.first;
            });
            if (onChanged != null) onChanged(_viewType);
          },
          style: SegmentedButton.styleFrom(
            backgroundColor: Colors.grey.shade100,
            selectedBackgroundColor: Colors.grey.shade800,
            selectedForegroundColor: Colors.white,
            foregroundColor: Colors.grey.shade700,
            textStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 15.sp),
            padding: EdgeInsets.symmetric(vertical: 12.h),
          ),
        ),
      ),
    );
  }

  // 리스트 아이템
  Widget _buildHistoryListItem(Map<String, dynamic> item) {
    print('상벌점 아이템: $item'); // 디버깅용
    final bool isMerit = item['point_type'] == '상점';
    final Color indicatorColor =
        isMerit ? Colors.blue.shade600 : Colors.red.shade500;
    final IconData pointIcon =
        isMerit
            ? Icons.add_circle_outline_rounded
            : Icons.remove_circle_outline_rounded;
    final int score = item['score'] as int;

    // reg_dt 안전 파싱 (ISO 8601 포맷으로 수정)
    final regDtStr = item['reg_dt'];
    DateTime? regDt;
    if (regDtStr != null && regDtStr is String && regDtStr.isNotEmpty) {
      try {
        regDt = DateTime.parse(regDtStr);
      } catch (_) {
        regDt = null;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 6.w,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(16.r),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(pointIcon, color: indicatorColor, size: 24.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item['reason'] ?? '사유 없음',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF343A40),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            '${regDt != null ? DateFormat('yyyy.MM.dd').format(regDt) : '날짜 미상'} | ${item['giver'] ?? '부여자 미상'}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: indicatorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        score > 0 ? '+$score' : '$score',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: indicatorColor,
                        ),
                      ),
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
}
