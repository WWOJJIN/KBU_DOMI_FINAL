import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'domi_portal/login.dart'; // LoginPage가 정의된 파일
import 'firstin.dart'; // FirstInPage가 정의된 파일

class DormIntroPage extends StatelessWidget {
  const DormIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                bottom: 0,
                left: 300.w,
                child: Container(
                  width: screenWidth - 320.w,
                  height: 220.h,
                  color: const Color(0xFF00205B),
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '<',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 80.sp,
                            fontFamily: 'Arial',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        SizedBox(width: 50.w),
                        navIcon(
                          context,
                          '합격자조회',
                          '2.png',
                          onTap: () {
                            Navigator.pushNamed(context, '/check');
                          },
                        ),
                        SizedBox(width: 50.w),
                        navIcon(context, '연락처', '3.png'),
                        SizedBox(width: 50.w),
                        navIcon(context, '오시는길', '4.png'),
                        SizedBox(width: 50.w),
                        navIcon(context, '층별안내도', 'domibbock.png'),
                        SizedBox(width: 40.w),
                        Text(
                          '>',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 80.sp,
                            fontFamily: 'Arial',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 최상단 회색바
                  Container(
                    color: const Color(0xFFF6F6F6),
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 4.h,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '경복대학교  |  입학홈페이지',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                        // 언어 선택 드롭다운 등 다른 요소가 필요하면 여기에 추가할 수 있습니다.
                      ],
                    ),
                  ),
                  // 2. 로고 + 메뉴 한 줄
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: 36.w,
                      vertical: 18.h,
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'imgs/kbu_logo1.png',
                          height: 50.h,
                          fit: BoxFit.fitHeight,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            TopMenuButton('생활관소개'),
                            TopMenuButton('시설안내'),
                            TopMenuButton('입사/퇴사/생활안내'),
                            TopMenuButton('커뮤니티'),
                            // [수정됨] highlight 속성을 제거하여 기본 색상을 검은색으로 변경
                            TopMenuButton(
                              '기숙사 입주신청',
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const LoginPage(
                                            redirectTo: 'application',
                                          ),
                                    ),
                                  ),
                            ),
                            TopMenuButton(
                              '기숙사 포털시스템',
                              onTap:
                                  () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const LoginPage(
                                            redirectTo: 'portal',
                                          ),
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
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 40.w,
                      vertical: 20.h,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 40.h),
                              Text(
                                '참되고 유능한 인재양성을 위한\n안식처',
                                style: TextStyle(
                                  fontSize: 36.sp,
                                  fontWeight: FontWeight.w900,
                                  height: 1.4,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                'KBU 기숙사',
                                style: TextStyle(fontSize: 16.sp),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: SizedBox(
                            width: 460.w,
                            child: Image.asset('imgs/1.png', fit: BoxFit.cover),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 170.h),
                ],
              ),

              Positioned(
                bottom: 130.h,
                left: 0,
                height: 260.h,
                child: ClipPath(
                  clipper: DiagonalCornerClipper(),
                  child: Container(
                    width: 520.w,
                    color: const Color(0xFFFF1E91),
                    padding: EdgeInsets.fromLTRB(120.w, 28.h, 28.w, 28.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '생활관 소개',
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 30.h),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white),
                          ),
                          onPressed: () {},
                          child: const Text(
                            '자세히보기',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget navIcon(
    BuildContext context,
    String title,
    String assetName, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('imgs/$assetName', width: 80.w, height: 80.h),
          SizedBox(height: 6.h),
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
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

class DiagonalCornerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width - 100, 0);
    path.lineTo(size.width, 100);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
