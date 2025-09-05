import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../student_provider.dart';

// --- KBU 도미토리 스타일 컬러 ---
const Color kKbuBg = Color(0xFFF4F6FA);
const Color kKbuSky = Color(0xFFE9F2FF);
const Color kKbuNavy = Color(0xFF1C2946);

class AppColors {
  static const primary = Color(0xFF4A69E2);
  static const accent = Color(0xFF4A69E2);
  static const background = Colors.white;
  static const card = Colors.white;
  static const textPrimary = kKbuNavy;
  static const textSecondary = Color(0xFF7F8C8D);
  static const success = Color(0xFF27AE60);
  static const danger = Color(0xFFE74C3C);
}

class AppPm extends StatefulWidget {
  const AppPm({super.key});
  @override
  State<AppPm> createState() => _AppPmState();
}

class _AppPmState extends State<AppPm> {
  List<Map<String, dynamic>> _allPoints = [];
  bool _isLoading = true;

  String _viewType = '전체';

  late int _currentAcademicYear;
  late int _currentSemester;
  final DateFormat _dateFormatter = DateFormat('yyyy.MM.dd');
  final DateTime _now = DateTime(2025, 6, 22);

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ko_KR');
    _initializeSemester();
    _loadPointHistory();
  }

  void _initializeSemester() {
    _currentAcademicYear = _now.year;
    if (_now.month >= 3 && _now.month <= 8) {
      _currentSemester = 1;
    } else {
      _currentSemester = 2;
      if (_now.month < 3) {
        _currentAcademicYear = _now.year - 1;
      }
    }
  }

  // 실제 상벌점 내역 불러오기
  Future<void> _loadPointHistory() async {
    setState(() => _isLoading = true);
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );
    final studentId = studentProvider.studentId;

    if (studentId == null) {
      print('❌ 학생 ID가 없습니다. 로그인 페이지로 이동합니다.');
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      // 상점과 벌점을 병렬로 가져오기
      final responses = await Future.wait([
        http.get(
          Uri.parse(
            'http://localhost:5050/api/point/history?student_id=$studentId&type=상점',
          ),
        ),
        http.get(
          Uri.parse(
            'http://localhost:5050/api/point/history?student_id=$studentId&type=벌점',
          ),
        ),
      ]);

      List<Map<String, dynamic>> allPoints = [];

      // 상점 처리
      if (responses[0].statusCode == 200) {
        final data = json.decode(responses[0].body);
        print('⭐ 상점 페이지 데이터: $data');

        List<dynamic> pointsData = [];
        if (data is Map<String, dynamic> &&
            data.containsKey('success') &&
            data['success'] == true) {
          // 새로운 API 형식: {success: true, points: [...]}
          pointsData = data['points'] ?? [];
        } else if (data is List<dynamic>) {
          // 기존 API 형식: [...] (직접 배열)
          pointsData = data;
        }

        for (var point in pointsData) {
          if (point is Map<String, dynamic>) {
            allPoints.add({
              'date': DateTime.parse(point['reg_dt']),
              'type': '상점',
              'score': point['score'],
              'reason': point['reason'] ?? '상점 부여',
              'giver': point['giver'] ?? '관리자',
            });
          }
        }
      }

      // 벌점 처리
      if (responses[1].statusCode == 200) {
        final data = json.decode(responses[1].body);
        print('⚠️ 벌점 페이지 데이터: $data');

        List<dynamic> pointsData = [];
        if (data is Map<String, dynamic> &&
            data.containsKey('success') &&
            data['success'] == true) {
          // 새로운 API 형식: {success: true, points: [...]}
          pointsData = data['points'] ?? [];
        } else if (data is List<dynamic>) {
          // 기존 API 형식: [...] (직접 배열)
          pointsData = data;
        }

        for (var point in pointsData) {
          if (point is Map<String, dynamic>) {
            allPoints.add({
              'date': DateTime.parse(point['reg_dt']),
              'type': '벌점',
              'score': point['score'],
              'reason': point['reason'] ?? '벌점 부여',
              'giver': point['giver'] ?? '관리자',
            });
          }
        }
      }

      // 날짜순으로 정렬 (최신순)
      allPoints.sort((a, b) => b['date'].compareTo(a['date']));
      print('📊 상벌점 페이지 로드 완료: ${allPoints.length}건');

      if (mounted) {
        setState(() {
          _allPoints = allPoints;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 상벌점 페이지 로딩 오류: $e');
      if (mounted) {
        setState(() {
          _allPoints = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 로딩 실패: $e')));
      }
    }
  }

  List<Map<String, dynamic>> _getSemesterFilteredPoints() {
    DateTime startDate, endDate;
    if (_currentSemester == 1) {
      startDate = DateTime(_currentAcademicYear, 3, 1);
      endDate = DateTime(_currentAcademicYear, 8, 31, 23, 59, 59);
    } else {
      startDate = DateTime(_currentAcademicYear, 9, 1);
      endDate = DateTime(_currentAcademicYear + 1, 2, 28, 23, 59, 59);
    }
    return _allPoints.where((item) {
      final itemDate = item['date'] as DateTime;
      return !itemDate.isBefore(startDate) && !itemDate.isAfter(endDate);
    }).toList();
  }

  void _showInfoSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
      ),
      backgroundColor: Colors.white,
      builder:
          (_) => Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 28.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "상벌점 안내",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text(
                  "- 상점은 봉사, 모범, 환경 등 다양한 활동에서 받을 수 있어.\n"
                  "- 벌점은 생활관 규정 위반 시 부여돼.\n"
                  "- 상점, 벌점 모두 학기별로 관리되고 졸업 시까지 누적 관리될 수 있어.\n"
                  "- 누적 벌점이 일정 기준을 초과하면 불이익이 있을 수 있음.",
                  style: TextStyle(
                    fontSize: 15.sp,
                    height: 1.6,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  "* 궁금한 점은 기숙사에 문의하세요.",
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semesterPoints = _getSemesterFilteredPoints();
    final filteredPoints =
        semesterPoints.where((item) {
          final typeMatch = _viewType == '전체' || item['type'] == _viewType;
          return typeMatch;
        }).toList();

    int plusSum = semesterPoints
        .where((e) => e['type'] == '상점')
        .fold(0, (sum, item) => sum + (item['score'] as int));
    int minusSum = semesterPoints
        .where((e) => e['type'] == '벌점')
        .fold(0, (sum, item) => sum + (item['score'] as int));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            _buildSummaryCard(plusSum, minusSum),
            _buildInlineFilterSection(),
            Expanded(child: _buildHistoryList(filteredPoints)),
          ],
        ),
      ),
    );
  }

  // 필터 한 줄로! 칩에 Expanded 적용해서 폭 강제분할
  Widget _buildInlineFilterSection() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20.r),
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            child: Text(
              '$_currentAcademicYear-$_currentSemester학기',
              style: TextStyle(
                color: kKbuNavy,
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Row(
              children: [
                _buildFilterChip('전체'),
                SizedBox(width: 4.w),
                _buildFilterChip('상점'),
                SizedBox(width: 4.w),
                _buildFilterChip('벌점'),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.info_outline,
              color: AppColors.primary,
              size: 20.sp,
            ),
            splashRadius: 18.r,
            tooltip: "상벌점 안내",
            onPressed: _showInfoSheet,
          ),
        ],
      ),
    );
  }

  // filter chip에 Expanded
  Widget _buildFilterChip(String type) {
    final isSelected = _viewType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) setState(() => _viewType = type);
        },
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? kKbuSky : AppColors.card,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 1.7 : 1,
            ),
          ),
          child: Text(
            type,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 15.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int plusSum, int minusSum) {
    final totalSum = plusSum + minusSum;
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 15,
            offset: Offset(0, 5.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            decoration: BoxDecoration(
              color: kKbuSky,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r),
              ),
            ),
            child: Center(
              child: Text(
                '현재 나의 점수',
                style: TextStyle(
                  color: kKbuNavy,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
            child: Column(
              children: [
                Text(
                  '${totalSum >= 0 ? '+' : ''}$totalSum점',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 42.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Divider(height: 32.h, color: Colors.black12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _summaryItem(
                      '상점',
                      '+$plusSum',
                      AppColors.success,
                      Icons.sentiment_satisfied_alt_rounded,
                    ),
                    _summaryItem(
                      '벌점',
                      '$minusSum',
                      AppColors.danger,
                      Icons.sentiment_very_dissatisfied_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String title, String score, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.8),
            fontSize: 15.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          score,
          style: TextStyle(
            color: color,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> points) {
    if (points.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 60.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              '해당 기간의 내역이 없습니다.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15.sp),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      itemCount: points.length,
      itemBuilder: (context, index) {
        final item = points[index];
        final isMerit = item['type'] == '상점';
        final color = isMerit ? AppColors.success : AppColors.danger;
        final score = item['score'] as int;
        final icon = isMerit ? Icons.add_circle : Icons.remove_circle;

        return Card(
          elevation: 2,
          shadowColor: Colors.grey.withOpacity(0.07),
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 32.sp),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['reason'],
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '${_dateFormatter.format(item['date'])} | ${item['giver']}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Text(
                  score > 0 ? '+$score' : '$score',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
    );
  }
}
