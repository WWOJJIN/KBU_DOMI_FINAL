import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home.dart';
import '../../student/check.dart';
import '../../student/vacation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../student_provider.dart';
import '../../student/first.dart';
import '../../student/firstin.dart';
import 'package:kbu_domi/env.dart';

class LoginPage extends StatefulWidget {
  final String redirectTo; // 'application' 또는 'portal'

  const LoginPage({super.key, this.redirectTo = 'portal'});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // --- 로그인 관련 상태 변수 및 컨트롤러 ---
  final TextEditingController idController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  bool _isLoading = false;
  String selectedType = '재학생'; // 기본값: 재학생

  @override
  void initState() {
    super.initState();
    // 포털 로그인에서는 재학생으로 고정
    if (widget.redirectTo != 'application') {
      selectedType = '재학생';
    }
  }

  // --- 로그인 로직 ---
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });
    final id = idController.text.trim();
    final pw = pwController.text.trim();
    try {
      final url = Uri.parse('$apiBase/api/login');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': id,
          'password': pw,
          'login_type': selectedType, // 모집구분 정보 추가
          'user_type':
              selectedType == '재학생'
                  ? 'current_student'
                  : 'new_student', // user_type 추가
          'redirect_to': widget.redirectTo, // redirectTo 정보 추가
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final studentProvider = Provider.of<StudentProvider>(
            context,
            listen: false,
          );
          studentProvider.setStudentInfo(data['user']);
          bool isAdmin = data['is_admin'] ?? false;
          if (mounted) {
            // redirectTo에 따른 페이지 이동
            if (widget.redirectTo == 'application') {
              Navigator.pushReplacementNamed(
                context,
                '/firstin',
                arguments: {
                  'studentId': data['user']['student_id'],
                  'studentName': data['user']['name'],
                  'userType': selectedType, // 재학생/신입생 구분 정보 추가
                },
              );
            } else {
              Navigator.pushReplacementNamed(
                context,
                isAdmin ? '/adhome' : '/home',
              );
            }
          }
        } else {
          _showError('아이디 또는 비밀번호가 틀렸습니다.');
        }
      } else {
        _showError('서버 오류: ${response.statusCode}');
      }
    } catch (e) {
      _showError('네트워크 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('로그인 실패', style: TextStyle(fontSize: 16.sp)),
            content: Text(msg, style: TextStyle(fontSize: 14.sp)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('확인', style: TextStyle(fontSize: 14.sp)),
              ),
            ],
          ),
    );
  }

  void handleAdmitTap() {
    Navigator.pushNamed(context, '/check');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Column(
        children: [
          // ==================== 상단 UI 부분 ====================
          // 1. 최상단 회색바
          Container(
            color: const Color(0xFFF6F6F6),
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 4.h),
            child: Row(
              children: [
                Text(
                  '경복대학교  |  입학홈페이지',
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          // 2. 로고 + 메뉴 한 줄
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 18.h),
            child: Row(
              children: [
                // [수정됨] 로고 클릭 시 first.dart로 이동
                InkWell(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DormIntroPage(),
                        ),
                      ),
                  child: Image.asset(
                    'imgs/kbu_logo1.png',
                    height: 50.h,
                    fit: BoxFit.fitHeight,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    TopMenuButton('생활관소개'),
                    TopMenuButton('시설안내'),
                    TopMenuButton('입사/퇴사/생활안내'),
                    TopMenuButton('커뮤니티'),
                    // [수정됨] 기숙사 입주신청 클릭 시 입주신청용 로그인으로 이동
                    TopMenuButton(
                      '기숙사 입주신청',
                      highlight: widget.redirectTo == 'application',
                      onTap:
                          () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const LoginPage(
                                    redirectTo: 'application',
                                  ),
                            ),
                          ),
                    ),
                    // [수정됨] 포털 로그인일 때만 highlight 적용
                    TopMenuButton(
                      '기숙사 포털시스템',
                      highlight: widget.redirectTo == 'portal',
                      onTap:
                          () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      const LoginPage(redirectTo: 'portal'),
                            ),
                          ),
                    ),
                    IconButton(
                      icon: Icon(Icons.menu, size: 28.sp),
                      onPressed: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 3. 네이비 헤더 영역
          Stack(
            children: [
              Container(
                height: 80.h,
                width: double.infinity,
                color: const Color(0xFF033762),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 56.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '기숙사 포털 로그인',
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'KBU Dormitory Portal System',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // ==================== 로그인 폼 UI 시작 ====================
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 50.h),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 400.w,
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10.r,
                              offset: Offset(0, 4.h),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 30.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'L',
                                    style: TextStyle(color: Color(0xFF00408B)),
                                  ),
                                  TextSpan(
                                    text: 'O',
                                    style: TextStyle(color: Color(0xFF00408B)),
                                  ),
                                  TextSpan(
                                    text: 'G',
                                    style: TextStyle(color: Color(0xFF00408B)),
                                  ),
                                  TextSpan(
                                    text: 'I',
                                    style: TextStyle(color: Color(0xFF00408B)),
                                  ),
                                  TextSpan(
                                    text: 'N',
                                    style: TextStyle(color: Color(0xFF00408B)),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24.h),
                            // 모집구분 선택 (입주신청용 로그인에서만 표시)
                            if (widget.redirectTo == 'application') ...[
                              Container(
                                width: double.infinity,
                                height: 36.h,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => selectedType = '재학생');
                                          // 입력 필드 초기화
                                          idController.clear();
                                          pwController.clear();
                                        },
                                        child: Container(
                                          height: 36.h,
                                          decoration: BoxDecoration(
                                            color:
                                                selectedType == '재학생'
                                                    ? Colors.blue[900]
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '재학생',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                color:
                                                    selectedType == '재학생'
                                                        ? Colors.white
                                                        : Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() => selectedType = '신입생');
                                          // 입력 필드 초기화
                                          idController.clear();
                                          pwController.clear();
                                        },
                                        child: Container(
                                          height: 36.h,
                                          decoration: BoxDecoration(
                                            color:
                                                selectedType == '신입생'
                                                    ? Colors.blue[900]
                                                    : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              8.r,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '신입생',
                                              style: TextStyle(
                                                fontSize: 14.sp,
                                                color:
                                                    selectedType == '신입생'
                                                        ? Colors.white
                                                        : Colors.grey[600],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16.h),
                            ],
                            _labeledTextField(
                              widget.redirectTo == 'application'
                                  ? (selectedType == '재학생' ? '학번' : '수험번호')
                                  : '학번',
                              widget.redirectTo == 'application'
                                  ? (selectedType == '재학생'
                                      ? '학번 입력'
                                      : '수험번호 입력')
                                  : '학번 입력',
                              controller: idController,
                            ),
                            SizedBox(height: 14.h),
                            _labeledTextField(
                              widget.redirectTo == 'application'
                                  ? (selectedType == '재학생' ? '비밀번호' : '생년월일')
                                  : '비밀번호',
                              widget.redirectTo == 'application'
                                  ? (selectedType == '재학생'
                                      ? '비밀번호 입력'
                                      : 'YYYYMMDD')
                                  : '비밀번호 입력',
                              obscure:
                                  widget.redirectTo == 'application'
                                      ? (selectedType == '재학생')
                                      : true,
                              controller: pwController,
                            ),
                            SizedBox(height: 32.h),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue[900],
                                  minimumSize: Size(double.infinity, 48.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                ),
                                child:
                                    _isLoading
                                        ? CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                        : Text(
                                          '로그인',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            color: Colors.white,
                                          ),
                                        ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            Text(
                              widget.redirectTo == 'application'
                                  ? (selectedType == '재학생'
                                      ? '※ 재학생은 학번과 비밀번호로 로그인하세요.'
                                      : '※ 신입생은 수험번호와 생년월일(YYYYMMDD)로 로그인하세요.')
                                  : '※ 로그인 정보는 대학 포털시스템과 동일합니다.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 30.h),
                      Container(
                        width: 600.w,
                        padding: EdgeInsets.symmetric(
                          vertical: 20.h,
                          horizontal: 24.w,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8.r,
                              offset: Offset(0, 2.h),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _QuickServiceIcon(
                              image: 'imgs/quick_link_home.png',
                              label: '홈페이지',
                              url: 'https://kbu.ac.kr/kor/Main.do',
                            ),
                            _QuickServiceIcon(
                              image: 'imgs/quick_link_online.png',
                              label: '공지사항',
                              url:
                                  'https://kbu.ac.kr/kor/CMS/Board/Board.do?mCode=MN069',
                            ),
                            _QuickServiceIcon(
                              image: 'imgs/portal.png',
                              label: '포털시스템',
                              url: 'https://newportal.kbu.ac.kr/por/mn',
                            ),
                            _QuickServiceIcon(
                              image: 'imgs/lunch.png',
                              label: '학식메뉴',
                              url:
                                  'https://kbu.ac.kr/kor/CMS/DietMenuMgr/list.do?mCode=MN203',
                            ),
                            _QuickServiceIcon(
                              image: 'imgs/rrcal.png',
                              label: '방학예약',
                              onTap:
                                  () =>
                                      Navigator.pushNamed(context, '/vacation'),
                            ),
                            _QuickServiceIcon(
                              image: 'imgs/check.png',
                              label: '합격자조회',
                              onTap: handleAdmitTap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 로그인 폼 관련 헬퍼 위젯들 ---

Widget _labeledTextField(
  String label,
  String hint, {
  bool obscure = false,
  TextEditingController? controller,
}) {
  return SizedBox(
    height: 44.h,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 60.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: TextStyle(fontSize: 13.sp),
            decoration: InputDecoration(
              hintText: hint,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 10.w,
                vertical: 6.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.r),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _QuickServiceIcon extends StatelessWidget {
  final String image;
  final String label;
  final String? url;
  final VoidCallback? onTap;

  const _QuickServiceIcon({
    required this.image,
    required this.label,
    this.url,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          onTap ??
          () async {
            if (url != null) {
              final uri = Uri.parse(url!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
      child: Column(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Image.asset(image, fit: BoxFit.contain),
          ),
          SizedBox(height: 8.h),
          Text(label, style: TextStyle(fontSize: 12.sp)),
        ],
      ),
    );
  }
}

class TopMenuButton extends StatefulWidget {
  final String label;
  final bool highlight;
  final VoidCallback? onTap;

  const TopMenuButton(
    this.label, {
    this.highlight = false,
    this.onTap,
    super.key,
  });

  @override
  State<TopMenuButton> createState() => _TopMenuButtonState();
}

class _TopMenuButtonState extends State<TopMenuButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        onTap: widget.onTap,
        hoverColor: Colors.transparent,
        splashColor: Colors.blue.withOpacity(0.1),
        highlightColor: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(4.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.0.w, vertical: 8.h),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 16.sp,
              color:
                  widget.highlight || _isHovering
                      ? const Color(0xFF1766AE)
                      : const Color(0xFF222222),
              fontWeight:
                  widget.highlight || _isHovering
                      ? FontWeight.bold
                      : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
