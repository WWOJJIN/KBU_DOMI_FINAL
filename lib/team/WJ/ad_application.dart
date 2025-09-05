// ignore_for_file: use_build_context_synchronously, avoid_function_literals_in_foreach_calls

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math';
// import 'package:kbu_domi/admin/ad_home.dart'; // adHomePageKey 사용 시 필요, 현재 더미로 주석 처리
// import 'application_data_service.dart'; // 데이터 서비스 사용 시 필요, 현재 더미로 주석 처리
// import 'package:http/http.dart' as http; // HTTP 통신을 위한 패키지 추가 (더미에서는 사용 안 함)
// import 'dart:convert'; // JSON 인코딩/디코딩을 위한 패키지 추가 (더미에서는 사용 안 함)
// import 'dart:developer'; // 로그를 위한 패키지 추가 (더미에서는 사용 안 함)

// --- 디자인에 사용될 색상 정의 (AdRoomStatusPage의 AppColors 통합) ---
class AppColors {
  static const Color background = Colors.white;
  static const Color primary = Color(
    0xFF673AB7,
  ); // AdApplicationPage의 기존 primary
  static const Color fontPrimary = Color(0xFF333333);
  static const Color fontSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color statusAutoSelected = Color(0xFF9C27B0); // 자동선발 (보라)
  static const Color statusRejected = Color(0xFFEF5350); // 미선발 (빨강)
  static const Color activeBorder = Color(0xFF0D47A1); // AdRoomStatusPage에서 가져옴
  static const Color statusAssigned = Color(
    0xFF42A5F5,
  ); // AdRoomStatusPage에서 가져옴
  static const Color statusUnassigned = Color(
    0xFF757575,
  ); // AdRoomStatusPage에서 가져옴
  static const Color genderFemale = Color(0xFFEC407A); // AdRoomStatusPage에서 가져옴
  static const Color disabledBackground = Color(
    0xFFF5F5F5,
  ); // AdRoomStatusPage에서 가져옴
  static const Color statusWaiting = Color(
    0xFFFFA726,
  ); // AdRoomStatusPage에서 가져옴
  static const Color statusConfirmed = Color(
    0xFF66BB6A,
  ); // AdRoomStatusPage에서 가져옴
}

class AdApplicationPage extends StatefulWidget {
  const AdApplicationPage({super.key});

  @override
  State<AdApplicationPage> createState() => _AdApplicationPageState();
}

