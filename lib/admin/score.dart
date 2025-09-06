import 'dart:io';
import 'dart:typed_data'; // [웹 호환성 수정] 웹에서 파일 데이터를 다루기 위해 import
import 'package:flutter/foundation.dart'; // [웹 호환성 수정] 웹 환경인지 확인하기 위해 import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kbu_domi/env.dart';

// === 컬러 및 텍스트 스타일 ===
const Color kNavy = Color(0xFF1C2946);
const Color kBlue = Color(0xFF3498DB);
const Color kRed = Color(0xFFE74C3C);
const Color kGreen = Color(0xFF2ECC71);
const Color kSurface = Colors.white;
const Color kBackground = Color(0xFFF6F7FA);
const Color kLightGray = Color(0xFFE7ECF3);
const Color kGrayText = Color(0xFF7F8C9A);

TextStyle heading1 = TextStyle(
  fontSize: 24.sp,
  fontWeight: FontWeight.bold,
  color: kNavy,
);
TextStyle heading2 = TextStyle(
  fontSize: 18.sp,
  fontWeight: FontWeight.bold,
  color: kNavy,
);
TextStyle bodyText = TextStyle(
  fontSize: 16.sp,
  color: kNavy.withOpacity(0.8),
  fontWeight: FontWeight.w500,
);
TextStyle bodyTextSmall = TextStyle(
  fontSize: 14.sp,
  color: kGrayText,
  fontWeight: FontWeight.w500,
);
TextStyle labelText = TextStyle(
  fontSize: 14.sp,
  color: kGrayText,
  fontWeight: FontWeight.w500,
);
TextStyle labelTextSmall = TextStyle(
  fontSize: 11.sp,
  color: kGrayText,
  fontWeight: FontWeight.w500,
);

// --- 상벌점 종류 enum ---
enum ScoreType { plus, minus }

// --- 데이터 모델 ---
class Student {
  final int number;
  final String name;
  final String studentId;
  int plus;
  int minus;
  Student({
    required this.number,
    required this.name,
    required this.studentId,
    this.plus = 0,
    this.minus = 0,
  });
  int get total => plus - minus;
}

// [웹 호환성 수정] fileBytes 필드 추가
class ScoreDetail {
  final int number;
  final String date;
  final ScoreType type;
  final String content;
  final String? filePath; // 모바일/데스크톱용
  final Uint8List? fileBytes; // 웹용
  final String eventDate;
  final int score;
  ScoreDetail({
    required this.number,
    required this.date,
    required this.type,
    required this.content,
    this.filePath,
    this.fileBytes,
    required this.eventDate,
    required this.score,
  });
}

class ScorePage extends StatefulWidget {
  const ScorePage({super.key});
  @override
  State<ScorePage> createState() => _ScorePageState();
}

class _ScorePageState extends State<ScorePage> {
  List<Student> students = [];
  Map<String, List<ScoreDetail>> studentScores = {};
  bool isLoading = true;
  bool isLoadingScores = false;

