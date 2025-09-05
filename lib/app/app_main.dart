import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // ✅ ScreenUtil import
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kbu_domi/app/app_login.dart';
import 'package:kbu_domi/app/app_home.dart';
import 'package:kbu_domi/app/app_as.dart';
import 'package:kbu_domi/app/app_dinner.dart';
import 'package:kbu_domi/app/app_pm.dart';
import 'package:kbu_domi/app/app_setting.dart';
import 'package:kbu_domi/app/app_overnight.dart';
import 'package:kbu_domi/student_provider.dart';
import 'package:kbu_domi/services/storage_service.dart';

void main() {
  runApp(const RootApp());
}

// ✅ ScreenUtilInit은 앱 전체를 감싸야 함!
class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    // designSize는 너가 Figma, XD 등 디자인한 기준 해상도!
    // 일반적으로 iPhone12(375x812), 갤럭시(360x800) 아무거나 써도 무난함
    return ScreenUtilInit(
      designSize: const Size(375, 812), // ← 기준 해상도
      minTextAdapt: true,
      splitScreenMode: true,
      builder:
          (context, child) => ChangeNotifierProvider(
            create: (context) => StudentProvider(),
            child: const MyApp(),
          ),
    );
  }
}

// --- 앱 루트 ---
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _initialRoute = '/login';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  /// 로그인 상태 확인 및 자동 복원
  Future<void> _checkLoginStatus() async {
    try {
      final studentProvider = Provider.of<StudentProvider>(
        context,
        listen: false,
      );
      final isLoggedIn = await studentProvider.isLoggedIn();

      if (isLoggedIn) {
        final restored = await studentProvider.loadFromStorage();
        if (restored) {
          print('✅ 자동 로그인 복원 성공');
          setState(() {
            _initialRoute = '/home';
            _isInitialized = true;
          });
          return;
        }
      }

      print('🔑 로그인 필요');
      setState(() {
        _initialRoute = '/login';
        _isInitialized = true;
      });
    } catch (e) {
      print('자동 로그인 확인 실패: $e');
      setState(() {
        _initialRoute = '/login';
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // 로딩 화면 표시
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('앱을 준비하고 있습니다...'),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'KBU Dormitory',
      debugShowCheckedModeBanner: false,
      initialRoute: _initialRoute,
      routes: {
        '/login': (context) => const AppLogin(),
        '/home': (context) => HomeShell(),
        '/settings': (context) => const AppSetting(),
        '/pm': (context) => const AppPm(),
        '/dinner': (context) => const AppDinner(),
        '/as': (context) => const AppAs(),
        '/overnight': (context) => const OverNight(),
      },
    );
  }
}

// ===================== 알림 데이터 구조 =====================
class NotificationItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String date;
  final String type;
  final String uuid;

  NotificationItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.type,
    required this.uuid,
  });

  // 서버 응답에서 NotificationItem 객체로 변환하는 팩토리 메서드
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    IconData icon;
    switch (json['icon']) {
      case 'check_circle':
        icon = Icons.check_circle;
        break;
      case 'cancel':
        icon = Icons.cancel;
        break;
      case 'restaurant':
        icon = Icons.restaurant_menu;
        break;
      default:
        icon = Icons.info;
    }

    return NotificationItem(
      icon: icon,
      color: Color(int.parse(json['color'].replaceFirst('#', '0xFF'))),
      title: json['title'],
      subtitle: json['subtitle'] ?? '',
      date: json['date'],
      type: json['type'],
      uuid: json['uuid'],
    );
  }
}

// ===================== 커스텀 알림 팝업 위젯 =====================
class CustomNotificationDialog extends StatelessWidget {
  final List<NotificationItem> notifications;
  final void Function(int) onDelete;

  const CustomNotificationDialog({
    super.key,
    required this.notifications,
    required this.onDelete,
  });

