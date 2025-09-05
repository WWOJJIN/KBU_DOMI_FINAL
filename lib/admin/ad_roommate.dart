// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- 디자인 통일을 위한 AppColors 클래스 (team 버전과 동일) ---
class AppColors {
  static const Color primary = Color(0xFF0D47A1); // 네이비 색상
  static const Color fontPrimary = Color(0xFF333333);
  static const Color fontSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color disabledBackground = Color(0xFFF5F5F5);
  static const Color selectedBackground = Color(0xFFE3F2FD); // 연한 파란색 배경

  // 룸메이트 상태별 색상
  static const Color statusWaiting = Color(0xFF90A4AE); // 대기 (Blue Grey)
  static const Color statusPending = Color(0xFFFFA726); // 보류 (Orange)
  static const Color statusConfirmed = Color(0xFF66BB6A); // 배정완료 (Green)
  static const Color statusRejected = Color(0xFFE57373); // 반려 (Red)
}

// --- Main Page Widget ---
class RoommateManagePage extends StatefulWidget {
  const RoommateManagePage({super.key});

  @override
  State<RoommateManagePage> createState() => _RoommateManagePageState();
}

class _RoommateManagePageState extends State<RoommateManagePage> {
  int _selectedIndex = -1;
  String _statusFilter = '전체';
  String _roomTypeFilter = '전체';
  String _buildingFilter = '전체';
  String _searchText = '';
  String _tab = '신청관리';
  String _selectedBuilding = '양덕원'; // 기본 건물 설정 (예: 여자 기숙사)
  String? _selectedFloor = '9'; // 팀원 스타일: 기본값 설정
  bool _isLoading = false; // 로딩 상태 추가

  bool _isEditing = false;

  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _rejectionReasonController =
      TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // DB에서 가져온 실제 데이터로 변경
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _cumulativeData = [];

  // 상태값 번역 함수들 추가

  /// 영어 상태값을 한국어로 번역 (DB → UI)
  String _translateStatusToKorean(String englishStatus) {
    print('번역할 영어 상태값: $englishStatus'); // 디버깅용 로그
    switch (englishStatus.toLowerCase()) {
      case 'pending':
        return '대기';
      case 'approved':
      case 'accepted':
      case 'confirmed':
        return '배정완료';
      case 'rejected':
        return '반려';
      case 'hold':
        return '보류';
      default:
        print('번역되지 않은 상태값: $englishStatus'); // 디버깅용 로그
        return englishStatus; // 이미 한국어인 경우 그대로 반환
    }
  }

  /// 한국어 상태값을 영어로 번역 (UI → DB)
  String _translateStatusToEnglish(String koreanStatus) {
    switch (koreanStatus) {
      case '대기':
        return 'pending';
      case '배정완료':
        return 'confirmed';
      case '반려':
        return 'rejected';
      case '보류':
        return 'hold';
      default:
        return koreanStatus; // 이미 영어인 경우 그대로 반환
    }
  }

  final List<Map<String, dynamic>> _roomList = [
    // 양덕원 10층 (룸메이트 호실로 사용)
    ...List.generate(
      24,
      (i) => {
        'building': '양덕원',
        'floor': '10',
        'room': (1001 + i).toString(),
        'capacity': 2,
        'assigned': [],
        'gender': '여',
      },
    ),
    ...List.generate(
      4,
      (i) => {
        'building': '양덕원',
        'floor': '10',
        'room': (1043 + i).toString(),
        'capacity': 2,
        'assigned': [],
        'gender': '여',
      },
    ),

    // 숭례원 10층 (룸메이트 호실로 사용)
    ...List.generate(
      22,
      (i) => {
        'building': '숭례원',
        'floor': '10',
        'room': (1001 + i).toString(),
        'capacity': 2,
        'assigned': [],
        'gender': '남',
      },
    ),
    ...List.generate(
      7,
      (i) => {
        'building': '숭례원',
        'floor': '10',
        'room': (1032 + i).toString(),
        'capacity': 2,
        'assigned': [],
        'gender': '남',
      },
    ),

    // 숭례원 11층 (추가 더미, 룸메이트 호실로 사용)
    ...List.generate(
      30,
      (i) => {
        'building': '숭례원',
        'floor': '11',
        'room': (1101 + i).toString(),
        'capacity': 2,
        'assigned': [],
        'gender': '남',
      },
    ),
  ];

  // --- 필터링 로직 ---
  List<Map<String, dynamic>> get _currentList =>
      _tab == '신청관리' ? _requests : _cumulativeData;

