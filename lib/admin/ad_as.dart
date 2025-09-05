import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class AdAsPage extends StatefulWidget {
  const AdAsPage({super.key});

  @override
  State<AdAsPage> createState() => _AdAsPageState();
}

class _AdAsPageState extends State<AdAsPage> {
  ASDataSource? _asDataSource;
  final List<ASRequest> _asRequests = [];
  List<ASRequest> _filteredRequests = [];
  final Set<String> _selectedUuids = {};
  bool _isLoading = true;

  // ▼ 필터 상태(통계 카드/드롭다운 공유)
  String _selectedStatus = '전체';
  String _selectedCategory = '전체';

  String _bulkStatus = '상태 변경';
  final TextEditingController _searchController = TextEditingController();
  String? _expandedRowUuid;

  // 행별 확장 가능 여부 저장
  final Map<String, bool> _isRowExpandable = {};

  // 통계
  Map<String, int> _statusCounts = {};
  int _totalRequests = 0;

  // 공지
  Map<String, dynamic>? _notice;
  final TextEditingController _noticeContentController =
      TextEditingController();

  static const List<String> _statusList = [
    '전체',
    '대기중',
    '접수',
    '처리중',
    '완료',
    '반려',
  ];
  static const List<String> _categoryList = [
    '전체',
    '침대',
    '책상',
    '의자',
    '옷장',
    '신발장',
    '커튼',
    '전등',
    '콘센트',
    '창문',
    '문',
    '기타',
  ];
  static const List<String> _bulkStatusList = ['접수', '대기중', '처리중', '완료', '반려'];

