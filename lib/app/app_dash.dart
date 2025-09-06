import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../student_provider.dart';
import 'package:kbu_domi/app/env_app.dart';

// --- 앱 공통 테마 (별도 파일로 분리 권장: app_theme.dart) ---
class AppColors {
  static const primary = Color(0xFF4A69E2);
  static const accent = Color(0xFF4A69E2);
  static const background = Colors.white;
  static const card = Colors.white;
  static const textPrimary = Color(0xFF34495E);
  static const textSecondary = Color(0xFF7F8C8D);
  static const success = Color(0xFF27AE60);
  static const warning = Color(0xFFF2994A);
  static const danger = Color(0xFFE74C3C);
}

// --- 공용 사이드 메뉴 위젯 (app_bar.dart 또는 app_drawer.dart로 분리 권장) ---
class AppDrawer extends StatelessWidget {
  final String studentName;
  const AppDrawer({super.key, required this.studentName});

  @override
  Widget build(BuildContext context) {
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(studentName),
          _buildDrawerItem(
            context,
            '홈',
            Icons.home_outlined,
            '/home',
            currentRoute,
          ),
          _buildDrawerItem(
            context,
            '대시보드',
            Icons.dashboard_outlined,
            '/dash',
            currentRoute,
          ),
          const Divider(indent: 16, endIndent: 16),
          _buildDrawerItem(
            context,
            'AS 신청',
            Icons.build_outlined,
            '/as',
            currentRoute,
          ),
          _buildDrawerItem(
            context,
            '외박 신청',
            Icons.bed_outlined,
            '/overnight',
            currentRoute,
          ),
          _buildDrawerItem(
            context,
            '석식 신청',
            Icons.restaurant_menu_outlined,
            '/dinner',
            currentRoute,
          ),
          _buildDrawerItem(
            context,
            '상벌점 조회',
            Icons.swap_vert_circle_outlined,
            '/pm',
            currentRoute,
          ),
          const Divider(indent: 16, endIndent: 16),
          _buildDrawerItem(
            context,
            '설정',
            Icons.settings_outlined,
            '/setting',
            currentRoute,
          ),
          _buildDrawerItem(
            context,
            '로그아웃',
            Icons.logout_outlined,
            '/login',
            currentRoute,
            isLogout: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(String name) {
    return UserAccountsDrawerHeader(
      accountName: Text(
        name,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
        ), // ✅ sp 적용
      ),
      accountEmail: Text(
        '20240001@kbu.ac.kr',
        style: TextStyle(fontSize: 13.sp),
      ), // ✅ sp 적용
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        child: Text(
          name.isNotEmpty ? name.substring(0, 1) : '학',
          style: TextStyle(
            fontSize: 24.sp,
            color: AppColors.primary,
          ), // ✅ sp 적용
        ),
      ),
      decoration: const BoxDecoration(color: AppColors.primary),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    String title,
    IconData icon,
    String routeName,
    String? currentRoute, {
    bool isLogout = false,
  }) {
    final bool isSelected = (currentRoute == routeName);
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        size: 24.sp, // ✅ sp 적용
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 15.sp,
        ),
      ),
      tileColor: isSelected ? AppColors.primary.withOpacity(0.1) : null,
      onTap: () {
        Navigator.pop(context); // Drawer 닫기
        if (!isSelected) {
          if (isLogout || routeName == '/home') {
            Navigator.pushNamedAndRemoveUntil(
              context,
              routeName,
              (route) => false,
            );
          } else {
            Navigator.pushNamed(context, routeName);
          }
        }
      },
    );
  }
}

// --- 대시보드 화면 위젯 ---
class AppDash extends StatefulWidget {
  const AppDash({super.key});

  @override
  State<AppDash> createState() => _AppDashState();
}