  String _search = '';
  Student? _selectedStudent;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  // 학생 목록 로드
  Future<void> _loadStudents() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$apiBase/api/admin/students'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          students =
              data
                  .map(
                    (item) => Student(
                      number: item['number'],
                      name: item['name'],
                      studentId: item['student_id'],
                      plus: item['plus'],
                      minus: item['minus'],
                    ),
                  )
                  .toList();
          isLoading = false;
        });
      } else {
        throw Exception('학생 목록을 불러오는데 실패했습니다.');
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('학생 목록 로드 실패: $e'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  // 학생별 상벌점 내역 로드
  Future<void> _loadStudentScores(String studentId) async {
    setState(() => isLoadingScores = true);
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/admin/student/scores/$studentId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          studentScores[studentId] =
              data
                  .map(
                    (item) => ScoreDetail(
                      number: item['number'],
                      date: item['date']?.split('T')[0] ?? '',
                      type:
                          item['type'] == 'plus'
                              ? ScoreType.plus
                              : ScoreType.minus,
                      content: item['content'],
                      filePath: item['file_path'],
                      eventDate: item['event_date']?.split('T')[0] ?? '',
                      score: item['score'],
                    ),
                  )
                  .toList();
          isLoadingScores = false;
        });
      } else {
        throw Exception('상벌점 내역을 불러오는데 실패했습니다.');
      }
    } catch (e) {
      setState(() => isLoadingScores = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('상벌점 내역 로드 실패: $e'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  // 상벌점 추가
  Future<void> _addScore({
    required ScoreType type,
    required String content,
    required DateTime eventDate,
    required PlatformFile? file,
    required int score,
  }) async {
    if (_selectedStudent == null) return;

    try {
      String? imgPath;

      // 파일 업로드 처리
      if (file != null) {
        final uploadResponse = await _uploadScoreFile(file);
        if (uploadResponse != null) {
          imgPath = uploadResponse['img_path'];
        }
      }

      // 상벌점 데이터 전송
      final response = await http.post(
        Uri.parse('$apiBase/api/admin/student/scores'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': _selectedStudent!.studentId,
          'type': type == ScoreType.plus ? 'plus' : 'minus',
          'content': content,
          'score': score,
          'event_date': DateFormat('yyyy-MM-dd').format(eventDate),
          'img_path': imgPath,
        }),
      );

      if (response.statusCode == 200) {
        // 성공 시 학생 목록과 상벌점 내역 새로고침
        await _loadStudents();
        await _loadStudentScores(_selectedStudent!.studentId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedStudent!.name} 학생의 상/벌점 내역이 성공적으로 반영되었습니다.',
            ),
            backgroundColor: kGreen,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(20),
          ),
        );
      } else {
        throw Exception('상벌점 추가에 실패했습니다.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('상벌점 추가 실패: $e'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  // 파일 업로드
  Future<Map<String, dynamic>?> _uploadScoreFile(PlatformFile file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBase/api/admin/score/upload'),
      );

      if (kIsWeb && file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else if (!kIsWeb && file.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path!),
        );
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return json.decode(responseData);
      }
    } catch (e) {
      print('파일 업로드 실패: $e');
    }
    return null;
  }

  // 샘플 데이터 추가
  Future<void> _addSampleData() async {
    try {
      final response = await http.post(
        Uri.parse('$apiBase/api/admin/score/sample-data'),
      );
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: kGreen,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(20),
          ),
        );
        // 데이터 새로고침
        await _loadStudents();
        if (_selectedStudent != null) {
          await _loadStudentScores(_selectedStudent!.studentId);
        }
      } else {
        throw Exception('샘플 데이터 추가에 실패했습니다.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('샘플 데이터 추가 실패: $e'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
        ),
      );
    }
  }

  Widget _buildLeftPanel() {
    final filtered =
        students
            .where((s) => s.name.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    return Container(
      margin: EdgeInsets.all(20.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16.r),
        // [수정] 테두리 추가
        border: Border.all(color: kLightGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("입주 학생 목록", style: heading1),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: 40.h,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _search = v),
                    style: bodyText.copyWith(fontSize: 14.sp),
                    decoration: InputDecoration(
                      hintText: '이름으로 검색',
                      hintStyle: bodyText.copyWith(fontSize: 14.sp),
                      prefixIcon: Icon(
                        Icons.search,
                        color: kGrayText,
                        size: 20.sp,
                      ),
                      filled: true,
                      fillColor: kBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(color: kBlue, width: 2),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                      suffixIcon:
                          _search.isNotEmpty
                              ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: kGrayText,
                                  size: 18.sp,
                                ),
                                onPressed:
                                    () => setState(() {
                                      _searchController.clear();
                                      _search = '';
                                    }),
                              )
                              : null,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              ElevatedButton.icon(
                onPressed: _loadStudents,
                icon: Icon(Icons.refresh, size: 16.sp),
                label: Text(
                  '새로고침',
                  style: labelText.copyWith(
                    fontSize: 16.sp,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(130.w, 50.h),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                  textStyle: bodyText.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          _buildStudentListHeader(),
          SizedBox(height: 8.h),
          Expanded(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final student = filtered[index];
                        final isSelected =
                            _selectedStudent?.studentId == student.studentId;
                        return _buildStudentListItem(student, isSelected);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('순번', style: labelText)),
          Expanded(flex: 3, child: Text('이름', style: labelText)),
          Expanded(flex: 3, child: Text('학번', style: labelText)),
          Expanded(
            flex: 2,
            child: Text('총점', style: labelText, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListItem(Student student, bool isSelected) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _selectedStudent = student);
            _loadStudentScores(student.studentId);
          },
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: isSelected ? kBlue.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(student.number.toString(), style: bodyText),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    student.name,
                    style: bodyText.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(student.studentId, style: bodyText),
                ),
                Expanded(flex: 2, child: _buildScoreTag(student.total)),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: const Divider(color: kLightGray, height: 1, thickness: 1),
        ),
      ],
    );
  }

  Widget _buildScoreTag(int score) {
    Color tagColor;
    if (score > 0) {
      tagColor = kBlue;
    } else if (score < 0) {
      tagColor = kRed;
    } else {
      tagColor = kGrayText;
    }

    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: tagColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          score.toString(),
          style: bodyText.copyWith(
            color: tagColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      margin: EdgeInsets.fromLTRB(0, 20.w, 20.w, 20.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16.r),
        // [수정] 테두리 추가
        border: Border.all(color: kLightGray),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child:
          _selectedStudent == null
              ? _buildPlaceholder()
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailHeader(),
                  SizedBox(height: 24.h),
                  _AddNewScoreForm(
                    key: ValueKey(_selectedStudent!.studentId),
                    onApply: _addScore,
                  ),
                  SizedBox(height: 24.h),
                  const Divider(color: kLightGray, thickness: 1.5),
                  SizedBox(height: 24.h),
                  Text("상/벌점 상세 내역", style: heading1),
                  SizedBox(height: 16.h),
                  _buildScoreHistoryHeader(),
                  SizedBox(height: 8.h),
                  Expanded(child: _buildScoreHistoryList()),
                ],
              ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 80.sp, color: kLightGray),
          SizedBox(height: 16.h),
          Text(
            "학생을 선택하여 상세 내역을 조회하세요.",
            style: heading2.copyWith(color: kGrayText),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(_selectedStudent!.name, style: heading1.copyWith(fontSize: 32.sp)),
        SizedBox(width: 12.w),
        Text(
          _selectedStudent!.studentId,
          style: labelText.copyWith(fontSize: 16.sp),
        ),
        const Spacer(),
        _buildScoreSummary('상점', _selectedStudent!.plus, kBlue),
        SizedBox(width: 16.w),
        _buildScoreSummary('벌점', _selectedStudent!.minus, kRed),
        SizedBox(width: 24.w),
        _buildScoreSummary('총점', _selectedStudent!.total, kNavy),
      ],
    );
  }

  Widget _buildScoreSummary(String title, int score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: labelText),
        Text(
          score.toString(),
          style: heading1.copyWith(color: color, height: 1.2),
        ),
      ],
    );
  }

  Widget _buildScoreHistoryHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text('순번', style: labelText)),
          Expanded(flex: 3, child: Text('부여일', style: labelText)),
          Expanded(flex: 3, child: Text('발생일', style: labelText)),
          Expanded(flex: 2, child: Text('종류', style: labelText)),
          Expanded(flex: 2, child: Center(child: Text('점수', style: labelText))),
          Expanded(flex: 4, child: Text('내용', style: labelText)),
          Expanded(
            flex: 2,
            child: Center(child: Text('첨부파일', style: labelText)),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreHistoryList() {
    if (isLoadingScores) {
      return const Center(child: CircularProgressIndicator());
    }

    final scores = studentScores[_selectedStudent!.studentId] ?? [];
    if (scores.isEmpty) {
      return Center(
        child: Text(
          "상/벌점 내역이 없습니다.",
          style: labelText.copyWith(fontSize: 16.sp),
        ),
      );
    }
    return ListView.builder(
      itemCount: scores.length,
      itemBuilder: (context, index) => _buildScoreHistoryItem(scores[index]),
    );
  }

  Widget _buildScoreHistoryItem(ScoreDetail detail) {
    final isPlus = detail.type == ScoreType.plus;
    final bool hasFile = detail.filePath != null;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kLightGray, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(detail.number.toString(), style: bodyText),
          ),
          Expanded(flex: 3, child: Text(detail.date, style: bodyTextSmall)),
          Expanded(
            flex: 3,
            child: Text(detail.eventDate, style: bodyTextSmall),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  isPlus ? Icons.add_circle : Icons.remove_circle,
                  color: isPlus ? kBlue : kRed,
                  size: 18.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  isPlus ? '상점' : '벌점',
                  style: bodyText.copyWith(
                    color: isPlus ? kBlue : kRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                '${isPlus ? '+' : '-'}${detail.score}',
                style: bodyText.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPlus ? kBlue : kRed,
                ),
              ),
            ),
          ),
          Expanded(flex: 4, child: Text(detail.content, style: bodyText)),
          Expanded(
            flex: 2,
            child: Center(
              child:
                  hasFile
                      ? ElevatedButton(
                        onPressed: () => _showFilePopup(detail.filePath, null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kLightGray,
                          foregroundColor: kNavy,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          textStyle: labelText.copyWith(
                            fontWeight: FontWeight.bold,
                            color: kNavy,
                          ),
                        ),
                        child: const Text('조회'),
                      )
                      : Text('-', style: labelText),
            ),
          ),
        ],
      ),
    );
  }

  // [웹 호환성 수정] _showFilePopup 로직 수정
  void _showFilePopup(String? filePath, Uint8List? fileBytes) {
    Widget imageWidget;

    // 표시할 이미지를 결정하는 로직
    if (filePath != null && filePath.startsWith('imgs/')) {
      // 1. 더미 데이터 (Asset)
      imageWidget = Image.asset(filePath);
    } else if (!kIsWeb && filePath != null) {
      // 2. 모바일/데스크톱에서 선택한 파일
      imageWidget = Image.file(File(filePath));
    } else if (kIsWeb && fileBytes != null) {
      // 3. 웹에서 선택한 파일
      imageWidget = Image.memory(fileBytes);
    } else if (filePath != null && filePath.startsWith('score/')) {
      // 4. 서버에서 업로드된 파일
      imageWidget = Image.network('$apiBase/uploads/$filePath');
    } else {
      // 5. 표시할 이미지가 없는 경우
      imageWidget = const Text("이미지 정보가 없습니다.");
    }

    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("첨부파일 보기", style: heading2),
                  SizedBox(height: 20.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: imageWidget,
                  ),
                  SizedBox(height: 20.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNavy,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: const Text('닫기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(
      context,
      designSize: const Size(1920, 1080),
      minTextAdapt: true,
    );
    return Scaffold(
      backgroundColor: kBackground,
      body: Row(
        children: [
          Expanded(flex: 4, child: _buildLeftPanel()),
          Expanded(flex: 7, child: _buildRightPanel()),
        ],
      ),
    );
  }
}