  // 카드 공통 스타일(점호 페이지 톤)
  final BorderRadius _cardRadius = BorderRadius.circular(12.r);
  final List<BoxShadow> _cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadASRequests();
    _loadNotice();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noticeContentController.dispose();
    super.dispose();
  }

  // 통계 계산
  void _calculateStatistics() {
    _statusCounts.clear();
    _totalRequests = _asRequests.length;

    for (final request in _asRequests) {
      _statusCounts[request.status] = (_statusCounts[request.status] ?? 0) + 1;
    }
  }

  Future<void> _loadASRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/as/requests/all'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        _asRequests
          ..clear()
          ..addAll(data.map((item) => ASRequest.fromJson(item)));
        _calculateStatistics();
        _applyFilter();
      } else {
        throw Exception('Failed to load AS requests');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터를 불러오는데 실패했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 통계 카드 클릭 → 필터 반영(드롭다운 동기화)
  void _onStatTap(String statusLabel) {
    setState(() {
      _selectedStatus = statusLabel;
      _applyFilter();
    });
  }

  void _onRowSelect(String uuid, bool selected) {
    setState(() {
      if (selected) {
        _selectedUuids.add(uuid);
      } else {
        _selectedUuids.remove(uuid);
      }
    });
  }

  void _onSelectAll(bool? selected) {
    if (selected == true) {
      setState(() {
        _selectedUuids.addAll(_filteredRequests.map((r) => r.uuid));
      });
    } else {
      setState(() {
        _selectedUuids.clear();
      });
    }
  }

  void _applyBulkStatus() async {
    if (_bulkStatus == '상태 변경' || _selectedUuids.isEmpty) return;
    setState(() => _isLoading = true);

    if (_bulkStatus == '반려') {
      final reason = await _showBulkRejectionDialog();
      if (reason == null) {
        setState(() => _isLoading = false);
        return;
      }
      for (final uuid in _selectedUuids) {
        await _updateRequestStatus(uuid, _bulkStatus, rejectionReason: reason);
      }
    } else {
      for (final uuid in _selectedUuids) {
        await _updateRequestStatus(uuid, _bulkStatus);
      }
    }

    _selectedUuids.clear();
    _bulkStatus = '상태 변경';
    await _loadASRequests();
    setState(() => _isLoading = false);
  }

  void _applyFilter() {
    final search = _searchController.text.trim();
    _filteredRequests =
        _asRequests.where((req) {
          final matchesStatus =
              _selectedStatus == '전체' || req.status == _selectedStatus;
          final matchesCategory =
              _selectedCategory == '전체' || req.category == _selectedCategory;
          final matchesSearch =
              search.isEmpty ||
              req.studentId.contains(search) ||
              req.name.contains(search);
          return matchesStatus && matchesCategory && matchesSearch;
        }).toList();

    _updateExpandableRows();

    setState(() {
      _asDataSource = ASDataSource(
        _filteredRequests,
        _selectedUuids,
        _onRowSelect,
        _showStatusUpdateDialog,
        _showAttachmentsDialog,
        _expandedRowUuid,
        _isRowExpandable,
      );
    });
  }

  void _updateExpandableRows() {
    _isRowExpandable.clear();
    const int descriptionMaxChars = 25;

    for (var req in _filteredRequests) {
      _isRowExpandable[req.uuid] = req.description.length > descriptionMaxChars;
    }
  }

  // 공지사항 로드/저장
  Future<void> _loadNotice() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/admin/notice?category=as'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _notice = data;
          _noticeContentController.text = data['content'] ?? '';
        });
      }
    } catch (_) {
      /* ignore */
    }
  }

  Future<void> _saveNotice(String content) async {
    try {
      final isUpdate = _notice != null && _notice!['id'] != null;
      final url =
          isUpdate
              ? 'http://localhost:5050/api/admin/notice/${_notice!['id']}'
              : 'http://localhost:5050/api/admin/notice';

      final body = json.encode({
        'title': 'AS 공지사항',
        'content': content,
        'category': 'as',
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('공지사항이 저장되었습니다.')));
        }
      } else {
        throw Exception('Failed to save notice: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('공지사항 저장에 실패했습니다: $e')));
      }
    }
  }

  Future<void> _updateRequestStatus(
    String uuid,
    String newStatus, {
    String? rejectionReason,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('http://localhost:5050/api/as/request/$uuid/status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': newStatus,
          'rejection_reason': rejectionReason,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update status');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('상태 업데이트에 실패했습니다: $e')));
      }
    }
  }

  Future<String?> _showBulkRejectionDialog() {
    final TextEditingController rejectionReasonController =
        TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('일괄 반려 사유 입력'),
            content: TextField(
              controller: rejectionReasonController,
              decoration: const InputDecoration(
                labelText: '반려 사유',
                hintText: '모든 선택된 항목에 동일한 사유가 적용됩니다.',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, rejectionReasonController.text);
                },
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  // 첨부파일 보기 다이얼로그
  void _showAttachmentsDialog(ASRequest request) {
    if (!request.hasAttachments || request.attachments.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('첨부파일이 없습니다.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          title: Text(
            '첨부 파일 (${request.attachments.length}개)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 500.w,
            height: 400.h,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                childAspectRatio: 1.0,
              ),
              itemCount: request.attachments.length,
              itemBuilder: (context, index) {
                final attachment = request.attachments[index];
                final imageUrl = attachment['url'] as String? ?? '';

                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: InteractiveViewer(
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: Center(
                                        child: Icon(
                                          Icons.error,
                                          color: Colors.red,
                                          size: 48.sp,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          blurRadius: 4.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey.shade600,
                                size: 40.sp,
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                strokeWidth: 3.w,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.blue,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '닫기',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showStatusUpdateDialog(ASRequest request) {
    final TextEditingController rejectionReasonController =
        TextEditingController();
    String newStatus = request.status;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              title: Text(
                'AS 상태 변경',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 400.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        children: [
                          Text(
                            request.name,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${request.studentId} / ${request.building} ${request.roomNumber}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    DropdownButtonFormField2<String>(
                      isExpanded: true,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(vertical: 16.h),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: Colors.blueAccent,
                            width: 1.5,
                          ),
                        ),
                      ),
                      value: newStatus,
                      items:
                          _bulkStatusList
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Center(
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setStateInDialog(() => newStatus = value);
                        }
                      },
                      buttonStyleData: ButtonStyleData(
                        padding: EdgeInsets.only(right: 8.w),
                      ),
                      dropdownStyleData: DropdownStyleData(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (newStatus == '반려') ...[
                      SizedBox(height: 16.h),
                      TextField(
                        controller: rejectionReasonController,
                        decoration: InputDecoration(
                          hintText: '반려 사유를 입력하세요...',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _updateRequestStatus(
                            request.uuid,
                            newStatus,
                            rejectionReason:
                                newStatus == '반려'
                                    ? rejectionReasonController.text
                                    : null,
                          );
                          await _loadASRequests();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('상태가 업데이트되었습니다.')),
                            );
                          }
                        },
                        child: Text(
                          '저장',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 점호 페이지와 동일하게 all(24) 적용
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: 16.h),
            _buildStatisticsCards(), // 점호 스타일의 통계 카드 + 클릭 필터
            SizedBox(height: 16.h),
            _buildFilterBar(),
            SizedBox(height: 8.h),
            Expanded(
              child:
                  _isLoading || _asDataSource == null
                      ? const Center(child: CircularProgressIndicator())
                      : _buildDataGrid(),
            ),
            _buildBulkActionRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // 점호 헤더와 유사한 레이아웃/사이즈
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'A/S 신청 관리',
          style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _showNoticeDialog,
              icon: Icon(Icons.announcement, size: 16.w),
              label: const Text('공지사항'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange,
                elevation: 0,
                side: const BorderSide(color: Color(0xFFFFCC80)),
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
            ElevatedButton.icon(
              onPressed: _loadASRequests,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0D47A1),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFE0E0E0)),
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
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // 점호 스타일의 상단 통계 카드 (클릭 시 상태 필터링 + 드롭다운 동기화)
  // ─────────────────────────────────────────────────────────
  Widget _buildStatisticsCards() {
    Widget card({
      required IconData icon,
      required Color color,
      required String title,
      required String value,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: 12.w),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _cardRadius,
              boxShadow: _cardShadow,
              border: Border.all(
                color: selected ? color : const Color(0xFFE0E0E0),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        value,
                        style: TextStyle(
                          color: Colors.black87,
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

    const totalColor = Color(0xFF0D47A1);
    const waitingColor = Color(0xFFFFB300);
    const processingColor = Color(0xFF1976D2);
    const completedColor = Color(0xFF2E7D32);
    const rejectedColor = Color(0xFFD32F2F);

    return Row(
      children: [
        card(
          icon: Icons.groups_rounded,
          color: totalColor,
          title: '전체',
          value: '$_totalRequests 건',
          selected: _selectedStatus == '전체',
          onTap: () => _onStatTap('전체'),
        ),
        card(
          icon: Icons.schedule_rounded,
          color: waitingColor,
          title: '대기중',
          value: '${_statusCounts['대기중'] ?? 0} 건',
          selected: _selectedStatus == '대기중',
          onTap: () => _onStatTap('대기중'),
        ),
        card(
          icon: Icons.handyman_rounded,
          color: processingColor,
          title: '처리중',
          value: '${_statusCounts['처리중'] ?? 0} 건',
          selected: _selectedStatus == '처리중',
          onTap: () => _onStatTap('처리중'),
        ),
        card(
          icon: Icons.check_circle_rounded,
          color: completedColor,
          title: '완료',
          value: '${_statusCounts['완료'] ?? 0} 건',
          selected: _selectedStatus == '완료',
          onTap: () => _onStatTap('완료'),
        ),
        card(
          icon: Icons.cancel_rounded,
          color: rejectedColor,
          title: '반려',
          value: '${_statusCounts['반려'] ?? 0} 건',
          selected: _selectedStatus == '반려',
          onTap: () => _onStatTap('반려'),
        ),
      ],
    );
  }
  // ─────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        SizedBox(width: 150.w, height: 38.h, child: _statusFilter()),
        SizedBox(width: 8.w),
        SizedBox(width: 150.w, height: 38.h, child: _categoryFilter()),
        SizedBox(width: 8.w),
        SizedBox(width: 250.w, height: 38.h, child: _searchField()),
      ],
    );
  }

  // 일괄 적용 영역
  Widget _buildBulkActionRow() {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '선택: ${_selectedUuids.length}건',
            style: TextStyle(fontSize: 14.sp),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 155.w,
            child: DropdownButtonFormField2<String>(
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 8.h,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              hint: Text('상태 변경', style: TextStyle(fontSize: 13.sp)),
              value: _bulkStatus == '상태 변경' ? null : _bulkStatus,
              items:
                  _bulkStatusList
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: TextStyle(fontSize: 13.sp)),
                        ),
                      )
                      .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _bulkStatus = val);
              },
              buttonStyleData: ButtonStyleData(
                height: 36.h,
                padding: const EdgeInsets.only(left: 0, right: 0),
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: 200.h,
                padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            onPressed: _applyBulkStatus,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text('일괄 적용', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Widget _statusFilter() {
    return _buildFilterDropdown('상태', _selectedStatus, _statusList, (value) {
      if (value != null) {
        setState(() {
          _selectedStatus = value;
          _applyFilter();
        });
      }
    });
  }

  Widget _categoryFilter() {
    return _buildFilterDropdown('카테고리', _selectedCategory, _categoryList, (
      value,
    ) {
      if (value != null) {
        setState(() {
          _selectedCategory = value;
          _applyFilter();
        });
      }
    });
  }

  Widget _searchField() {
    return TextField(
      controller: _searchController,
      style: TextStyle(fontSize: 13.sp),
      decoration: InputDecoration(
        labelText: '학번/이름',
        labelStyle: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        prefixIcon: Icon(Icons.search, size: 18.w),
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
        contentPadding: EdgeInsets.fromLTRB(12.w, 15.h, 12.w, 5.h),
      ),
      onChanged: (value) => _applyFilter(),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField2<String>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.fromLTRB(0, 5.h, 8.w, 5.h),
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
      value: value,
      items:
          items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, style: TextStyle(fontSize: 13.sp)),
                ),
              )
              .toList(),
      onChanged: onChanged,
      buttonStyleData: ButtonStyleData(
        padding: EdgeInsets.only(left: 12.w, right: 4.w),
      ),
      dropdownStyleData: DropdownStyleData(
        maxHeight: 310.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          color: Colors.white,
        ),
        offset: const Offset(0, -4),
        scrollbarTheme: const ScrollbarThemeData(
          radius: Radius.circular(40),
          thickness: MaterialStatePropertyAll(6),
          thumbVisibility: MaterialStatePropertyAll(true),
        ),
      ),
    );
  }

  Widget _buildDataGrid() {
    final bool isAllSelected =
        _filteredRequests.isNotEmpty &&
        _selectedUuids.length == _filteredRequests.length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300, width: 1.0),
        borderRadius: BorderRadius.circular(8.r),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: Colors.white,
      child: SfDataGridTheme(
        data: SfDataGridThemeData(
          headerColor: Color(0xFFF8F9FA),
          gridLineColor: Color(0xFFE0E0E0),
          gridLineStrokeWidth: 1.0,
        ),
        child: SfDataGrid(
          source: _asDataSource!,
          headerRowHeight: 48.h,
          rowHeight: 52.h,
          gridLinesVisibility: GridLinesVisibility.horizontal,
          headerGridLinesVisibility: GridLinesVisibility.horizontal,
          onCellTap: (details) {
            if (details.rowColumnIndex.rowIndex > 0) {
              final request =
                  _filteredRequests[details.rowColumnIndex.rowIndex - 1];

              _onRowSelect(
                request.uuid,
                !_selectedUuids.contains(request.uuid),
              );

              if (_isRowExpandable[request.uuid] == true) {
                setState(() {
                  if (_expandedRowUuid == request.uuid) {
                    _expandedRowUuid = null;
                  } else {
                    _expandedRowUuid = request.uuid;
                  }
                });
              }
            }
          },
          onQueryRowHeight: (RowHeightDetails details) {
            if (details.rowIndex == 0) return details.rowHeight;
            final request = _filteredRequests[details.rowIndex - 1];

            double baseHeight = 52.h;
            if (request.rejectionReason != null &&
                request.rejectionReason!.isNotEmpty) {
              baseHeight = 75.h;
            }

            if (_isRowExpandable[request.uuid] == true &&
                _expandedRowUuid == request.uuid) {
              final descriptionLines = (request.description.length / 25).ceil();
              final newHeight = (descriptionLines * 20.h) + 16.h;
              return newHeight > baseHeight ? newHeight : baseHeight;
            }
            return baseHeight;
          },
          columns: [
            GridColumn(
              columnName: 'select',
              width: 50.w,
              label: Center(
                child: Transform.scale(
                  scale: 0.8,
                  child: Checkbox(
                    value: isAllSelected,
                    onChanged: _onSelectAll,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'registeredAt',
              width: 100.w,
              label: Center(
                child: Text(
                  '신청일',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'building',
              width: 80.w,
              label: Center(
                child: Text(
                  '건물',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'roomNumber',
              width: 70.w,
              label: Center(
                child: Text(
                  '호실',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'studentId',
              width: 100.w,
              label: Center(
                child: Text(
                  '학번',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'name',
              width: 80.w,
              label: Center(
                child: Text(
                  '이름',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'category',
              width: 100.w,
              label: Center(
                child: Text(
                  '카테고리',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'description',
              columnWidthMode: ColumnWidthMode.fill,
              minimumWidth: 200.w,
              label: Center(
                child: Text(
                  '내용',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'rejectionReason',
              width: 150.w,
              label: Center(
                child: Text(
                  '반려사유',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'status',
              width: 90.w,
              label: Center(
                child: Text(
                  '상태',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'attachments',
              width: 80.w,
              label: Center(
                child: Text(
                  '첨부파일',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'actions',
              width: 100.w,
              label: Center(
                child: Text(
                  '관리',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDialog() {
    _noticeContentController.text = _notice?['content'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          title: Text(
            'AS 공지사항 관리',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 500.w,
            child: TextField(
              controller: _noticeContentController,
              maxLines: 5,
              style: TextStyle(fontSize: 14.sp),
              decoration: InputDecoration(
                hintText: '공지사항 내용을 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: Colors.grey.shade700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () async {
                if (_noticeContentController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('공지사항 내용을 입력해주세요.')),
                  );
                  return;
                }
                Navigator.pop(context);
                await _saveNotice(_noticeContentController.text.trim());
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }
}

class ASRequest {
  final String uuid;
  final String studentId;
  final String name;
  final String category;
  final String description;
  String status;
  final DateTime registeredAt;
  final String building;
  final String roomNumber;
  final String? rejectionReason;
  final List<dynamic> attachments; // 첨부파일 목록
  final bool hasAttachments; // 첨부파일 유무

  ASRequest({
    required this.uuid,
    required this.studentId,
    required this.name,
    required this.category,
    required this.description,
    required this.status,
    required this.registeredAt,
    required this.building,
    required this.roomNumber,
    this.rejectionReason,
    this.attachments = const [],
    this.hasAttachments = false,
  });

  factory ASRequest.fromJson(Map<String, dynamic> json) {
    return ASRequest(
      uuid: json['as_uuid'] ?? '',
      studentId: json['student_id'] ?? 'N/A',
      name: json['name'] ?? '알 수 없음',
      category: json['as_category'] ?? '기타',
      description: json['description'] ?? '',
      status: json['stat'] ?? '대기중',
      registeredAt: DateTime.tryParse(json['reg_dt'] ?? '') ?? DateTime.now(),
      building: json['dorm_building'] ?? '정보없음',
      roomNumber: json['room_num'] ?? '정보없음',
      rejectionReason: json['rejection_reason'],
      attachments: json['attachments'] ?? [],
      hasAttachments: json['has_attachments'] ?? false,
    );
  }
}

class ASDataSource extends DataGridSource {
  final List<ASRequest> _requests;
  final Set<String> _selectedUuids;
  final void Function(String uuid, bool selected) onRowSelect;
  final void Function(ASRequest request) onStatusEdit;
  final void Function(ASRequest request) onShowAttachments;
  final String? expandedRowUuid;
  final Map<String, bool> isRowExpandable;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  ASDataSource(
    this._requests,
    this._selectedUuids,
    this.onRowSelect,
    this.onStatusEdit,
    this.onShowAttachments,
    this.expandedRowUuid,
    this.isRowExpandable,
  ) {
    buildDataGridRows();
  }

  List<DataGridRow> _dataGridRows = [];

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final ASRequest req = row.getCells()[1].value;
    final bool isSelected = _selectedUuids.contains(req.uuid);
    return DataGridRowAdapter(
      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
      cells: [
        Center(
          child: Transform.scale(
            scale: 0.8,
            child: Checkbox(
              value: isSelected,
              onChanged: (val) => onRowSelect(req.uuid, val ?? false),
              activeColor: Colors.blue,
            ),
          ),
        ),
        ...row.getCells().skip(2).map<Widget>((cell) {
          if (cell.columnName == 'status') {
            return _buildStatusText(req.status);
          } else if (cell.columnName == 'attachments') {
            return Center(
              child:
                  req.hasAttachments
                      ? IconButton(
                        icon: Icon(
                          Icons.attach_file,
                          color: Colors.green,
                          size: 18.w,
                        ),
                        onPressed: () => onShowAttachments(req),
                        tooltip: '첨부파일 보기 (${req.attachments.length}개)',
                      )
                      : Icon(
                        Icons.remove,
                        color: Colors.grey.shade400,
                        size: 18.w,
                      ),
            );
          } else if (cell.columnName == 'rejectionReason') {
            return Container(
              padding: EdgeInsets.all(8.w),
              alignment: Alignment.centerLeft,
              child:
                  (req.rejectionReason != null &&
                          req.rejectionReason!.isNotEmpty)
                      ? Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          req.rejectionReason!,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                      )
                      : Text(
                        '-',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey.shade400,
                        ),
                      ),
            );
          } else if (cell.columnName == 'actions') {
            return Center(
              child: IconButton(
                icon: Icon(Icons.edit, color: Colors.blueGrey, size: 18.w),
                onPressed: () => onStatusEdit(req),
                tooltip: '상태 변경',
              ),
            );
          } else {
            bool isExpanded =
                isRowExpandable[req.uuid] == true &&
                expandedRowUuid == req.uuid;

            Alignment alignment = Alignment.center;
            if (cell.columnName == 'description')
              alignment = Alignment.centerLeft;

            return Container(
              padding: EdgeInsets.all(8.w),
              alignment: alignment,
              child: Text(
                cell.value?.toString() ?? '',
                style: TextStyle(fontSize: 13.sp),
                maxLines: isExpanded ? null : 1,
                overflow:
                    isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            );
          }
        }).toList(),
      ],
    );
  }

  Widget _buildStatusText(String status) {
    Color fg;
    switch (status) {
      case '완료':
      case '승인':
        fg = Colors.green;
        break;
      case '반려':
        fg = Colors.red;
        break;
      case '처리중':
      case '수리중':
        fg = Colors.blue;
        break;
      case '대기':
      case '대기중':
      case '접수':
        fg = Colors.orange;
        break;
      default:
        fg = Colors.grey[800]!;
        break;
    }
    return Center(
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 13.sp,
        ),
      ),
    );
  }

  void buildDataGridRows() {
    _dataGridRows =
        _requests.map<DataGridRow>((request) {
          return DataGridRow(
            cells: [
              const DataGridCell(columnName: 'select', value: null),
              DataGridCell(columnName: 'req', value: request),
              DataGridCell(
                columnName: 'registeredAt',
                value: _dateFormat.format(request.registeredAt),
              ),
              DataGridCell(columnName: 'building', value: request.building),
              DataGridCell(columnName: 'roomNumber', value: request.roomNumber),
              DataGridCell(columnName: 'studentId', value: request.studentId),
              DataGridCell(columnName: 'name', value: request.name),
              DataGridCell(columnName: 'category', value: request.category),
              DataGridCell(
                columnName: 'description',
                value: request.description,
              ),
              DataGridCell(
                columnName: 'rejectionReason',
                value: request.rejectionReason ?? '',
              ),
              DataGridCell(columnName: 'status', value: request.status),
              DataGridCell(
                columnName: 'attachments',
                value:
                    request.hasAttachments
                        ? '${request.attachments.length}'
                        : '',
              ),
              const DataGridCell(columnName: 'actions', value: ''),
            ],
          );
        }).toList();
  }
}