  List<Map<String, dynamic>> get _filteredList => _currentList.where((r) {
    final displayStatus = r['tempStatus'] ?? r['status'];
    final statusMatch = _statusFilter == '전체' || displayStatus == _statusFilter;
    final roomTypeMatch =
        _roomTypeFilter == '전체' ||
        (r['partners'] as List).length == (_roomTypeFilter == '2인실' ? 1 : 2);
    final building = r['partnerName']?.contains('여') == true
        ? '양덕원'
        : '숭례원'; // 간단한 성별 구분
    final buildingMatch =
        _buildingFilter == '전체' || building == _buildingFilter;
    final searchMatch =
        _searchText.isEmpty ||
        r['applicantId'].toString().contains(_searchText) ||
        r['applicantName'].toString().contains(_searchText) ||
        r['partnerName'].toString().contains(_searchText);
    return statusMatch && roomTypeMatch && buildingMatch && searchMatch;
  }).toList();

  List<String> get _floors =>
      _roomList
          .where((r) => r['building'] == _selectedBuilding)
          .map((r) => r['floor'].toString())
          .toSet()
          .toList()
        ..sort();

  List<Map<String, dynamic>> get _visibleRooms => _roomList
      .where(
        (r) =>
            r['building'] == _selectedBuilding && r['floor'] == _selectedFloor,
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _selectedFloor = _floors.isNotEmpty ? _floors.first : null;
    _searchController.addListener(
      () => setState(() => _searchText = _searchController.text),
    );
    _loadRoommateData(); // DB에서 데이터 로드
  }

  // 팀원 스타일: 층별 방 타입 표시 함수 추가
  String _getFloorName(String floor) {
    switch (floor) {
      case '6':
        return '6층 (1인실)';
      case '7':
        return '7층 (2인실)';
      case '8':
        return '8층 (3인실)';
      case '9':
        return '9층 (룸메이트)';
      case '10':
        return '10층 (방학이용)';
      default:
        return '$floor층';
    }
  }

