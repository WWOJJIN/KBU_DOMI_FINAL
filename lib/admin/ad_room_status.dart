// 파일명: ad_room_status_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kbu_domi/admin/ad_home.dart'; // adHomePageKey 사용을 위해 ad_home import
import 'application_data_service.dart';
import 'package:http/http.dart' as http; // HTTP 통신을 위한 패키지 추가
import 'dart:convert'; // JSON 인코딩/디코딩을 위한 패키지 추가
import 'dart:developer'; // 로그를 위한 패키지 추가

// --- 디자인에 사용될 색상 정의 ---
class AppColors {
  static const Color primary = Color(0xFF0D47A1);
  static const Color fontPrimary = Color(0xFF333333);
  static const Color fontSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color statusAssigned = Color(0xFF42A5F5);
  static const Color statusUnassigned = Color(0xFF757575);
  static const Color statusRejected = Color(0xFFEF5350);
  static const Color genderFemale = Color(0xFFEC407A);
  static const Color activeBorder = Color(0xFF0D47A1);
  static const Color disabledBackground = Color(0xFFF5F5F5);
  static const Color statusWaiting = Color(0xFFFFA726);
  static const Color statusConfirmed = Color(0xFF66BB6A);
}

class AdRoomStatusPage extends StatefulWidget {
  const AdRoomStatusPage({super.key});

  @override
  State<AdRoomStatusPage> createState() => _AdRoomStatusPageState();
}

class _AdRoomStatusPageState extends State<AdRoomStatusPage> {
  int _selectedIndex = -1;
  int _hoveredIndex = -1;
  String _searchText = '';
  String _currentRightPanelTab = '학생 조회';
  bool _isEditMode = false;
  bool _isLoading = true;