class _AdApplicationPageState extends State<AdApplicationPage>
    with AutomaticKeepAliveClientMixin {
  // AutomaticKeepAliveClientMixin 추가
  int _selectedIndex = -1;
  String _searchText = '';
  List<Map<String, dynamic>> _allApplications = [];
  List<Map<String, dynamic>> _filteredApplications = [];

  String _currentFilterStatus = '전체';

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _adminMemoController = TextEditingController();

  bool _isLoading = true;
  bool _isCalculatingDistance = false;
  bool _isMemoEditing = false; // AdApplicationPage의 관리자 메모 편집 모드 상태

  @override
  bool get wantKeepAlive => true; // 상태 유지를 위한 오버라이드

  @override
  void initState() {
    super.initState();
    _loadInitialApplications();
  }

  Future<void> _loadInitialApplications() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));
    _allApplications = _getDummyData();
    _filterAndSortApplications();
    _updateSelection();
    setState(() => _isLoading = false);
  }

  Future<void> _calculateDistancesAndSelect() async {
    setState(() => _isCalculatingDistance = true);
    await Future.delayed(const Duration(seconds: 2));

    // '거리 기준 자동선발'을 누르면 모든 신청자에게 거리 값이 할당됩니다.
    // 기존에 거리가 없던 학생들에게만 거리를 부여합니다.
    for (var app in _allApplications) {
      if (app['distance'] == null) {
        app['distance'] = (Random().nextDouble() * 50).toStringAsFixed(2);
      }
    }

    _allApplications.sort(
      (a, b) => (double.tryParse(a['distance']?.toString() ?? '999') ?? 999)
          .compareTo(
            double.tryParse(b['distance']?.toString() ?? '999') ?? 999,
          ),
    );

    int selectionCount = 0;
    for (var i = 0; i < _allApplications.length && selectionCount < 10; i++) {
      if (_allApplications[i]['status'] == '신청') {
        _allApplications[i]['status'] = '자동선발';
        selectionCount++;
      }
    }

    setState(() {
      _currentFilterStatus = '전체'; // 필터를 '선발'이 아닌 '전체'로 유지
      _filterAndSortApplications();
      _isCalculatingDistance = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('거리 계산 완료: $selectionCount명 자동선발'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _cancelSelection() {
    if (_selectedIndex == -1 || _filteredApplications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('취소할 학생을 선택하세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedApp = _filteredApplications[_selectedIndex];
    if (selectedApp['status'] != '자동선발') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('자동선발 상태인 학생만 취소할 수 있습니다.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final index = _allApplications.indexWhere(
      (app) => app['id'] == selectedApp['id'],
    );

    setState(() {
      if (index != -1) {
        _allApplications[index]['status'] = '미선발';
        // 선발 취소 시에도 'distance' 값은 유지됩니다.
      }
      _filterAndSortApplications();
      _updateSelection();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selectedApp['name']} 학생의 선발이 취소되었습니다.'),
        backgroundColor: Colors.red, // 배경색을 빨간색으로 변경
      ),
    );
  }

  void _manualSelect() {
    if (_selectedIndex == -1 || _filteredApplications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('선발할 학생을 선택하세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedApp = _filteredApplications[_selectedIndex];
    if (selectedApp['status'] == '자동선발') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 선발된 학생입니다.'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final index = _allApplications.indexWhere(
      (app) => app['id'] == selectedApp['id'],
    );

    setState(() {
      if (index != -1) {
        if (_allApplications[index]['distance'] == null) {
          // 수동 선발 시에도 거리가 없으면 새로 할당
          _allApplications[index]['distance'] = (Random().nextDouble() * 50)
              .toStringAsFixed(2);
        }
        _allApplications[index]['status'] = '자동선발'; // 수동 선발도 자동선발 상태로
      }
      _filterAndSortApplications();
      _updateSelection();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${selectedApp['name']} 학생이 선발되었습니다.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _filterAndSortApplications() {
    setState(() {
      _filteredApplications =
          _allApplications.where((app) {
            final searchLower = _searchText.toLowerCase();
            final nameMatch =
                app['name']?.toString().toLowerCase().contains(searchLower) ??
                false;
            final idMatch =
                app['student_id']?.toString().toLowerCase().contains(
                  searchLower,
                ) ??
                false;

            final statusMatch =
                _currentFilterStatus == '전체' ||
                app['status'] == _currentFilterStatus;

            return (_searchText.isEmpty || nameMatch || idMatch) && statusMatch;
          }).toList();
    });
  }

  void _updateSelection({bool reset = false}) {
    if (reset) _selectedIndex = -1;
    if (_filteredApplications.isNotEmpty) {
      if (_selectedIndex < 0 ||
          _selectedIndex >= _filteredApplications.length) {
        _selectedIndex = 0;
      }
      _adminMemoController.text =
          _filteredApplications[_selectedIndex]['admin_memo'] ?? '';
      _isMemoEditing = false; // 선택 변경 시 메모 편집 모드 해제
    } else {
      _selectedIndex = -1;
      _adminMemoController.clear();
      _isMemoEditing = false;
    }
    if (mounted) setState(() {});
  }

  final List<String> _statusOptions = ['전체', '신청', '자동선발', '미선발'];

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 사용 시 필요
    if (_selectedIndex != -1 &&
        _selectedIndex >= _filteredApplications.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedIndex = -1;
          _updateSelection();
        });
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.border, width: 1.w),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildLeftPanel()),
                          VerticalDivider(width: 1.w, color: AppColors.border),
                          Expanded(flex: 3, child: _buildRightPanel()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 16.h),
      child: Text(
        '최초 입주 신청 심사',
        style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLeftPanel() {
    // AdApplicationPage에서는 '룸메이트 조회' 탭이 없으므로 해당 로직 제거
    final listItems = _filteredApplications;

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterAndSearch(),
          SizedBox(height: 16.h),
          Text(
            '${listItems.length}개 항목',
            style: TextStyle(fontSize: 18.0.sp, color: AppColors.fontSecondary),
          ),
          SizedBox(height: 8.h),
          Expanded(child: _buildStudentList()),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearch() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 40.h,
            child: DropdownButtonFormField<String>(
              style: TextStyle(fontSize: 14.sp, color: AppColors.fontPrimary),
              dropdownColor: AppColors.background,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
              ),
              value: _currentFilterStatus,
              items:
                  _statusOptions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(
                            option,
                            style: TextStyle(fontSize: 14.sp),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _currentFilterStatus = value;
                  _filterAndSortApplications();
                  _updateSelection();
                });
              },
            ),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 40.h,
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: '이름 또는 학번으로 검색',
                hintStyle: TextStyle(fontSize: 14.sp),
                prefixIcon: Icon(Icons.search, size: 20.sp),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                setState(() {
                  _searchText = value;
                  _filterAndSortApplications();
                  _updateSelection();
                });
              },
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _manualSelect,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  side: const BorderSide(color: AppColors.fontSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  '선발',
                  style: TextStyle(
                    color: AppColors.fontSecondary,
                    fontSize: 13.sp,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              OutlinedButton(
                onPressed: _cancelSelection,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  side: const BorderSide(color: AppColors.fontSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: Text(
                  '선발취소',
                  style: TextStyle(
                    color: AppColors.fontSecondary,
                    fontSize: 13.sp,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              ElevatedButton.icon(
                onPressed:
                    _isCalculatingDistance
                        ? null
                        : _calculateDistancesAndSelect,
                icon:
                    _isCalculatingDistance
                        ? SizedBox(
                          width: 14.w,
                          height: 14.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Icon(Icons.calculate, size: 16.sp),
                label: Text(
                  _isCalculatingDistance ? '계산 중...' : '거리 기준 자동선발',
                  style: TextStyle(fontSize: 13.sp),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusAutoSelected,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_filteredApplications.isEmpty) {
      return const Center(child: Text('해당 조건의 학생이 없습니다.'));
    }
    return ListView.builder(
      itemCount: _filteredApplications.length,
      itemBuilder: (context, index) {
        final app = _filteredApplications[index];
        final isSelected = _selectedIndex == index;
        return Card(
          elevation: 0,
          margin: EdgeInsets.symmetric(vertical: 4.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
            side: BorderSide(
              color:
                  isSelected ? AppColors.statusAutoSelected : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          color: Colors.white,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedIndex = index;
                _updateSelection();
              });
            },
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${app['name']}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.fontPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        app['status'],
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(app['status']),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.fontSecondary,
                      ),
                      children: [
                        TextSpan(
                          text: '${app['student_id']} | ${app['department']}',
                        ),
                        if (app['distance'] != null &&
                            app['distance'].toString().isNotEmpty)
                          TextSpan(
                            text: ' | 거리: ${app['distance']}km',
                            style: const TextStyle(
                              color: AppColors.statusAutoSelected,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRightPanel() {
    // AdApplicationPage에서는 '룸메이트 조회' 탭이 없으므로 해당 로직 제거
    final listItems = _filteredApplications;
    final selectedApp =
        (_selectedIndex != -1 && listItems.isNotEmpty)
            ? listItems[_selectedIndex]
            : null;

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
              // '학생 조회' 탭 이름을 '신청 정보'로 변경
              _buildRightPanelTabButton('신청 정보'),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child:
                listItems.isEmpty || _selectedIndex < 0 || selectedApp == null
                    ? Center(
                      child: Text(
                        '왼쪽에서 조회할 항목을 선택해주세요.',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppColors.fontSecondary,
                        ),
                      ),
                    )
                    : _buildSingleStudentDetails(selectedApp), // 단일 학생 정보만 표시
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanelTabButton(String tabName) {
    // AdApplicationPage는 탭이 하나뿐이므로, 선택 상태는 항상 true
    final bool isSelected = true;

    return GestureDetector(
      onTap: () {
        // 이 페이지는 탭이 하나뿐이므로 탭 전환 로직은 필요 없음
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

  Widget _buildSingleStudentDetails(Map<String, dynamic> student) {
    final bool isKoreanNational =
        student['nationality'] == '대한민국' && student['applicant_type'] == '내국인';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Row(
            // Row로 변경하여 학생 정보와 상태값 나란히 배치
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '학생 정보',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.fontPrimary,
                ),
              ),
              Text(
                // 여기에서 상태값을 표시
                student['status'] ?? 'N/A',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(student['status']),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Divider(color: AppColors.border, thickness: 1.h),
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
              student['name'] ?? 'N/A', // studentName -> name
            ),
            _buildInfoFieldWithLabelAbove(
              '학번',
              student['student_id'] ?? 'N/A',
            ), // studentId -> student_id
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
        _buildMemoSection(student),
      ],
    );
  }

  // 각 섹션의 타이틀을 빌드하는 함수 (AdRoomStatusPage에서 복사)
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

  // 라벨이 필드 위에 걸쳐지는 TextFormField 형태의 정보 필드를 빌드하는 함수 (AdRoomStatusPage에서 복사)
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
          filled: true, // 항상 채워진 배경
          fillColor:
              isGreyed
                  ? AppColors.disabledBackground
                  : Colors.white, // 회색 배경 여부
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

  // 여러 정보 필드를 가로로 배열하는 Row (AdRoomStatusPage에서 복사)
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

  // 관리자 메모 섹션 빌드 함수 (AdRoomStatusPage에서 복사)
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
            if (!_isMemoEditing) // _isEditMode 대신 _isMemoEditing 사용
              TextButton(
                onPressed: () => setState(() => _isMemoEditing = true),
                child: const Text('작성'),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _adminMemoController,
          enabled: _isMemoEditing, // _isEditMode 대신 _isMemoEditing 사용
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
            filled: !_isMemoEditing, // _isEditMode 대신 _isMemoEditing 사용
            fillColor: AppColors.disabledBackground,
          ),
        ),
        SizedBox(height: 16.h),
        if (_isMemoEditing) // _isEditMode 대신 _isMemoEditing 사용
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {
                  // 현재 선택된 학생의 메모 업데이트
                  if (_selectedIndex != -1 &&
                      _filteredApplications.isNotEmpty) {
                    final currentApp = _filteredApplications[_selectedIndex];
                    final originalIndex = _allApplications.indexWhere(
                      (app) => app['id'] == currentApp['id'],
                    );
                    if (originalIndex != -1) {
                      setState(() {
                        _allApplications[originalIndex]['admin_memo'] =
                            _adminMemoController.text;
                        _isMemoEditing = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('관리자 메모가 저장되었습니다.'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }
                  }
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

  Color _getStatusColor(String? status) {
    switch (status) {
      case '자동선발':
        return AppColors.statusAutoSelected;
      case '미선발':
        return AppColors.statusRejected;
      case '신청':
      default:
        return AppColors.fontSecondary;
    }
  }

  List<Map<String, dynamic>> _getDummyData() {
    final names = [
      '김민준',
      '이서연',
      '박지훈',
      '최수아',
      '정다은',
      '강현우',
      '윤지민',
      '한지우',
      '오세훈',
      '송예은',
      '임도현',
      '황미나',
      '서준호',
      '안유진',
      '백승찬',
      '유지애',
      '차민규',
      '하선우',
      '곽철용',
      '나미리',
    ];
    final departments = [
      '컴퓨터공학과',
      '경영학과',
      '전자공학과',
      '디자인학과',
      '영문학과',
      '기계공학과',
      '국어국문학과',
      '수학과',
      '물리학과',
      '화학과',
      '생명과학과',
      '사회복지학과',
      '산업공학과',
      '통계학과',
      '신소재공학과',
      '의류학과',
      '건축공학과',
      '정치외교학과',
      '철학과',
      '유아교육과',
    ];
    final genders = [
      '남',
      '여',
      '남',
      '여',
      '여',
      '남',
      '여',
      '남',
      '남',
      '여',
      '남',
      '여',
      '남',
      '여',
      '남',
      '여',
      '남',
      '여',
      '남',
      '여',
    ];
    final nationalities = [
      '대한민국',
      '미국',
      '중국',
      '대한민국',
      '일본',
      '대한민국',
      '베트남',
      '대한민국',
      '프랑스',
      '대한민국',
      '몽골',
      '대한민국',
      '러시아',
      '대한민국',
      '영국',
      '대한민국',
      '독일',
      '대한민국',
      '캐나다',
      '대한민국',
    ];
    final applicantTypes = [
      '내국인',
      '외국인',
      '외국인',
      '내국인',
      '외국인',
      '내국인',
      '외국인',
      '내국인',
      '외국인',
      '내국인',
      '외국인',
      '내국인',
      '외국인',
      '내국인',
      '외국인',
      '내국인',
      '외국인',
      '내국인',
      '외국인',
      '내국인',
    ];
    final booleanOptions = [true, false];

    return List.generate(20, (index) {
      bool isKorean = nationalities[index] == '대한민국';
      String? passportNum = isKorean ? null : 'P${1000000 + index}';

      return {
        'id': index + 1,
        'name': names[index],
        'student_id': (20240001 + index).toString(),
        'department': departments[index],
        'gender': genders[index],
        'tel_mobile':
            '010-${(1000 + index).toString().padLeft(4, '0')}-${(1000 + index).toString().padLeft(4, '0')}',
        'address': '랜덤 주소 $index',
        'distance': null, // 초기에는 거리값 없음
        'status': '신청', // 초기 상태는 '신청'
        'admin_memo': '',

        // AdRoomStatusPage에서 가져온 추가 필드
        'recruitmentType': (index % 2 == 0) ? '신입생' : '재학생',
        'academicYear': '2025',
        'semester': (index % 2 == 0) ? '1학기' : '2학기',
        'applicant_type': applicantTypes[index],
        'grade': (index % 4 + 1).toString(),
        'birth_date':
            '200${(index % 9 + 1).toString().padLeft(2, '0')}-0${(index % 12 + 1).toString().padLeft(2, '0')}-0${(index % 28 + 1).toString().padLeft(2, '0')}',
        'nationality': nationalities[index],
        'passport_num': passportNum,
        'smokingStatus': (index % 2 == 0) ? '흡연' : '비흡연',
        'basic_living_support': booleanOptions[index % 2],
        'disabled': booleanOptions[(index + 1) % 2],
        'postal_code': '0${123 + index}',
        'address_basic': '서울시 강남구 ${100 + index}길',
        'address_detail': '${index}호',
        'region_type': (index % 3 == 0) ? '수도권' : '비수도권',
        'tel_home':
            '02-${(2000 + index).toString().padLeft(4, '0')}-${(3000 + index).toString().padLeft(4, '0')}',
        'guardian_name': '보호자 ${names[index]}',
        'guardian_relation': (index % 2 == 0) ? '부' : '모',
        'guardian_phone':
            '010-${(4000 + index).toString().padLeft(4, '0')}-${(5000 + index).toString().padLeft(4, '0')}',
        'dormBuilding': (index % 2 == 0) ? '숭례원' : '양덕원',
        'roomType': (index % 2 == 0) ? '2인실' : '1인실',
        'assignedRoomNumber': null, // 초기에는 배정 없음
        'bank': '국민은행',
        'account_num': '123-45-6789${index}0',
        'account_holder': names[index],
      };
    });
  }
}
