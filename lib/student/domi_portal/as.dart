import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../student_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

// 파일 정보 모델
class UploadFile {
  final File? file;
  final String name;
  final int size;
  double progress;
  String status; // '대기', '업로드중', '완료', '에러'
  Uint8List? webBytes; // 웹 미리보기용

  UploadFile({
    this.file,
    required this.name,
    required this.size,
    this.progress = 0,
    this.status = '대기',
    this.webBytes,
  });
}

class ASRequestPage extends StatefulWidget {
  const ASRequestPage({super.key});

  @override
  _ASRequestPageState createState() => _ASRequestPageState();
}

class _ASRequestPageState extends State<ASRequestPage> {
  // ... (initState, 각종 컨트롤러 및 함수들은 이전과 모두 동일합니다) ...
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController roomController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController issueController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController semesterController = TextEditingController();

  String? studentIdError;
  String? nameError;
  String? roomError;
  String? contactError;
  String? issueError;
  String? reasonError;
  String? imageError;

  File? _selectedImage;
  Uint8List? _webImageBytes;
  final ImagePicker _picker = ImagePicker();
  String? _selectedFileName;

  List<Map<String, dynamic>> requests = [];

  final List<String> issueItems = [
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
  String? selectedIssue;

  List<UploadFile> uploadFiles = [];
  bool isUploading = false;
  String? asUuid;
  List<String> uploadedImgPaths = [];

  // 공지사항 관련 변수들 (DB에서 받아올 예정)
  String? noticeText; // DB에서 받아온 공지사항 텍스트
  bool isNoticeLoading = false; // 공지사항 로딩 상태

  @override
  void initState() {
    super.initState();
    final student = Provider.of<StudentProvider>(context, listen: false);

    // 년도와 학기 설정 (현재 날짜 기준)
    final now = DateTime.now();
    yearController.text = now.year.toString();
    semesterController.text = now.month >= 3 && now.month <= 8 ? '1학기' : '2학기';

    studentIdController.text = student.studentId ?? '';
    nameController.text = student.name ?? '';
    roomController.text = student.roomNum ?? '';
    contactController.text = student.phoneNum ?? '';
    _loadASRequests();
    _loadNotice(); // 공지사항 로드
  }

  Future<void> _loadASRequests() async {
    try {
      final student = Provider.of<StudentProvider>(context, listen: false);
      print('🔍 웹 AS - _loadASRequests 호출, studentId: ${student.studentId}');

      if (student.studentId == null) {
        print('❌ 웹 AS - studentId가 null입니다!');
        return;
      }

      final url = Uri.parse(
        'http://localhost:5050/api/as/requests?student_id=${student.studentId}',
      );
      final response = await http.get(url);
      print('🔍 웹 AS - API 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic responseData = json.decode(response.body);
        print('🔍 웹 AS - 응답 데이터: $responseData');

        List<Map<String, dynamic>> requestList = [];

        // API 응답 형식 확인
        if (responseData is Map &&
            responseData.containsKey('success') &&
            responseData['success'] == true) {
          // 새로운 형식: {success: true, requests: [...]}
          final List<dynamic> requests = responseData['requests'] ?? [];
          requestList = List<Map<String, dynamic>>.from(requests);
          print('✅ 웹 AS - 데이터 로드 완료 (새 형식): ${requestList.length}건');
        } else if (responseData is List) {
          // 기존 형식: [...]
          requestList = List<Map<String, dynamic>>.from(responseData);
          print('✅ 웹 AS - 데이터 로드 완료 (기존 형식): ${requestList.length}건');
        }

        if (mounted) {
          setState(() {
            requests = requestList;
          });
        }
      } else {
        print('❌ 웹 AS - API 호출 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ 웹 AS - 신청 내역 로드 중 오류: $e');
      if (mounted) {
        setState(() {
          requests = [];
        });
      }
    }
  }

  // 공지사항을 DB에서 받아오는 함수
  Future<void> _loadNotice() async {
    try {
      setState(() {
        isNoticeLoading = true;
      });

      final response = await http.get(
        Uri.parse('http://localhost:5050/api/notice?category=as'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          noticeText = data['content'] ?? '';
          isNoticeLoading = false;
        });
      } else {
        setState(() {
          noticeText = null; // 기본 텍스트 사용
          isNoticeLoading = false;
        });
      }
    } catch (e) {
      print('AS 공지사항 로드 중 오류: $e');
      setState(() {
        noticeText = null; // 오류 시 기본 텍스트 사용
        isNoticeLoading = false;
      });
    }
  }

  // ... (이하 다른 함수들은 모두 동일)

  bool _isFormValid() {
    studentIdError = studentIdController.text.isEmpty ? '필수요소입니다' : null;
    nameError = nameController.text.isEmpty ? '필수요소입니다' : null;
    roomError = roomController.text.isEmpty ? '필수요소입니다' : null;
    contactError = contactController.text.isEmpty ? '필수요소입니다' : null;
    issueError =
        (selectedIssue == null || selectedIssue!.isEmpty) ? '필수요소입니다' : null;
    reasonError = reasonController.text.isEmpty ? '필수요소입니다' : null;
    imageError = uploadFiles.isEmpty ? '필수요소입니다' : null;
    setState(() {});
    return [
      studentIdError,
      nameError,
      roomError,
      contactError,
      issueError,
      reasonError,
      imageError,
    ].every((e) => e == null);
  }

  // 유효성 검사 에러가 있는지 확인하는 함수 (외박신청과 동일)
  bool _hasValidationErrors() {
    return [
      studentIdError,
      nameError,
      roomError,
      contactError,
      issueError,
      reasonError,
      imageError,
    ].any((error) => error != null);
  }

  // 공지사항 텍스트를 가져오는 함수 (DB에서 받아온 텍스트 또는 기본 텍스트)
  String _getNoticeText() {
    if (isNoticeLoading) {
      return '공지사항을 불러오는 중...';
    }

    // DB에서 받아온 텍스트가 있으면 사용, 없으면 기본 텍스트 사용
    return noticeText ?? _getDefaultNoticeText();
  }

  // 기본 공지사항 텍스트 (DB 연결 전 임시 사용)
  String _getDefaultNoticeText() {
    return 'A/S 신청 시 정확한 문제 현상과 사진을 첨부해주세요.\n신청 후 처리까지 1-3일 소요됩니다.';
  }

  // ===== 공지사항 카드 위젯 =====
  Widget _buildNoticeCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 정보 아이콘
            Icon(Icons.info_outline, size: 20.w, color: Colors.blue.shade600),
            SizedBox(width: 12.w),
            // 공지사항 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공지사항',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _getNoticeText(),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade700,
                      height: 1.4,
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

  Future<void> _deleteRequest(int index) async {
    try {
      final asUuid = requests[index]['as_uuid'];
      final url = Uri.parse('http://localhost:5050/api/as/request/$asUuid');

      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          requests.removeAt(index);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('AS 신청이 삭제되었습니다.')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 실패: ${response.body}')));
      }
    } catch (e) {
      print('AS 신청 삭제 중 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('삭제 중 오류가 발생했습니다: $e')));
    }
  }

  Future<void> _submitASRequest() async {
    final url = Uri.parse('http://localhost:5050/api/as/apply');
    final data = {
      'student_id': studentIdController.text,
      'as_category': selectedIssue ?? '',
      'description': reasonController.text,
      'stat': '대기중',
      'reg_dt': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      final respData = json.decode(response.body);
      final asUuidFromServer = respData['as_uuid'];

      for (final imgPath in uploadedImgPaths) {
        final imgUrl = Uri.parse('http://localhost:5050/api/as/image');
        await http.post(
          imgUrl,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'as_uuid': asUuidFromServer, 'img_path': imgPath}),
        );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신청이 완료되었습니다.')));

      final student = Provider.of<StudentProvider>(context, listen: false);
      setState(() {
        selectedIssue = null;
        reasonController.clear();
        uploadFiles.clear();
        uploadedImgPaths.clear();
      });

      await _loadASRequests();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('신청 실패: ${response.body}')));
    }
  }

  Future<void> pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );

      if (result != null) {
        for (var file in result.files) {
          if (kIsWeb) {
            if (file.bytes != null) {
              uploadFiles.add(
                UploadFile(
                  file: null,
                  name: file.name,
                  size: file.size,
                  webBytes: file.bytes,
                ),
              );
            }
          } else {
            if (file.path != null) {
              uploadFiles.add(
                UploadFile(
                  file: File(file.path!),
                  name: file.name,
                  size: file.size,
                ),
              );
            }
          }
        }
        setState(() {
          imageError = null; // 파일 선택 시 에러 상태 초기화
        });
        for (var file in uploadFiles) {
          if (file.status == '대기') {
            await uploadFile(file);
          }
        }
      }
    } catch (e) {
      print('파일 선택 중 오류: $e');
    }
  }

  Future<void> uploadFile(UploadFile file) async {
    try {
      file.status = '업로드중';
      setState(() {});

      String fileName = file.name;
      FormData formData;

      if (kIsWeb) {
        formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            file.webBytes!,
            filename: fileName,
            contentType: MediaType.parse('image/jpeg'),
          ),
        });
      } else {
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            file.file!.path,
            filename: fileName,
          ),
        });
      }

      final dio = Dio();
      dio.options.baseUrl = 'http://localhost:5050';
      dio.options.connectTimeout = const Duration(seconds: 120);
      dio.options.receiveTimeout = const Duration(seconds: 120);

      final response = await dio.post(
        '/api/upload',
        data: formData,
        onSendProgress: (sent, total) {
          file.progress = sent / total;
          setState(() {});
        },
      );

      if (response.statusCode == 200 && response.data['success']) {
        uploadedImgPaths.add(response.data['img_path']);
        file.status = '완료';
      } else {
        file.status = '에러';
        throw Exception(response.data['error'] ?? '파일 업로드 실패');
      }
    } catch (e) {
      file.status = '에러';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 업로드 실패: ${e.toString()}')));
    }
    setState(() {});
  }

  // =================================================================
  // ====================== UI 개선 코드 시작 ==========================
  // =================================================================

  @override
  Widget build(BuildContext context) {
    // 디자이너가 제안하는 세련된 색상 팔레트
    const pageBackgroundColor = Colors.white; // 전체 배경 흰색
    const cardBackgroundColor = Colors.white; // 카드도 흰색
    const borderColor = Color(0xFFDEE2E6); // 부드러운 테두리 색

    return Container(
      color: pageBackgroundColor, // 페이지 전체에 배경색 적용
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _mainTitle('A/S 신청'),
            SizedBox(height: 10.h),
            _buildUserInfoBar(),
            SizedBox(height: 16.h),
            _buildNoticeCard(),
            Divider(height: 22.h, thickness: 1, color: borderColor),
            SizedBox(height: 10.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 700.h, // 두 카드의 높이를 맞춤
                    child: _buildRequestFormCard(
                      cardBackgroundColor,
                      borderColor,
                    ),
                  ),
                ),
                SizedBox(width: 20.w),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 700.h, // 두 카드의 높이를 맞춘
                    child: _buildRequestHistorySection(
                      cardBackgroundColor,
                      borderColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 오른쪽 'A/S 신청 내역' 전체 섹션
  Widget _buildRequestHistorySection(Color backgroundColor, Color borderColor) {
    return Card(
      elevation: 1,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: borderColor, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20.w,
          20.h,
          20.w,
          8.h,
        ), // 하단 패딩 줄여서 카드와 경계 맞춤
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('A/S 신청 내역'),
            SizedBox(height: 16.h),
            Expanded(
              child:
                  requests.isNotEmpty
                      ? _buildRequestCardList()
                      : Center(
                        child: Text(
                          '신청 내역이 없습니다.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16.sp,
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  /// 최종 개선안이 적용된 A/S 신청 내역 카드 리스트
  Widget _buildRequestCardList() {
    // 텍스트, 아이콘 등에 사용할 색상 정의
    const primaryTextColor = Color(0xFF212529); // 부드러운 검정
    const secondaryTextColor = Color(0xFF6C757D); // 중간 회색

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        final status = req['stat'] ?? '대기중';

        return Card(
          elevation: 0,
          margin: EdgeInsets.only(bottom: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
            side: BorderSide(color: const Color(0xFFE9ECEF)),
          ),
          color: Colors.white, // 카드 배경 흰색
          // InkWell을 추가하여 탭 상호작용과 시각적 피드백 제공
          child: InkWell(
            onTap: () {
              // TODO: 상세 보기 페이지로 이동하는 로직 구현
              print('Tapped on request: ${req['as_category']}');
            },
            borderRadius: BorderRadius.circular(10.r),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              // [개선] ListTile 대신 커스텀 레이아웃으로 정렬 및 구조 최적화
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 첫 번째 줄: 문제 현상(좌측) | 날짜(우측)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          req['as_category'] ?? '문제 현상 없음',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      Text(
                        req['reg_dt'] ?? '',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  // 두 번째 줄: 문제 사유(좌측) | 상태 + 삭제버튼(우측)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          req['description'] ?? '상세 사유 없음',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: secondaryTextColor,
                            height: 1.5,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // 상태와 삭제 버튼을 한 줄에 배치
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatusChip(status),
                          if (status == '접수')
                            Padding(
                              padding: EdgeInsets.only(left: 8.w),
                              child: GestureDetector(
                                onTap: () => _deleteRequest(index),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20.sp,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  // 반려 사유 표시 추가
                  if (req['stat'] == '반려' &&
                      req['rejection_reason'] != null &&
                      req['rejection_reason'].toString().isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_rounded,
                            size: 16.sp,
                            color: Colors.red.shade600,
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '사유',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  req['rejection_reason'].toString(),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.red.shade700,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 16.h),
                  // 하단: 부가 정보 (첨부파일, 댓글 등) - UX 확장성
                  Row(
                    children: [
                      if (req['has_attachments'] == true)
                        InkWell(
                          onTap: () => _showAttachmentsDialog(req),
                          child: _buildInfoChip(
                            Icons.attachment_rounded,
                            '사진 ${req['attachments']?.length ?? 0}개',
                          ),
                        ),
                      if (req['has_comments'] == true)
                        Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: _buildInfoChip(Icons.comment_rounded, '답변 있음'),
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

  /// 상태(stat)에 따라 색상이 다른 텍스트를 생성
  Widget _buildStatusChip(String status) {
    Map<String, Color> colorMap = {
      '승인': Colors.green,
      '완료': Colors.green,
      '반려': Colors.red,
      '처리중': Colors.orange,
      '대기중': Colors.grey,
      '접수': Colors.blue,
      '처리완료': Colors.green,
    };
    Color baseColor = colorMap[status] ?? Colors.grey;
    return Text(
      status,
      style: TextStyle(
        color: baseColor,
        fontWeight: FontWeight.bold,
        fontSize: 12.sp,
      ),
    );
  }

  /// 하단 부가 정보 칩 (사진, 답변 여부 등)
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: Colors.grey.shade600),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  // --- 이하 위젯들은 색상 변수를 받도록เล็กน้อย 수정 ---
  Widget _mainTitle(String title) => Row(
    children: [
      Container(
        width: 4.w,
        height: 24.h,
        color: Colors.blue[900],
        margin: EdgeInsets.only(right: 8.w),
      ),
      Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.sp),
      ),
    ],
  );

  Widget _sectionTitle(String title) => Text(
    title,
    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
  );

  Widget _buildUserInfoBar() => LayoutBuilder(
    builder:
        (context, constraints) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _fixedField('년도', yearController.text)),
            SizedBox(width: 10.w),
            Expanded(child: _fixedField('학기', semesterController.text)),
            Container(
              height: 40.h,
              width: 1.w,
              color: Colors.grey[300],
              margin: EdgeInsets.symmetric(horizontal: 8.w),
            ),
            Expanded(child: _fixedField('학번', studentIdController.text)),
            SizedBox(width: 10.w),
            Expanded(child: _fixedField('이름', nameController.text)),
          ],
        ),
  );

  Widget _fixedField(String label, String value) => TextField(
    controller: TextEditingController(text: value),
    readOnly: true,
    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: OutlineInputBorder(),
      filled: true,
      fillColor: Colors.grey[100],
    ),
  );

  Widget _buildRequestFormCard(
    Color backgroundColor,
    Color borderColor,
  ) => Card(
    elevation: 1,
    color: backgroundColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.r),
      side: BorderSide(color: borderColor, width: 1),
    ),
    child: Padding(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('문제 현상 및 사유'),
          SizedBox(height: 16.h),
          // 호실과 연락처 필드 추가
          Row(
            children: [
              Expanded(
                child: _textField(
                  '호실',
                  roomController,
                  errorText: roomError,
                  onChanged:
                      () => setState(() => roomError = null), // 입력 시 에러 초기화
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _textField(
                  '연락처',
                  contactController,
                  errorText: contactError,
                  onChanged:
                      () => setState(() => contactError = null), // 입력 시 에러 초기화
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _issueDropdown(errorText: issueError),
          SizedBox(height: 8.h),
          _largeTextField(
            '문제 발생 사유를 입력하세요',
            reasonController,
            errorText: reasonError,
            onChanged: () => setState(() => reasonError = null), // 입력 시 에러 초기화
          ),
          SizedBox(height: 20.h),
          _sectionTitle('사진 업로드'),
          SizedBox(height: 8.h),
          _imageUploadBox(),
          SizedBox(height: 24.h),
          // 신청하기 버튼 영역
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // 필수값 입력 메시지 (유효성 검사 에러가 있을 때만 표시)
              if (_hasValidationErrors()) ...[
                Text(
                  '필수값을 입력하세요',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 16.w),
              ],
              // 신청하기 버튼
              _customButton('신청하기', () async {
                if (_isFormValid()) {
                  await _submitASRequest();
                } else {
                  // 유효성 검사 실패 시 상태 업데이트만 하고 스낵바는 제거
                  setState(() {});
                }
              }),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _textField(
    String label,
    TextEditingController controller, {
    String? errorText,
    VoidCallback? onChanged, // 입력 시 에러 상태 초기화용 콜백
  }) => TextField(
    controller: controller,
    style: TextStyle(fontSize: 13.sp),
    onChanged: (value) {
      if (onChanged != null) {
        onChanged(); // 입력 시 에러 상태 초기화
      }
    },
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13.sp),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      // 에러 상태일 때만 빨간색 테두리, 에러 텍스트는 완전 제거
      enabledBorder:
          errorText != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8.r),
              )
              : null, // null이면 전역 테마 사용
      focusedBorder:
          errorText != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8.r),
              )
              : null, // null이면 전역 테마 사용
      // errorText 완전 제거 - 빨간색 테두리만 표시
    ),
  );
  Widget _largeTextField(
    String hint,
    TextEditingController controller, {
    String? errorText,
    VoidCallback? onChanged, // 입력 시 에러 상태 초기화용 콜백
  }) => TextField(
    controller: controller,
    maxLines: 5,
    onChanged: (value) {
      if (onChanged != null) {
        onChanged(); // 입력 시 에러 상태 초기화
      }
    },
    decoration: InputDecoration(
      hintText: hint,
      contentPadding: EdgeInsets.all(12.w),
      // 에러 상태일 때만 빨간색 테두리, 에러 텍스트는 완전 제거
      enabledBorder:
          errorText != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8.r),
              )
              : null, // null이면 전역 테마 사용
      focusedBorder:
          errorText != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8.r),
              )
              : null, // null이면 전역 테마 사용
      // errorText 완전 제거 - 빨간색 테두리만 표시
    ),
  );
  Widget _issueDropdown({String? errorText}) =>
      DropdownButtonFormField2<String>(
        isExpanded: true,
        decoration: InputDecoration(
          labelText: '문제 현상',
          labelStyle: TextStyle(fontSize: 13.sp),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 12.w,
            vertical: 12.h,
          ),
          // 에러 상태일 때만 빨간색 테두리, 에러 텍스트는 완전 제거
          enabledBorder:
              errorText != null
                  ? OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(8.r),
                  )
                  : null, // null이면 전역 테마 사용
          focusedBorder:
              errorText != null
                  ? OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(8.r),
                  )
                  : null, // null이면 전역 테마 사용
          // errorText 완전 제거 - 빨간색 테두리만 표시
        ),
        hint: Text('선택하세요', style: TextStyle(fontSize: 13.sp)),
        value: selectedIssue,
        items:
            issueItems
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item, style: TextStyle(fontSize: 13.sp)),
                  ),
                )
                .toList(),
        onChanged:
            (val) => setState(() {
              selectedIssue = val;
              issueError = null; // 선택 시 에러 상태 초기화
            }),
        buttonStyleData: ButtonStyleData(
          height: 20.h,
          padding: EdgeInsets.only(left: 0, right: 0),
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 250.h,
          padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
      );
  Widget _customButton(String label, VoidCallback onPressed) => GestureDetector(
    onTap: onPressed,
    child: Container(
      width: 150.w, // 외박신청과 동일한 고정 너비
      padding: EdgeInsets.symmetric(vertical: 6.h), // 외박신청과 동일한 패딩
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r), // 외박신청과 동일한 더 둥근 모서리
        color: Colors.indigo, // 외박신청과 동일한 단색 배경
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.3),
            blurRadius: 6.r,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ),
  );

  Widget _imageUploadBox() {
    /* ... 이전과 동일 ... */
    return Container(
      height: 200.h,
      decoration: BoxDecoration(
        border: Border.all(
          color:
              imageError != null
                  ? Colors.red
                  : Colors.grey.shade400, // 에러 시 빨간색 테두리
          width: imageError != null ? 2 : 1, // 에러 시 두꺼운 테두리
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: pickFiles,
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.r),
                    bottomLeft: Radius.circular(8.r),
                  ),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48.w,
                      color: Colors.blue.shade300,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '클릭하여 파일 선택',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey.shade400)),
              ),
              child: _buildFileList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    /* ... 이전과 동일 ... */
    if (uploadFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Text(
            '업로드된 파일이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14.sp),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(8.w),
      shrinkWrap: true,
      itemCount: uploadFiles.length,
      itemBuilder: (context, index) {
        final file = uploadFiles[index];
        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // 이미지 미리보기
              ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: Container(
                  width: 50.w,
                  height: 50.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child:
                      kIsWeb && file.webBytes != null
                          ? Image.memory(
                            file.webBytes!,
                            width: 50.w,
                            height: 50.h,
                            fit: BoxFit.cover,
                          )
                          : Image.file(
                            file.file!,
                            width: 50.w,
                            height: 50.h,
                            fit: BoxFit.cover,
                          ),
                ),
              ),
              SizedBox(width: 12.w),
              // 파일 정보 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 파일명
                    Text(
                      file.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    // 용량과 상태를 한 줄에 배치
                    Row(
                      children: [
                        Text(
                          '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          file.status == '완료'
                              ? '업로드 완료'
                              : file.status == '업로드중'
                              ? '업로드 대기 중'
                              : file.status == '에러'
                              ? '업로드 실패'
                              : '대기 중',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color:
                                file.status == '완료'
                                    ? Colors.green.shade600
                                    : file.status == '에러'
                                    ? Colors.red.shade600
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    // 업로드 중일 때 진행바 표시
                    if (file.status == '업로드중') ...[
                      SizedBox(height: 6.h),
                      LinearProgressIndicator(
                        value: file.progress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ],
                  ],
                ),
              ),
              // 삭제 버튼
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Colors.grey.shade500,
                  size: 20.sp,
                ),
                onPressed: () {
                  // 파일 삭제 로직
                  setState(() {
                    uploadFiles.removeAt(index);
                    if (index < uploadedImgPaths.length) {
                      uploadedImgPaths.removeAt(index);
                    }
                  });
                },
                tooltip: '파일 삭제',
                padding: EdgeInsets.all(4.w),
                constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
              ),
            ],
          ),
        );
      },
    );
  }

  // 첨부파일 보기 다이얼로그
  void _showAttachmentsDialog(Map<String, dynamic> request) {
    final attachments = request['attachments'] as List<dynamic>? ?? [];

    if (attachments.isEmpty) {
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
            '첨부 파일 (${attachments.length}개)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400.w,
            height: 300.h,
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8.w,
                mainAxisSpacing: 8.h,
              ),
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                final attachment = attachments[index];
                final imageUrl = attachment['url'] as String;

                return GestureDetector(
                  onTap: () {
                    // 이미지 크게 보기
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
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 32.sp,
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    '이미지 로드 실패',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
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
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