  final Map<String, Set<String>> _selectedFilters = {
    '기숙사': {'전체'},
  };
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _adminMemoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAndInitializeData();
  }

  void _loadAndInitializeData() async {
    setState(() => _isLoading = true);

    try {
      // 실제 API에서 데이터 로드
      await ApplicationDataService.initializeData();

      if (!mounted) return;

      // 방 점유율 계산
      ApplicationDataService.updateRoomOccupancy();
      _updateSelection();
    } catch (e) {
      log('데이터 로드 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 로드에 실패했습니다: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredApplications {
    return ApplicationDataService.applications.where((app) {
      bool dormitoryMatch =
          _selectedFilters['기숙사']!.contains('전체') ||
          _selectedFilters['기숙사']!.contains(app['dormBuilding']);
      final bool searchMatch =
          _searchText.isEmpty ||
          app['studentId'].toString().contains(_searchText) ||
          app['studentName'].toString().contains(_searchText);
      return dormitoryMatch && searchMatch;
    }).toList();
  }

  // 룸메이트 조회 리스트에 표시될 항목을 필터링하는 함수
  List<Map<String, dynamic>> _getOnlyRoommatePairs() {
    final filtered = _filteredApplications;
    // pairId가 있고, roommateType이 'mutual'인 경우만 룸메이트 목록에 표시
    final roommateApplicants =
        filtered
            .where(
              (app) => app['pairId'] != null && app['roommateType'] == 'mutual',
            )
            .toList();
    final Map<String, List<Map<String, dynamic>>> pairsById = {};

    for (var app in roommateApplicants) {
      final pairId = app['pairId'];
      if (pairId != null) {
        pairsById.putIfAbsent(pairId, () => []).add(app);
      }
    }

    final List<Map<String, dynamic>> result = [];
    pairsById.forEach((pairId, pairList) {
      if (pairList.length == 2) {
        result.add({
          'isPair': true,
          'student1': pairList[0],
          'student2': pairList[1],
        });
      }
    });

    return result;
  }

  void _updateSelection() {
    final listItems =
        _currentRightPanelTab == '룸메이트 조회'
            ? _getOnlyRoommatePairs()
            : _filteredApplications;
    if (listItems.isNotEmpty) {
      if (_selectedIndex >= listItems.length || _selectedIndex == -1) {
        _selectedIndex = 0;
      }
      final selectedItem = listItems[_selectedIndex];
      final isPair = selectedItem['isPair'] ?? false;
      final student =
          isPair
              ? selectedItem['student1']
              : (selectedItem['student'] ?? selectedItem);
      _adminMemoController.text = student['adminMemo'] ?? '';
      _isEditMode = false;
    } else {
      _selectedIndex = -1;
      _adminMemoController.text = '';
      _isEditMode = false;
    }
    if (mounted) setState(() {});
  }

  void _handleStudentTap(int index) {
    setState(() {
      _selectedIndex = index;
      _updateSelection();
    });
  }

  void _cancelRoommatePairing(
    Map<String, dynamic> student1,
    Map<String, dynamic> student2,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            title: Text(
              '룸메이트 관계 해지', // 타이틀 변경
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
                color: AppColors.fontPrimary,
              ),
            ),
            content: SizedBox(
              width: 380.w,
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: AppColors.fontSecondary,
                    fontSize: 16.sp,
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(
                      text: '${student1['studentName']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.fontPrimary,
                      ),
                    ),
                    const TextSpan(text: ' 학생과 '),
                    TextSpan(
                      text: '${student2['studentName']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.fontPrimary,
                      ),
                    ),
                    const TextSpan(
                      text: ' 학생의 룸메이트 관계를 해지 하시겠습니까?\n',
                    ), // 텍스트 변경
                    const TextSpan(
                      text: '관계 해지된 학생들은 일반 배정 대상으로 변경되며, 배정된 방도 취소됩니다.',
                    ),
                  ],
                ),
                textAlign: TextAlign.start,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  '취소',
                  style: TextStyle(color: AppColors.fontSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  // 관계 해지 API 연동
                  try {
                    // API 호출
                    final response = await http.post(
                      Uri.parse('http://localhost:5050/api/roommate/terminate'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'student_id': student1['studentId'],
                        'partner_id': student2['studentId'],
                        'reason': '관리자 해지',
                      }),
                    );
                    final result = jsonDecode(response.body);
                    if (response.statusCode == 200 &&
                        result['message'] != null) {
                      // 성공 안내
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('룸메이트 관계가 해지되었습니다.')),
                      );
                      // 목록 새로고침
                      setState(() => _loadAndInitializeData());
                    } else {
                      // 실패 안내
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '해지 실패: \\${result['error'] ?? '알 수 없음'}',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    // 에러 처리 및 로그
                    log('Error occurred: $e');
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
                  }
                  Navigator.of(ctx).pop(); // 팝업 닫기
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusRejected,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text('해지'), // 버튼 텍스트 변경
              ),
            ],
          ),
    );
  }

  void _cancelAssignmentForPair(
    Map<String, dynamic> student1,
    Map<String, dynamic> student2,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: Colors.white, // 배경색 흰색으로 통일
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            title: Text(
              '방 배정 취소', // 타이틀 변경
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
                color: AppColors.fontPrimary,
              ),
            ),
            content: SizedBox(
              // Sizedbox 추가
              width: 380.w, // Sizedbox width 추가
              child: Text.rich(
                // Text.rich로 변경
                TextSpan(
                  style: TextStyle(
                    // 스타일 추가
                    color: AppColors.fontSecondary,
                    fontSize: 16.sp,
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(
                      text: '${student1['studentName']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.fontPrimary,
                      ),
                    ),
                    const TextSpan(text: ' 학생과 '),
                    TextSpan(
                      text: '${student2['studentName']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.fontPrimary,
                      ),
                    ),
                    const TextSpan(text: ' 학생의 방 배정을 취소하시겠습니까?'),
                  ],
                ),
                textAlign: TextAlign.start,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  '취소', // 텍스트 변경
                  style: TextStyle(color: AppColors.fontSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // 데이터 서비스에서 두 학생의 assignedBuilding, assignedRoomNumber 초기화 및 status '확인'으로 변경
                  var app1 = ApplicationDataService.applications.firstWhere(
                    (app) => app['id'] == student1['id'],
                  );
                  var app2 = ApplicationDataService.applications.firstWhere(
                    (app) => app['id'] == student2['id'],
                  );

                  for (var student in [app1, app2]) {
                    student['assignedBuilding'] = null;
                    student['assignedRoomNumber'] = null;
                    student['status'] = '확인';
                  }

                  Navigator.of(ctx).pop(); // 팝업 닫기
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('방 배정이 취소되었습니다.')),
                  );

                  // UI를 새로고침하여 변경된 상태를 반영 (룸메이트 관계는 유지되므로 목록에는 남아 있음)
                  setState(() {
                    _loadAndInitializeData();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusRejected, // 빨간색 버튼
                  foregroundColor: Colors.white, // 흰색 글씨
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text('해지'), // 텍스트 변경
              ),
            ],
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
              : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildLeftPanel()),
                        VerticalDivider(width: 1.w, color: AppColors.border),
                        Expanded(flex: 5, child: _buildRightPanel()),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            '학생 관리',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.fontPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    final listItems =
        _currentRightPanelTab == '룸메이트 조회'
            ? _getOnlyRoommatePairs()
            : _filteredApplications;
    final filterOptions = {
      '기숙사': ['전체', '양덕원', '숭례원'],
    };

    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "기숙사 필터",
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.fontPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children:
                      filterOptions['기숙사']!.map((option) {
                        final isSelected = _selectedFilters['기숙사']!.contains(
                          option,
                        );
                        return ChoiceChip(
                          label: Text(
                            option,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color:
                                  isSelected
                                      ? const Color.fromRGBO(68, 138, 255, 1)
                                      : AppColors.fontSecondary,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFilters['기숙사'] = {option};
                              _updateSelection();
                            });
                          },
                          selectedColor: const Color.fromRGBO(
                            68,
                            138,
                            255,
                            0.15,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? const Color.fromRGBO(68, 138, 255, 1)
                                      : AppColors.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  height: 40.h,
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged:
                        (value) => setState(() {
                          _searchText = value;
                          _updateSelection();
                        }),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20.sp,
                        color: AppColors.fontSecondary,
                      ),
                      hintText: '이름 또는 학번으로 검색',
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.fontSecondary.withOpacity(0.7),
                      ),
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
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: EdgeInsets.only(left: 14.w),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                '${listItems.length}개 항목',
                style: TextStyle(
                  fontSize: 15.sp,
                  color: AppColors.fontSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView.builder(
              itemCount: listItems.length,
              itemBuilder: (context, index) {
                final item = listItems[index];
                final isPair = item['isPair'] ?? false;
                if (isPair) {
                  return _buildPairedApplicationListItem(item, index);
                } else {
                  return _buildApplicationListItem(item, index);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusWidget(Map<String, dynamic> app) {
    if (app['assignedBuilding'] != null && app['assignedRoomNumber'] != null) {
      return Text(
        '${app['assignedBuilding']} ${app['assignedRoomNumber']}',
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.statusAssigned,
        ),
      );
    }
    return Text(
      '미배정',
      style: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.statusUnassigned,
      ),
    );
  }

  Widget _buildApplicationListItem(Map<String, dynamic> app, int index) {
    final bool isSelected = _selectedIndex == index;
    final bool isHovered = _hoveredIndex == index;
    return MouseRegion(
      onEnter: (event) => setState(() => _hoveredIndex = index),
      onExit: (event) => setState(() => _hoveredIndex = -1),
      child: GestureDetector(
        onTap: () => _handleStudentTap(index),
        child: Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isHovered ? Colors.grey.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected ? AppColors.activeBorder : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${app['studentName']}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.fontPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _buildStatusWidget(app),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                (app['assignedRoomNumber'] != null)
                    ? '${app['studentId']} | ${app['gender']} | ${app['department']}'
                    : '${app['studentId']} | ${app['gender']} | ${app['department']} | ${app['roomType']} | ${app['smokingStatus']}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.fontSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPairedApplicationListItem(
    Map<String, dynamic> pairData,
    int index,
  ) {
    final bool isSelected = _selectedIndex == index;
    final bool isHovered = _hoveredIndex == index;
    final Map<String, dynamic> student1 = pairData['student1'];
    final Map<String, dynamic> student2 = pairData['student2'];
    final bool isMutual = student1['roommateType'] == 'mutual'; // 룸메이트 타입 확인
    final String assignedRoom =
        student1['assignedRoomNumber'] != null
            ? '${student1['assignedBuilding']} ${student1['assignedRoomNumber']}'
            : '미배정';

    return MouseRegion(
      onEnter: (event) => setState(() => _hoveredIndex = index),
      onExit: (event) => setState(() => _hoveredIndex = -1),
      child: GestureDetector(
        onTap: () => _handleStudentTap(index),
        child: Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isHovered ? Colors.grey.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected ? AppColors.activeBorder : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMutual ? '룸메이트*' : '룸메이트', // 룸메이트* 또는 룸메이트 표시
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fontPrimary,
                    ),
                  ),
                  Text(
                    assignedRoom,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color:
                          assignedRoom == '미배정'
                              ? AppColors.statusUnassigned
                              : AppColors.statusAssigned,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${student1['studentName']}',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text:
                                '\n${student1['studentId']} | ${student1['department']}',
                            style: TextStyle(fontSize: 13.sp),
                          ),
                          TextSpan(
                            text:
                                '\n${student1['gender']} | ${student1['smokingStatus']}',
                            style: TextStyle(fontSize: 13.sp),
                          ),
                        ],
                      ),
                      style: TextStyle(color: AppColors.fontPrimary),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${student2['studentName']}',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text:
                                '\n${student2['studentId']} | ${student2['department']}',
                            style: TextStyle(fontSize: 13.sp),
                          ),
                          TextSpan(
                            text:
                                '\n${student2['gender']} | ${student2['smokingStatus']}',
                            style: TextStyle(fontSize: 13.sp),
                          ),
                        ],
                      ),
                      style: TextStyle(color: AppColors.fontPrimary),
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

  Widget _buildStudentInfoLine(Map<String, dynamic> student) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          student['studentName'],
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.fontPrimary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '${student['studentId']} | ${student['gender']} | ${student['department']} | ${student['smokingStatus']}',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13.sp, color: AppColors.fontSecondary),
        ),
      ],
    );
  }

  Widget _buildRightPanel() {
    final listItems =
        _currentRightPanelTab == '룸메이트 조회'
            ? _getOnlyRoommatePairs()
            : _filteredApplications;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 24.w),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1.h),
            ),
          ),
          child: Row(
            children: [
              _buildRightPanelTabButton('학생 조회'),
              SizedBox(width: 20.w),
              _buildRightPanelTabButton('룸메이트 조회'),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child:
                listItems.isEmpty ||
                        _selectedIndex < 0 ||
                        _selectedIndex >= listItems.length
                    ? Center(
                      child: Text(
                        '왼쪽에서 조회할 항목을 선택해주세요.',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.fontSecondary,
                        ),
                      ),
                    )
                    : _buildStudentDetails(),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanelTabButton(String tabName) {
    final bool isSelected = _currentRightPanelTab == tabName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentRightPanelTab = tabName;
          _searchText = '';
          _searchController.clear();
          _selectedFilters['기숙사'] = {'전체'};
          // 탭 전환 시 _selectedIndex 초기화
          _selectedIndex = -1; // 탭 전환 시 선택 항목 초기화
          _updateSelection(); // 이 함수는 초기화된 _selectedIndex를 반영하여 다시 선택 로직을 실행함
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tabName,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.primary : AppColors.fontSecondary,
            ),
          ),
          SizedBox(height: 6.h),
          if (isSelected)
            Container(width: 40.w, height: 3.h, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildStudentDetails() {
    final listItems =
        _currentRightPanelTab == '룸메이트 조회'
            ? _getOnlyRoommatePairs()
            : _filteredApplications;
    final selectedItem = listItems[_selectedIndex];
    final isPair = selectedItem['isPair'] ?? false;
    if (isPair) {
      return _buildPairedStudentDetails(
        selectedItem['student1'],
        selectedItem['student2'],
      );
    } else {
      return _buildSingleStudentDetails(selectedItem);
    }
  }

  Widget _buildSingleStudentDetails(Map<String, dynamic> student) {
    final bool isKoreanNational =
        student['nationality'] == '대한민국' && student['applicant_type'] == '내국인';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '학생 정보',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.fontPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Divider(color: AppColors.border, thickness: 1.h),
            ],
          ),
        ),
        // 정보 필드 컨테이너와 라벨 위에 올라오는 필드 함수 호출
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '모집구분',
              student['recruitmentType'] ?? 'N/A',
              isGreyed: true,
            ),
            _buildInfoFieldWithLabelAbove(
              '학년도',
              student['academicYear'] ?? 'N/A',
              isGreyed: true,
            ),
            _buildInfoFieldWithLabelAbove(
              '학기',
              student['semester'] ?? 'N/A',
              isGreyed: true,
            ),
            _buildInfoFieldWithLabelAbove(
              '지원생구분',
              student['applicant_type'] ?? 'N/A',
              isGreyed: true,
            ),
          ],
        ),
        SizedBox(height: 16.h),
        _buildSectionTitle('기본 정보'),
        SizedBox(height: 8.h),
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '성명',
              student['studentName'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove('학번', student['studentId'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove('학과', student['department'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove('학년', student['grade'] ?? 'N/A'),
          ],
        ),
        SizedBox(height: 8.h),
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '생년월일',
              student['birth_date'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove('성별', student['gender'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove(
              '국적',
              student['nationality'] ?? 'N/A',
            ),
            if (!isKoreanNational)
              _buildInfoFieldWithLabelAbove(
                '여권번호',
                student['passport_num'] ?? 'N/A',
              )
            else
              const SizedBox.shrink(),
          ],
        ),
        SizedBox(height: 8.h),
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '흡연여부',
              student['smokingStatus'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '국민기초생활수급자',
              (student['basic_living_support'] == true) ? '예' : '아니오',
            ),
            _buildInfoFieldWithLabelAbove(
              '장애학생 여부',
              (student['disabled'] == true) ? '예' : '아니오',
            ),
            const SizedBox.shrink(),
          ],
        ),
        SizedBox(height: 24.h),
        _buildSectionTitle('주소 정보'),
        SizedBox(height: 8.h),
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '우편번호',
              student['postal_code'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '기본주소',
              student['address_basic'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '상세주소',
              student['address_detail'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '지역구분',
              student['region_type'] ?? 'N/A',
            ),
          ],
        ),
        SizedBox(height: 8.h),
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove('집전화', student['tel_home'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove(
              '핸드폰',
              student['tel_mobile'] ?? 'N/A',
            ),
            const SizedBox.shrink(),
            const SizedBox.shrink(),
          ],
        ),
        SizedBox(height: 24.h),
        _buildSectionTitle('보호자 정보'),
        SizedBox(height: 8.h),
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '보호자 성명',
              student['guardian_name'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '보호자 관계',
              student['guardian_relation'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '보호자 전화번호',
              student['guardian_phone'] ?? 'N/A',
            ),
            const SizedBox.shrink(),
          ],
        ),
        SizedBox(height: 24.h),
        _buildSectionTitle('기숙사 및 환불 정보'),
        SizedBox(height: 8.h),
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '건물',
              student['dormBuilding'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove('방타입', student['roomType'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove(
              '배정 호실',
              student['assignedRoomNumber'] ?? '미배정',
            ),
            const SizedBox.shrink(),
          ],
        ),
        SizedBox(height: 8.h),
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove('은행', student['bank'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove(
              '계좌번호',
              student['account_num'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '예금주명',
              student['account_holder'] ?? 'N/A',
            ),
            const SizedBox.shrink(),
          ],
        ),
        SizedBox(height: 24.h),
        _buildSectionTitle('제출 서류'),
        SizedBox(height: 8.h),
        _buildDocumentList(student),
        SizedBox(height: 24.h),
        _buildMemoSection(student),
      ],
    );
  }

  Widget _buildPairedStudentDetails(
    Map<String, dynamic> student1,
    Map<String, dynamic> student2,
  ) {
    final bool isAssigned = student1['assignedRoomNumber'] != null;
    final bool isMutual = student1['roommateType'] == 'mutual'; // 룸메이트 타입 확인

    String? mutualAgreementDate;
    if (isMutual && student1['roommateHistory'] != null) {
      for (var historyEntry in student1['roommateHistory']) {
        if (historyEntry['event'] == 'confirmed') {
          mutualAgreementDate = historyEntry['date'];
          break;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '룸메이트 정보',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.fontPrimary,
              ),
            ),
            if (isMutual && mutualAgreementDate != null)
              Row(
                children: [
                  Text(
                    '동의 날짜: $mutualAgreementDate',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.fontSecondary,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  ElevatedButton(
                    onPressed: () => _cancelRoommatePairing(student1, student2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusRejected,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5.r),
                      ),
                    ),
                    child: Text('관계 해지', style: TextStyle(fontSize: 12.sp)),
                  ),
                ],
              )
            else if (isAssigned) // 상호동의 아니면서 배정완료일 경우의 배정취소 버튼 (기존 로직)
              SizedBox(
                height: 32.h,
                child: ElevatedButton(
                  onPressed: () => _cancelAssignmentForPair(student1, student2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusRejected,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.r),
                    ),
                  ),
                  child: Text('배정취소', style: TextStyle(fontSize: 12.sp)),
                ),
              ),
          ],
        ),
        SizedBox(height: 16.h),
        // 학생 1 정보
        _buildSimplifiedInfoCardForPairedStudent(student1),
        SizedBox(height: 16.h),
        // 학생 2 정보
        _buildSimplifiedInfoCardForPairedStudent(student2),
        // 룸메이트 신청 내역 (상호 동의일 경우에만 표시)
        if (isMutual) // isMutual 조건 추가
          _buildRoommateHistoryTable(student1, student2),
        // 관리자 메모 (학생 1 기준으로 표시)
        _buildMemoSection(student1),
      ],
    );
  }

  // 룸메이트 조회를 위한 간소화된 정보 카드 (새로 추가)
  Widget _buildSimplifiedInfoCardForPairedStudent(
    Map<String, dynamic> student,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white, // 흰색 배경
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          // 그림자 추가 (이미지 참고)
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이름
          Text(
            '${student['studentName']}',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.fontPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          // 학번|학과
          Text(
            '${student['studentId']} | ${student['department']}',
            style: TextStyle(fontSize: 13.sp, color: AppColors.fontSecondary),
          ),
          Divider(height: 16.h, thickness: 1.h, color: AppColors.border),
          // 성별, 흡연여부, 희망 건물, 희망 방타입 (한 줄로 이어서 표시)
          Text(
            '성별: ${student['gender'] ?? 'N/A'}     '
            '흡연여부: ${student['smokingStatus'] ?? 'N/A'}     '
            '건물: ${student['dormBuilding'] ?? 'N/A'}     '
            '방타입: ${student['roomType'] ?? 'N/A'}', // 배정 호실은 여기서 제외
            style: TextStyle(fontSize: 13.sp, color: AppColors.fontPrimary),
            overflow: TextOverflow.ellipsis, // 길면 ... 처리
            maxLines: 1, // 한 줄로 제한
          ),
        ],
      ),
    );
  }

  // 각 섹션의 타이틀을 빌드하는 함수
  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.fontPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Divider(color: AppColors.border, thickness: 1.h),
      ],
    );
  }

  // 제출 서류 목록을 빌드하는 함수 (Table 형태로 변경)
  Widget _buildDocumentList(Map<String, dynamic> studentApp) {
    final List<dynamic> documents = studentApp['documents'] ?? [];

    if (documents.isEmpty) {
      return Text(
        '제출된 서류가 없습니다.',
        style: TextStyle(fontSize: 14.sp, color: AppColors.fontSecondary),
      );
    }

    return Table(
      border: TableBorder.all(color: AppColors.border),
      columnWidths: const {
        0: FixedColumnWidth(40.0), // 체크박스
        1: FlexColumnWidth(1), // 서류명
        2: FlexColumnWidth(1.5), // 파일명
        3: FixedColumnWidth(80.0), // 상태
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppColors.disabledBackground),
          children: [
            _buildTableCell('✔', isHeader: true),
            _buildTableCell('서류명', isHeader: true),
            _buildTableCell('첨부파일명', isHeader: true),
            _buildTableCell('상태', isHeader: true),
          ],
        ),
        ...documents.map((doc) {
          final bool isVerified = doc['isVerified'] == true;
          return TableRow(
            children: [
              // 체크박스 (readOnly 이므로 onChanged는 null)
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Center(
                  child: Checkbox(
                    value: isVerified,
                    onChanged: null, // 수정 불가능
                    activeColor: AppColors.primary, // 체크된 상태의 색상
                  ),
                ),
              ),
              _buildTableCell(doc['name'] ?? 'N/A'),
              _buildTableCell(doc['fileName'] ?? 'N/A'),
              // '미확인' 상태일 때만 클릭 가능
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: GestureDetector(
                  onTap:
                      isVerified
                          ? null // 이미 확인된 서류는 클릭 불가
                          : () {
                            // AdHomePage의 _selectedMenu를 변경하여 '입실관리' 탭으로 이동
                            // 또한, AdInPage에 선택된 학생 정보를 전달하기 위해 arguments를 넘깁니다.
                            // 이 때, AdHomePage의 _menuList에서 '입실관리'의 인덱스를 찾아야 합니다.
                            final int adInPageIndex = adHomePageKey
                                .currentState!
                                .getMenuIndexByTitle('입실관리');
                            adHomePageKey.currentState?.selectMenuByIndex(
                              adInPageIndex,
                              arguments: {
                                'studentId': studentApp['studentId'],
                                'initialTab': '서류심사',
                              },
                            );
                          },
                  child: Text(
                    isVerified ? '확인' : '미확인',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color:
                          isVerified
                              ? AppColors.statusConfirmed
                              : AppColors.statusWaiting,
                      fontWeight: FontWeight.bold,
                      decoration:
                          isVerified
                              ? TextDecoration.none
                              : TextDecoration.underline, // 미확인일 때 밑줄
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isHeader ? 13.sp : 12.sp,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? AppColors.fontPrimary : AppColors.fontSecondary,
        ),
      ),
    );
  }

  // 라벨이 필드 위에 걸쳐지는 TextFormField 형태의 정보 필드를 빌드하는 함수
  // (AdRoomStatusPage에서 필요하므로 여기에 추가)
  Widget _buildInfoFieldWithLabelAbove(
    String label,
    String value, {
    bool isGreyed = false,
  }) {
    final TextEditingController _tempController = TextEditingController(
      text: value,
    );

    return SizedBox(
      height: 38.h, // 고정 높이 적용
      child: TextFormField(
        controller: _tempController,
        readOnly: true, // 수정 불가능하게 설정
        style: TextStyle(
          fontSize: 13.sp, // 값 폰트 크기
          color: AppColors.fontPrimary,
          fontWeight: FontWeight.normal,
        ),
        decoration: InputDecoration(
          labelText: label, // 라벨 텍스트
          labelStyle: TextStyle(
            fontSize: 10.sp, // 라벨 폰트 크기
            color: AppColors.fontSecondary,
          ),
          floatingLabelBehavior:
              FloatingLabelBehavior.always, // 라벨을 항상 위로 띄웁니다.
          contentPadding: EdgeInsets.fromLTRB(
            10.w,
            15.h,
            10.w,
            5.h,
          ), // 내부 패딩 조정 (상단 패딩 줄여 라벨 공간 확보)
          filled: isGreyed, // 회색 배경 여부
          fillColor: isGreyed ? AppColors.disabledBackground : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(color: AppColors.border, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            // readOnly일 때의 테두리
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(color: AppColors.border, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            // 포커스 시 테두리 (readOnly여도 포커스 스타일 적용 가능)
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(
              color: AppColors.primary,
              width: 1.0,
            ), // 클릭 시 색상 변경
          ),
        ),
      ),
    );
  }

  // 여러 정보 필드를 가로로 배열하는 Row
  // (AdRoomStatusPage에서 필요하므로 여기에 추가)
  Widget _buildInfoFieldContainer({required List<Widget> children}) {
    List<Widget> rowChildren = [];
    for (int i = 0; i < children.length; i++) {
      rowChildren.add(Expanded(child: children[i]));
      if (i < children.length - 1) {
        rowChildren.add(SizedBox(width: 8.w));
      }
    }
    return Row(children: rowChildren);
  }

  // 관리자 메모 섹션 빌드 함수 (AdRoomStatusPage에서 필요하므로 여기에 추가)
  Widget _buildMemoSection(Map<String, dynamic> student) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '관리자 메모',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.fontPrimary,
              ),
            ),
            if (!_isEditMode)
              TextButton(
                onPressed: () => setState(() => _isEditMode = true),
                child: const Text('작성'),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _adminMemoController,
          enabled: _isEditMode,
          maxLines: 4,
          style: TextStyle(fontSize: 16.sp, color: AppColors.fontPrimary),
          decoration: InputDecoration(
            hintText: '메모를 입력하려면 \'작성\' 버튼을 눌러주세요.',
            hintStyle: TextStyle(
              fontSize: 16.sp,
              color: AppColors.fontSecondary.withOpacity(0.6),
            ),
            contentPadding: EdgeInsets.all(12.w),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: BorderSide(color: AppColors.border),
            ),
            filled: !_isEditMode,
            fillColor: AppColors.disabledBackground,
          ),
        ),
        SizedBox(height: 16.h),
        if (_isEditMode)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    student['adminMemo'] = _adminMemoController.text;
                    _isEditMode = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('저장'),
              ),
            ],
          ),
      ],
    );
  }

  // _showDocumentPreviewDialog 함수 (AdRoomStatusPage에서 필요하므로 여기에 추가)
  Future<void> _showDocumentPreviewDialog(
    Map<String, dynamic> studentApp,
    Map<String, dynamic> document,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          title: Text(
            '${document['name']} 미리보기',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
              color: AppColors.fontPrimary,
            ),
          ),
          content: SizedBox(
            width: 380.w,
            child: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(
                    '\'${document['fileName']}\'의 서류 내용을 여기에 표시합니다.',
                    style: TextStyle(
                      color: AppColors.fontSecondary,
                      fontSize: 15.sp,
                      height: 1.6,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    height: 200.h,
                    color: AppColors.disabledBackground,
                    alignment: Alignment.center,
                    child: const Text('(미리보기 더미 영역)'),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                '닫기',
                style: TextStyle(color: AppColors.fontSecondary),
              ),
            ),
            // 이 다이얼로그에서 '확인' 버튼을 누르는 것은 서류 확인이 아니라 그냥 닫는 역할
            // 실제 서류 확인 상태 변경은 AdInPage에서 이루어져야 하므로, 여기서는 관련 로직 제거
          ],
        );
      },
    );
  }

  Widget _buildRoommateHistoryTable(
    Map<String, dynamic> student1,
    Map<String, dynamic> student2,
  ) {
    final bool isMutual = student1['roommateType'] == 'mutual';
    final List<dynamic>? history = student1['roommateHistory'];

    if (!isMutual || history == null || history.isEmpty) {
      return const SizedBox.shrink();
    }

    String getEventText(String eventKey) {
      switch (eventKey) {
        case 'student1_applied_to_student2':
          return '${student1['studentName']} 학생이 ${student2['studentName']} 학생에게 룸메이트를 신청했습니다.';
        case 'student2_accepted':
          return '${student2['studentName']} 학생이 신청을 수락했습니다.';
        case 'confirmed':
          return '룸메이트 배정이 확정되었습니다.';
        default:
          return '';
      }
    }

    IconData getIconForEvent(String eventKey) {
      switch (eventKey) {
        case 'student1_applied_to_student2':
          return Icons.person_add_alt_1_outlined;
        case 'student2_accepted':
          return Icons.check_circle_outline;
        case 'confirmed':
          return Icons.handshake_outlined;
        default:
          return Icons.circle_outlined;
      }
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 24.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '룸메이트 신청 내역',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.fontPrimary,
            ),
          ),
          Divider(height: 24.h, thickness: 1, color: AppColors.border),
          Column(
            children: List.generate(history.length, (index) {
              final log = history[index] as Map<String, dynamic>;
              return _buildHistoryTimelineTile(
                icon: getIconForEvent(log['event']!),
                iconColor: AppColors.primary.withOpacity(0.8),
                title: getEventText(log['event']!),
                date: log['date']!,
                isLast: index == history.length - 1,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTimelineTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String date,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 24.sp),
              if (!isLast)
                Expanded(child: Container(width: 1.w, color: AppColors.border)),
            ],
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24.h, top: 2.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.fontSecondary,
                      ),
                    ),
                  ),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.fontSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
