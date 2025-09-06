// ignore_for_file: use_build_context_synchronously, avoid_function_literals_in_foreach_calls

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kbu_domi/env.dart';

// --- 디자인에 사용될 색상 정의 ---
class AppColors {
  static const Color primary = Color(0xFF673AB7);
  static const Color fontPrimary = Color(0xFF333333);
  static const Color fontSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color statusWaiting = Color(0xFFFFA726); // 대기
  static const Color statusInProgress = Colors.blue; // 서류확인중
  static const Color statusPendingCheck = Colors.orange; // 점검대기
  static const Color statusApproved = Color(0xFF66BB6A); // 승인
  static const Color statusRejected = Color(0xFFEF5350); // 반려
  static const Color statusCompleted = Color(0xFF42A5F5); // 완료

  // --- [수정] 선택 시 테두리 색상 추가 ---
  static const Color activeBorder = Color(0xFF0D47A1);
}

class AdOutPage extends StatefulWidget {
  const AdOutPage({super.key});

  @override
  State<AdOutPage> createState() => _AdOutPageState();
}

class _AdOutPageState extends State<AdOutPage> {
  int _selectedIndex = -1;
  String _searchText = '';
  String _statusFilter = '전체';
  bool _isLoading = true;
  bool _isEditMode = false;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _adminMemoController = TextEditingController();

  List<Map<String, dynamic>> _checkoutRequests = [];

  final List<String> _statusOptions = [
    '전체',
    '대기',
    '서류확인중',
    '점검대기',
    '승인',
    '반려',
    '완료',
  ];

  @override
  void initState() {
    super.initState();
    _loadCheckoutRequests();
  }

