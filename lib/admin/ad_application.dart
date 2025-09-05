// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

// --- 디자인에 사용될 색상 정의 ---
class AppColors {
  static const Color background = Colors.white;
  static const Color primary = Color(0xFF673AB7);
  static const Color fontPrimary = Color(0xFF333333);
  static const Color fontSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color statusAutoSelected = Color(0xFF9C27B0); // 자동선발 (보라)
  static const Color statusRejected = Color(0xFFEF5350); // 미선발 (빨강)
  static const Color activeBorder = Color(0xFF0D47A1);
  static const Color statusAssigned = Color(0xFF42A5F5);
  static const Color statusUnassigned = Color(0xFF757575);
  static const Color genderFemale = Color(0xFFEC407A);
  static const Color disabledBackground = Color(0xFFF5F5F5);
  static const Color statusWaiting = Color(0xFFFFA726);
  static const Color statusConfirmed = Color(0xFF66BB6A);
}

class AdApplicationPage extends StatefulWidget {
  const AdApplicationPage({super.key});

  @override
  State<AdApplicationPage> createState() => _AdApplicationPageState();
}

class _AdApplicationPageState extends State<AdApplicationPage>
    with AutomaticKeepAliveClientMixin {
  int _selectedIndex = -1;
  String _searchText = '';
  List<Map<String, dynamic>> _allApplications = [];
  List<Map<String, dynamic>> _filteredApplications = [];
  String _currentFilterStatus = '전체';

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _adminMemoController = TextEditingController();

  bool _isLoading = true;
  bool _isCalculatingDistance = false;
  bool _isMemoEditing = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitialApplications();
  }

  Future<void> _showErrorDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('확인'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // 전체 신입생 신청 목록 로드
  Future<void> _loadInitialApplications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/admin/firstin/applications'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _allApplications = List<Map<String, dynamic>>.from(data);
          _filterAndSortApplications();
          _isLoading = false;
        });
      } else {
        throw Exception('신청 목록을 불러오는데 실패했습니다.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog('데이터 로딩 오류: $e');
    }
  }

  // 거리 계산 및 자동 선별 기능 - API 호출 복원
  Future<void> _calculateDistancesAndSelect() async {
    setState(() => _isCalculatingDistance = true);
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5050/api/admin/firstin/distance-calculate'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '거리 계산 완료: ${data['total_calculated']}명 계산, 상위 ${data['top_selected']}명 자동선별됨',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _loadInitialApplications();
        setState(() {
          _currentFilterStatus = '자동선별';
          _filterAndSortApplications();
        });
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['error'] ?? '거리 계산 중 오류가 발생했습니다.');
      }
    } catch (e) {
      _showErrorDialog('거리 계산 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isCalculatingDistance = false);
      }
    }
  }

  // 승인 기능 (자동선별된 학생을 승인)
  Future<void> _manualSelect() async {
    if (_selectedIndex == -1 || _filteredApplications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('승인할 학생을 선택하세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedApp = _filteredApplications[_selectedIndex];
    if (selectedApp['status'] == '승인') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 승인된 학생입니다.'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final int originalId = int.parse(
      selectedApp['id'].toString().replaceAll('app', ''),
    );

    try {
      final response = await http.put(
        Uri.parse(
          'http://localhost:5050/api/admin/firstin/application/$originalId',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': '승인',
          'admin_memo': _adminMemoController.text,
        }),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedApp['name']} 학생이 승인되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadInitialApplications();
        setState(() {
          _selectedIndex = -1;
        });
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['error'] ?? '상태 업데이트 중 오류가 발생했습니다.');
      }
    } catch (e) {
      _showErrorDialog('승인 실패: $e');
    }
  }

  // 선별제외 기능 (신청 상태로 되돌리기)
  Future<void> _cancelSelection() async {
    if (_selectedIndex == -1 || _filteredApplications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('선별제외할 학생을 선택하세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedApp = _filteredApplications[_selectedIndex];

    final int originalId = int.parse(
      selectedApp['id'].toString().replaceAll('app', ''),
    );

    try {
      final response = await http.put(
        Uri.parse(
          'http://localhost:5050/api/admin/firstin/application/$originalId',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': '신청',
          'admin_memo': _adminMemoController.text,
        }),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedApp['name']} 학생이 선별제외되어 신청 상태로 되돌렸습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadInitialApplications();
        setState(() {
          _selectedIndex = -1;
        });
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['error'] ?? '상태 업데이트 중 오류가 발생했습니다.');
      }
    } catch (e) {
      _showErrorDialog('선별제외 실패: $e');
    }
  }

  // 관리자 메모만 저장하는 함수 - API 호출 복원
  Future<void> _saveAdminMemo() async {
    if (_selectedIndex == -1 || _filteredApplications.isEmpty) return;

    final app = _filteredApplications[_selectedIndex];
    final int originalId = int.parse(
      app['id'].toString().replaceAll('app', ''),
    );

    try {
      final response = await http.put(
        Uri.parse(
          'http://localhost:5050/api/admin/firstin/application/$originalId',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'admin_memo': _adminMemoController.text}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('관리자 메모가 저장되었습니다.'),
            backgroundColor: Colors.blue,
          ),
        );
        await _loadInitialApplications();
        setState(() {
          _isMemoEditing = false;
        });
      } else {
        final errorData = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorData['error'] ?? '메모 저장 중 오류가 발생했습니다.');
      }
    } catch (e) {
      _showErrorDialog('메모 저장 실패: $e');
    }
  }

  // 데이터 필터링
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

      _selectedIndex = -1;
      _updateSelection();
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
      _isMemoEditing = false;
    } else {
      _selectedIndex = -1;
      _adminMemoController.clear();
      _isMemoEditing = false;
    }
    if (mounted) setState(() {});
  }

  final List<String> _statusOptions = ['전체', '신청', '자동선별', '개별승인', '선별제외'];

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
                  _getApprovalButtonText(),
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
                  '선별제외',
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
                  _isCalculatingDistance ? '계산 중...' : '거리 기준 자동선별',
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

  Widget _buildRightPanel() {
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
          child: Row(children: [_buildRightPanelTabButton('신청 정보')]),
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
                    : _buildSingleStudentDetails(selectedApp),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanelTabButton(String tabName) {
    const bool isSelected = true;

    return GestureDetector(
      onTap: () {},
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
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

  Widget _buildSingleStudentDetails(Map<String, dynamic> student) {
    final bool isKoreanNational =
        student['nationality'] == '대한민국' && student['applicant_type'] == '내국인';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Row(
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
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '모집구분',
              student['recruit_type'] ?? 'N/A',
              isGreyed: true,
            ),
            _buildInfoFieldWithLabelAbove(
              '학년도',
              student['year']?.toString() ?? 'N/A',
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
            _buildInfoFieldWithLabelAbove('성명', student['name'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove('학번', student['student_id'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove('학과', student['department'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove(
              '학년',
              student['grade']?.toString() ?? 'N/A',
            ),
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
              student['smoking_status'] ?? '비흡연',
            ),
            _buildInfoFieldWithLabelAbove(
              '지역구분',
              student['region_type'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '기초생활수급',
              student['basic_living_support'] == true ? '수급자' : '일반',
            ),
            _buildInfoFieldWithLabelAbove(
              '장애여부',
              student['disabled'] == true ? '장애인' : '일반',
            ),
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
            _buildInfoFieldWithLabelAbove('기본주소', student['address'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove(
              '상세주소',
              student['address_detail'] ?? 'N/A',
            ),
            const SizedBox.shrink(),
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
            if (student['distance'] != null && student['distance'] > 0)
              _buildInfoFieldWithLabelAbove('거리', '${student['distance']}km')
            else
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
              student['par_name'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '보호자 관계',
              student['par_relation'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '보호자 전화번호',
              student['par_phone'] ?? 'N/A',
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
              student['dorm_building'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove('방타입', student['room_type'] ?? 'N/A'),
            const SizedBox.shrink(),
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

  Widget _buildInfoFieldWithLabelAbove(
    String label,
    String value, {
    bool isGreyed = false,
  }) {
    final TextEditingController _tempController = TextEditingController(
      text: value,
    );

    return SizedBox(
      height: 38.h,
      child: TextFormField(
        controller: _tempController,
        readOnly: true,
        style: TextStyle(
          fontSize: 13.sp,
          color: AppColors.fontPrimary,
          fontWeight: FontWeight.normal,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 10.sp,
            color: AppColors.fontSecondary,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: EdgeInsets.fromLTRB(10.w, 15.h, 10.w, 5.h),
          filled: true,
          fillColor: isGreyed ? AppColors.disabledBackground : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(color: AppColors.border, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(color: AppColors.border, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(color: AppColors.primary, width: 1.0),
          ),
        ),
      ),
    );
  }

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
            if (!_isMemoEditing)
              TextButton(
                onPressed: () => setState(() => _isMemoEditing = true),
                child: const Text('작성'),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _adminMemoController,
          enabled: _isMemoEditing,
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
            filled: !_isMemoEditing,
            fillColor: AppColors.disabledBackground,
          ),
        ),
        SizedBox(height: 16.h),
        if (_isMemoEditing)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _saveAdminMemo,
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
                        app['status'] ?? '미확인',
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

  Color _getStatusColor(String? status) {
    switch (status) {
      case '자동선별':
        return AppColors.statusAutoSelected;
      case '개별승인':
        return AppColors.statusConfirmed;
      case '선별제외':
        return AppColors.statusRejected;
      case '신청':
      default:
        return AppColors.fontSecondary;
    }
  }

  String _getApprovalButtonText() {
    return '개별승인';
  }
}
