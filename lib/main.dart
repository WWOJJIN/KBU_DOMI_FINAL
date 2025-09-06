import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart'; // 📦 screenutil 추가!
import 'package:flutter_localizations/flutter_localizations.dart'; // 📦 한국어 지원 패키지 import
import 'student/domi_portal/login.dart'; // LoginPage 포함된 파일
import 'student/domi_portal/home.dart' as student_home;
import 'admin/ad_home.dart' as admin_home;
import 'admin/ad_home.dart'; // adHomePageKey를 사용하기 위해 직접 import

import 'student/vacation.dart';
import 'student/check.dart'; // 또는 admit.dart로 파일명 확인!
import 'student/first.dart';
import 'student/firstin.dart';
import 'package:provider/provider.dart';
import 'student_provider.dart';
import 'services/storage_service.dart';
import 'admin/ad_as.dart'; // AS신청관리 페이지
import 'admin/ad_overnight.dart'; // 외박관리 페이지
import 'admin/ad_dinner.dart'; // 석식관리 페이지
import 'admin/scorecheck.dart'; // 상벌점관리 페이지
import 'admin/ad_out.dart'; // 퇴소관리 페이지
import 'admin/ad_dash.dart'; // 방금 만든 관리자 대쉬보드 페이지
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'student/domi_portal/pm.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => StudentProvider(),
          lazy: false, // Provider를 즉시 생성하도록 설정
        ),
      ],
      child: const RootApp(),
    ),
  );
}

// 🔑 전역 navigatorKey 설정
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// 👉 screenutil 초기화용 wrapper
class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1920, 1080), // 💡 기준 디자인 사이즈
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          // ▼▼▼▼▼ [추가] 한국어 지원 설정 ▼▼▼▼▼
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ko', 'KR'), // 한국어
            Locale('en', 'US'), // 영어 (기본 지원 언어)
          ],
          locale: const Locale('ko'), // 앱의 기본 언어를 한국어로 설정
          // ▲▲▲▲▲ [추가] 한국어 지원 설정 ▲▲▲▲▲

          // ▼▼▼▼▼ [추가] 전역 테마 설정 ▼▼▼▼▼
          theme: ThemeData(
            // 기본 색상 스키마 설정
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1), // 인디고 계열 메인 색상
              primary: const Color(0xFF6366F1), // 메인 색상
            ),
            // 폰트 패밀리 설정 (텍스트 그라데이션 문제 해결)
            fontFamily: 'Gmarket',
            textTheme: const TextTheme().apply(fontFamily: 'Gmarket'),
            // 입력 필드 전역 테마 설정
            inputDecorationTheme: InputDecorationTheme(
              // 포커스 시 테두리 색상
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: const Color(0xFF6366F1), // 인디고 색상으로 통일
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              // 기본 테두리 색상
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade400, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              // 에러 테두리 색상
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              // 포커스된 에러 테두리 색상
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              // 라벨 색상 설정
              labelStyle: TextStyle(
                color: Colors.grey[600], // 기본 라벨 색상
                fontSize: 14,
              ),
              // 힌트 텍스트 색상
              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            // 드롭다운 버튼 테마
            dropdownMenuTheme: DropdownMenuThemeData(
              inputDecorationTheme: InputDecorationTheme(
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: const Color(0xFF6366F1), // 드롭다운도 동일한 색상
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // ▲▲▲▲▲ [추가] 전역 테마 설정 ▲▲▲▲▲
          navigatorKey: navigatorKey, // ✅ 네비게이터 키 연결
          debugShowCheckedModeBanner: false,
          home: const DormIntroPage(),
          onGenerateRoute: (settings) {
            print('🔍 라우트 생성: ${settings.name}');

            // URL 파싱
            final uri = Uri.parse(settings.name ?? '/');
            final path = uri.path;

            switch (path) {
              case '/login':
                return MaterialPageRoute(
                  builder: (context) => const LoginPage(),
                  settings: settings,
                );
              case '/home':
                return MaterialPageRoute(
                  builder: (context) => const student_home.HomePage(),
                  settings: settings, // 쿼리 파라미터 전달
                );
              case '/vacation':
                return MaterialPageRoute(
                  builder: (context) => const VacationPage(),
                  settings: settings,
                );
              case '/check':
                return MaterialPageRoute(
                  builder: (context) => const AdmitPage(),
                  settings: settings,
                );
              case '/firstin':
                return MaterialPageRoute(
                  builder: (context) => const FirstInPage(),
                  settings: settings,
                );
              case '/pm':
                return MaterialPageRoute(
                  builder: (context) => const PointHistoryPage(),
                  settings: settings,
                );
              case '/adhome':
                return MaterialPageRoute(
                  builder:
                      (context) => admin_home.AdHomePage(key: adHomePageKey),
                  settings: settings,
                );
              case '/dash':
                return MaterialPageRoute(
                  builder: (context) => AdDashPage(),
                  settings: settings,
                );
              case '/adas':
                return MaterialPageRoute(
                  builder: (context) => AdAsPage(),
                  settings: settings,
                );
              case '/adovernight':
                return MaterialPageRoute(
                  builder: (context) => AdOvernightPage(),
                  settings: settings,
                );
              case '/addinner':
                return MaterialPageRoute(
                  builder: (context) => AdDinnerPage(),
                  settings: settings,
                );
              case '/scorecheck':
                return MaterialPageRoute(
                  builder: (context) => ScoreCheckPage(),
                  settings: settings,
                );
              case '/adout':
                return MaterialPageRoute(
                  builder: (context) => AdOutPage(),
                  settings: settings,
                );
              default:
                return MaterialPageRoute(
                  builder: (context) => const DormIntroPage(),
                  settings: settings,
                );
            }
          },
        );
      },
    );
  }
}
