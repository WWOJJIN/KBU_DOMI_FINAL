// 파일명: ad_jumho.dart
// [수정] 2025-07-01 요청사항 v3 반영
// - 설정 팝업의 토글 및 시간 필드 크기 축소
// - 건물 필터 드롭다운 메뉴 추가 (펼침 배경 흰색 적용)

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:intl/intl.dart';
import 'package:kbu_domi/env.dart';

// --- AppColors 클래스 (ad_dinner_page 스타일 적용) ---
class AppColors {
  static const Color primary = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color accent = Color(0xFFFFA000);
  static const Color fontPrimary = Color(0xFF212121);
  static const Color fontSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color statusSuccess = Color(0xFF388E3C);
  static const Color statusWarning = Color(0xFFFBC02D);
  static const Color statusError = Color(0xFFD32F2F);
  static const Color background = Colors.white;
  static const Color cardBackground = Colors.white;
  static const Color disabledBackground = Color(0xFFF5F5F5);
}

// --- 텍스트 스타일 함수 (ad_dinner_page 스타일 적용) ---
TextStyle headingStyle(double size, FontWeight weight, Color color) {
  return TextStyle(
    fontSize: size.sp,
    fontWeight: weight,
    color: color,
    letterSpacing: -0.5,
  );
}

TextStyle tableHeaderStyle = TextStyle(
  fontSize: 14.sp,
  fontWeight: FontWeight.bold,
  color: AppColors.fontPrimary,
);
TextStyle tableCellStyle = TextStyle(
  fontSize: 13.sp,
  color: AppColors.fontPrimary,
  fontWeight: FontWeight.w500,
);
final _cardRadius = BorderRadius.circular(12.r);
final _cardShadow = [
  BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 10,
    offset: const Offset(0, 4),
  ),
];

class AdJumhoPage extends StatefulWidget {
  const AdJumhoPage({super.key});
  @override
  State<AdJumhoPage> createState() => _AdJumhoPageState();
}

class _AdJumhoPageState extends State<AdJumhoPage> {
  JumhoDataSource? _jumhoDataSource;
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  String selectedFilter = "전체";
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedStudentIds = {};
  String _bulkAction = '일괄 처리';
  bool _isLoading = true;

  int _totalStudents = 0;
  int _checkedStudents = 0;
  int _uncheckedStudents = 0;
  int _exemptedStudents = 0;

  // [추가] 건물 필터링을 위한 state 변수
  List<Map<String, dynamic>> _buildingStats = [];
  String _selectedBuilding = "전체";

