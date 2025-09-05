import 'package:flutter/material.dart';
import 'search.dart'; // 학생조회
import 'ad_overnight.dart'; // 외박관리
import 'ad_as.dart'; // AS신청관리
import 'ad_dinner.dart'; // 석식관리
import 'score.dart'; // 상벌점조회
import 'scorecheck.dart'; // 상벌점 관리
import 'ad_out.dart'; // 퇴소관리
import 'ad_dash.dart';
import 'ad_vacation.dart'; // 방학 이용관리
import 'ad_roommate.dart'; // 룸메이트 관리
import 'ad_room_status.dart'; // ✅ 새로 추가된 호실 전체 현황 페이지 import
import 'ad_application.dart'; // 입주 신청 관리 추가
import 'ad_in.dart'; // 입실관리
import 'ad_jumho.dart'; // 점호관리 추가

final GlobalKey<_AdHomePageState> adHomePageKey = GlobalKey<_AdHomePageState>();

class AdHomePage extends StatefulWidget {
  const AdHomePage({super.key});

  @override
  State<AdHomePage> createState() => _AdHomePageState();
}

class _AdHomePageState extends State<AdHomePage> {
  int _selectedMenu = 0;
  final Color kbuBlue = const Color(0xFF00408B);
  final Color kbuPink = const Color(0xFFEC008C);

  // 메뉴 항목 및 연결 페이지 (원래 방식으로 복원)
  final List<Map<String, dynamic>> _menuList = [
    {"icon": Icons.assessment, "title": "대쉬보드", "page": () => AdDashPage()},
    {
      "icon": Icons.group_outlined,
      "title": "학생 관리",
      "page": () => AdRoomStatusPage(),
    },
    {
      "icon": Icons.assignment,
      "title": "입주 신청 관리",
      "page": () => AdApplicationPage(),
    },
    {
      "icon": Icons.meeting_room_outlined,
      "title": "입실관리",
      "page": () => const AdInPage(),
    },
    {
      "icon": Icons.event_available,
      "title": "점호관리",
      "page": () => AdJumhoPage(),
    },
    {"icon": Icons.stars_rounded, "title": "상벌점관리", "page": () => ScorePage()},

    {
      "icon": Icons.night_shelter_outlined,
      "title": "외박관리",
      "page": () => AdOvernightPage(),
    },

    {
      "icon": Icons.build_circle_outlined,
      "title": "AS신청관리",
      "page": () => AdAsPage(),
    },
    {
      "icon": Icons.restaurant_menu_rounded,
      "title": "석식관리",
      "page": () => AdDinnerPage(),
    },

    {
      "icon": Icons.exit_to_app_rounded,
      "title": "퇴소관리",
      "page": () => AdOutPage(),
    },
    {
      "icon": Icons.holiday_village,
      "title": "방학이용관리",
      "page": () => AdVacationPage(),
    },

    // {"icon": Icons.search, "title": "학생조회", "page": () => SearchPage()},
  ];

  Map<String, dynamic>? _adInPageArguments;

  // 외부에서 메뉴를 변경하고 필요한 인자를 전달받을 수 있는 Public 메서드
  void selectMenuByIndex(int index, {Map<String, dynamic>? arguments}) {
    setState(() {
      _selectedMenu = index;
      _adInPageArguments = arguments;
    });
  }

  // 외부에서 _menuList의 인덱스를 찾을 수 있도록 Public 메서드 추가
  int getMenuIndexByTitle(String title) {
    return _menuList.indexWhere((item) => item['title'] == title);
  }

  // 선택된 메뉴에 따라 해당 페이지만 빌드하는 메서드
  Widget _buildSelectedPage() {
    switch (_selectedMenu) {
      case 0: // 대쉬보드
        return AdDashPage(
          onMenuChange: (index) {
            selectMenuByIndex(index);
          },
        );
      case 1: // 학생 관리
        return AdRoomStatusPage();
      case 2: // 입주 신청 관리
        return AdApplicationPage();
      case 3: // 입실관리
        return AdInPage(
          key: ValueKey(_adInPageArguments),
          studentIdToSelect: _adInPageArguments?['studentId'],
          initialTab: _adInPageArguments?['initialTab'],
        );
      case 4: // 점호관리
        return AdJumhoPage();
      case 5: // 상벌점관리
        return ScorePage();
      case 6: // 외박관리
        return AdOvernightPage();
      case 7: // AS신청관리
        return AdAsPage();
      case 8: // 석식관리
        return AdDinnerPage();
      case 9: // 퇴소관리
        return AdOutPage();
      case 10: // 방학이용관리
        return AdVacationPage();
      default:
        return AdDashPage(
          onMenuChange: (index) {
            selectMenuByIndex(index);
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget sideMenu() {
      return Container(
        width: 230,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 팀원 버전 적용: 로고 이미지 및 개선된 스타일
            SizedBox(height: 18),
            Image.asset('imgs/logo.png', height: 58),
            SizedBox(height: 14),
            Icon(Icons.school_outlined, color: kbuBlue, size: 44),
            Text(
              "관리자 포털",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: kbuBlue,
                fontSize: 20,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ..._menuList.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final isSelected = _selectedMenu == idx;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
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
                            setState(() {
                              _selectedMenu = idx;
                              _adInPageArguments = null;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
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
                                const SizedBox(width: 13),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 7),
              child: SizedBox(
                width: 150,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text(
                    "로그아웃",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Row(
          children: [
            sideMenu(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - 64,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 9,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildSelectedPage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
