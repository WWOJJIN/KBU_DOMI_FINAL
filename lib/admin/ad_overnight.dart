// 파일명: ad_overnight_page.dart
// 변경사항
// - 상단 패딩/간격을 '점호관리(ad_jumho.dart)'와 동일 톤으로 정리 (상단 여백 줄임)
// - 헤더(외박 신청 관리)와 통계 카드 레이아웃/여백, 카드 높이/너비를 맞춤
// - 통계 카드 클릭 시 상태 필터와 드롭다운 동기화(유지)

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class AdOvernightPage extends StatefulWidget {
  const AdOvernightPage({super.key});

  @override
  State<AdOvernightPage> createState() => _AdOvernightPageState();
}

class _AdOvernightPageState extends State<AdOvernightPage> {
  OvernightDataSource? _overnightDataSource;
  final List<OvernightRequest> _overnightRequests = [];
  List<OvernightRequest> _filteredRequests = [];
  final Set<String> _selectedUuids = {};
  bool _isLoading = true;

  // ▼ 필터 상태(통계 카드/드롭다운 공유)
  String _selectedStatus = '전체';
  String _selectedBuilding = '전체';

  String _bulkStatus = '상태 변경';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _rejectionReasonController =
      TextEditingController();
  String? _expandedRowUuid;

  // 확장 가능 여부
  final Map<String, bool> _isRowExpandable = {};

  // 통계
  Map<String, int> _statusCounts = {};
  int _totalRequests = 0;

  // 공지
  Map<String, dynamic>? _notice;
  final TextEditingController _noticeContentController =
      TextEditingController();

  static const List<String> _statusList = ['전체', '대기', '승인', '반려'];
  static const List<String> _buildingList = ['전체', '숭례원', '양덕원'];
  static const List<String> _bulkStatusList = ['승인', '대기', '반려'];

