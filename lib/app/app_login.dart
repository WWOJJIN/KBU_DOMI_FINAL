import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ✅ 반응형
import 'package:provider/provider.dart';
import '../student_provider.dart';
import 'package:kbu_domi/env.dart';

class AppColors {
  static const primary = Color(0xFF4A69E2);
  static const primaryDark = Color(0xFF2C3E50);
  static const background = Color(0xFFF4F6FA);
  static const card = Colors.white;
  static const textPrimary = Color(0xFF34495E);
  static const textSecondary = Color(0xFF7F8C8D);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Pretendard',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.r),
        borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
      ),
      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 15.sp),
      contentPadding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
    ),
  );
}

class AppLogin extends StatefulWidget {
  const AppLogin({super.key});

  @override
  State<AppLogin> createState() => _AppLoginState();
}

class _AppLoginState extends State<AppLogin> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (_idController.text.trim().isEmpty ||
        _pwController.text.trim().isEmpty) {
      _showErrorDialog('아이디와 비밀번호를 입력해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final id = _idController.text.trim();
    final pw = _pwController.text.trim();

    try {
      final url = Uri.parse('$apiBase/api/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'student_id': id, 'password': pw}),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success']) {
            // StudentProvider에 학생 정보 저장
            final studentProvider = Provider.of<StudentProvider>(
              context,
              listen: false,
            );
            studentProvider.setStudentInfo(data['user']);

            Navigator.pushReplacementNamed(context, '/home');
          } else {
            _showErrorDialog(data['message'] ?? '아이디 또는 비밀번호가 일치하지 않습니다.');
          }
        } else {
          _showErrorDialog('서버와 통신할 수 없습니다. (코드: ${response.statusCode})');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('로그인 중 오류가 발생했습니다. 네트워크 연결을 확인해주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('로그인 실패'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. 로고 및 환영 메시지
                  Icon(Icons.school, size: 60.sp, color: AppColors.primary),
                  SizedBox(height: 24.h),
                  Text(
                    'KBU Dormitory',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '기숙사 통합 관리 시스템',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 48.h),

                  // 2. 입력 필드
                  TextField(
                    controller: _idController,
                    decoration: InputDecoration(
                      hintText: '아이디 (학번)',
                      hintStyle: TextStyle(
                        fontSize: 15.sp,
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: AppColors.textSecondary,
                        size: 22.sp,
                      ),
                    ),
                    style: TextStyle(fontSize: 16.sp),
                    keyboardType: TextInputType.text,
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: _pwController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: '비밀번호',
                      hintStyle: TextStyle(
                        fontSize: 15.sp,
                        color: AppColors.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: AppColors.textSecondary,
                        size: 22.sp,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                          size: 22.sp,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    style: TextStyle(fontSize: 16.sp),
                    keyboardType: TextInputType.visiblePassword,
                  ),
                  SizedBox(height: 32.h),

                  // 3. 로그인 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child:
                          _isLoading
                              ? SizedBox(
                                height: 24.h,
                                width: 24.h,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                              : Text(
                                '로그인',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // 4. 기타 옵션
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          '아이디/비밀번호 찾기',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                      Text(
                        '|',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          '회원가입',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
