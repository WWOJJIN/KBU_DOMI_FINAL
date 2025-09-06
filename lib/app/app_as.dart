import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ✅ ScreenUtil import!
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../student_provider.dart';
import 'package:kbu_domi/env.dart';

// --- 앱 공통 테마 ---
class AppColors {
  static const primary = Color(0xFF4A69E2);
  static const accent = Color(0xFF4A69E2);
  static const background = Colors.white;
  static const card = Colors.white;
  static const textPrimary = Color(0xFF34495E);
  static const textSecondary = Color(0xFF7F8C8D);
  static const success = Color(0xFF27AE60);
  static const warning = Color(0xFFF2994A);
  static const danger = Color(0xFFE74C3C);
}

// --- 파일 정보 모델 ---
class UploadFile {
  final String name;
  final int size;
  final Uint8List? bytes;
  double progress;
  String status;
  String? uploadedPath;

  UploadFile({
    required this.name,
    required this.size,
    this.bytes,
    this.progress = 0,
    this.status = '대기',
    this.uploadedPath,
  });
}

// --- ScreenUtilInit 최상단에 꼭 감싸야 함! ---
class AppAsRoot extends StatelessWidget {
  const AppAsRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // 디자인 기준 해상도
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) => const AppAs(),
    );
  }
}

class AppAs extends StatefulWidget {
  const AppAs({super.key});

  @override
  State<AppAs> createState() => _AppAsState();
}