  @override
  void dispose() {
    _memoController.dispose();
    _rejectionReasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Row(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '룸메이트 관리',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.fontPrimary,
            ),
          ),
          Row(
            children: [
              _buildTab('신청관리'),
              SizedBox(width: 20.w),
              _buildTab('누적데이터'),
              SizedBox(width: 20.w),
              // 새로고침 버튼 추가
              ElevatedButton.icon(
                onPressed: _loadRoommateData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('새로고침'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  elevation: 0,
                  side: const BorderSide(color: Colors.blue),
                  textStyle: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
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

  Widget _buildTab(String label) {
    final isActive = _tab == label;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = label;
        _selectedIndex = -1;
        _isEditing = false;
        _statusFilter = '전체';
        _roomTypeFilter = '전체';
        _buildingFilter = '전체';
        for (var req in _requests) {
          req['tempStatus'] = null;
          req['tempRoom'] = null;
        }
        _syncRoomAssignments();
      }),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isActive ? AppColors.primary : AppColors.fontSecondary,
            ),
          ),
          SizedBox(height: 6.h),
          if (isActive)
            Container(
              width: 50.w,
              height: 3.h,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterAndSearch(),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredList.length}개의 항목',
                style: TextStyle(
                  fontSize: 15.sp,
                  color: AppColors.fontSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_tab == '신청관리')
                ElevatedButton(
                  onPressed: () {
                    _showConfirmationDialog(
                      context: context,
                      title: '자동 배정',
                      content: '현재 필터링된 \'대기\' 상태의 모든 신청을 자동으로 배정하시겠습니까?',
                      onConfirm: _performAutoAssignment,
                    );
                  },
                  child: Text('자동 배정'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
              if (_tab == '누적데이터')
                ElevatedButton(
                  onPressed: () {
                    _showConfirmationDialog(
                      context: context,
                      title: '대기 일괄 처리',
                      content: '현재 필터링된 모든 항목을 \'대기\' 상태로 복구하시겠습니까?',
                      onConfirm: _performBulkWaiting,
                    );
                  },
                  child: Text('대기 일괄 처리'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    textStyle: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 10.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          Expanded(child: _buildRequestList()),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearch() {
    // 팀원 스타일: '불가' → '반려'로 변경
    final statusFilters = _tab == '신청관리'
        ? ['전체', '대기', '보류', '반려']
        : ['전체', '배정완료', '반려'];
    // 팀원 스타일: 3인실 옵션 추가
    final roomTypeFilters = ['전체', '2인실', '3인실'];
    final buildingFilters = ['전체', '양덕원', '숭례원'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterRow(
          '상태',
          statusFilters,
          _statusFilter,
          (value) => setState(() => _statusFilter = value),
        ),
        SizedBox(height: 8.h),
        _buildFilterRow(
          '방 타입',
          roomTypeFilters,
          _roomTypeFilter,
          (value) => setState(() => _roomTypeFilter = value),
        ),
        SizedBox(height: 8.h),
        _buildFilterRow(
          '건물',
          buildingFilters,
          _buildingFilter,
          (value) => setState(() => _buildingFilter = value),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          height: 38.h,
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontSize: 13.sp),
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
              prefixIcon: Icon(Icons.search, size: 18.sp, color: Colors.grey),
              hintText: '이름 또는 학번 검색',
              hintStyle: TextStyle(
                color: AppColors.fontSecondary,
                fontSize: 13.sp,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: Colors.blue, width: 1.5.w),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow(
    String title,
    List<String> options,
    String selectedValue,
    ValueChanged<String> onSelected,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 60.w,
          child: Text(
            title,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 38.h,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: options
                  .map(
                    (f) => Padding(
                      padding: EdgeInsets.only(right: 8.w),
                      child: ChoiceChip(
                        label: Text(f, style: TextStyle(fontSize: 13.sp)),
                        selected: selectedValue == f,
                        onSelected: (_) => onSelected(f),
                        backgroundColor: Colors.white,
                        selectedColor: AppColors.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                          side: BorderSide(
                            color: selectedValue == f
                                ? AppColors.primary
                                : Colors.grey.shade300,
                          ),
                        ),
                        showCheckmark: false,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestList() {
    if (_filteredList.isEmpty) {
      return Center(
        child: Text(
          '해당 조건의 항목이 없습니다.',
          style: TextStyle(fontSize: 16.sp, color: AppColors.fontSecondary),
        ),
      );
    }
    return ListView.builder(
      itemCount: _filteredList.length,
      itemBuilder: (context, index) {
        final request = _filteredList[index];
        final isSelected = _selectedIndex == index;

        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          margin: EdgeInsets.only(bottom: 8.h),
          color: isSelected ? AppColors.selectedBackground : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isSelected ? AppColors.primary : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1.0,
            ),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: InkWell(
            hoverColor: Colors.grey.withOpacity(0.15),
            onTap: () {
              setState(() {
                if (_selectedIndex != -1 &&
                    _selectedIndex < _filteredList.length) {
                  final prevRequest = _filteredList[_selectedIndex];
                  prevRequest['tempStatus'] = null;
                  prevRequest['tempRoom'] = null;
                }
                _selectedIndex = index;
                _memoController.text = request['memo'] ?? '';
                _rejectionReasonController.text =
                    request['rejectionReason'] ?? '';

                if (_tab == '신청관리') {
                  _isEditing = (request['status'] == '대기');
                } else {
                  _isEditing = false;
                }
              });
            },
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${request['applicantName']} (${request['applicantId']})',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.fontPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '동의학생: ${request['partnerName']}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.fontSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildStatusBadge(
                        request['tempStatus'] ?? request['status'],
                      ),
                      SizedBox(width: 8.w),
                      // 이력 보기 버튼 추가
                      IconButton(
                        onPressed: () => _showHistory(request['id']),
                        icon: Icon(
                          Icons.history,
                          size: 20.sp,
                          color: AppColors.primary,
                        ),
                        tooltip: '이력 보기',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          padding: EdgeInsets.all(8.w),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '대기':
        return AppColors.statusWaiting;
      case '보류':
        return AppColors.statusPending;
      case '배정완료':
        return AppColors.statusConfirmed;
      case '반려':
        return AppColors.statusRejected;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13.sp,
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_selectedIndex == -1 ||
        _filteredList.isEmpty ||
        _selectedIndex >= _filteredList.length) {
      return Center(
        child: Text(
          '좌측 목록에서 항목을 선택해주세요.',
          style: TextStyle(fontSize: 18.sp, color: AppColors.fontSecondary),
        ),
      );
    }

    final request = _filteredList[_selectedIndex];
    final isReadOnly = !_isEditing;

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Opacity(
        opacity: isReadOnly ? 0.7 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStudentInfo(request),
            Divider(height: 32.h, thickness: 1, color: AppColors.border),
            Text(
              '호실 배정',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.fontPrimary,
              ),
            ),
            SizedBox(height: 16.h),
            IgnorePointer(ignoring: isReadOnly, child: _buildRoomSelectors()),
            SizedBox(height: 16.h),
            IgnorePointer(ignoring: isReadOnly, child: _buildRoomGrid()),
            SizedBox(height: 24.h),
            Text(
              '반려 사유', // 팀원 스타일: '불가' → '반려'
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.fontPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            _buildTextField(
              _rejectionReasonController,
              '반려 처리 시 사유를 입력하세요.', // 팀원 스타일: '불가' → '반려'
              isReadOnly,
            ),
            SizedBox(height: 16.h),
            Text(
              '관리자 메모',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.fontPrimary,
              ),
            ),
            SizedBox(height: 8.h),
            _buildTextField(_memoController, '필요한 내용을 메모하세요.', isReadOnly),
            SizedBox(height: 24.h),
            _buildActionArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfo(Map<String, dynamic> request) {
    final displayStatus = request['tempStatus'] ?? request['status'];
    final displayRoom = (request['tempRoom']?.isNotEmpty == true
        ? request['tempRoom']
        : request['room']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '신청 정보',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.fontPrimary,
              ),
            ),
            _buildStatusBadge(displayStatus),
          ],
        ),
        SizedBox(height: 16.h),
        _buildInfoField(
          '신청학생',
          '${request['applicantName']} (${request['applicantId']})',
        ),
        SizedBox(height: 12.h),
        // 팀원 스타일: 동의학생들을 개별적으로 표시
        if (request['partners'] != null && request['partners'] is List)
          ...request['partners']
              .map<Widget>(
                (p) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _buildInfoField(
                    '동의학생',
                    '${p['name']} (${p['id'] ?? ''})',
                  ),
                ),
              )
              .toList()
        else
          // 기존 방식 (단일 파트너명)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _buildInfoField('동의학생', '${request['partnerName']}'),
          ),
        _buildInfoField('배정호실', displayRoom.isEmpty ? '미배정' : displayRoom),
      ],
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.fontPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 15.sp, color: AppColors.fontPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelectors() {
    return Row(
      children: [
        Expanded(
          child: _buildStyledDropdown('건물', ['양덕원', '숭례원'], _selectedBuilding, (
            String? v,
          ) {
            setState(() {
              _selectedBuilding = v!;
            });
          }),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: _buildStyledDropdown(
            '층',
            _floors,
            _selectedFloor,
            (String? v) => setState(() => _selectedFloor = v),
            itemLabel: (f) => _getFloorName(f), // 팀원 스타일: 세부 정보 표시
          ),
        ),
      ],
    );
  }

  Widget _buildStyledDropdown<T>(
    String label,
    List<T> items,
    T? value,
    ValueChanged<T?>? onChanged, {
    String Function(T)? itemLabel,
  }) {
    final validValue = items.contains(value) ? value : null;
    final isEnabled = onChanged != null;

    return DropdownButtonFormField<T>(
      value: validValue,
      items: items
          .map(
            (i) => DropdownMenuItem(
              value: i,
              child: Text(
                itemLabel != null ? itemLabel(i) : i.toString(),
                style: TextStyle(fontSize: 15.sp),
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
      isExpanded: true,
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 13.sp,
          color: isEnabled ? Colors.grey[700] : Colors.grey[500],
          fontWeight: FontWeight.w500,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: isEnabled ? Colors.white : AppColors.disabledBackground,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: Colors.blue, width: 1.5.w),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  Widget _buildRoomGrid() {
    if (_selectedFloor == null)
      return const Center(child: Text('건물과 층을 선택해주세요.'));

    // 팀원 스타일: 선택된 요청의 방 타입 확인
    final selectedRequest =
        _selectedIndex != -1 && _selectedIndex < _filteredList.length
        ? _filteredList[_selectedIndex]
        : null;

    final currentRequestEffectiveRoom = selectedRequest != null
        ? (selectedRequest['tempRoom'] ?? selectedRequest['room'])
        : null;

    if (_visibleRooms.isEmpty)
      return const Center(child: Text('해당 층에 호실이 없습니다.'));

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: _visibleRooms.map((room) {
        final assignedCount = (room['assigned'] as List).length;
        final isFull = assignedCount >= room['capacity'];
        final isAssignedToThis =
            currentRequestEffectiveRoom != null &&
            currentRequestEffectiveRoom ==
                '${room['building']} ${room['room']}호';

        // 팀원 스타일: 동적 그룹 크기 계산
        int groupSize = 1; // 기본적으로 신청자 1명
        if (selectedRequest != null) {
          if (selectedRequest['partners'] != null &&
              selectedRequest['partners'] is List) {
            groupSize = 1 + (selectedRequest['partners'] as List).length;
          } else if (selectedRequest['partnerName'] != null) {
            groupSize = 2; // 기존 방식 (신청자 + 파트너 1명)
          }
        }

        final canAssign =
            !isFull && (room['capacity'] - assignedCount) >= groupSize;

        // 팀원 스타일: 층별 배정 제한
        bool isAssignableFloor = true;
        if (selectedRequest != null) {
          final requestedRoomType = selectedRequest['roomType'] ?? '2인실';
          isAssignableFloor =
              (_selectedFloor == '9' && requestedRoomType == '2인실') ||
              (_selectedFloor == '8' && requestedRoomType == '3인실') ||
              (_selectedFloor == '7' && requestedRoomType == '2인실') ||
              (_selectedFloor == '6' && requestedRoomType == '1인실') ||
              (_selectedFloor == '10'); // 방학이용은 모든 타입 허용
        }

        final bool isClickable = isAssignableFloor && canAssign;

        Color cardColor = Colors.white;
        Color textColor = AppColors.fontPrimary;
        BorderSide borderSide = BorderSide(color: AppColors.border);

        if (!isAssignableFloor) {
          cardColor = AppColors.disabledBackground;
          textColor = AppColors.fontSecondary;
        } else if (isAssignedToThis) {
          cardColor = AppColors.statusConfirmed.withOpacity(0.15);
          borderSide = BorderSide(color: AppColors.statusConfirmed, width: 1.5);
        } else if (isFull || !canAssign) {
          cardColor = AppColors.disabledBackground;
          textColor = AppColors.fontSecondary;
        }

        return InkWell(
          onTap: isClickable ? () => _assignRoom(room) : null,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            width: 100.w,
            height: 60.h,
            decoration: BoxDecoration(
              color: cardColor,
              border: Border.fromBorderSide(borderSide),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${room['room']}호',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '(${assignedCount}/${room['capacity']})',
                  style: TextStyle(
                    color: textColor.withOpacity(0.8),
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hintText,
    bool isReadOnly,
  ) {
    return SizedBox(
      height: 80.h,
      child: TextField(
        controller: controller,
        readOnly: isReadOnly,
        maxLines: 3,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(fontSize: 16.sp, color: AppColors.fontPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 14.sp,
            color: AppColors.fontSecondary.withOpacity(0.6),
          ),
          contentPadding: EdgeInsets.all(12.w),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: Colors.blue, width: 1.5.w),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: true,
          fillColor: isReadOnly ? AppColors.disabledBackground : Colors.white,
        ),
      ),
    );
  }

  Widget _buildActionArea() {
    if (_isEditing) {
      return _buildEditingButtons();
    } else {
      return _buildViewingButtons();
    }
  }

  Widget _buildViewingButtons() {
    // 팀원 스타일: 복구/삭제 버튼 제거, 수정 버튼만 유지
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.edit),
          label: const Text('수정'),
          onPressed: () => setState(() => _isEditing = true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildEditingButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _buildStatusButton('보류', AppColors.statusPending),
            SizedBox(width: 10.w),
            _buildStatusButton('배정완료', AppColors.statusConfirmed),
            SizedBox(width: 10.w),
            _buildStatusButton(
              '반려',
              AppColors.statusRejected,
            ), // 팀원 스타일: '불가' → '반려'
          ],
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('저장'),
          onPressed: _onSaveButtonPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
            textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusButton(String status, Color color) {
    final bool isSelected =
        _selectedIndex != -1 &&
        _selectedIndex < _filteredList.length &&
        (_filteredList[_selectedIndex]['tempStatus'] ??
                _filteredList[_selectedIndex]['status']) ==
            status;
    final Map<String, dynamic>? request =
        _selectedIndex != -1 && _selectedIndex < _filteredList.length
        ? _filteredList[_selectedIndex]
        : null;

    VoidCallback? onPressed = request != null
        ? () {
            setState(() {
              request['tempStatus'] = status;
              if (status != '배정완료') {
                request['tempRoom'] = '';
              }
            });
          }
        : null;

    final buttonStyle = TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600);
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: 20.w,
      vertical: 12.h,
    );

    return isSelected
        ? ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              textStyle: buttonStyle,
              padding: buttonPadding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(status),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.fontSecondary,
              side: BorderSide(color: AppColors.fontSecondary),
              textStyle: buttonStyle,
              padding: buttonPadding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(status),
          );
  }

  // --- Logic Methods ---
  void _performBulkWaiting() {
    if (_tab != '누적데이터') return;
    final List<Map<String, dynamic>> toRestore = _filteredList;
    if (toRestore.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('복구할 항목이 없습니다.')));
      return;
    }

    setState(() {
      for (var request in toRestore) {
        request['status'] = '대기';
        request['room'] = '';
        request['tempStatus'] = null;
        request['tempRoom'] = null;
        _requests.insert(0, request);
        _cumulativeData.remove(request);
      }
      _syncRoomAssignments();
      _selectedIndex = -1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${toRestore.length}건의 데이터를 신청관리 목록으로 복구했습니다.'),
        backgroundColor: AppColors.statusConfirmed,
      ),
    );
  }

  void _performAutoAssignment() {
    int successCount = 0;
    int failCount = 0;
    final List<Map<String, dynamic>> toAssign = _filteredList
        .where((r) => r['status'] == '대기')
        .toList();

    for (var request in toAssign) {
      // 팀원 스타일: 동적 그룹 크기 계산
      int groupSize = 1; // 기본적으로 신청자 1명
      if (request['partners'] != null && request['partners'] is List) {
        groupSize = 1 + (request['partners'] as List).length;
      } else if (request['partnerName'] != null) {
        groupSize = 2; // 기존 방식 (신청자 + 파트너 1명)
      }

      final requestedRoomType = request['roomType'] ?? '2인실';
      final requestGender =
          request['gender'] ??
          (request['applicantName']?.contains('여') == true ? '여' : '남');

      // 팀원 스타일: 층별 제한이 있는 방 찾기
      final rooms = _roomList.where((room) {
        final isCorrectFloor =
            (requestedRoomType == '2인실' &&
                (room['floor'] == '9' || room['floor'] == '7')) ||
            (requestedRoomType == '3인실' && room['floor'] == '8') ||
            (requestedRoomType == '1인실' && room['floor'] == '6') ||
            (room['floor'] == '10'); // 방학이용은 모든 타입 허용

        if (!isCorrectFloor) return false;

        return room['gender'] == requestGender &&
            (room['capacity'] - (room['assigned'] as List).length) >= groupSize;
      }).toList();

      if (rooms.isNotEmpty) {
        final room = rooms.first;
        request['status'] = '배정완료';
        request['room'] = '${room['building']} ${room['room']}호';

        // 팀원 스타일: 모든 그룹 멤버 추가
        (room['assigned'] as List).add(request['applicantId']);
        if (request['partners'] != null && request['partners'] is List) {
          for (var partner in request['partners']) {
            (room['assigned'] as List).add(partner['id'] ?? partner['name']);
          }
        } else if (request['partnerName'] != null) {
          (room['assigned'] as List).add(request['partnerName']);
        }

        successCount++;
      } else {
        failCount++;
      }
    }

    setState(() {
      _requests.removeWhere((r) => r['status'] == '배정완료');
      _cumulativeData.addAll(toAssign.where((r) => r['status'] == '배정완료'));
      _syncRoomAssignments();
    });

    _showResultDialog(
      '자동 배정 결과',
      '총 ${toAssign.length}건 중 ${successCount}건 배정 성공, ${failCount}건 실패했습니다.',
    );
  }

  // 방 할당 현황을 _requests와 _cumulativeData를 기반으로 재계산
  void _syncRoomAssignments() {
    // 모든 방의 할당 리스트를 초기화
    for (var room in _roomList) {
      (room['assigned'] as List).clear();
    }

    // _requests와 _cumulativeData의 모든 항목을 확인하여 방 할당
    final allProcessedRequests = [..._requests, ..._cumulativeData];
    for (var request in allProcessedRequests) {
      // 'room' 필드가 유효하고, 'room' 필드가 실제 배정된 호실을 나타낼 때만 처리
      if (request['room']?.isNotEmpty == true &&
          request['status'] != '대기' &&
          request['status'] != '보류') {
        final assignedRoomFullString = request['room'] as String;
        final parts = assignedRoomFullString.split(' ');
        if (parts.length == 2) {
          final assignedBuilding = parts[0];
          final assignedRoomNumber = parts[1];

          final roomToUpdate = _roomList.firstWhere(
            (room) =>
                room['building'] == assignedBuilding &&
                room['room'] == assignedRoomNumber.replaceAll('호', ''),
            orElse: () => {},
          );

          if (roomToUpdate.isNotEmpty) {
            (roomToUpdate['assigned'] as List).add(request['applicantId']);
            (roomToUpdate['assigned'] as List).add(request['partnerName']);
          }
        }
      }
    }
  }

  void _assignRoom(Map<String, dynamic> room) {
    if (_selectedIndex < 0 || _selectedIndex >= _filteredList.length) return;
    final request = _filteredList[_selectedIndex];
    setState(() {
      // 임시 방 정보 업데이트
      request['tempRoom'] = '${room['building']} ${room['room']}호';
      // 임시 상태를 '배정완료'로 변경
      request['tempStatus'] = '배정완료';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${request['applicantName']} 학생이 ${request['tempRoom']}에 임시 배정되었습니다. \'저장\' 버튼을 눌러 확정하세요.',
        ),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  void _onSaveButtonPressed() {
    if (_selectedIndex < 0 || _selectedIndex >= _filteredList.length) return;
    final request = _filteredList[_selectedIndex];
    final effectiveStatus = request['tempStatus'] ?? request['status'];
    final effectiveRoom = request['tempRoom']?.isNotEmpty == true
        ? request['tempRoom']
        : request['room'];

    if (effectiveStatus == '반려' &&
        _rejectionReasonController.text.trim().isEmpty) {
      _showErrorDialog('\'반려\' 처리 시에는 반드시 반려 사유를 입력해야 합니다.');
      return;
    }
    if (effectiveStatus == '배정완료' &&
        (effectiveRoom == null || effectiveRoom.isEmpty)) {
      _showErrorDialog('\'배정완료\' 처리 시에는 반드시 호실을 배정해야 합니다.');
      return;
    }

    _showConfirmationDialog(
      context: context,
      title: "변경사항 저장 확인",
      content: "신청 정보를 '${effectiveStatus}' 상태로 저장하시겠습니까?",
      onConfirm: _tab == '신청관리'
          ? _saveApplicationChanges
          : _saveCumulativeChanges,
    );
  }

  // '신청관리' 탭 저장 로직 (상태값 번역 추가)
  void _saveApplicationChanges() async {
    if (_selectedIndex < 0 || _selectedIndex >= _filteredList.length) return;

    final request = _filteredList[_selectedIndex];

    // 유효 상태/방 정보 가져오기 (임시 값이 있으면 사용)
    final effectiveStatus = request['tempStatus'] ?? request['status'];
    final effectiveRoom = request['tempRoom']?.isNotEmpty == true
        ? request['tempRoom']
        : request['room'];

    try {
      // 한국어 상태값을 영어로 변환하여 DB에 저장
      final englishStatus = _translateStatusToEnglish(effectiveStatus);

      // API 호출로 상태 업데이트
      final response = await http.put(
        Uri.parse(
          'http://localhost:5050/api/admin/roommate/requests/${request['id']}/status',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': englishStatus, // 영어 상태값으로 변환하여 전송
          'room_assigned': effectiveRoom,
          'memo': _memoController.text,
          'rejection_reason': _rejectionReasonController.text,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          // 1. 컨트롤러의 텍스트를 데이터에 저장
          request['memo'] = _memoController.text;
          request['rejectionReason'] = _rejectionReasonController.text;

          // 2. 임시 상태/방 정보를 실제 상태/방으로 반영 (한국어 상태 유지)
          request['status'] = effectiveStatus;
          request['room'] = effectiveRoom;
          request['tempStatus'] = null; // 임시 상태 초기화
          request['tempRoom'] = null; // 임시 방 초기화
          _isEditing = false;

          // 3. '배정완료' 또는 '반려' 상태일 때 데이터 이동
          if (effectiveStatus == '배정완료' || effectiveStatus == '반려') {
            _cumulativeData.add(request); // 누적 데이터에 추가
            _requests.remove(request); // 원본 신청 리스트에서 제거
            _selectedIndex = -1; // 선택 초기화

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '룸메이트 신청이 ${effectiveStatus} 처리되어 누적 데이터로 이동했습니다.',
                ),
                backgroundColor: AppColors.statusConfirmed,
              ),
            );
          } else {
            // '대기' 또는 '보류' 상태 저장 (데이터 이동 없음)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('변경사항이 저장되었습니다.'),
                backgroundColor: AppColors.primary,
              ),
            );
          }
          _syncRoomAssignments(); // 데이터 저장 후 방 할당 현황 동기화
        });
      } else {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장에 실패했습니다: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // '누적데이터' 탭 저장 로직 (상태값 번역 추가)
  void _saveCumulativeChanges() async {
    if (_selectedIndex < 0 || _selectedIndex >= _filteredList.length) return;
    final request = _filteredList[_selectedIndex];

    try {
      // 한국어 상태값을 영어로 변환하여 DB에 저장
      final englishStatus = _translateStatusToEnglish(request['status']);

      // API 호출로 메모와 반려 사유 업데이트
      final response = await http.put(
        Uri.parse(
          'http://localhost:5050/api/admin/roommate/requests/${request['id']}/status',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': englishStatus, // 영어 상태값으로 변환하여 전송
          'room_assigned': request['room'],
          'memo': _memoController.text,
          'rejection_reason': _rejectionReasonController.text,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          request['memo'] = _memoController.text;
          request['rejectionReason'] = _rejectionReasonController.text;
          _isEditing = false; // 수정 모드 종료
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('수정사항이 저장되었습니다.'),
            backgroundColor: AppColors.primary,
          ),
        );
      } else {
        throw Exception('Failed to update data');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장에 실패했습니다: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 데이터 복구 로직
  void _restoreRequest() {
    if (_selectedIndex < 0 || _selectedIndex >= _filteredList.length) return;
    final request = _filteredList[_selectedIndex];
    setState(() {
      _requests.add(request); // 신청 리스트에 다시 추가
      _cumulativeData.remove(request); // 누적 리스트에서 제거
      _selectedIndex = -1; // 선택 해제

      request['status'] = '대기'; // 복구 시 상태를 '대기'로 초기화
      request['room'] = ''; // 복구 시 호실도 초기화
      // 임시 상태도 초기화
      request['tempStatus'] = null;
      request['tempRoom'] = null;
      _isEditing = false;

      _syncRoomAssignments(); // 복구 후 방 할당 현황 동기화
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('데이터가 신청관리 목록으로 복구되었습니다.'),
        backgroundColor: AppColors.statusConfirmed,
      ),
    );
  }

  // 데이터 삭제 로직
  void _deleteRequest() {
    if (_selectedIndex < 0 || _selectedIndex >= _filteredList.length) return;
    final request = _filteredList[_selectedIndex];
    setState(() {
      _cumulativeData.remove(request);
      _selectedIndex = -1;
      _isEditing = false;
    });
    _syncRoomAssignments(); // 삭제 후 방 할당 현황 동기화
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('데이터가 삭제되었습니다.'),
        backgroundColor: AppColors.statusRejected,
      ),
    );
  }

  // 에러 다이얼로그 표시 함수
  Future<void> _showErrorDialog(String content) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          title: Text(
            '알림',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.fontPrimary,
            ),
          ),
          content: Text(
            content,
            style: TextStyle(fontSize: 14.sp, color: AppColors.fontSecondary),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '확인',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 결과 다이얼로그 표시 함수
  Future<void> _showResultDialog(String title, String content) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.fontPrimary,
            ),
          ),
          content: Text(
            content,
            style: TextStyle(fontSize: 14.sp, color: AppColors.fontSecondary),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '확인',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 확인 팝업창 표시 함수
  Future<void> _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.fontPrimary,
            ),
          ),
          content: Text(
            content,
            style: TextStyle(fontSize: 14.sp, color: AppColors.fontSecondary),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '취소',
                style: TextStyle(
                  color: AppColors.fontSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
              child: Text(
                '확인',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // DB에서 룸메이트 신청 데이터 로드 (상태값 번역 추가)
  Future<void> _loadRoommateData() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/admin/roommate/requests'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // 데이터를 기존 형식에 맞게 변환
        _requests = [];
        _cumulativeData = [];

        for (var pairGroup in data) {
          // pair_id 그룹 내의 각 요청 처리
          if (pairGroup['requests'] != null &&
              pairGroup['requests'].isNotEmpty) {
            for (var requestData in pairGroup['requests']) {
              final englishStatus = requestData['status'];
              final koreanStatus = _translateStatusToKorean(
                englishStatus,
              ); // 영어 → 한국어 번역

              final request = {
                'id': requestData['id'],
                'applicantName': requestData['applicant_name'],
                'applicantId': requestData['applicant_id'],
                'partnerName': requestData['partner_name'],
                'partners': [
                  {
                    'id': requestData['partner_id'],
                    'name': requestData['partner_name'],
                  },
                ],
                'room': requestData['room_assigned'] ?? '',
                'status': koreanStatus, // 한국어 상태값으로 저장
                'memo': requestData['memo'] ?? '',
                'rejectionReason': requestData['rejection_reason'] ?? '',
                'tempStatus': null,
                'tempRoom': null,
                'pairId': pairGroup['pair_id'], // pair_id 정보 추가
                'roommateType':
                    pairGroup['roommate_type'], // roommate_type 정보 추가
              };

              // 상태에 따라 분류 (한국어 상태값 기준)
              if (koreanStatus == '배정완료' || koreanStatus == '반려') {
                _cumulativeData.add(request);
              } else {
                _requests.add(request);
              }
            }
          }
        }

        _syncRoomAssignments(); // 방 할당 현황 동기화
      } else {
        throw Exception('Failed to load roommate data');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('데이터를 불러오는데 실패했습니다: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 샘플 데이터 추가
  Future<void> _addSampleData() async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5050/api/admin/roommate/sample-data'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']),
            backgroundColor: AppColors.statusConfirmed,
          ),
        );
        _loadRoommateData(); // 데이터 새로고침
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('샘플 데이터 추가에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('네트워크 오류: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 이력 조회 처리
  Future<void> _showHistory(int requestId) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/roommate/history/$requestId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> historyData = json.decode(response.body);
        _showHistoryDialog(historyData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이력을 불러오는데 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이력 조회 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 이력 다이얼로그 표시
  void _showHistoryDialog(List<dynamic> historyData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          title: Text(
            '룸메이트 신청 이력',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
              color: AppColors.fontPrimary,
            ),
          ),
          content: SizedBox(
            width: 600.w,
            height: 500.h,
            child: ListView.builder(
              itemCount: historyData.length,
              itemBuilder: (context, index) {
                final history = historyData[index];
                return Card(
                  elevation: 0,
                  margin: EdgeInsets.symmetric(vertical: 4.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    title: Text(
                      history['change_reason'] ?? '상태 변경',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                        color: AppColors.fontPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8.h),
                        Text(
                          '이전 상태: ${_translateStatusToKorean(history['previous_status'] ?? '없음')}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.fontSecondary,
                          ),
                        ),
                        Text(
                          '변경 상태: ${_translateStatusToKorean(history['new_status'] ?? '없음')}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.fontSecondary,
                          ),
                        ),
                        Text(
                          '변경자: ${history['changed_by'] ?? '알 수 없음'}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.fontSecondary,
                          ),
                        ),
                        Text(
                          '변경 시간: ${history['created_at'] ?? '알 수 없음'}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.fontSecondary,
                          ),
                        ),
                        if (history['admin_memo'] != null &&
                            history['admin_memo'].isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            '관리자 메모: ${history['admin_memo']}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                        if (history['room_assigned'] != null &&
                            history['room_assigned'].isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            '배정된 방: ${history['room_assigned']}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    leading: Icon(
                      _getHistoryIcon(history['new_status']),
                      color: _getHistoryColor(history['new_status']),
                      size: 24.sp,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '닫기',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 이력 아이콘 반환
  IconData _getHistoryIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'confirmed':
        return Icons.verified;
      case 'cancelled':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  // 이력 색상 반환
  Color _getHistoryColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return AppColors.statusWaiting;
      case 'accepted':
        return AppColors.statusConfirmed;
      case 'rejected':
        return AppColors.statusRejected;
      case 'confirmed':
        return AppColors.primary;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
