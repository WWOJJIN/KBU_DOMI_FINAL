import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_screenutil/flutter_screenutil.dart'; // 📱 반응형 패키지 추가

// 실제 프로젝트의 파일 경로에 맞게 수정해!
import 'package:kbu_domi/student/domi_portal/dash.dart';
import 'package:kbu_domi/student_provider.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();

  String? _searchedStudentId;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _searchResult;

  // 🧑‍💻 학생 이름 또는 학번으로 검색 (API 연동)
  Future<void> _performSearch() async {
    final studentName = _nameController.text.trim();
    final studentId = _studentIdController.text.trim();

    if (studentName.isEmpty && studentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('이름 또는 학번을 입력해주세요.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchedStudentId = null;
      _searchResult = null;
    });

    try {
      http.Response response;
      String searchParam;
      bool isNameSearch = studentName.isNotEmpty;

      if (studentId.isNotEmpty) {
        searchParam = studentId;
        response = await http.get(
          Uri.parse('http://localhost:5050/api/student/$searchParam'),
        );
      } else {
        searchParam = studentName;
        response = await http.get(
          Uri.parse('http://localhost:5050/api/student/name/$searchParam'),
        );
      }

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          Map<String, dynamic>? user;

          if (isNameSearch) {
            // 이름 검색의 경우
            if (data['success'] == true && data['user'] != null) {
              user = data['user'];
            }
          } else {
            // 학번 검색의 경우
            if (data != null && data.isNotEmpty) {
              user = data;
            }
          }

          if (user != null) {
            setState(() {
              _searchResult = user;
              _searchedStudentId = user?['student_id'];
            });
            _showSuccessSnackBar(user['name'], user['student_id']);
          } else {
            setState(() {
              _errorMessage = "'$searchParam'(으)로 학생을 찾을 수 없습니다.";
            });
          }
        } else if (response.statusCode == 404) {
          setState(() {
            _errorMessage = "'$searchParam'(으)로 학생을 찾을 수 없습니다.";
          });
        } else {
          setState(() {
            _errorMessage = "서버와 통신할 수 없습니다. (코드: ${response.statusCode})";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "네트워크 연결을 확인하거나 서버 상태를 점검해주세요!";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 검색 성공 알림 스낵바
  void _showSuccessSnackBar(String name, String studentId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20.sp),
            SizedBox(width: 10.w),
            Text('$name ($studentId) 님을 찾았습니다.'),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 검색 초기화
  void _resetSearch() {
    setState(() {
      _nameController.clear();
      _studentIdController.clear();
      _searchedStudentId = null;
      _errorMessage = null;
      _searchResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ⚡️ ScreenUtil 반응형 반드시 최상단에서 호출! (RootApp에서 이미 되어있어야 함)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 8.h),
          child: Text(
            "학생 정보 검색",
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
          child: _buildSearchPanel(),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildResultView(),
          ),
        ),
      ],
    );
  }

  /// 🔍 검색 패널 위젯
  Widget _buildSearchPanel() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.10),
            spreadRadius: 2.r,
            blurRadius: 10.r,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTextField(_nameController, "이름", Icons.person_outline),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _buildTextField(
              _studentIdController,
              "학번",
              Icons.badge_outlined,
            ),
          ),
          SizedBox(width: 12.w),
          if (_searchedStudentId != null && !_isLoading)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: SizedBox(
                height: 50.h,
                child: OutlinedButton(
                  onPressed: _resetSearch,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    side: BorderSide(color: Colors.grey[400]!),
                    foregroundColor: Colors.grey[700],
                  ),
                  child: Icon(Icons.refresh, size: 20.sp),
                ),
              ),
            ),
          // 검색 버튼
          SizedBox(
            height: 50.h,
            child: AspectRatio(
              aspectRatio: 1,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _performSearch,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  backgroundColor: const Color(0xFF00408B), // KBU Blue
                ),
                child:
                    _isLoading
                        ? SizedBox(
                          width: 20.sp,
                          height: 20.sp,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : Icon(Icons.search, color: Colors.white, size: 24.sp),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 📝 공용 텍스트 필드 위젯
  Widget _buildTextField(
    TextEditingController controller,
    String hintText,
    IconData icon,
  ) {
    return TextField(
      controller: controller,
      style: TextStyle(fontSize: 15.sp),
      enabled: !_isLoading,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 15.sp, color: Colors.grey[500]),
        prefixIcon: Icon(icon, color: Colors.grey[600], size: 20.sp),
        filled: true,
        fillColor: _isLoading ? Colors.grey[200] : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 10.w),
      ),
      onSubmitted: (_) => _performSearch(),
    );
  }

  /// 🔄 검색 결과에 따라 다른 뷰 보여줌
  Widget _buildResultView() {
    if (_isLoading) {
      return Center(
        key: const ValueKey('loading'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48.w,
              height: 48.w,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF00408B),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "학생 정보를 검색하고 있습니다...",
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        key: const ValueKey('error'),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64.w, color: Colors.red[300]),
              SizedBox(height: 16.h),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.red[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16.h),
              ElevatedButton.icon(
                onPressed: _resetSearch,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 검색'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00408B),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchedStudentId != null && _searchResult != null) {
      // 검색 성공 시 DashPage를 searchMode: true로 보여준다!
      return ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22.r),
          topRight: Radius.circular(22.r),
        ),
        child: ChangeNotifierProvider(
          key: ValueKey(_searchedStudentId),
          create: (_) => StudentProvider(),
          child: DashPage(
            studentId: _searchedStudentId!,
            searchMode: true, // 반드시 searchMode true로!
          ),
        ),
      );
    }

    // 초기 상태 (아직 검색 전)
    return Center(
      key: const ValueKey('initial'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_outlined,
            size: 80.w,
            color: Colors.grey[300],
          ),
          SizedBox(height: 16.h),
          Text(
            "학생 이름 또는 학번으로 정보를 조회하세요.",
            style: TextStyle(
              fontSize: 17.sp,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            "이름 또는 학번 중 하나만 입력해도 검색 가능합니다.",
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
