// ignore_for_file: use_build_context_synchronously, avoid_function_literals_in_foreach_calls

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kbu_domi/env.dart';

// --- 디자인 개선을 위한 스타일 클래스 ---
class AppStyles {
  // 기본 색상
  static const Color background = Colors.white;
  static const Color primary = Color(0xFF0D47A1); // 주요 색상 (네이비)
  static const Color fontPrimary = Color(0xFF333333);
  static const Color fontSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color selectedBackground = Color(0xFFE3F2FD);
  static Color hoverBackground = Colors.grey.shade200;
  static Color pastCardBackground = Colors.grey.shade100;
  static const Color disabledBackground = Color(0xFFF5F5F5); // AdInPage에서 가져옴

  // 상태별 색상
  static const Color statusCancelled = Color(0xFFD32F2F); // 예약불가 (진빨강)
  static const Color statusConfirmed = Color(0xFF42A5F5); // 확정 (밝은 파랑)

  // 상태에 따른 텍스트/버튼 색상을 가져오는 함수
  static Color getStatusTextColor(String status) {
    switch (status) {
      case '대기':
        return fontSecondary; // 회색
      case '확정':
        return statusConfirmed; // 밝은 파랑
      case '예약불가':
        return statusCancelled; // 빨간색
      default:
        return fontPrimary; // 기본 검정
    }
  }
}

class AdVacationPage extends StatefulWidget {
  const AdVacationPage({super.key});

  @override
  State<AdVacationPage> createState() => _AdVacationPageState();
}

class _AdVacationPageState extends State<AdVacationPage> {
  int _selectedIndex = -1;
  String _filter = '전체';
  String _searchText = '';
  bool _isViewingHistory = false;
  bool _isLoading = false;

  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _allReservations = [];

  static const String baseUrl = '$apiBase';

