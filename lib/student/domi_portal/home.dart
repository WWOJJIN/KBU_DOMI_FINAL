import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 사용을 위해
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart'; // GPS 점호 기능을 위한 패키지 추가
import '../../student_provider.dart';
import '../../services/storage_service.dart';
import 'dart:html' as html; // 웹 전용 import
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login.dart';
import 'as.dart';
import 'overnight.dart';
import 'out.dart';
import 'dinner.dart';
import 'in.dart';
import 'roommate.dart';
import 'dash.dart'; // 대쉬보드(내기숙사) 페이지
import 'package:provider/provider.dart';
import 'pm.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedMenu = 0; // ⭐️ 내기숙사(대쉬보드 역할) 기본 선택!
  bool _hasLoadedFromUrl = false; // 🚨 중복 URL 로드 방지 플래그

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🚨 화면 크기 변경으로 인한 중복 호출 방지
    if (!_hasLoadedFromUrl) {
      _loadPageFromUrl();
      _hasLoadedFromUrl = true;
    }
  }

  /// URL에서 페이지 인덱스 로드
  void _loadPageFromUrl() {
    try {
      final route = ModalRoute.of(context);
      if (route?.settings.name != null) {
        final uri = Uri.parse(route!.settings.name!);
        final pageParam = uri.queryParameters['page'];
        print('🔍 URL에서 페이지 파라미터 확인: $pageParam');

        if (pageParam != null) {
          final pageIndex = int.tryParse(pageParam);
          print('🔍 파싱된 페이지 인덱스: $pageIndex');

          if (pageIndex != null &&
              pageIndex >= 0 &&
              pageIndex < _menuList.length) {
            // 🚨 A/S 페이지(인덱스 6)로의 의도하지 않은 이동 방지
            if (pageIndex == 6 && _selectedMenu != 6) {
              print('⚠️ AS 페이지(6)로의 의도하지 않은 이동 감지 - 내기숙사(0)로 유지');
              setState(() {
                _selectedMenu = 0; // 내기숙사로 강제 설정
              });
              // URL도 올바르게 업데이트
              _updateUrl(0);
              return;
            }

            setState(() {
              _selectedMenu = pageIndex;
            });
            print(
              '🔍 URL에서 페이지 복원: $_selectedMenu (${_menuList[_selectedMenu]["title"]})',
            );
          } else {
            print('⚠️ 유효하지 않은 페이지 인덱스: $pageIndex, 기본값(0) 사용');
            setState(() {
              _selectedMenu = 0;
            });
          }
        } else {
          print('🔍 URL에 페이지 파라미터 없음, 기본값(0) 사용');
        }
      }
    } catch (e) {
      print('❌ URL 페이지 로드 실패: $e');
    }
  }

  /// URL 업데이트 (페이지 상태 유지를 위해)
  void _updateUrl(int pageIndex) {
    try {
      final newUrl = '/home?page=$pageIndex';
      // HTML5 History API 사용하여 URL 변경 (새로고침 없이)
      if (kIsWeb) {
        html.window.history.replaceState(null, '', '#$newUrl');
        print('🔍 URL 업데이트: $newUrl (${_menuList[pageIndex]["title"]})');
      }

      // StorageService에도 저장
      StorageService.saveStudentPageIndex(pageIndex);
    } catch (e) {
      print('❌ URL 업데이트 실패: $e');
    }
  }

  final Color kbuBlue = const Color(0xFF00408B);
  final Color kbuPink = const Color(0xFFEC008C);

  // GPS 점호를 위한 상수 정의
  static const double _kCampusLat = 37.735700;
  static const double _kCampusLng = 127.210523;
  static const double _kAllowedDistance = 500.0; // 500m 이내 통과

  final List<Map<String, dynamic>> _menuList = [
    {
      "icon": Icons.home_rounded,
      "title": "내기숙사",
      "page": () => const DashPage(),
    },
    {
      "icon": Icons.search,
      "title": "상벌점조회",
      "page": () => const PointHistoryPage(),
    },
    {
      "icon": Icons.meeting_room_outlined,
      "title": "입실신청",
      "page": () => const InPage(),
    },
    {
      "icon": Icons.group_add,
      "title": "룸메이트 신청",
      "page": () => const RoommatePage(),
    },
    {
      "icon": Icons.restaurant_menu_rounded,
      "title": "석식신청",
      "page": () => const DinnerRequestPage(),
    },
    {
      "icon": Icons.night_shelter_outlined,
      "title": "외박신청",
      "page": () => const OutingRequestPage(),
    },
    {
      "icon": Icons.build_circle_outlined,
      "title": "AS신청",
      "page": () => const ASRequestPage(),
    },
    {
      "icon": Icons.exit_to_app_rounded,
      "title": "퇴소신청",
      "page": () => const CheckoutApplyPage(),
    },
  ];

  @override
  void initState() {
    super.initState();
    print('HomePage initState - _selectedMenu: $_selectedMenu'); // 디버그 출력

    // 🔧 잠시 기다린 후 자동 로그인 체크 (로그인 직후 충돌 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkAndRestoreLoginSafely();
        }
      });
    });
  }

  /// 안전한 자동 로그인 체크 (새로고침 시에만)
  Future<void> _checkAndRestoreLoginSafely() async {
    try {
      print('🔍 HomePage - 안전한 로그인 체크 시작');

      final studentProvider = Provider.of<StudentProvider>(
        context,
        listen: false,
      );

      // 이미 studentId가 있으면 체크하지 않음 (로그인 직후)
      if (studentProvider.studentId != null) {
        print('✅ HomePage - 이미 로그인됨, 체크 생략: ${studentProvider.studentId}');
        return;
      }

      print('🔍 HomePage - studentId가 없어서 저장된 정보 확인 중...');

      // StorageService 초기화
      await StorageService.init();

      // 로그인 상태 확인
      final isLoggedIn = await studentProvider.isLoggedIn();
      print('🔍 HomePage - 저장소 로그인 상태: $isLoggedIn');

      if (isLoggedIn) {
        print('🔍 HomePage - 저장된 정보 복원 시도');
        final restored = await studentProvider.loadFromStorage();
        print('🔍 HomePage - 복원 결과: $restored');
        print('🔍 HomePage - 복원 후 studentId: ${studentProvider.studentId}');

        if (restored && studentProvider.studentId != null) {
          print('✅ HomePage - 저장된 정보 복원 성공');
          return; // 성공적으로 복원됨
        } else {
          print('❌ HomePage - 저장된 정보 복원 실패');
        }
      }

      // 5초 후에도 studentId가 없으면 로그인 페이지로 이동
      print('⏰ HomePage - 5초 후 재확인 예정...');
      await Future.delayed(const Duration(seconds: 5));

      if (mounted) {
        final currentProvider = Provider.of<StudentProvider>(
          context,
          listen: false,
        );
        if (currentProvider.studentId == null) {
          print('🔑 HomePage - 최종 확인 후 로그인 페이지로 이동');
          Navigator.pushReplacementNamed(context, '/login');
        } else {
          print(
            '✅ HomePage - 지연 후 studentId 확인됨: ${currentProvider.studentId}',
          );
        }
      }
    } catch (e) {
      print('❌ HomePage - 안전한 로그인 확인 실패: $e');
      // 에러 발생 시에는 즉시 로그인 페이지로 이동하지 않음
      print('⚠️ HomePage - 에러 무시하고 계속 진행');
    }
  }

  /// 자동 로그인 체크 및 복원 (기존 함수 유지)
  Future<void> _checkAndRestoreLogin() async {
    try {
      print('🔍 HomePage - 자동 로그인 체크 시작');

      final studentProvider = Provider.of<StudentProvider>(
        context,
        listen: false,
      );

      // StorageService 초기화
      await StorageService.init();

      // 로그인 상태 확인
      final isLoggedIn = await studentProvider.isLoggedIn();
      print('🔍 HomePage - 로그인 상태: $isLoggedIn');

      if (isLoggedIn) {
        print('🔍 HomePage - 저장된 정보 복원 시도');
        final restored = await studentProvider.loadFromStorage();
        print('🔍 HomePage - 복원 결과: $restored');
        print('🔍 HomePage - 복원 후 studentId: ${studentProvider.studentId}');

        if (restored && studentProvider.studentId != null) {
          print('✅ HomePage - 자동 로그인 복원 성공');
          return; // 성공적으로 복원됨
        } else {
          print('❌ HomePage - 저장된 정보 복원 실패');
        }
      }

      print('🔑 HomePage - 로그인 필요 - 로그인 페이지로 이동');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      print('❌ HomePage - 자동 로그인 확인 실패: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  // GPS 점호 처리 함수
  Future<void> _handleRollCall() async {
    try {
      // 위치 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _showInfoDialog(
            icon: Icons.error_outline,
            iconColor: Colors.redAccent,
            title: '위치 권한 필요',
            message: '점호를 위해 위치 권한을 허용해주세요.',
          );
          return;
        }
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 캠퍼스와의 거리 계산
      double distance = Geolocator.distanceBetween(
        _kCampusLat,
        _kCampusLng,
        position.latitude,
        position.longitude,
      );

      // 거리 표시 형식 설정
      String distanceStr;
      if (distance < 1000) {
        distanceStr = '${distance.toStringAsFixed(0)}m';
      } else {
        distanceStr = '${(distance / 1000).toStringAsFixed(2)}km';
      }

      // 점호 성공/실패 판정
      if (distance <= _kAllowedDistance) {
        _showInfoDialog(
          icon: Icons.check_circle_outline,
          iconColor: Colors.green,
          title: '점호 승인 🎉',
          message: '기준점에서 $distanceStr 거리에 있습니다.\n출석이 정상적으로 처리되었습니다.',
        );
      } else {
        _showInfoDialog(
          icon: Icons.error_outline,
          iconColor: Colors.redAccent,
          title: '점호 실패',
          message: '기준점에서 너무 멉니다.\n현재 위치는 약 $distanceStr 떨어져 있습니다.',
        );
      }
    } catch (e) {
      _showInfoDialog(
        icon: Icons.error_outline,
        iconColor: Colors.redAccent,
        title: '위치 확인 오류',
        message: '현재 위치를 가져올 수 없습니다.\nGPS 설정을 확인해주세요.',
      );
    }
  }

  // 정보 다이얼로그 표시 함수
  void _showInfoDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: 340,
              height: 340,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor.withOpacity(0.12),
                    ),
                    child: Icon(icon, color: iconColor, size: 40),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kbuBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '확인',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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

  @override
  Widget build(BuildContext context) {
    final studentProvider = Provider.of<StudentProvider>(context);

    // 🔧 studentId가 아직 로딩 중이면 로딩 화면 표시
    if (studentProvider.studentId == null) {
      print('HomePage build - studentId 로딩 중...');
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                '학생 정보를 불러오는 중...',
                style: TextStyle(fontSize: 16, color: Color(0xFF2C3E50)),
              ),
            ],
          ),
        ),
      );
    }

    Widget sideMenu() {
      return Container(
        width: 240.w,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8.r,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(height: 28), // 팀원 버전: 여백 증가
            Image.asset('imgs/logo.png', height: 58), // 팀원 버전: 크기 증가
            SizedBox(height: 14), // 팀원 버전: 여백 조정
            Icon(
              Icons.person_outline,
              color: kbuBlue,
              size: 44.w,
            ), // 팀원 버전: 사용자 아이콘 추가
            Text(
              "KBU 기숙사",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: kbuBlue,
                fontSize: 20.sp, // 팀원 버전: 폰트 크기 증가
                letterSpacing: 0.2, // 팀원 버전: letterSpacing 추가
              ),
            ),
            SizedBox(height: 15),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ..._menuList.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final isSelected = _selectedMenu == idx;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 3,
                        horizontal: 10,
                      ),
                      child: Material(
                        color:
                            isSelected
                                ? kbuPink.withOpacity(0.12)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            print(
                              '메뉴 클릭: ${item["title"]} (인덱스: $idx)',
                            ); // 디버그 출력
                            setState(() {
                              _selectedMenu = idx;
                            });
                            // URL 업데이트
                            _updateUrl(idx);
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 7,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item["icon"],
                                  color: isSelected ? kbuPink : kbuBlue,
                                  size: 23,
                                ),
                                SizedBox(width: 13),
                                Text(
                                  item["title"],
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                    color:
                                        isSelected ? kbuPink : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            // ---- 사이드바 하단: 프로필/로그아웃 (팀원 버전 스타일 적용) ----
            Padding(
              padding: EdgeInsets.only(bottom: 20, top: 7), // 팀원 버전: 패딩 조정
              child: Column(
                children: [
                  // 프로필 아바타 (팀원 버전 스타일)
                  CircleAvatar(
                    radius: 28, // 팀원 버전: 크기 조정
                    backgroundColor: kbuBlue.withOpacity(0.15), // 팀원 버전: 투명도 조정
                    child:
                        studentProvider.name != null &&
                                studentProvider.name!.isNotEmpty
                            ? Text(
                              studentProvider.name![0],
                              style: TextStyle(
                                color: kbuBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 20, // 팀원 버전: 폰트 크기 조정
                                letterSpacing: 1, // 팀원 버전: letterSpacing 추가
                              ),
                            )
                            : Icon(
                              Icons.person,
                              color: kbuBlue,
                              size: 20,
                            ), // 팀원 버전: 아이콘 크기 조정
                  ),
                  SizedBox(height: 10),
                  Text(
                    studentProvider.name ?? '이름',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kbuBlue,
                      fontSize: 14, // 팀원 버전: 폰트 크기 조정
                    ),
                  ),
                  Text(
                    studentProvider.studentId != null
                        ? '학번: ${studentProvider.studentId}'
                        : '학번: -',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ), // 팀원 버전: 색상 조정
                  ),
                  SizedBox(height: 15), // 팀원 버전: 여백 조정
                  // 로그아웃 버튼 (팀원 버전 스타일)
                  SizedBox(
                    width: 150, // 팀원 버전: 너비 조정
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor:
                            Colors.white, // 팀원 버전: foregroundColor 추가
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: 11,
                        ), // 팀원 버전: 패딩 조정
                      ),
                      icon: Icon(Icons.logout, size: 20), // 팀원 버전: 아이콘 크기 조정
                      label: Text(
                        "로그아웃",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15, // 팀원 버전: 폰트 크기 조정
                        ),
                      ),
                      onPressed: () {
                        Provider.of<StudentProvider>(
                          context,
                          listen: false,
                        ).clear();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 메뉴별 페이지(컨텐츠)
    Widget contentForMenu() {
      print('contentForMenu 호출 - _selectedMenu: $_selectedMenu'); // 디버그 출력
      final pageBuilder = _menuList[_selectedMenu]['page'];
      if (pageBuilder != null && pageBuilder is Function) {
        print('페이지 빌더 실행: ${_menuList[_selectedMenu]['title']}'); // 디버그 출력
        return pageBuilder();
      }
      print('페이지 빌더가 null이거나 Function이 아님'); // 디버그 출력
      return const SizedBox.shrink();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Row(
          children: [
            sideMenu(),
            // 오른쪽(컨텐츠) - 흰 박스 + 여백
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 64,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 9,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // 팀원 버전: 명확한 패딩 구조
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 34,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: contentForMenu(),
                          ),
                        ),
                        SizedBox(height: 12), // 팀원 버전: 여백 추가
                        SizedBox(height: 18), // 팀원 버전: 추가 여백
                      ],
                    ),
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