  String _formatDate(String dateString) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final date = DateTime.parse(dateString);
      final notificationDate = DateTime(date.year, date.month, date.day);
      final difference = today.difference(notificationDate).inDays;
      if (difference == 0) {
        return '오늘';
      } else if (difference == 1) {
        return '어제';
      } else if (difference > 1 && difference < 30) {
        return '$difference일 전';
      } else {
        return dateString;
      }
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r), // ✅ r 적용
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 24.h,
          horizontal: 20.w,
        ), // ✅ h, w 적용
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 헤더 ---
            Padding(
              padding: EdgeInsets.only(left: 4.w, bottom: 16.h),
              child: Text(
                '알림',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22.sp, // ✅ sp 적용
                  color: const Color(0xFF34495E),
                ),
              ),
            ),
            // --- 알림 목록 or "없음" 메시지 ---
            notifications.isEmpty
                ? _buildEmptyState()
                : Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 아이콘
                          CircleAvatar(
                            radius: 20.r,
                            backgroundColor: item.color.withOpacity(0.1),
                            child: Icon(
                              item.icon,
                              color: item.color,
                              size: 22.sp,
                            ),
                          ),
                          SizedBox(width: 16.w),
                          // 내용
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    color: const Color(0xFF34495E),
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (item.subtitle.isNotEmpty) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    item.subtitle,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: const Color(0xFF5D6D7E),
                                    ),
                                  ),
                                ],
                                SizedBox(height: 4.h),
                                Text(
                                  _formatDate(item.date),
                                  style: TextStyle(
                                    color: const Color(0xFF7F8C8D),
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // X 버튼
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 20.sp,
                              color: const Color(0xFFB0B8C1),
                            ),
                            tooltip: "삭제",
                            splashRadius: 16.r,
                            onPressed: () => onDelete(index),
                          ),
                        ],
                      );
                    },
                    separatorBuilder:
                        (context, index) => Divider(
                          height: 1.h,
                          color: const Color(0xFFF0F2F5),
                        ),
                  ),
                ),
            SizedBox(height: 24.h),
            // --- 닫기 버튼 ---
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A69E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                padding: EdgeInsets.symmetric(vertical: 14.h),
              ),
              child: Text(
                '닫기',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 알림이 없을 때 보여줄 위젯
  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 40.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 50.sp,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16.h),
          Text(
            '새로운 알림이 없습니다.',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ===================== 상단 더블앱바 =====================
class DoubleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isHome;
  final String? pageTitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const DoubleAppBar({
    super.key,
    required this.isHome,
    this.pageTitle,
    this.onBack,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 첫 줄: 홈 상단바 (로고 + actions)
          Container(
            height: 48.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            color: const Color(0xFFEAF4FF),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset(
                  'imgs/4.png',
                  height: 28.h,
                  width: 28.w,
                  errorBuilder:
                      (context, error, stackTrace) =>
                          Icon(Icons.school, size: 28.sp),
                ),
                SizedBox(width: 8.w),
                Text(
                  'KBU Dormitory',
                  style: TextStyle(
                    color: const Color(0xFF34495E),
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
                const Spacer(),
                ...actions,
              ],
            ),
          ),
          if (!isHome && pageTitle != null) ...[
            Container(
              height: 1.h,
              width: double.infinity,
              color: const Color(0xFFDBDEE4),
            ),
            Container(
              height: 40.h,
              width: double.infinity,
              color: Colors.white,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: const Color(0xFF34495E),
                        size: 24.sp,
                      ),
                      onPressed: onBack,
                    ),
                  ),
                  Text(
                    pageTitle!,
                    style: TextStyle(
                      color: const Color(0xFF34495E),
                      fontWeight: FontWeight.bold,
                      fontSize: 17.sp,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Container(
            height: 1.h,
            width: double.infinity,
            color: const Color(0xFFDBDEE4),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize {
    final double totalHeight = isHome ? 49.h : 90.h;
    return Size.fromHeight(totalHeight);
  }
}

// ===================== 메인 페이지(하단네비/앱바) =====================
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 2; // 홈
  VoidCallback? _homeRefreshCallback;

  /// 저장된 페이지 인덱스 로드
  Future<void> _loadSavedPageIndex() async {
    try {
      final savedIndex = await StorageService.getStudentPageIndex();
      if (mounted && savedIndex >= 0 && savedIndex < _labels.length) {
        setState(() {
          _selectedIndex = savedIndex;
        });
        print('학생 페이지 복원: $_selectedIndex');
      }
    } catch (e) {
      print('학생 페이지 인덱스 로드 실패: $e');
    }
  }

  static const List<String> _labels = [
    'A/S 신청',
    '외박 신청',
    'KBU Dormitory',
    '석식 신청',
    '상벌점 내역',
  ];
  static const List<IconData> _icons = [
    Icons.build_outlined,
    Icons.hotel_outlined,
    Icons.home_rounded,
    Icons.restaurant_menu_outlined,
    Icons.grade_outlined,
  ];

  // 알림 데이터 (서버에서 로드)
  List<NotificationItem> _notifications = [];
  bool _isLoadingNotifications = false;

  @override
  void initState() {
    super.initState();
    print('🔔 HomeShell initState 시작');

    // 저장된 페이지 인덱스 로드
    _loadSavedPageIndex();

    // 앱 시작 시 알림 로드 (더 늦은 시점에 실행)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔔 PostFrameCallback 실행');

      // 약간의 지연을 두고 실행 (Provider 초기화 대기)
      Future.delayed(const Duration(milliseconds: 500), () {
        print('🔔 지연 후 _loadNotifications 호출');
        _loadNotifications();
      });
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // 페이지 인덱스를 로컬 저장소에 저장
    _savePageIndex(index);

    // 홈 탭이 선택되었을 때 홈 화면 데이터 새로고침
    if (index == 2 && _homeRefreshCallback != null) {
      print('🔄 홈 탭 선택됨 - 데이터 새로고침 요청');
      _homeRefreshCallback!();
    }
  }

  /// 페이지 인덱스 저장
  Future<void> _savePageIndex(int index) async {
    try {
      await StorageService.saveStudentPageIndex(index);
    } catch (e) {
      print('학생 페이지 인덱스 저장 실패: $e');
    }
  }

  void _onHomeCardTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // 홈 카드 클릭 시에도 페이지 인덱스 저장
    _savePageIndex(index);
  }

  // 서버에서 알림 데이터 로드하는 메서드
  Future<void> _loadNotifications() async {
    print('🔔 _loadNotifications() 함수 시작');

    if (_isLoadingNotifications) {
      print('🔴 이미 알림 로딩 중입니다.');
      return;
    }

    setState(() {
      _isLoadingNotifications = true;
    });

    print('🔔 알림 로딩 상태를 true로 설정');

    try {
      final studentProvider = Provider.of<StudentProvider>(
        context,
        listen: false,
      );
      final studentId = studentProvider.studentId;

      print('🔔 StudentProvider에서 가져온 studentId: $studentId');

      // StudentProvider가 아직 초기화되지 않았을 경우 임시로 하드코딩된 값 사용
      String? actualStudentId = studentId;
      if (studentId == null) {
        print('🔴 학생 ID가 없어서 임시로 하드코딩된 값(1) 사용');
        actualStudentId = '1'; // 임시 하드코딩
      } else {
        print('🔔 학생 ID 확인 완료: $studentId');
      }

      final response = await http.get(
        Uri.parse(
          'http://localhost:5050/api/student/notifications?student_id=$actualStudentId',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      print('🔔 알림 API 응답: ${response.statusCode}');
      print('🔔 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🔔 파싱된 데이터: $data');

        if (data['success'] == true) {
          final List<dynamic> notificationList = data['notifications'];
          print('🔔 알림 리스트 길이: ${notificationList.length}');

          setState(() {
            _notifications =
                notificationList
                    .map((item) => NotificationItem.fromJson(item))
                    .toList();
          });
          print('🔔 알림 ${_notifications.length}개 로드 완료');
          print('🔔 설정된 _notifications: $_notifications');
        } else {
          print('🔴 API 응답 success가 false');
        }
      } else {
        print('🔴 알림 로드 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('🔴 알림 로드 오류: $e');
    } finally {
      setState(() {
        _isLoadingNotifications = false;
      });
    }
  }

  void _showNotificationsDialog() {
    print('🔔 다이얼로그 열기 - 현재 알림 개수: ${_notifications.length}');

    // 알림이 비어있으면 다시 로드 시도
    if (_notifications.isEmpty) {
      print('🔔 알림이 비어있어서 다시 로드 시도');
      _loadNotifications().then((_) {
        // 로드 완료 후 다이얼로그 표시
        _showNotificationDialogInternal();
      });
    } else {
      _showNotificationDialogInternal();
    }
  }

  void _showNotificationDialogInternal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => CustomNotificationDialog(
            notifications: _notifications, // 직접 현재 리스트 전달
            onDelete: (idx) {
              Navigator.of(context).pop(); // 먼저 다이얼로그 닫기
              setState(() {
                _notifications.removeAt(idx); // 알림 삭제
              });
            },
          ),
    ).then((_) {
      // 다이얼로그가 닫힐 때 모든 알림을 읽음 처리 (빨간 점 제거)
      print('🔔 알림 다이얼로그 닫힘 - 모든 알림 읽음 처리');
      setState(() {
        _notifications.clear(); // 모든 알림 제거하여 빨간 점 숨김
      });
    });
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: Text(
              '로그아웃',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF34495E),
                fontSize: 18.sp,
              ),
            ),
            content: Text(
              '정말 로그아웃 하시겠습니까?',
              style: TextStyle(color: const Color(0xFF7F8C8D), fontSize: 15.sp),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '취소',
                  style: TextStyle(
                    color: const Color(0xFF7F8C8D),
                    fontSize: 15.sp,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (Route<dynamic> route) => false,
                  );
                },
                child: Text(
                  '로그아웃',
                  style: TextStyle(
                    color: const Color(0xFFE74C3C),
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  List<Widget> _buildHomeActions() {
    return [
      // 알림 아이콘 (배지 포함)
      Stack(
        children: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: const Color(0xFF7F8C8D),
              size: 24.sp,
            ),
            onPressed: _showNotificationsDialog,
          ),
          // 알림 있을 때 빨간 점 표시
          if (_notifications.isNotEmpty)
            Positioned(
              right: 8.w,
              top: 8.h,
              child: Container(
                width: 8.w,
                height: 8.w,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      IconButton(
        icon: Icon(
          Icons.settings_outlined,
          color: const Color(0xFF7F8C8D),
          size: 24.sp,
        ),
        onPressed: () => Navigator.pushNamed(context, '/settings'),
      ),
      IconButton(
        icon: Icon(Icons.logout, color: const Color(0xFF7F8C8D), size: 24.sp),
        onPressed: _showLogoutConfirmationDialog,
      ),
      SizedBox(width: 8.w),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool isHome = _selectedIndex == 2;

    final List<Widget> pages = [
      const AppAs(),
      const OverNight(),
      AppHome(
        onCardTap: _onHomeCardTap,
        onRefreshRequested: (refreshCallback) {
          _homeRefreshCallback = refreshCallback; // 콜백 등록
        },
      ),
      const AppDinner(),
      const AppPm(),
    ];

    return Scaffold(
      appBar: DoubleAppBar(
        isHome: isHome,
        pageTitle: isHome ? null : _labels[_selectedIndex],
        onBack:
            isHome
                ? null
                : () {
                  setState(() {
                    _selectedIndex = 2;
                  });
                },
        actions: _buildHomeActions(),
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF4A69E2),
        unselectedItemColor: const Color(0xFF7F8C8D),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: List.generate(
          _labels.length,
          (i) => BottomNavigationBarItem(
            icon: Icon(
              i == 2
                  ? (_selectedIndex == 2
                      ? Icons.home_filled
                      : Icons.home_outlined)
                  : _icons[i],
              size: 26.sp,
            ),
            label: _labels[i] == 'KBU Dormitory' ? '홈' : _labels[i],
          ),
        ),
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }
}