  List<Map<String, dynamic>> get _filteredList {
    return _allReservations.where((r) {
      final searchMatch =
          _searchText.isEmpty ||
          r['studentId'].toString().contains(_searchText) ||
          r['studentName'].toString().contains(_searchText);
      if (!searchMatch) return false;

      final status = r['status'];
      final bool filterMatch = (_filter == '전체') ? true : (status == _filter);

      return filterMatch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchText != _searchController.text) {
        setState(() {
          _searchText = _searchController.text;
          _selectedIndex = -1;
        });
      }
    });
    _loadVacationData();
  }

  Future<void> _loadVacationData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String tab = _isViewingHistory ? '누적데이터' : '예약정보';
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/vacation/requests?tab=$tab'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          _allReservations =
              data.map((item) {
                return {
                  'reservation_id': item['reservation_id'],
                  'studentName': item['student_name'],
                  'studentId': item['student_id'],
                  'phone': item['student_phone'],
                  'department': null, // 사용하지 않음
                  'reserverName': item['reserver_name'],
                  'relation': item['reserver_relation'],
                  'reserverPhone': item['reserver_phone'],
                  'building': item['building'],
                  'room': item['room_type'],
                  'guest': '${item['guest_count']}명',
                  'checkIn': item['check_in_date'],
                  'checkOut': item['check_out_date'],
                  'amount': '${item['total_amount']}원',
                  'status': item['status'],
                  'reason': item['cancel_reason'] ?? '',
                  'admin_memo': item['admin_memo'] ?? '',
                  'tempStatus': null,
                };
              }).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load vacation data');
      }
    } catch (e) {
      print('방학이용 데이터 로드 오류: $e');
      // 오류 발생 시 빈 리스트로 설정
      setState(() {
        _allReservations = [];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터를 불러오는데 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _selectItem(int index) {
    setState(() {
      if (_selectedIndex == index) {
        _selectedIndex = -1;
      } else {
        _selectedIndex = index;
        _allReservations.forEach((res) => res['tempStatus'] = null);
        final selectedItem = _filteredList[index];
        _reasonController.text = selectedItem['reason'] ?? '';
      }
    });
  }

  void _saveChanges() async {
    if (_selectedIndex < 0 || _selectedIndex >= _filteredList.length) return;

    final selectedRequest = _filteredList[_selectedIndex];
    final String? tempStatus = selectedRequest['tempStatus'];
    final String studentName = selectedRequest['studentName'] ?? '이름 없음';
    final int reservationId = selectedRequest['reservation_id'];

    if (tempStatus == '예약불가' && _reasonController.text.trim().isEmpty) {
      _showErrorDialog(context, '\'예약불가\' 처리 시에는 반드시 불가 사유를 입력해야 합니다.');
      return;
    }

    final String finalStatus = tempStatus ?? selectedRequest['status'];
    final bool? confirmed = await _showConfirmationDialog(context, finalStatus);

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await http.put(
          Uri.parse(
            '$baseUrl/api/admin/vacation/request/$reservationId/status',
          ),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'status': finalStatus,
            'admin_memo': selectedRequest['admin_memo'] ?? '',
            'cancel_reason': _reasonController.text.trim(),
          }),
        );

        if (response.statusCode == 200) {
          // 성공 시 데이터 다시 로드
          await _loadVacationData();

          setState(() {
            _selectedIndex = -1;
          });

          if (mounted) {
            if (finalStatus == '확정') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$studentName 학생의 예약이 확정되었습니다.'),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (finalStatus == '예약불가') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$studentName 학생의 예약이 취소되었습니다.'),
                  backgroundColor: Colors.red,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('변경 사항이 저장되었습니다.'),
                  backgroundColor: AppStyles.primary,
                ),
              );
            }
          }
        } else {
          final errorData = json.decode(response.body);
          throw Exception(errorData['error'] ?? '상태 업데이트에 실패했습니다.');
        }
      } catch (e) {
        print('상태 업데이트 오류: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('상태 업데이트에 실패했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool?> _showConfirmationDialog(
    BuildContext context,
    String newStatus,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          title: Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                color: AppStyles.primary,
                size: 28.sp,
              ),
              SizedBox(width: 10.w),
              Text(
                '변경사항 저장 확인',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.fontPrimary,
                ),
              ),
            ],
          ),
          content: Text(
            '신청 정보를 \'$newStatus\' 상태로 저장하시겠습니까?',
            style: TextStyle(
              fontSize: 16.sp,
              color: AppStyles.fontSecondary,
              height: 1.5,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                '취소',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppStyles.fontSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                '확인',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppStyles.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showErrorDialog(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700),
              SizedBox(width: 10.w),
              Text(
                '알림',
                style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(
              fontSize: 16.sp,
              color: AppStyles.fontSecondary,
              height: 1.5,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                '확인',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: AppStyles.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex != -1 && _selectedIndex >= _filteredList.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedIndex = -1;
        });
      });
    }

    return Scaffold(
      backgroundColor: AppStyles.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppStyles.border, width: 1.w),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        Expanded(flex: 3, child: _buildLeftPanel()),
                        Divider(
                          height: 1.w,
                          color: AppStyles.border,
                          thickness: 1,
                        ),
                        Expanded(flex: 4, child: _buildRightPanel()),
                      ],
                    );
                  } else {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: _buildLeftPanel()),
                        VerticalDivider(
                          width: 1.w,
                          color: AppStyles.border,
                          thickness: 1,
                        ),
                        Expanded(flex: 5, child: _buildRightPanel()),
                      ],
                    );
                  }
                },
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '방학이용 관리',
            style: TextStyle(
              fontSize: 26.0.sp,
              fontWeight: FontWeight.bold,
              color: AppStyles.fontPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterAndSearch(),
          SizedBox(height: 16.h),
          Text(
            '${_filteredList.length}개의 항목',
            style: TextStyle(fontSize: 18.0.sp, color: AppStyles.fontSecondary),
          ),
          SizedBox(height: 8.h),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppStyles.primary,
                        ),
                      ),
                    )
                    : _filteredList.isEmpty
                    ? Center(
                      child: Text(
                        '표시할 항목이 없습니다.',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: AppStyles.fontSecondary,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) {
                        final r = _filteredList[index];
                        return _buildRequestCardItem(r, index);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearch() {
    final filters = ['전체', '대기', '확정', '예약불가'];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "필터 및 검색",
            style: TextStyle(
              fontSize: 14.sp, // 글자 크기 통일
              fontWeight: FontWeight.bold,
              color: AppStyles.fontPrimary,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Container(
                height: 40.h,
                width: 150.w,
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                decoration: BoxDecoration(
                  color: AppStyles.background,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppStyles.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _filter,
                    isExpanded: true,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: AppStyles.fontSecondary,
                    ),
                    style: TextStyle(
                      fontSize: 14.sp, // 글자 크기 통일
                      color: AppStyles.fontPrimary,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _filter = newValue;
                          _selectedIndex = -1;
                        });
                      }
                    },
                    items:
                        filters.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              ChoiceChip(
                label: Text(
                  '과거 이력 조회',
                  style: TextStyle(
                    fontSize: 14.sp, // 글자 크기 통일
                    fontWeight:
                        _isViewingHistory ? FontWeight.bold : FontWeight.normal,
                    color:
                        _isViewingHistory
                            ? AppStyles.primary
                            : AppStyles.fontPrimary,
                  ),
                ),
                selected: _isViewingHistory,
                onSelected: (bool selected) {
                  setState(() {
                    _isViewingHistory = selected;
                    _filter = '전체';
                    _selectedIndex = -1;
                  });
                  _loadVacationData(); // 데이터 다시 로드
                },
                selectedColor: AppStyles.primary.withOpacity(0.1),
                backgroundColor: AppStyles.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  side: BorderSide(
                    color:
                        _isViewingHistory
                            ? AppStyles.primary
                            : AppStyles.border,
                  ),
                ),
                showCheckmark: false,
              ),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 40.h,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, size: 20.sp),
                hintText: '이름 또는 학번으로 검색',
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: AppStyles.fontSecondary.withOpacity(0.7),
                ),
                filled: true,
                fillColor: AppStyles.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: AppStyles.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: AppStyles.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: BorderSide(color: AppStyles.primary, width: 1.5),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCardItem(Map<String, dynamic> r, int index) {
    final bool isSelected = _selectedIndex == index;
    final String displayStatus = r['tempStatus'] ?? r['status'];

    Color cardColor;
    if (isSelected) {
      cardColor = AppStyles.selectedBackground;
    } else if (_isViewingHistory) {
      cardColor = AppStyles.pastCardBackground;
    } else {
      cardColor = AppStyles.background;
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 4.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(
          color: isSelected ? AppStyles.primary : AppStyles.border,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      color: cardColor,
      child: InkWell(
        onTap: () => _selectItem(index),
        borderRadius: BorderRadius.circular(8.r),
        hoverColor: AppStyles.hoverBackground,
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
                      '${r['studentName']}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.fontPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    displayStatus,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.getStatusTextColor(displayStatus),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                '${r['studentId']} | ${r['phone']}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppStyles.fontSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    if (_selectedIndex == -1 || _filteredList.isEmpty) {
      return Center(
        child: Text(
          '좌측 목록에서 항목을 선택해주세요.',
          style: TextStyle(fontSize: 18.0.sp, color: AppStyles.fontSecondary),
        ),
      );
    }

    final r = _filteredList[_selectedIndex];
    final bool isReadOnly = _isViewingHistory;
    final String displayStatus = r['tempStatus'] ?? r['status'];
    final String? tempStatus = r['tempStatus'];

    final bool isReasonFieldEnabled = !isReadOnly && (tempStatus == '예약불가');

    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '신청 정보',
                        style: TextStyle(
                          fontSize: 22.0.sp,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.fontPrimary,
                        ),
                      ),
                      Text(
                        displayStatus,
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: AppStyles.getStatusTextColor(displayStatus),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // 방학이용 신청 정보 필드들
                  _buildInfoFieldContainer(
                    children: [
                      _buildInfoFieldWithLabelAbove(
                        '학생 이름',
                        r['studentName'] ?? '',
                      ),
                      _buildInfoFieldWithLabelAbove('학번', r['studentId'] ?? ''),
                      _buildInfoFieldWithLabelAbove(
                        '학생 전화번호',
                        r['phone'] ?? '',
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  _buildInfoFieldContainer(
                    children: [
                      _buildInfoFieldWithLabelAbove(
                        '예약자 이름',
                        r['reserverName'] ?? '',
                      ),
                      _buildInfoFieldWithLabelAbove('관계', r['relation'] ?? ''),
                      _buildInfoFieldWithLabelAbove(
                        '예약자 전화번호',
                        r['reserverPhone'] ?? '',
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  _buildInfoFieldContainer(
                    children: [
                      _buildInfoFieldWithLabelAbove('건물', r['building'] ?? ''),
                      _buildInfoFieldWithLabelAbove('인실', r['room'] ?? ''),
                      _buildInfoFieldWithLabelAbove('입실 인원', r['guest'] ?? ''),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  _buildInfoFieldContainer(
                    children: [
                      _buildInfoFieldWithLabelAbove('입실일', r['checkIn']),
                      _buildInfoFieldWithLabelAbove('퇴실일', r['checkOut']),
                      _buildInfoFieldWithLabelAbove('금액', r['amount']),
                    ],
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Divider(color: AppStyles.border, thickness: 1.h),
                  ),

                  _buildMemoField(
                    _reasonController,
                    label: '예약불가 사유',
                    hint: '예약불가 선택 시 사유를 입력하세요...',
                    enabled: isReasonFieldEnabled,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),
          if (!isReadOnly) _buildActionButtons(),
        ],
      ),
    );
  }

  // AdInPage의 _buildSectionTitle 함수를 복사하여 사용
  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppStyles.fontPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Divider(color: AppStyles.border, thickness: 1.h),
      ],
    );
  }

  // AdInPage의 _buildInfoFieldWithLabelAbove 함수를 복사하여 사용
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
          color: AppStyles.fontPrimary,
          fontWeight: FontWeight.normal,
        ),
        decoration: InputDecoration(
          labelText: label, // 라벨 텍스트
          labelStyle: TextStyle(
            fontSize: 10.sp, // 라벨 폰트 크기
            color: AppStyles.fontSecondary,
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
                  ? AppStyles.disabledBackground
                  : AppStyles.disabledBackground, // 회색 배경
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(color: AppStyles.border, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            // readOnly일 때의 테두리
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(color: AppStyles.border, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            // 포커스 시 테두리 (readOnly여도 포커스 스타일 적용 가능)
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(
              color: AppStyles.primary,
              width: 1.0,
            ), // 클릭 시 색상 변경
          ),
        ),
      ),
    );
  }

  // AdInPage의 _buildInfoFieldContainer 함수를 복사하여 사용
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

  // _buildMemoField 스타일을 AdInPage와 일치하도록 수정
  Widget _buildMemoField(
    TextEditingController controller, {
    required String label,
    required String hint,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16.sp, // AdInPage와 동일
            fontWeight: FontWeight.bold, // AdInPage와 동일
            color: AppStyles.fontPrimary, // AdInPage와 동일
          ),
        ),
        SizedBox(height: 8.h),
        SizedBox(
          height: 100.h, // AdInPage와 동일
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            enabled: enabled,
            style: TextStyle(fontSize: 16.sp, color: AppStyles.fontPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 16.sp,
                color: AppStyles.fontSecondary.withOpacity(0.6),
              ),
              contentPadding: EdgeInsets.all(12.w),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: AppStyles.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: AppStyles.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: AppStyles.primary),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
                borderSide: BorderSide(color: AppStyles.border),
              ),
              filled: !enabled, // 활성화되지 않았을 때만 채움
              fillColor: AppStyles.disabledBackground, // 배경색 통일
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_selectedIndex == -1 || _filteredList.isEmpty)
      return const SizedBox.shrink();

    final selectedRequest = _filteredList[_selectedIndex];
    final String currentDisplayStatus =
        selectedRequest['tempStatus'] ?? selectedRequest['status'];

    final buttonPadding = EdgeInsets.symmetric(
      horizontal: 20.w,
      vertical: 13.h,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.r),
    );
    final buttonTextStyle = TextStyle(
      fontSize: 16.sp,
      fontWeight: FontWeight.w600,
    );

    final statusActions = ['대기', '확정', '예약불가'];

    return Row(
      children: [
        ...statusActions.map((status) {
          final targetStatus = status;
          final isButtonSelected = currentDisplayStatus == targetStatus;

          return Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: ElevatedButton(
              onPressed: () => _updateTempStatus(selectedRequest, targetStatus),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isButtonSelected
                        ? AppStyles.getStatusTextColor(targetStatus)
                        : Colors.white,
                foregroundColor:
                    isButtonSelected ? Colors.white : AppStyles.fontSecondary,
                padding: buttonPadding,
                shape: buttonShape,
                textStyle: buttonTextStyle,
                side:
                    isButtonSelected
                        ? BorderSide.none
                        : BorderSide(color: AppStyles.border, width: 1.5),
                elevation: isButtonSelected ? 2 : 0,
              ),
              child: Text(status),
            ),
          );
        }).toList(),
        const Spacer(),
        ElevatedButton(
          onPressed: _saveChanges,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppStyles.primary,
            foregroundColor: Colors.white,
            padding: buttonPadding,
            shape: buttonShape,
            textStyle: buttonTextStyle,
          ),
          child: const Text('저장'),
        ),
      ],
    );
  }

  void _updateTempStatus(Map<String, dynamic> request, String status) {
    setState(() {
      if (request['tempStatus'] == status) {
        request['tempStatus'] = null;
      } else {
        request['tempStatus'] = status;
      }
    });
  }
}