// =========================[ 입력폼 위젯 ]========================
class _AddNewScoreForm extends StatefulWidget {
  final Function({
    required ScoreType type,
    required String content,
    required DateTime eventDate,
    required PlatformFile? file,
    required int score,
  })
  onApply;

  const _AddNewScoreForm({super.key, required this.onApply});
  @override
  State<_AddNewScoreForm> createState() => _AddNewScoreFormState();
}

class _AddNewScoreFormState extends State<_AddNewScoreForm> {
  bool _isFormEnabled = false;
  final _contentController = TextEditingController();
  final _scoreController = TextEditingController();
  DateTime _eventDate = DateTime.now();
  ScoreType? _addType;
  PlatformFile? _pickedFile;

  ThemeData _datePickerTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme: const ColorScheme.light(
        primary: kBlue,
        onPrimary: Colors.white,
        onSurface: kNavy,
        surface: kSurface,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kBlue,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    ); // 이미지 파일만 선택하도록 제한
    if (result != null) setState(() => _pickedFile = result.files.first);
  }

  void _submitForm() {
    if (_addType == null ||
        _contentController.text.trim().isEmpty ||
        _scoreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('상/벌점 종류, 점수, 내용을 모두 입력해주세요.'),
          backgroundColor: kRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
        ),
      );
      return;
    }

    widget.onApply(
      type: _addType!,
      content: _contentController.text,
      eventDate: _eventDate,
      file: _pickedFile,
      score: int.tryParse(_scoreController.text) ?? 0,
    );

    setState(() {
      _isFormEnabled = false;
      _contentController.clear();
      _scoreController.clear();
      _addType = null;
      _eventDate = DateTime.now();
      _pickedFile = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(12.r),
        border:
            _isFormEnabled ? Border.all(color: kBlue.withOpacity(0.5)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 150.w, height: 50.h, child: _buildDatePickerField()),
          SizedBox(width: 12.w),
          SizedBox(width: 110.w, height: 50.h, child: _buildTypeDropdown()),
          SizedBox(width: 12.w),
          SizedBox(width: 80.w, height: 50.h, child: _buildScoreField()),
          SizedBox(width: 12.w),
          Expanded(
            child: SizedBox(
              height: 50.h,
              child: TextField(
                controller: _contentController,
                enabled: _isFormEnabled,
                style: bodyText.copyWith(fontSize: 13.sp),
                decoration: _inputDecoration(label: '내용'),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          SizedBox(width: 150.w, height: 50.h, child: _buildFilePickerField()),
          SizedBox(width: 16.w),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildDatePickerField() {
    return GestureDetector(
      onTap:
          _isFormEnabled
              ? () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _eventDate,
                  firstDate: DateTime(2022, 1),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                  builder:
                      (context, child) =>
                          Theme(data: _datePickerTheme(context), child: child!),
                );
                if (picked != null) setState(() => _eventDate = picked);
              }
              : null,
      child: AbsorbPointer(
        child: TextField(
          enabled: _isFormEnabled,
          controller: TextEditingController(
            text: DateFormat('yyyy-MM-dd').format(_eventDate),
          ),
          style: bodyText.copyWith(fontSize: 13.sp),
          decoration: _inputDecoration(
            label: '발생일',
            icon: Icons.calendar_today,
          ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<ScoreType>(
      value: _addType,
      items: const [
        DropdownMenuItem(value: ScoreType.plus, child: Text('상점')),
        DropdownMenuItem(value: ScoreType.minus, child: Text('벌점')),
      ],
      onChanged: _isFormEnabled ? (v) => setState(() => _addType = v) : null,
      style: bodyText.copyWith(fontSize: 13.sp),
      decoration: _inputDecoration(label: '종류'),
      dropdownColor: kSurface,
      disabledHint:
          _addType != null
              ? Text(
                _addType == ScoreType.plus ? '상점' : '벌점',
                style: bodyText.copyWith(fontSize: 13.sp),
              )
              : null,
    );
  }

  Widget _buildScoreField() {
    return TextField(
      controller: _scoreController,
      enabled: _isFormEnabled,
      style: bodyText.copyWith(fontSize: 13.sp),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _inputDecoration(label: '점수'),
    );
  }

  Widget _buildFilePickerField() {
    return GestureDetector(
      onTap: _isFormEnabled ? _pickFile : null,
      child: AbsorbPointer(
        child: TextField(
          enabled: _isFormEnabled,
          controller: TextEditingController(text: _pickedFile?.name ?? '파일 선택'),
          style: bodyText.copyWith(
            overflow: TextOverflow.ellipsis,
            fontSize: 13.sp,
          ),
          decoration: _inputDecoration(label: '첨부파일', icon: Icons.attach_file),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder:
          (child, animation) => ScaleTransition(scale: animation, child: child),
      child:
          _isFormEnabled
              ? ElevatedButton.icon(
                key: const ValueKey('applyButton'),
                onPressed: _submitForm,
                icon: const Icon(Icons.check),
                label: const Text('반영'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  minimumSize: Size(90.w, 50.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  textStyle: bodyText.copyWith(fontWeight: FontWeight.bold),
                ),
              )
              : ElevatedButton.icon(
                key: const ValueKey('addButton'),
                onPressed: () => setState(() => _isFormEnabled = true),
                icon: Icon(Icons.add, size: 16.sp),
                label: Text(
                  '추가',
                  style: labelText.copyWith(
                    fontSize: 16.sp,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue,
                  foregroundColor: Colors.white,
                  minimumSize: Size(130.w, 50.h),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                  textStyle: bodyText.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
    );
  }

  InputDecoration _inputDecoration({required String label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 10.sp, color: kGrayText),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: _isFormEnabled ? kSurface : kBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6.r),
        borderSide: const BorderSide(color: kLightGray, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6.r),
        borderSide: const BorderSide(color: kLightGray, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6.r),
        borderSide: const BorderSide(color: kBlue, width: 1.0),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6.r),
        borderSide: const BorderSide(color: kLightGray, width: 1.0),
      ),
      contentPadding: EdgeInsets.fromLTRB(10.w, 15.h, 10.w, 5.h),
      prefixIcon:
          icon != null ? Icon(icon, color: kGrayText, size: 16.sp) : null,
    );
  }
}