class _AppDashState extends State<AppDash> {
  bool _isLoading = true;
  String _studentName = "학생";
  Map<String, int> _overnightStatus = {
    'approved': 0,
    'pending': 0,
    'rejected': 0,
  };
  Map<String, int> _asStatus = {
    'requested': 0,
    'in_progress': 0,
    'completed': 0,
  };
  Map<String, int> _points = {'merit': 0, 'demerit': 0};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDashboardData();
    });
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );
    final studentId =
        studentProvider.studentId ?? "1"; // Provider에서 studentId 가져오기

    try {
      // API 병렬 호출
      final responses = await Future.wait([
        http.get(Uri.parse('$apiBase/api/student/$studentId')),
        http.get(
          Uri.parse(
            '$apiBase/api/overnight_status_count?student_id=$studentId',
          ),
        ),
        http.get(
          Uri.parse('$apiBase/api/as_status_count?student_id=$studentId'),
        ),
        http.get(
          Uri.parse('$apiBase/api/point/history?student_id=$studentId&type=상점'),
        ),
        http.get(
          Uri.parse('$apiBase/api/point/history?student_id=$studentId&type=벌점'),
        ),
      ]);

      if (mounted) {
        // 학생 정보 처리
        if (responses[0].statusCode == 200) {
          final data = json.decode(responses[0].body);
          if (data['success']) _studentName = data['user']?['name'] ?? '학생';
        }

        // 외박 현황 처리
        if (responses[1].statusCode == 200) {
          final data = json.decode(responses[1].body);
          _overnightStatus = {
            'approved': data['approved'] ?? 0,
            'pending': data['pending'] ?? 0,
            'rejected': data['rejected'] ?? 0,
          };
        }

        // AS 현황 처리
        if (responses[2].statusCode == 200) {
          final data = json.decode(responses[2].body);
          _asStatus = {
            'requested': data['requested'] ?? 0,
            'in_progress': data['in_progress'] ?? 0,
            'completed': data['completed'] ?? 0,
          };
        }

        // 상점 처리
        int meritPoints = 0;
        if (responses[3].statusCode == 200) {
          final data = json.decode(responses[3].body);
          if (data['success'] && data['points'] != null) {
            for (var point in data['points']) {
              meritPoints += (point['score'] ?? 0) as int;
            }
          }
        }

        // 벌점 처리
        int demeritPoints = 0;
        if (responses[4].statusCode == 200) {
          final data = json.decode(responses[4].body);
          if (data['success'] && data['points'] != null) {
            for (var point in data['points']) {
              demeritPoints += (point['score'] ?? 0) as int;
            }
          }
        }

        _points = {'merit': meritPoints, 'demerit': demeritPoints};
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 로딩 실패: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppDrawer(studentName: _studentName),
      appBar: AppBar(
        title: Text(
          '대시보드',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ), // ✅ sp 적용
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primary, size: 22.sp),
      ),
      body:
          _isLoading
              ? Center(
                child: SizedBox(
                  height: 60.h,
                  width: 60.h,
                  child: CircularProgressIndicator(),
                ),
              )
              : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16.w), // ✅ w 적용
                  child: Column(
                    children: [
                      _buildInfoCard(
                        context,
                        title: '외박 신청 현황',
                        icon: Icons.hotel_outlined,
                        color: AppColors.success,
                        routeName: '/overnight',
                        children: [
                          _infoRow('승인', '${_overnightStatus['approved']}건'),
                          _infoRow('대기', '${_overnightStatus['pending']}건'),
                          _infoRow('반려', '${_overnightStatus['rejected']}건'),
                        ],
                      ),
                      SizedBox(height: 16.h), // ✅ h 적용
                      _buildInfoCard(
                        context,
                        title: 'A/S 요청 현황',
                        icon: Icons.build_outlined,
                        color: AppColors.warning,
                        routeName: '/as',
                        children: [
                          _infoRow('접수', '${_asStatus['requested']}건'),
                          _infoRow('처리중', '${_asStatus['in_progress']}건'),
                          _infoRow('처리완료', '${_asStatus['completed']}건'),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      _buildInfoCard(
                        context,
                        title: '상/벌점 현황',
                        icon: Icons.swap_vert_circle_outlined,
                        color: AppColors.primary,
                        routeName: '/pm',
                        children: [
                          _infoRow('상점', '+${_points['merit']}점'),
                          _infoRow('벌점', '${_points['demerit']}점'),
                          _infoRow(
                            '총점',
                            '${(_points['merit'] ?? 0) + (_points['demerit'] ?? 0)}점',
                            isTotal: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String routeName,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ), // ✅ r 적용
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, routeName),
        borderRadius: BorderRadius.circular(16.r), // ✅ r 적용
        child: Padding(
          padding: EdgeInsets.all(20.w), // ✅ w 적용
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 24.sp), // ✅ sp 적용
                  SizedBox(width: 12.w),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16.sp,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              Divider(height: 32.h),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h), // ✅ h 적용
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 15.sp,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? AppColors.primary : AppColors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