  @override
  void initState() {
    super.initState();
    _loadRollCallData();
    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text;
        _applyFilter();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateDataSource() {
    setState(() {
      _jumhoDataSource = JumhoDataSource(
        students: _filteredStudents,
        onManualJumho: _showManualJumhoDialog,
        onShowOutingDetails: _showOutingDetails,
        selectedStudentIds: _selectedStudentIds,
        onRowSelect: _onRowSelect,
      );
    });
  }

  void _generateDummyData() {
    setState(() {
      _allStudents = [
        {
          "studentId": "20210001",
          "name": "김완료",
          "building": "숭례원",
          "room": "101호",
          "status": "완료",
          "jumhoTime": "23:55:12",
          "isManual": false,
        },
        {
          "studentId": "20210002",
          "name": "이미완",
          "building": "숭례원",
          "room": "102호",
          "status": "미완료",
        },
        {
          "studentId": "20210003",
          "name": "박외박",
          "building": "양덕원",
          "room": "201호",
          "status": "외박",
          "out_start": "2025-06-28",
          "out_end": "2025-06-30",
          "reason": "본가 방문",
        },
        {
          "studentId": "20210004",
          "name": "최수동",
          "building": "양덕원",
          "room": "202호",
          "status": "완료",
          "jumhoTime": "23:58:01",
          "isManual": true,
        },
      ];
      _buildingStats = [
        {
          "building_name": "숭례원",
          "total": 2,
          "completed": 1,
          "pending": 1,
          "exempted": 0,
        },
        {
          "building_name": "양덕원",
          "total": 2,
          "completed": 1,
          "pending": 0,
          "exempted": 1,
        },
      ];
      _totalStudents = 4;
      _checkedStudents = 2;
      _uncheckedStudents = 1;
      _exemptedStudents = 1;
      _applyFilter();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('서버 연결에 실패하여 더미 데이터를 표시합니다.'),
            backgroundColor: AppColors.statusWarning,
          ),
        );
      }
    });
  }

  Future<void> _loadRollCallData() async {
    setState(() => _isLoading = true);
    try {
      // [수정] 건물 필터링 쿼리 다시 추가
      String url = '$apiBase/api/rollcall/status';
      if (_selectedBuilding != "전체") {
        url += '?building=$_selectedBuilding';
      }

      print('🔍 점호 API 호출: $url');
      final response = await http.get(Uri.parse(url));
      print('🔍 점호 API 응답 상태: ${response.statusCode}');
      print('🔍 점호 API 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔍 파싱된 데이터: $data');

        if (data['summary'] == null) throw Exception('점호 요약 정보가 없습니다.');

        setState(() {
          _totalStudents = data['summary']['total'] ?? 0;
          _checkedStudents = data['summary']['completed'] ?? 0;
          _uncheckedStudents = data['summary']['pending'] ?? 0;
          _exemptedStudents = data['summary']['exempted'] ?? 0;
          // [수정] 건물 통계 데이터 파싱
          _buildingStats = List<Map<String, dynamic>>.from(
            data['building_stats'] ?? [],
          );

          // 서버 데이터를 Flutter 형식으로 변환
          _allStudents = [
            ...List<Map<String, dynamic>>.from(
              data['completed_students']?.map(
                    (s) => _convertStudentData(s, "완료"),
                  ) ??
                  [],
            ),
            ...List<Map<String, dynamic>>.from(
              data['pending_students']?.map(
                    (s) => _convertStudentData(s, "미완료"),
                  ) ??
                  [],
            ),
            ...List<Map<String, dynamic>>.from(
              data['exempted_students']?.map(
                    (s) => _convertStudentData(s, "외박"),
                  ) ??
                  [],
            ),
          ];

          print('🔍 변환된 학생 데이터: $_allStudents');
          _applyFilter();
        });
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 점호 데이터 로드 실패: $e');
      _generateDummyData();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 서버 데이터를 Flutter 형식으로 변환하는 함수
  Map<String, dynamic> _convertStudentData(
    Map<String, dynamic> serverData,
    String status,
  ) {
    return {
      "studentId": serverData['student_id']?.toString() ?? '',
      "name": serverData['name']?.toString() ?? '',
      "building": serverData['dorm_building']?.toString() ?? '',
      "room": serverData['room_num']?.toString() ?? '',
      "status": status,
      "jumhoTime": serverData['rollcall_time']?.toString() ?? '',
      "isManual": serverData['rollcall_type'] == 'manual',
      "out_start": serverData['out_start']?.toString() ?? '',
      "out_end": serverData['out_end']?.toString() ?? '',
      "reason": serverData['reason']?.toString() ?? '',
    };
  }

  void _applyFilter() {
    setState(() {
      _filteredStudents =
          _allStudents.where((student) {
            final query = searchQuery.toLowerCase();
            final statusMatch =
                selectedFilter == "전체" ||
                (selectedFilter == "점호 완료" && student['status'] == "완료") ||
                (selectedFilter == "미완료" && student['status'] == "미완료") ||
                (selectedFilter == "외박" && student['status'] == "외박");
            final searchMatch =
                (student['name']?.toLowerCase() ?? '').contains(query) ||
                (student['studentId']?.toLowerCase() ?? '').contains(query) ||
                (student['room']?.toLowerCase() ?? '').contains(query);
            return statusMatch && searchMatch;
          }).toList();
      _selectedStudentIds.clear();
      _updateDataSource();
    });
  }

  void _onRowSelect(String studentId, bool selected) {
    setState(() {
      if (selected) {
        _selectedStudentIds.add(studentId);
      } else {
        _selectedStudentIds.remove(studentId);
      }
      _updateDataSource();
    });
  }

  void _onSelectAll(bool? selected) {
    setState(() {
      _selectedStudentIds.clear();
      if (selected == true) {
        for (var student in _filteredStudents) {
          _selectedStudentIds.add(student['studentId']);
        }
      }
      _updateDataSource();
    });
  }

  Future<void> _showRollCallSettingsDialog() async {
    final settings = await _loadCurrentSettings();
    TimeOfDay startTime = TimeOfDay.fromDateTime(
      DateFormat.Hms().parse(settings['rollcall_start_time']!),
    );
    TimeOfDay endTime = TimeOfDay.fromDateTime(
      DateFormat.Hms().parse(settings['rollcall_end_time']!),
    );
    bool isAutoEnabled = settings['auto_rollcall_enabled'] == 'true';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              title: Text(
                '점호 설정',
                style: headingStyle(18, FontWeight.bold, AppColors.fontPrimary),
              ),
              content: SizedBox(
                width: 350.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '자동 점호 활성화',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: AppColors.fontPrimary,
                          ),
                        ),
                        // [수정] 스위치 크기 조절
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: isAutoEnabled,
                            onChanged:
                                (value) =>
                                    setDialogState(() => isAutoEnabled = value),
                            activeColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: startTime.format(context),
                      ),
                      // [수정] 필드 크기 조절
                      decoration: InputDecoration(
                        labelText: '점호 시작 시간',
                        suffixIcon: const Icon(
                          Icons.access_time,
                          color: AppColors.fontSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10.h,
                          horizontal: 12.w,
                        ),
                      ),
                      onTap: () async {
                        final newTime = await showDialog<TimeOfDay>(
                          context: context,
                          builder: (BuildContext context) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: Colors.white,
                                  dialBackgroundColor: Colors.white,
                                  dialHandColor: AppColors.primary,
                                  hourMinuteColor: AppColors.primary
                                      .withOpacity(0.1),
                                  hourMinuteTextColor: AppColors.fontPrimary,
                                  dayPeriodColor: AppColors.primary.withOpacity(
                                    0.2,
                                  ),
                                  dayPeriodTextColor: AppColors.fontPrimary,
                                  entryModeIconColor: AppColors.primary,
                                ),
                              ),
                              child: TimePickerDialog(initialTime: startTime),
                            );
                          },
                        );
                        if (newTime != null)
                          setDialogState(() => startTime = newTime);
                      },
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: endTime.format(context),
                      ),
                      // [수정] 필드 크기 조절
                      decoration: InputDecoration(
                        labelText: '점호 종료 시간',
                        suffixIcon: const Icon(
                          Icons.access_time,
                          color: AppColors.fontSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10.h,
                          horizontal: 12.w,
                        ),
                      ),
                      onTap: () async {
                        final newTime = await showDialog<TimeOfDay>(
                          context: context,
                          builder: (BuildContext context) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                timePickerTheme: TimePickerThemeData(
                                  backgroundColor: Colors.white,
                                  dialBackgroundColor: Colors.white,
                                  dialHandColor: AppColors.primary,
                                  hourMinuteColor: AppColors.primary
                                      .withOpacity(0.1),
                                  hourMinuteTextColor: AppColors.fontPrimary,
                                  dayPeriodColor: AppColors.primary.withOpacity(
                                    0.2,
                                  ),
                                  dayPeriodTextColor: AppColors.fontPrimary,
                                  entryModeIconColor: AppColors.primary,
                                ),
                              ),
                              child: TimePickerDialog(initialTime: endTime),
                            );
                          },
                        );
                        if (newTime != null)
                          setDialogState(() => endTime = newTime);
                      },
                    ),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  onPressed: () async {
                    final newSettings = {
                      'rollcall_start_time':
                          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00',
                      'rollcall_end_time':
                          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00',
                      'auto_rollcall_enabled': isAutoEnabled.toString(),
                    };
                    bool success = await _saveRollCallSettings(newSettings);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success ? '설정이 저장되었습니다.' : '저장에 실패했습니다.',
                          ),
                          backgroundColor:
                              success
                                  ? AppColors.statusSuccess
                                  : AppColors.statusError,
                        ),
                      );
                    }
                  },
                  child: const Text('저장'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>> _loadCurrentSettings() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/rollcall/settings'),
      );
      if (response.statusCode == 200)
        return Map<String, String>.from(json.decode(response.body));
    } catch (e) {
      /* Fail silently */
    }
    return {
      'rollcall_start_time': '23:50:00',
      'rollcall_end_time': '00:10:00',
      'auto_rollcall_enabled': 'true',
    };
  }

  Future<bool> _saveRollCallSettings(Map<String, String> settings) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBase/api/rollcall/settings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(settings),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _showManualJumhoDialog(Map<String, dynamic> student) async {
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          title: Text(
            '수동 점호 처리',
            style: headingStyle(18, FontWeight.bold, AppColors.fontPrimary),
          ),
          content: SizedBox(
            width: 350.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학생 정보',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.fontPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.disabledBackground,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '학번: ${student['studentId']}',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '이름: ${student['name']}',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '호실: ${student['building']} ${student['room']}',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  '점호 처리 시간: $timeString',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.statusSuccess,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '해당 학생의 점호를 수동으로 처리하시겠습니까?',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.fontSecondary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '취소',
                style: TextStyle(color: AppColors.fontSecondary),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () async {
                bool success = await _processManualRollCall(
                  student['studentId'],
                  timeString,
                );
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? '점호 처리가 완료되었습니다.' : '점호 처리에 실패했습니다.',
                      ),
                      backgroundColor:
                          success
                              ? AppColors.statusSuccess
                              : AppColors.statusError,
                    ),
                  );
                  if (success) {
                    _loadRollCallData(); // 데이터 새로고침
                  }
                }
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _processManualRollCall(
    String studentId,
    String rollCallTime,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBase/api/rollcall/manual'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': studentId,
          'rollcall_time': rollCallTime,
          'type': 'manual',
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('❌ 수동 점호 처리 실패: $e');
      return false;
    }
  }

  void _showOutingDetails(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          title: Text(
            '외박 상세 정보',
            style: headingStyle(18, FontWeight.bold, AppColors.fontPrimary),
          ),
          content: SizedBox(
            width: 350.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '학번: ${student['studentId']}',
                  style: TextStyle(fontSize: 14.sp),
                ),
                SizedBox(height: 8.h),
                Text(
                  '이름: ${student['name']}',
                  style: TextStyle(fontSize: 14.sp),
                ),
                SizedBox(height: 8.h),
                Text(
                  '외박 시작: ${student['out_start'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 14.sp),
                ),
                SizedBox(height: 8.h),
                Text(
                  '외박 종료: ${student['out_end'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 14.sp),
                ),
                SizedBox(height: 8.h),
                Text(
                  '외박 사유: ${student['reason'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                '닫기',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
              : Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 16.h),
                    _buildSummaryCards(),
                    SizedBox(height: 16.h),
                    _buildFilterBar(),
                    SizedBox(height: 8.h),
                    Expanded(child: _buildDataGrid()),
                    _buildBulkActionRow(),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '점호 관리',
          style: headingStyle(22, FontWeight.bold, AppColors.fontPrimary),
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _loadRollCallData,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardBackground,
                foregroundColor: AppColors.primary,
                elevation: 0,
                side: const BorderSide(color: AppColors.border),
                textStyle: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            IconButton(
              onPressed: _showRollCallSettingsDialog,
              icon: Icon(
                Icons.settings_rounded,
                color: AppColors.fontSecondary,
                size: 22.sp,
              ),
              tooltip: "점호 시간 설정",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    Widget card({
      required IconData icon,
      required Color color,
      required String title,
      required String value,
      required bool selected,
      VoidCallback? onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: 12.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: _cardRadius,
              boxShadow: _cardShadow,
              border: Border.all(
                color: selected ? color : AppColors.border,
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: color.withOpacity(0.1),
                  child: Icon(icon, color: color, size: 22.r),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.fontSecondary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        value,
                        style: TextStyle(
                          color: AppColors.fontPrimary,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        card(
          icon: Icons.groups_rounded,
          color: AppColors.primary,
          title: "전체 학생",
          value: "$_totalStudents 명",
          selected: selectedFilter == "전체",
          onTap:
              () => setState(() {
                selectedFilter = "전체";
                _applyFilter();
              }),
        ),
        card(
          icon: Icons.check_circle_rounded,
          color: AppColors.statusSuccess,
          title: "점호 완료",
          value: "$_checkedStudents 명",
          selected: selectedFilter == "점호 완료",
          onTap:
              () => setState(() {
                selectedFilter = "점호 완료";
                _applyFilter();
              }),
        ),
        card(
          icon: Icons.cancel_rounded,
          color: AppColors.statusError,
          title: "미완료",
          value: "$_uncheckedStudents 명",
          selected: selectedFilter == "미완료",
          onTap:
              () => setState(() {
                selectedFilter = "미완료";
                _applyFilter();
              }),
        ),
        card(
          icon: Icons.flight_takeoff_rounded,
          color: AppColors.statusWarning,
          title: "외박",
          value: "$_exemptedStudents 명",
          selected: selectedFilter == "외박",
          onTap:
              () => setState(() {
                selectedFilter = "외박";
                _applyFilter();
              }),
        ),
      ],
    );
  }

  // [수정] 건물 필터 추가
  Widget _buildFilterBar() {
    return Row(
      children: [
        _buildBuildingFilter(),
        const Spacer(),
        SizedBox(width: 250.w, height: 40.h, child: _searchField()),
      ],
    );
  }

  // [추가] 건물 필터 드롭다운 위젯
  Widget _buildBuildingFilter() {
    return SizedBox(
      width: 150.w,
      height: 40.h,
      child: DropdownButtonFormField2<String>(
        isExpanded: true,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            vertical: 10.h,
            horizontal: 12.w,
          ),
          filled: true,
          fillColor: AppColors.cardBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
        value: _selectedBuilding,
        items:
            ['전체', '숭례원', '양덕원']
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
            setState(() {
              _selectedBuilding = value;
              _loadRollCallData();
            });
          }
        },
        dropdownStyleData: DropdownStyleData(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            color: AppColors.cardBackground, // 펼쳤을 때 배경색 흰색
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      style: TextStyle(fontSize: 14.sp),
      decoration: InputDecoration(
        hintText: '학번/이름 검색',
        hintStyle: TextStyle(
          fontSize: 14.sp,
          color: AppColors.fontSecondary.withOpacity(0.8),
        ),
        prefixIcon: const Icon(
          Icons.search,
          size: 20,
          color: AppColors.fontSecondary,
        ),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
      ),
    );
  }

  Widget _buildDataGrid() {
    final bool isAllSelected =
        _filteredStudents.isNotEmpty &&
        _selectedStudentIds.length == _filteredStudents.length;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(8.r),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: AppColors.cardBackground,
      child: SfDataGridTheme(
        data: SfDataGridThemeData(
          headerColor: AppColors.disabledBackground,
          gridLineColor: AppColors.border,
          rowHoverColor: AppColors.primaryLight.withOpacity(0.5),
        ),
        child: SfDataGrid(
          source: _jumhoDataSource!,
          headerRowHeight: 48.h,
          rowHeight: 52.h,
          gridLinesVisibility: GridLinesVisibility.horizontal,
          headerGridLinesVisibility: GridLinesVisibility.horizontal,
          onCellTap: (details) {
            if (details.rowColumnIndex.rowIndex > 0) {
              final student =
                  _filteredStudents[details.rowColumnIndex.rowIndex - 1];
              _onRowSelect(
                student['studentId'],
                !_selectedStudentIds.contains(student['studentId']),
              );
            }
          },
          columns: [
            GridColumn(
              columnName: 'select',
              width: 60.w,
              label: Center(
                child: Transform.scale(
                  scale: 0.8,
                  child: Checkbox(
                    value: isAllSelected,
                    onChanged: _onSelectAll,
                    activeColor: AppColors.primary,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'no',
              width: 70.w,
              label: Center(child: Text('No.', style: tableHeaderStyle)),
            ),
            GridColumn(
              columnName: 'studentId',
              columnWidthMode: ColumnWidthMode.fill,
              minimumWidth: 100.w,
              label: Center(child: Text('학번', style: tableHeaderStyle)),
            ),
            GridColumn(
              columnName: 'name',
              columnWidthMode: ColumnWidthMode.fill,
              minimumWidth: 80.w,
              label: Center(child: Text('이름', style: tableHeaderStyle)),
            ),
            GridColumn(
              columnName: 'building',
              columnWidthMode: ColumnWidthMode.fill,
              minimumWidth: 80.w,
              label: Center(child: Text('건물', style: tableHeaderStyle)),
            ),
            GridColumn(
              columnName: 'room',
              columnWidthMode: ColumnWidthMode.fill,
              minimumWidth: 70.w,
              label: Center(child: Text('호실', style: tableHeaderStyle)),
            ),
            GridColumn(
              columnName: 'rollcall_time',
              columnWidthMode: ColumnWidthMode.fill,
              minimumWidth: 120.w,
              label: Center(child: Text('점호처리', style: tableHeaderStyle)),
            ),
            GridColumn(
              columnName: 'status',
              columnWidthMode: ColumnWidthMode.fill,
              minimumWidth: 90.w,
              label: Center(child: Text('상태', style: tableHeaderStyle)),
            ),
            GridColumn(
              columnName: 'management',
              columnWidthMode: ColumnWidthMode.fill,
              minimumWidth: 100.w,
              label: Center(child: Text('관리', style: tableHeaderStyle)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionRow() {
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Row(
        children: [
          Text(
            '총 ${_filteredStudents.length}건 | 선택: ${_selectedStudentIds.length}건',
            style: TextStyle(fontSize: 14.sp, color: AppColors.fontSecondary),
          ),
          const Spacer(),
          SizedBox(
            width: 150.w,
            child: DropdownButtonFormField2<String>(
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 10.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              hint: Text('일괄 처리', style: TextStyle(fontSize: 13.sp)),
              value: _bulkAction == '일괄 처리' ? null : _bulkAction,
              items:
                  ['일괄 처리', '수동 점호']
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: TextStyle(fontSize: 13.sp)),
                        ),
                      )
                      .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _bulkAction = val);
              },
              buttonStyleData: ButtonStyleData(height: 40.h),
              dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  color: AppColors.cardBackground,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed: () {
              /* 일괄 처리 로직 (미구현) */
            },
            child: Text(
              '적용',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class JumhoDataSource extends DataGridSource {
  final List<Map<String, dynamic>> students;
  final Function(Map<String, dynamic>) onManualJumho;
  final Function(Map<String, dynamic>) onShowOutingDetails;
  final Set<String> selectedStudentIds;
  final void Function(String, bool) onRowSelect;
  late List<DataGridRow> _dataGridRows;

  JumhoDataSource({
    required this.students,
    required this.onManualJumho,
    required this.onShowOutingDetails,
    required this.selectedStudentIds,
    required this.onRowSelect,
  }) {
    _buildDataGridRows();
  }

  void _buildDataGridRows() {
    _dataGridRows =
        students.asMap().entries.map<DataGridRow>((entry) {
          int index = entry.key;
          Map<String, dynamic> student = entry.value;
          return DataGridRow(
            cells: [
              DataGridCell<Map<String, dynamic>>(
                columnName: 'select',
                value: student,
              ),
              DataGridCell<int>(columnName: 'no', value: index + 1),
              DataGridCell<String>(
                columnName: 'studentId',
                value: student['studentId'],
              ),
              DataGridCell<String>(columnName: 'name', value: student['name']),
              DataGridCell<String>(
                columnName: 'building',
                value: student['building'],
              ),
              DataGridCell<String>(columnName: 'room', value: student['room']),
              DataGridCell<Map<String, dynamic>>(
                columnName: 'rollcall_time',
                value: student,
              ),
              DataGridCell<String>(
                columnName: 'status',
                value: student['status'],
              ),
              DataGridCell<Map<String, dynamic>>(
                columnName: 'management',
                value: student,
              ),
            ],
          );
        }).toList();
  }

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final studentData = row.getCells()[0].value as Map<String, dynamic>;
    final studentId = studentData['studentId'];
    final bool isSelected = selectedStudentIds.contains(studentId);

    return DataGridRowAdapter(
      color:
          isSelected
              ? AppColors.primaryLight.withOpacity(0.5)
              : Colors.transparent,
      cells: [
        Center(
          child: Transform.scale(
            scale: 0.8,
            child: Checkbox(
              value: isSelected,
              onChanged: (val) => onRowSelect(studentId, val ?? false),
              activeColor: AppColors.primary,
            ),
          ),
        ),
        _buildCell(row.getCells()[1].value.toString()),
        _buildCell(row.getCells()[2].value),
        _buildCell(row.getCells()[3].value),
        _buildCell(row.getCells()[4].value),
        _buildCell(row.getCells()[5].value),
        _buildRollcallTimeCell(row.getCells()[6].value),
        _buildStatusChip(row.getCells()[7].value),
        _buildManagementCell(row.getCells()[8].value),
      ],
    );
  }

  Widget _buildCell(String text) => Container(
    alignment: Alignment.center,
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: Text(text, overflow: TextOverflow.ellipsis, style: tableCellStyle),
  );

  Widget _buildRollcallTimeCell(Map<String, dynamic> student) {
    final status = student['status'];
    final isManual = student['isManual'] ?? false;
    final jumhoTime = student['jumhoTime'];

    if (status == '완료' && jumhoTime != null && jumhoTime.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              jumhoTime,
              style: tableCellStyle.copyWith(
                fontSize: 12.sp,
                color:
                    isManual ? AppColors.statusWarning : AppColors.fontPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isManual)
              Text(
                "(수동)",
                style: tableCellStyle.copyWith(
                  fontSize: 10.sp,
                  color: AppColors.statusWarning,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      );
    }

    // 미완료나 외박 상태일 때는 빈 칸
    return Center(
      child: Text(
        "-",
        style: tableCellStyle.copyWith(
          fontSize: 12.sp,
          color: AppColors.fontSecondary,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case '완료':
        color = AppColors.statusSuccess;
        break;
      case '미완료':
        color = AppColors.statusError;
        break;
      case '외박':
        color = AppColors.statusWarning;
        break;
      default:
        color = AppColors.fontSecondary;
    }
    return Center(
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12.sp,
        ),
      ),
    );
  }

  Widget _buildManagementCell(Map<String, dynamic> student) {
    final status = student['status'];

    if (status == '미완료') {
      return Center(
        child: IconButton(
          onPressed: () => onManualJumho(student),
          icon: Icon(Icons.edit, color: AppColors.primary, size: 18.w),
          tooltip: '수동 점호 처리',
          splashRadius: 18,
        ),
      );
    } else if (status == '외박') {
      return Center(
        child: TextButton(
          onPressed: () => onShowOutingDetails(student),
          child: Text(
            '상세보기',
            style: tableCellStyle.copyWith(
              fontSize: 11.sp,
              color: AppColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    }

    // 완료 상태일 때는 빈 칸
    return Container();
  }
}