  // 카드 공통 스타일(점호관리와 동일 톤)
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
    _loadOvernightRequests();
    _loadNotice();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _rejectionReasonController.dispose();
    _noticeContentController.dispose();
    super.dispose();
  }

  void _calculateStatistics() {
    _statusCounts.clear();
    _totalRequests = _overnightRequests.length;

    for (final request in _overnightRequests) {
      final key = request.status == '대기중' ? '대기' : request.status;
      _statusCounts[key] = (_statusCounts[key] ?? 0) + 1;
    }
  }

  Future<void> _loadNotice() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/admin/notice?category=overnight'),
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
        'title': '외박 공지사항',
        'content': content,
        'category': 'overnight',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('공지사항이 저장되었습니다.')));
      } else {
        throw Exception('Failed to save notice: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('공지사항 저장에 실패했습니다: $e')));
    }
  }

  Future<void> _loadOvernightRequests() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5050/api/overnight/requests'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _overnightRequests
          ..clear()
          ..addAll(data.map((item) => OvernightRequest.fromJson(item)));
        _calculateStatistics();
        _applyFilter();
      } else {
        throw Exception('Failed to load requests');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('데이터를 불러오는데 실패했습니다: $e')));
    } finally {
      setState(() => _isLoading = false);
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
    await _loadOvernightRequests();
    setState(() => _isLoading = false);
  }

  void _applyFilter() {
    final search = _searchController.text.trim();
    _filteredRequests =
        _overnightRequests.where((req) {
          final statusMatch =
              _selectedStatus == '전체' ||
              req.status == _selectedStatus ||
              (_selectedStatus == '대기' && req.status == '대기중');
          final buildingMatch =
              _selectedBuilding == '전체' || req.building == _selectedBuilding;
          final matchesSearch =
              search.isEmpty ||
              req.studentId.contains(search) ||
              req.name.contains(search);
          return statusMatch && buildingMatch && matchesSearch;
        }).toList();

    _updateExpandableRows();

    setState(() {
      _overnightDataSource = OvernightDataSource(
        _filteredRequests,
        _selectedUuids,
        _onRowSelect,
        _showStatusUpdateDialog,
        _showDetailDialog,
        _expandedRowUuid,
        _isRowExpandable,
      );
    });
  }

  void _updateExpandableRows() {
    _isRowExpandable.clear();
    const int reasonMaxChars = 20;
    const int rejectionReasonMaxChars = 15;

    for (var req in _filteredRequests) {
      if ((req.reason.length > reasonMaxChars) ||
          (req.rejectionReason?.length ?? 0) > rejectionReasonMaxChars) {
        _isRowExpandable[req.uuid] = true;
      } else {
        _isRowExpandable[req.uuid] = false;
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
        Uri.parse('http://localhost:5050/api/overnight/request/$uuid/status'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('상태 업데이트에 실패했습니다: $e')));
    }
  }

  Future<String?> _showBulkRejectionDialog() {
    _rejectionReasonController.clear();
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('일괄 반려 사유 입력'),
            content: TextField(
              controller: _rejectionReasonController,
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
                  Navigator.pop(context, _rejectionReasonController.text);
                },
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  void _showStatusUpdateDialog(OvernightRequest request) {
    _rejectionReasonController.text = request.rejectionReason ?? '';
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
                '신청 상태 변경',
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
                            '${request.studentId} / ${request.building} ${request.room}',
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
                      value: (newStatus == '대기중') ? '대기' : newStatus,
                      items:
                          ['대기', '승인', '반려']
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
                          setStateInDialog(() {
                            newStatus = value;
                          });
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
                        controller: _rejectionReasonController,
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
                                    ? _rejectionReasonController.text
                                    : null,
                          );
                          await _loadOvernightRequests();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('상태가 업데이트되었습니다.')),
                          );
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

  void _showDetailDialog(OvernightRequest request) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('외박 신청 상세', style: TextStyle(fontSize: 18.sp)),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('학번', request.studentId),
                  _buildDetailRow('이름', request.name),
                  _buildDetailRow('건물', request.building),
                  _buildDetailRow('호실', request.room),
                  _buildDetailRow(
                    '시작일',
                    DateFormat('yyyy-MM-dd').format(request.startDate),
                  ),
                  _buildDetailRow(
                    '종료일',
                    DateFormat('yyyy-MM-dd').format(request.endDate),
                  ),
                  _buildDetailRow('복귀시간', request.returnTime),
                  _buildDetailRow('장소', request.place),
                  _buildDetailRow('사유', request.reason),
                  if (request.status == '반려' &&
                      request.rejectionReason != null &&
                      request.rejectionReason!.isNotEmpty)
                    _buildDetailRow('반려 사유', request.rejectionReason!),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: _getStatusColor(request.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: _getStatusColor(request.status),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStatusIcon(request.status),
                          color: _getStatusColor(request.status),
                          size: 20.w,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '상태: ${request.status}',
                          style: TextStyle(
                            color: _getStatusColor(request.status),
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('닫기', style: TextStyle(fontSize: 14.sp)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showStatusUpdateDialog(request);
                },
                child: Text('상태 변경', style: TextStyle(fontSize: 14.sp)),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14.sp))),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '승인':
        return Colors.green;
      case '반려':
        return Colors.red;
      case '대기':
      case '대기중':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case '승인':
        return Icons.check_circle;
      case '반려':
        return Icons.cancel;
      case '대기':
      case '대기중':
        return Icons.schedule;
      default:
        return Icons.help;
    }
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
            '외박 공지사항 관리',
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

  @override
  Widget build(BuildContext context) {
    // 상단 여백을 점호관리와 동일하게: all(24)
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(), // 헤더
            SizedBox(height: 16.h),
            _buildStatisticsCards(), // 통계 카드(높이/너비/여백 동일)
            SizedBox(height: 16.h),
            _buildFilterBar(),
            SizedBox(height: 8.h),
            Expanded(
              child:
                  _isLoading || _overnightDataSource == null
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
    // 점호관리 헤더와 동일 톤(텍스트 22, 오른쪽 액션)
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '외박 신청 관리',
          style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            // 공지사항 관리 버튼은 유지
            ElevatedButton.icon(
              onPressed: _showNoticeDialog,
              icon: Icon(Icons.announcement, size: 16.w),
              label: const Text('공지사항 관리'),
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
              onPressed: _loadOvernightRequests,
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
  // 상단 통계 카드(점호관리와 동일한 높이/너비/여백)
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
            padding: EdgeInsets.all(20.w), // 점호관리와 동일
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
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
    const approvedColor = Color(0xFF2E7D32);
    const rejectedColor = Color(0xFFD32F2F);

    return Row(
      children: [
        card(
          icon: Icons.groups_rounded,
          color: totalColor,
          title: '전체',
          value: '$_totalRequests 명',
          selected: _selectedStatus == '전체',
          onTap: () => _onStatTap('전체'),
        ),
        card(
          icon: Icons.schedule,
          color: waitingColor,
          title: '대기',
          value: '${_statusCounts['대기'] ?? 0} 명',
          selected: _selectedStatus == '대기',
          onTap: () => _onStatTap('대기'),
        ),
        card(
          icon: Icons.check_circle_rounded,
          color: approvedColor,
          title: '승인',
          value: '${_statusCounts['승인'] ?? 0} 명',
          selected: _selectedStatus == '승인',
          onTap: () => _onStatTap('승인'),
        ),
        card(
          icon: Icons.cancel_rounded,
          color: rejectedColor,
          title: '반려',
          value: '${_statusCounts['반려'] ?? 0} 명',
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
        SizedBox(width: 150.w, height: 38.h, child: _buildingFilter()),
        SizedBox(width: 8.w),
        SizedBox(width: 250.w, height: 38.h, child: _searchField()),
      ],
    );
  }

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
            width: 15.w,
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

  Widget _buildingFilter() {
    return _buildFilterDropdown('건물', _selectedBuilding, _buildingList, (
      value,
    ) {
      if (value != null) {
        setState(() {
          _selectedBuilding = value;
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
        side: BorderSide(color: Colors.grey.shade200, width: 1.0),
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
          source: _overnightDataSource!,
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
            if (details.rowIndex == 0) {
              return details.rowHeight;
            }
            final request = _filteredRequests[details.rowIndex - 1];

            if (_isRowExpandable[request.uuid] == true &&
                _expandedRowUuid == request.uuid) {
              final reasonLines = (request.reason.length / 20).ceil();
              final rejectionReasonLines =
                  ((request.rejectionReason?.length ?? 0) / 15).ceil();
              final maxLines =
                  reasonLines > rejectionReasonLines
                      ? reasonLines
                      : rejectionReasonLines;

              final newHeight = (maxLines * 20.h) + 16.h;

              return newHeight > 52.h ? newHeight : 52.h;
            }
            return 52.h;
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
              columnName: 'room',
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
              columnName: 'startDate',
              width: 100.w,
              label: Center(
                child: Text(
                  '시작일',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'endDate',
              width: 100.w,
              label: Center(
                child: Text(
                  '종료일',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'returnTime',
              width: 80.w,
              label: Center(
                child: Text(
                  '복귀시간',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'place',
              width: 120.w,
              label: Center(
                child: Text(
                  '장소',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'reason',
              columnWidthMode: ColumnWidthMode.fill,
              minimumWidth: 150.w,
              label: Center(
                child: Text(
                  '사유',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ),
            GridColumn(
              columnName: 'rejectionReason',
              width: 180.w,
              label: Center(
                child: Text(
                  '반려 사유',
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
}

class OvernightRequest {
  final String uuid;
  final String studentId;
  final String name;
  final String building;
  final String room;
  final DateTime startDate;
  final DateTime endDate;
  final String returnTime;
  final String place;
  final String reason;
  final String status;
  final String? rejectionReason;

  OvernightRequest({
    required this.uuid,
    required this.studentId,
    required this.name,
    required this.building,
    required this.room,
    required this.startDate,
    required this.endDate,
    required this.returnTime,
    required this.place,
    required this.reason,
    required this.status,
    this.rejectionReason,
  });

  factory OvernightRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value);
      } catch (_) {
        try {
          return DateFormat(
            'EEE, dd MMM yyyy HH:mm:ss GMT',
            'en_US',
          ).parseUtc(value);
        } catch (_) {
          return null;
        }
      }
    }

    return OvernightRequest(
      uuid: json['out_uuid'] ?? '',
      studentId: json['student_id'] ?? '',
      name: json['name'] ?? '',
      building: json['building'] ?? '',
      room: json['room'] ?? '',
      startDate: parseDate(json['out_start']) ?? DateTime.now(),
      endDate: parseDate(json['out_end']) ?? DateTime.now(),
      returnTime: json['return_time'] ?? '',
      place: json['place'] ?? '',
      reason: json['reason'] ?? '',
      status: json['stat'] ?? '',
      rejectionReason: json['rejection_reason'],
    );
  }
}

class OvernightDataSource extends DataGridSource {
  final List<OvernightRequest> _requests;
  final Set<String> _selectedUuids;
  final void Function(String uuid, bool selected) onRowSelect;
  final void Function(OvernightRequest request) onStatusEdit;
  final void Function(OvernightRequest request) onDetailView;
  final String? expandedRowUuid;
  final Map<String, bool> isRowExpandable;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  OvernightDataSource(
    this._requests,
    this._selectedUuids,
    this.onRowSelect,
    this.onStatusEdit,
    this.onDetailView,
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
    final OvernightRequest req = row.getCells()[1].value;
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
            final columnName = cell.columnName;
            if (columnName == 'reason' || columnName == 'rejectionReason') {
              alignment = Alignment.centerLeft;
            }

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
      case '승인':
        fg = Colors.green;
        break;
      case '반려':
        fg = Colors.red;
        break;
      case '대기':
      case '대기중':
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
              DataGridCell(columnName: 'studentId', value: request.studentId),
              DataGridCell(columnName: 'name', value: request.name),
              DataGridCell(columnName: 'building', value: request.building),
              DataGridCell(columnName: 'room', value: request.room),
              DataGridCell(
                columnName: 'startDate',
                value: _dateFormat.format(request.startDate),
              ),
              DataGridCell(
                columnName: 'endDate',
                value: _dateFormat.format(request.endDate),
              ),
              DataGridCell(columnName: 'returnTime', value: request.returnTime),
              DataGridCell(columnName: 'place', value: request.place),
              DataGridCell(columnName: 'reason', value: request.reason),
              DataGridCell(
                columnName: 'rejectionReason',
                value: request.rejectionReason ?? '',
              ),
              DataGridCell(columnName: 'status', value: request.status),
              const DataGridCell(columnName: 'actions', value: ''),
            ],
          );
        }).toList();
  }

  @override
  void handleTap(int rowIndex, int columnIndex) {
    // onCellTap에서 처리
  }
}