class _AppAsState extends State<AppAs> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isHistoryLoading = false;
  final _formKey = GlobalKey<FormState>();
  String? _selectedIssue;
  final _reasonController = TextEditingController();
  final List<UploadFile> _uploadFiles = [];
  List<Map<String, dynamic>> _requestHistory = [];

  // 학생 정보 변수들 추가
  String _studentName = '';
  String _studentId = '';
  String _dormBuilding = '';
  String _roomNumber = '';

  final List<String> _issueItems = [
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudentInfo(); // 학생 정보 로드
    _loadASRequests();
  }

  // 학생 정보 가져오기
  Future<void> _loadStudentInfo() async {
    final studentId = context.read<StudentProvider>().studentId;

    if (studentId == null) {
      print('❌ 학생 ID가 없습니다. 로그인 페이지로 이동합니다.');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/student/$studentId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('👤 AS 페이지 학생 정보 API 응답: $data');

        if (data['success'] == true && data['user'] != null) {
          final user = data['user'];
          if (mounted) {
            setState(() {
              _studentName = user['name'] ?? '';
              _studentId = studentId;
              _dormBuilding = user['dorm_building'] ?? '';
              _roomNumber = user['room_num']?.toString() ?? '';
            });
          }
          print(
            '✅ AS 페이지 학생 정보 설정 완료: $_studentName, $_dormBuilding $_roomNumber호',
          );
        }
      }
    } catch (e) {
      print('❌ AS 페이지 학생 정보 로드 오류: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  // 실제 AS 신청 내역 불러오기
  Future<void> _loadASRequests() async {
    setState(() => _isHistoryLoading = true);
    final studentId = context.read<StudentProvider>().studentId;

    if (studentId == null) {
      print('❌ 학생 ID가 없습니다.');
      setState(() => _isHistoryLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/as/requests?student_id=$studentId'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔧 AS 신청 내역 API 응답: $data');

        List<Map<String, dynamic>> parsed = [];
        if (data is Map && data.containsKey('success')) {
          if (data['success'] == true) {
            parsed = List<Map<String, dynamic>>.from(data['requests'] ?? []);
          }
        } else if (data is List) {
          parsed = List<Map<String, dynamic>>.from(data);
        }

        // 서버 상태 → 화면 상태 매핑
        _requestHistory =
            parsed.map((req) {
              final serverStatus = req['stat'] ?? '';
              String flutterStatus;
              switch (serverStatus) {
                case '접수':
                  flutterStatus = '신청';
                  break;
                case '처리중':
                  flutterStatus = '수리중';
                  break;
                case '완료':
                  flutterStatus = '수리완료';
                  break;
                case '반려':
                  flutterStatus = '반려';
                  break;
                default:
                  flutterStatus = '신청';
              }
              return {...req, 'stat': flutterStatus};
            }).toList();

        print('✅ AS 신청 내역 로드 완료: ${_requestHistory.length}건');
      } else {
        _requestHistory = [];
        print('❌ AS API 호출 실패: ${response.statusCode}');
        _showSnackBar('신청 내역을 불러올 수 없습니다.', isError: true);
      }
    } catch (e) {
      _requestHistory = [];
      print('❌ AS API 네트워크 오류: $e');
      _showSnackBar('네트워크 오류: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isHistoryLoading = false);
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: true,
      );
      if (result != null) {
        setState(() {
          _uploadFiles.addAll(
            result.files.map(
              (file) => UploadFile(
                name: file.name,
                size: file.size,
                bytes: file.bytes,
              ),
            ),
          );
        });
      }
    } catch (e) {
      _showSnackBar('파일 선택 중 오류 발생', isError: true);
    }
  }

  Future<void> _submitASRequest() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackBar('모든 항목을 입력해주세요.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final studentId = context.read<StudentProvider>().studentId;

    if (studentId == null) {
      setState(() => _isLoading = false);
      _showSnackBar('학생 정보를 찾을 수 없습니다. 다시 로그인해주세요.', isError: true);
      return;
    }

    try {
      // 먼저 AS 신청을 제출
      final response = await http.post(
        Uri.parse('$apiBase/api/as/apply'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': studentId,
          'as_category': _selectedIssue,
          'description': _reasonController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔧 AS 신청 API 응답: $data');
        if (data['success']) {
          final asUuid = data['as_uuid'];

          // 이미지 업로드 (파일이 있을 때만)
          if (_uploadFiles.isNotEmpty) {
            for (var file in _uploadFiles) {
              if (file.bytes != null) {
                var request = http.MultipartRequest(
                  'POST',
                  Uri.parse('$apiBase/api/as/image'),
                );
                request.fields['as_uuid'] = asUuid;
                request.files.add(
                  http.MultipartFile.fromBytes(
                    'image',
                    file.bytes!,
                    filename: file.name,
                  ),
                );
                await request.send();
              }
            }
          }

          _showSnackBar('A/S 신청이 완료되었습니다.');
          _resetForm();
          _tabController.animateTo(1);
          await _loadASRequests(); // 신청 목록 새로고침
        } else {
          _showSnackBar(
            data['error'] ?? data['message'] ?? '신청 처리 중 오류가 발생했습니다.',
            isError: true,
          );
        }
      } else {
        _showSnackBar(
          '서버와 통신할 수 없습니다. (코드: ${response.statusCode})',
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar('네트워크 오류: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // AS 신청 취소
  Future<void> _cancelASRequest(String uuid) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBase/api/as/request/$uuid'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          await _loadASRequests(); // 목록 새로고침
          _showSnackBar('신청이 취소되었습니다.');
        } else {
          _showSnackBar(
            data['message'] ?? '취소 처리 중 오류가 발생했습니다.',
            isError: true,
          );
        }
      } else {
        _showSnackBar('서버와 통신할 수 없습니다.', isError: true);
      }
    } catch (e) {
      _showSnackBar('네트워크 오류: $e', isError: true);
    }
  }

  void _cancelRequest(String uuid) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(24.0.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72.w,
                    height: 72.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.danger.withOpacity(0.1),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      size: 40.sp,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    '취소',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 280.w),
                    child: Column(
                      children: [
                        Text(
                          '정말로 신청을 취소하시겠습니까?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '취소된 내역은 복구할 수 없습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('닫기', style: TextStyle(fontSize: 15.sp)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _cancelASRequest(uuid);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            elevation: 0,
                          ),
                          child: Text(
                            '취소하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15.sp,
                            ),
                          ),
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

  void _resetForm() {
    _formKey.currentState?.reset();
    _reasonController.clear();
    setState(() {
      _selectedIssue = null;
      _uploadFiles.clear();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontSize: 15.sp)),
        backgroundColor: isError ? AppColors.danger : AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            Divider(
              height: 1.h,
              thickness: 1.h,
              color: const Color(0xFFE6E8EC),
            ),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3.h,
              tabs: [
                Tab(
                  child: Text(
                    '신청하기',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                Tab(
                  child: Text(
                    '신청내역',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildRequestForm(context), _buildRequestHistory()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestForm(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(
          context,
        ).colorScheme.copyWith(primary: AppColors.primary),
      ),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('신청자 정보', Icons.person_outline),
                SizedBox(height: 16.h),
                _buildInfoCard(),
                SizedBox(height: 32.h),
                _buildSectionTitle('문제 내용', Icons.report_problem_outlined),
                SizedBox(height: 16.h),
                _CustomDropdown(
                  value: _selectedIssue,
                  items: _issueItems,
                  label: '문제 종류 선택',
                  onChanged: (value) => setState(() => _selectedIssue = value),
                  validator: (value) => value == null ? '문제 종류를 선택해주세요.' : null,
                ),
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: '문제 발생 사유를 자세히 입력해주세요.',
                    alignLabelWithHint: true,
                  ),
                  validator:
                      (value) =>
                          (value?.isEmpty ?? true) ? '사유를 입력해주세요.' : null,
                  style: TextStyle(fontSize: 15.sp),
                ),
                SizedBox(height: 32.h),
                _buildSectionTitle('사진 첨부', Icons.camera_alt_outlined),
                SizedBox(height: 16.h),
                if (_uploadFiles.isEmpty) _buildImageUploadArea(),
                SizedBox(height: 8.h),
                if (_uploadFiles.isNotEmpty) _buildFileList(),
                if (_uploadFiles.isNotEmpty)
                  Align(
                    alignment: Alignment.center,
                    child: IconButton(
                      iconSize: 36.sp,
                      onPressed: _pickFiles,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                SizedBox(height: 40.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitASRequest,
                    icon:
                        _isLoading
                            ? Container()
                            : Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                    label:
                        _isLoading
                            ? SizedBox(
                              height: 24.h,
                              width: 24.w,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3.w,
                              ),
                            )
                            : Text(
                              '신청하기',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                              ),
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ✅ 신청내역: 당겨서 새로고침 적용
  Widget _buildRequestHistory() {
    if (_isHistoryLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3.w,
            ),
            SizedBox(height: 16.h),
            Text(
              'AS 신청 내역을 불러오는 중...',
              style: TextStyle(fontSize: 16.sp, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadASRequests,
      child:
          _requestHistory.isEmpty
              // 비어 있을 때도 당겨서 새로고침 되도록 AlwaysScrollable 적용
              ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 16.w),
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64.sp,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'AS 신청 내역이 없습니다',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '아래로 끌어당겨 새로고침하거나,\n첫 번째 탭에서 AS를 신청해보세요',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: AppColors.textSecondary.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              )
              : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                itemCount: _requestHistory.length,
                itemBuilder:
                    (context, idx) => _buildStepCard(_requestHistory[idx]),
              ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> req) {
    final status = req['stat'] ?? '신청';

    if (status == '수리완료' || status == '반려') {
      final bool isSuccess = status == '수리완료';
      return Card(
        margin: EdgeInsets.only(bottom: 16.h),
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isSuccess)
                Padding(
                  padding: EdgeInsets.only(top: 8.0.h, right: 12.w),
                  child: Icon(
                    Icons.cancel,
                    color: AppColors.danger,
                    size: 30.sp,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            req['as_category'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.sp,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _StatusChip(status: status),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      req['reg_dt'] ?? '',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      req['description'] ?? '',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    int currentStep = 0;
    if (status == '수리중') currentStep = 1;

    final List<Map<String, dynamic>> steps = [
      {
        'label': '신청',
        'icon': Icons.note_alt_outlined,
        'color': AppColors.primary,
      },
      {
        'label': '수리중',
        'icon': Icons.build_circle_outlined,
        'color': AppColors.warning,
      },
      {
        'label': '완료',
        'icon': Icons.check_circle_outline,
        'color': AppColors.success,
      },
    ];

    return Card(
      margin: EdgeInsets.only(bottom: 16.h),
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8.w, 12.h, 8.w, 12.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: List.generate(steps.length, (idx) {
                final bool active = idx == currentStep;
                Color color;
                if (status == '신청') {
                  color = idx == 0 ? AppColors.primary : Colors.grey.shade300;
                } else if (status == '수리중') {
                  if (idx == 1) {
                    color = AppColors.warning;
                  } else {
                    color = Colors.grey.shade300;
                  }
                } else {
                  color = Colors.grey.shade300;
                }
                return Column(
                  children: [
                    Container(
                      width: 22.w,
                      height: 22.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            active
                                ? color.withOpacity(0.14)
                                : Colors.transparent,
                        border: Border.all(color: color, width: 1.5.w),
                      ),
                      child: Icon(
                        steps[idx]['icon'] as IconData,
                        color: color,
                        size: 15.sp,
                      ),
                    ),
                    if (idx != steps.length - 1)
                      Container(
                        width: 2.w,
                        height: 16.h,
                        color:
                            (status == '수리중' && idx == 0)
                                ? AppColors.warning
                                : Colors.grey.shade200,
                      ),
                  ],
                );
              }),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          req['as_category'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18.sp,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _StatusChip(status: status),
                      if (status == '신청')
                        SizedBox(
                          width: 22.w,
                          height: 22.h,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            splashRadius: 16.r,
                            icon: Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                              size: 18.sp,
                            ),
                            onPressed: () => _cancelRequest(req['as_uuid']),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    req['reg_dt'] ?? '',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    req['description'] ?? '',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accent, size: 20.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      color: Colors.grey.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0.h),
        child: IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _infoItem(
                  '이름',
                  _studentName.isEmpty ? '로딩중...' : _studentName,
                ),
              ),
              VerticalDivider(
                width: 1.w,
                thickness: 1.w,
                indent: 8.h,
                endIndent: 8.h,
              ),
              Expanded(
                child: _infoItem(
                  '학번',
                  _studentId.isEmpty ? '로딩중...' : _studentId,
                ),
              ),
              VerticalDivider(
                width: 1.w,
                thickness: 1.w,
                indent: 8.h,
                endIndent: 8.h,
              ),
              Expanded(
                child: _infoItem(
                  '건물',
                  _dormBuilding.isEmpty ? '로딩중...' : _dormBuilding,
                ),
              ),
              VerticalDivider(
                width: 1.w,
                thickness: 1.w,
                indent: 8.h,
                endIndent: 8.h,
              ),
              Expanded(
                child: _infoItem(
                  '호실',
                  _roomNumber.isEmpty ? '로딩중...' : '${_roomNumber}호',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildImageUploadArea() {
    return GestureDetector(
      onTap: _pickFiles,
      child: Container(
        height: 120.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade300, width: 1.w),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              color: AppColors.accent,
              size: 40.sp,
            ),
            SizedBox(height: 8.h),
            Text(
              '사진 첨부하기',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _uploadFiles.length,
      itemBuilder: (context, index) {
        final file = _uploadFiles[index];
        return Card(
          color: AppColors.card,
          margin: EdgeInsets.symmetric(vertical: 4.h),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Icon(
              Icons.image_outlined,
              color: AppColors.accent,
              size: 24.sp,
            ),
            title: Text(
              file.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.sp),
            ),
            subtitle: Text(
              '${(file.size / 1024).toStringAsFixed(1)} KB',
              style: TextStyle(fontSize: 12.sp),
            ),
            trailing: IconButton(
              icon: Icon(Icons.close, color: Colors.grey, size: 22.sp),
              onPressed: () => setState(() => _uploadFiles.removeAt(index)),
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: 4.h),
    );
  }
}

class _CustomDropdown extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String label;
  final ValueChanged<String?> onChanged;
  final String? Function(String?)? validator;

  const _CustomDropdown({
    Key? key,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    this.validator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 15.sp),
      ),
      menuMaxHeight: 240.0.h,
      items:
          items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
              )
              .toList(),
      onChanged: onChanged,
      isExpanded: true,
      icon: Icon(
        Icons.arrow_drop_down,
        color: AppColors.textSecondary,
        size: 22.sp,
      ),
      dropdownColor: AppColors.background,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    Color chipColor;
    String chipText = status;
    switch (status) {
      case '신청':
        chipColor = AppColors.primary;
        break;
      case '수리중':
        chipColor = AppColors.warning;
        break;
      case '수리완료':
        chipColor = AppColors.success;
        chipText = '완료';
        break;
      case '반려':
        chipColor = AppColors.danger;
        break;
      default:
        chipColor = AppColors.textSecondary;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Text(
        chipText,
        style: TextStyle(
          color: chipColor,
          fontSize: 12.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