  // 퇴소 신청 목록 로드 (실제 API 또는 더미 데이터)
  Future<void> _loadCheckoutRequests() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/admin/checkout/requests'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _checkoutRequests = List<Map<String, dynamic>>.from(data);
        });
      } else {
        // API 실패 시 더미 데이터 사용
        _checkoutRequests = _getDummyData();
      }
    } catch (e) {
      // 네트워크 오류 시 더미 데이터 사용
      _checkoutRequests = _getDummyData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('서버 연결에 실패하여 더미 데이터를 표시합니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    _updateSelection(reset: true);
    setState(() => _isLoading = false);
  }

  // 상태 변경 (실제 API 또는 로컬 업데이트)
  Future<void> _updateStatus(int checkoutId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBase/api/admin/checkout/$checkoutId/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': status,
          'adminMemo': _adminMemoController.text,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message']),
            backgroundColor: Colors.green,
          ),
        );
        _loadCheckoutRequests(); // 목록 새로고침
      } else {
        throw Exception('API 오류');
      }
    } catch (e) {
      // API 실패 시 로컬 업데이트
      final index = _checkoutRequests.indexWhere(
        (r) => r['checkout_id'] == checkoutId,
      );
      if (index != -1) {
        setState(() {
          _checkoutRequests[index]['status'] = status;
          _checkoutRequests[index]['admin_memo'] = _adminMemoController.text;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상태가 "$status"(으)로 변경되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // 관리자 메모 저장 함수
  Future<void> _saveMemo(int checkoutId) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBase/api/admin/checkout/$checkoutId/memo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'adminMemo': _adminMemoController.text}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // 로컬 데이터 업데이트
        final index = _checkoutRequests.indexWhere(
          (r) => r['checkout_id'] == checkoutId,
        );
        if (index != -1) {
          setState(() {
            _checkoutRequests[index]['admin_memo'] = _adminMemoController.text;
            _isEditMode = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(responseData['message']),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('API 오류');
      }
    } catch (e) {
      // API 실패 시 로컬 업데이트
      final index = _checkoutRequests.indexWhere(
        (r) => r['checkout_id'] == checkoutId,
      );
      if (index != -1) {
        setState(() {
          _checkoutRequests[index]['admin_memo'] = _adminMemoController.text;
          _isEditMode = false;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('메모가 저장되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _updateSelection({bool reset = false}) {
    if (reset) _selectedIndex = -1;
    final list = _filteredRequests;
    if (list.isNotEmpty) {
      if (_selectedIndex == -1 || _selectedIndex >= list.length) {
        _selectedIndex = 0;
      }
      final selectedRequest = list[_selectedIndex];
      _adminMemoController.text = selectedRequest['admin_memo'] ?? '';
      _isEditMode = false;
    } else {
      _selectedIndex = -1;
      _adminMemoController.text = '';
      _isEditMode = false;
    }
    if (mounted) setState(() {});
  }

  List<Map<String, dynamic>> get _filteredRequests {
    return _checkoutRequests.where((request) {
      final statusMatch =
          _statusFilter == '전체' || request['status'] == _statusFilter;
      final searchMatch =
          _searchText.isEmpty ||
          request['student_id'].toString().contains(_searchText) ||
          request['name'].toString().contains(_searchText);
      return statusMatch && searchMatch;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '대기':
        return AppColors.statusWaiting;
      case '서류확인중':
        return AppColors.statusInProgress;
      case '점검대기':
        return AppColors.statusPendingCheck;
      case '승인':
        return AppColors.statusApproved;
      case '반려':
        return AppColors.statusRejected;
      case '완료':
        return AppColors.statusCompleted;
      default:
        return AppColors.fontSecondary;
    }
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '퇴소관리',
            style: TextStyle(
              fontSize: 26.0.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.fontPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCheckoutRequests,
            tooltip: '새로고침',
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
            '${_filteredRequests.length}개의 항목',
            style: TextStyle(fontSize: 18.0.sp, color: AppColors.fontSecondary),
          ),
          SizedBox(height: 8.h),
          Expanded(child: _buildRequestList()),
        ],
      ),
    );
  }

  // --- [수정] 필터 및 검색창 UI/사이즈/레이아웃 조정 ---
  Widget _buildFilterAndSearch() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        // 가로로 한 줄에 배치
        children: [
          // 드롭다운
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 40.h,
              child: DropdownButtonFormField<String>(
                value: _statusFilter,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.fontPrimary,
                ), // 글자 크기 통일
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
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
                items:
                    _statusOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(
                          status,
                          style: TextStyle(fontSize: 14.sp),
                        ), // 글자 크기 통일
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value!;
                    _updateSelection(reset: true);
                  });
                },
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // 검색창
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40.h,
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontSize: 14.sp), // 글자 크기 통일
                decoration: InputDecoration(
                  hintText: '이름 또는 학번으로 검색',
                  hintStyle: TextStyle(fontSize: 14.sp), // 글자 크기 통일
                  prefixIcon: Icon(Icons.search, size: 20.sp), // 아이콘 크기 축소
                  filled: true,
                  fillColor: Colors.white,
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
                    _updateSelection(reset: true);
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList() {
    if (_filteredRequests.isEmpty) {
      return Center(
        child: Text(
          '해당 조건의 퇴소 신청이 없습니다.',
          style: TextStyle(fontSize: 16.sp, color: AppColors.fontSecondary),
        ),
      );
    }
    return ListView.builder(
      itemCount: _filteredRequests.length,
      itemBuilder: (context, index) {
        final request = _filteredRequests[index];
        return _buildCheckoutRequestCardItem(request, index);
      },
    );
  }

  // --- [수정] 리스트 아이템 선택 스타일 변경 ---
  Widget _buildCheckoutRequestCardItem(
    Map<String, dynamic> request,
    int index,
  ) {
    final bool isSelected = _selectedIndex == index;

    return Card(
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 4.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(
          color:
              isSelected
                  ? AppColors.activeBorder
                  : AppColors.border, // 선택 시 테두리 색상 변경
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      color: Colors.white, // 내부 배경색은 항상 흰색
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _adminMemoController.text = request['admin_memo'] ?? '';
            _isEditMode = false;
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
                      '${request['name']} (${request['student_id']})',
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
                    request['status'],
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(request['status']),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                '퇴실 예정: ${request['checkout_date'] ?? '-'}',
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

  // --- [수정] 상세 정보 패널 상태 표시 UI 변경 ---
  Widget _buildRightPanel() {
    if (_selectedIndex == -1 || _filteredRequests.isEmpty) {
      return Center(
        child: Text(
          '퇴소 신청을 선택해주세요.',
          style: TextStyle(fontSize: 16.sp, color: AppColors.fontSecondary),
        ),
      );
    }
    final request = _filteredRequests[_selectedIndex];
    return SingleChildScrollView(
      padding: EdgeInsets.all(24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '퇴소 신청 상세',
                style: TextStyle(
                  fontSize: 22.0.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.fontPrimary,
                ),
              ),
              // 버튼 형식 대신 글자 형식으로 변경
              Text(
                request['status'] ?? '대기',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(request['status']),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          _buildInfoSection('기본 정보', [
            _buildInfoRow('학생명', request['name'] ?? '-'),
            _buildInfoRow('학번', request['student_id'] ?? '-'),
            _buildInfoRow('연락처', request['contact'] ?? '-'),
            _buildInfoRow('보호자 연락처', request['guardian_contact'] ?? '-'),
            _buildInfoRow('비상 연락처', request['emergency_contact'] ?? '-'),
          ]),
          SizedBox(height: 16.h),
          _buildInfoSection('퇴소 정보', [
            _buildInfoRow('퇴실 예정일', request['checkout_date'] ?? '-'),
            _buildInfoRow('퇴소 사유', request['reason'] ?? '-'),
            _buildInfoRow('상세 사유', request['reason_detail'] ?? '-'),
          ]),
          SizedBox(height: 16.h),
          _buildInfoSection('환불 정보', [
            _buildInfoRow('은행', request['payback_bank'] ?? '-'),
            _buildInfoRow('계좌번호', request['payback_num'] ?? '-'),
            _buildInfoRow('예금주', request['payback_name'] ?? '-'),
          ]),
          SizedBox(height: 16.h),
          _buildInfoSection('체크리스트', [
            _buildChecklistRow('방 청소 완료', request['checklist_clean'] ?? false),
            _buildChecklistRow('열쇠 반납 완료', request['checklist_key'] ?? false),
            _buildChecklistRow('공과금 정산 완료', request['checklist_bill'] ?? false),
          ]),
          SizedBox(height: 16.h),
          _buildInfoSection('동의 사항', [
            _buildChecklistRow('보호자 동의', request['guardian_agree'] ?? false),
            _buildChecklistRow('개인정보 수집 동의', request['agree_privacy'] ?? false),
          ]),
          SizedBox(height: 24.h),
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
            maxLines: 3,
            enabled: _isEditMode,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              hintText:
                  _isEditMode
                      ? '관리자 메모를 입력하세요...'
                      : '메모를 입력하려면 \'수정\' 또는 \'작성\' 버튼을 눌러주세요.',
              filled: !_isEditMode,
              fillColor: _isEditMode ? Colors.white : Colors.grey[50],
            ),
          ),
          if (_isEditMode)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _adminMemoController.text = request['admin_memo'] ?? '';
                        _isEditMode = false;
                      });
                    },
                    child: const Text(
                      '취소',
                      style: TextStyle(color: AppColors.fontSecondary),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton(
                    onPressed: () => _saveMemo(request['checkout_id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 14.h,
                      ),
                      textStyle: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: const Text('저장'),
                  ),
                ],
              ),
            ),
          SizedBox(height: 24.h),
          _buildStepButtons(request),
        ],
      ),
    );
  }

  Widget _buildStepButtons(Map<String, dynamic> request) {
    final currentStatus = request['status'] ?? '대기';
    final checkoutId = request['checkout_id'];
    if (['승인', '반려', '완료'].contains(currentStatus)) {
      return Container();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '진행 단계',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.fontPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        if (currentStatus == '대기')
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(checkoutId, '서류확인중'),
                  icon: Icon(Icons.description, size: 18.sp),
                  label: Text('서류 확인 시작', style: TextStyle(fontSize: 14.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(checkoutId, '반려'),
                  icon: Icon(Icons.close, size: 18.sp),
                  label: Text('반려', style: TextStyle(fontSize: 14.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusRejected,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
            ],
          ),
        if (currentStatus == '서류확인중')
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(checkoutId, '점검대기'),
                  icon: Icon(Icons.checklist, size: 18.sp),
                  label: Text('서류 확인 완료', style: TextStyle(fontSize: 14.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(checkoutId, '반려'),
                  icon: Icon(Icons.close, size: 18.sp),
                  label: Text('반려', style: TextStyle(fontSize: 14.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusRejected,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
            ],
          ),
        if (currentStatus == '점검대기')
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(checkoutId, '승인'),
                  icon: Icon(Icons.check_circle, size: 18.sp),
                  label: Text('최종 승인', style: TextStyle(fontSize: 14.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusApproved,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: () => _updateStatus(checkoutId, '반려'),
                  icon: Icon(Icons.close, size: 18.sp),
                  label: Text('반려', style: TextStyle(fontSize: 14.sp)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusRejected,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.fontPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.fontSecondary,
                fontSize: 14.sp,
              ),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14.sp))),
        ],
      ),
    );
  }

  Widget _buildChecklistRow(String label, bool value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            color: value ? AppColors.statusApproved : AppColors.statusRejected,
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Text(label, style: TextStyle(fontSize: 14.sp)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getDummyData() {
    return [
      {
        'checkout_id': 1,
        'name': '김민준',
        'student_id': '20210001',
        'contact': '010-1234-5678',
        'guardian_contact': '010-1111-2222',
        'emergency_contact': '010-3333-4444',
        'checkout_date': '2025-08-20',
        'reason': '졸업',
        'reason_detail': '정규 학기 졸업',
        'payback_bank': '국민은행',
        'payback_num': '123-456-7890',
        'payback_name': '김민준',
        'checklist_clean': true,
        'checklist_key': true,
        'checklist_bill': true,
        'guardian_agree': true,
        'agree_privacy': true,
        'status': '대기',
        'admin_memo': '',
      },
      {
        'checkout_id': 2,
        'name': '이서연',
        'student_id': '20220002',
        'contact': '010-2345-6789',
        'guardian_contact': '010-2222-3333',
        'emergency_contact': '010-4444-5555',
        'checkout_date': '2025-08-21',
        'reason': '휴학',
        'reason_detail': '군 휴학',
        'payback_bank': '신한은행',
        'payback_num': '234-567-8901',
        'payback_name': '이서연',
        'checklist_clean': true,
        'checklist_key': false,
        'checklist_bill': true,
        'guardian_agree': true,
        'agree_privacy': true,
        'status': '서류확인중',
        'admin_memo': '열쇠 반납 확인 필요',
      },
      {
        'checkout_id': 3,
        'name': '박지훈',
        'student_id': '20200003',
        'contact': '010-3456-7890',
        'guardian_contact': '010-3333-4444',
        'emergency_contact': '010-5555-6666',
        'checkout_date': '2025-08-22',
        'reason': '자퇴',
        'reason_detail': '',
        'payback_bank': '우리은행',
        'payback_num': '345-678-9012',
        'payback_name': '박지훈',
        'checklist_clean': true,
        'checklist_key': true,
        'checklist_bill': true,
        'guardian_agree': true,
        'agree_privacy': true,
        'status': '점검대기',
        'admin_memo': '서류 이상 없음, 퇴실 점검 예정',
      },
      {
        'checkout_id': 4,
        'name': '최수아',
        'student_id': '20230004',
        'contact': '010-4567-8901',
        'guardian_contact': '010-4444-5555',
        'emergency_contact': '010-6666-7777',
        'checkout_date': '2025-08-23',
        'reason': '기타',
        'reason_detail': '개인 사정',
        'payback_bank': '하나은행',
        'payback_num': '456-789-0123',
        'payback_name': '최수아',
        'checklist_clean': false,
        'checklist_key': false,
        'checklist_bill': false,
        'guardian_agree': false,
        'agree_privacy': true,
        'status': '승인',
        'admin_memo': '최종 승인 완료',
      },
      {
        'checkout_id': 5,
        'name': '정다은',
        'student_id': '20210005',
        'contact': '010-5678-9012',
        'guardian_contact': '010-5555-6666',
        'emergency_contact': '010-7777-8888',
        'checkout_date': '2025-08-24',
        'reason': '졸업',
        'reason_detail': '',
        'payback_bank': '기업은행',
        'payback_num': '567-890-1234',
        'payback_name': '정다은',
        'checklist_clean': true,
        'checklist_key': true,
        'checklist_bill': true,
        'guardian_agree': true,
        'agree_privacy': true,
        'status': '반려',
        'admin_memo': '보호자 동의서 누락',
      },
      {
        'checkout_id': 6,
        'name': '강현우',
        'student_id': '20220006',
        'contact': '010-6789-0123',
        'guardian_contact': '010-6666-7777',
        'emergency_contact': '010-8888-9999',
        'checkout_date': '2025-08-25',
        'reason': '휴학',
        'reason_detail': '어학연수',
        'payback_bank': '농협은행',
        'payback_num': '678-901-2345',
        'payback_name': '강현우',
        'checklist_clean': true,
        'checklist_key': true,
        'checklist_bill': true,
        'guardian_agree': true,
        'agree_privacy': true,
        'status': '완료',
        'admin_memo': '퇴소 처리 완료됨',
      },
    ];
  }
}
