import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../student_provider.dart';

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

class AppHome extends StatefulWidget {
  final void Function(int)? onCardTap;
  final void Function(VoidCallback)? onRefreshRequested;
  const AppHome({super.key, this.onCardTap, this.onRefreshRequested});
  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> with WidgetsBindingObserver {
  bool _isLoading = true;
  String _studentName = "학생";
  String _dormBuilding = "우정관";
  String _dormRoom = "301호";

  int _outingApproved = 0;
  int _outingPending = 0;
  int _asInProgress = 0;
  int _totalPoints = 0;

  static const double _kCampusLat = 37.735700;
  static const double _kCampusLng = 127.210523;
  static const double _kAllowedDistance = 500.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDashboardData();
      widget.onRefreshRequested?.call(_fetchDashboardData);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchDashboardData();
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );
    final studentId = studentProvider.studentId;

    if (studentId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('http://localhost:5050/api/student/$studentId')),
        http.get(
          Uri.parse(
            'http://localhost:5050/api/overnight_status_count?student_id=$studentId',
          ),
        ),
        http.get(
          Uri.parse(
            'http://localhost:5050/api/as_status_count?student_id=$studentId',
          ),
        ),
        http.get(
          Uri.parse(
            'http://localhost:5050/api/point/history?student_id=$studentId&type=상점',
          ),
        ),
        http.get(
          Uri.parse(
            'http://localhost:5050/api/point/history?student_id=$studentId&type=벌점',
          ),
        ),
      ]);

      if (mounted) {
        if (responses[0].statusCode == 200) {
          final data = json.decode(responses[0].body);
          if (data is Map<String, dynamic>) {
            Map<String, dynamic> userData;
            if (data.containsKey('success') && data['success'] == true) {
              userData = data['user'] ?? {};
            } else if (data.containsKey('student_id')) {
              userData = data;
            } else {
              userData = {};
            }
            if (userData.isNotEmpty) {
              _studentName = userData['name']?.toString() ?? '학생';
              _dormBuilding = userData['dorm_building']?.toString() ?? '기숙사';
              _dormRoom = userData['room_num']?.toString() ?? '호실';
            }
          }
        }

        if (responses[1].statusCode == 200) {
          final data = json.decode(responses[1].body);
          _outingApproved = data['approved'] ?? 0;
          _outingPending = data['pending'] ?? 0;
        }
        if (responses[2].statusCode == 200) {
          final data = json.decode(responses[2].body);
          _asInProgress = data['total'] ?? 0;
        }

        int totalPoints = 0;
        if (responses[3].statusCode == 200) {
          final data = json.decode(responses[3].body);
          final list =
              (data is Map && data['success'] == true)
                  ? (data['points'] ?? [])
                  : (data is List ? data : []);
          for (final p in list) {
            final s = p['score'];
            if (s is int) totalPoints += s;
            if (s is String) totalPoints += int.tryParse(s) ?? 0;
          }
        }
        if (responses[4].statusCode == 200) {
          final data = json.decode(responses[4].body);
          final list =
              (data is Map && data['success'] == true)
                  ? (data['points'] ?? [])
                  : (data is List ? data : []);
          for (final p in list) {
            final s = p['score'];
            if (s is int) totalPoints += s;
            if (s is String) totalPoints += int.tryParse(s) ?? 0;
          }
        }
        _totalPoints = totalPoints;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 로딩 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRollCall() async {
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );
    final studentId = studentProvider.studentId;

    if (studentId == null) {
      _showInfoDialog(
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        title: '오류',
        message: '학생 정보를 찾을 수 없습니다. 다시 로그인해주세요.',
      );
      return;
    }

    try {
      final timeResponse = await http.get(
        Uri.parse('http://localhost:5050/api/rollcall/is-time'),
      );
      if (timeResponse.statusCode == 200) {
        final timeData = json.decode(timeResponse.body);
        if (!timeData['is_rollcall_time']) {
          _showInfoDialog(
            icon: Icons.schedule_outlined,
            iconColor: AppColors.warning,
            title: '점호 시간이 아닙니다',
            message: '점호는 23:50 ~ 00:10 사이에만 가능합니다.',
          );
          return;
        }
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _showInfoDialog(
            icon: Icons.error_outline,
            iconColor: AppColors.danger,
            title: '위치 권한 필요',
            message: '점호를 위해 위치 권한을 허용해주세요.',
          );
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await http.post(
        Uri.parse('http://localhost:5050/api/rollcall/check'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': studentId,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final distance = data['distance'];
          final building = data['building_name'] ?? '기숙사';
          String distanceStr =
              distance < 1000
                  ? '${distance.toStringAsFixed(0)}m'
                  : '${(distance / 1000).toStringAsFixed(2)}km';

          if (data['message'].contains('면제')) {
            _showInfoDialog(
              icon: Icons.celebration_outlined,
              iconColor: AppColors.success,
              title: '점호 면제 🎉',
              message: data['message'],
            );
          } else {
            _showInfoDialog(
              icon: Icons.check_circle_outline,
              iconColor: AppColors.success,
              title: '점호 완료 🎉',
              message: '$building 점호가 완료되었습니다!\n기준점에서 $distanceStr 거리입니다.',
            );
          }
        } else {
          _showInfoDialog(
            icon: Icons.error_outline,
            iconColor: AppColors.danger,
            title: '점호 실패',
            message: data['message'] ?? '점호 처리 중 오류가 발생했습니다.',
          );
        }
      } else {
        _showInfoDialog(
          icon: Icons.error_outline,
          iconColor: AppColors.danger,
          title: '점호 실패',
          message: '서버와 통신할 수 없습니다. (코드: ${response.statusCode})',
        );
      }
    } catch (e) {
      _showInfoDialog(
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        title: '점호 오류',
        message: '점호 처리 중 오류가 발생했습니다.\n네트워크 연결을 확인해주세요.',
      );
    }
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
            title: const Text(
              '로그아웃',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            content: const Text(
              '정말 로그아웃 하시겠습니까?',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '취소',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login',
                    (Route<dynamic> route) => false,
                  );
                },
                child: const Text(
                  '로그아웃',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  /// ✅ 알림 팝업
  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 18.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 2.w, bottom: 10.h),
                    child: Text(
                      '알림',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20.sp,
                        color: const Color(0xFF34495E),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: 2,
                      separatorBuilder:
                          (_, __) => Divider(
                            height: 14.h,
                            color: const Color(0xFFF0F2F5),
                          ),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _oneLineNotificationItem(
                            icon: Icons.check_circle,
                            color: AppColors.success,
                            title: '외박 신청이 승인되었습니다.',
                            subtitle: '집 - 졸려요...',
                            timestamp: '오늘',
                            onDelete: () {},
                          );
                        } else {
                          return _oneLineNotificationItem(
                            icon: Icons.cancel,
                            color: AppColors.danger,
                            title: '외박 신청이 반려되었습니다.',
                            subtitle: '집 - 너무 피곤해요...',
                            timestamp: '오늘',
                            onDelete: () {},
                          );
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A69E2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      '닫기',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// 🔧 알림 한 줄 아이템 (아이콘/닫기 버튼 축소 + 제목 가변 축소)
  /// 🔧 아주 작은 아이콘 + 닫기 버튼(초소형) + 제목은 폭에 맞춰 자동 축소(… 제거)
  Widget _oneLineNotificationItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String timestamp,
    VoidCallback? onDelete,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ▶ 왼쪽 상태 아이콘: 훨씬 더 작게
        Container(
          width: 10.w, // 훨씬 더 작게
          height: 10.w, // 훨씬 더 작게
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 6.sp), // 훨씬 더 작게
        ),
        SizedBox(width: 8.w),

        // ▶ 텍스트 영역
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제목: 한 줄 유지, 넘치면 말줄임표
              Text(
                title, // 예: '외박 신청이 승인되었습니다.'
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.sp, // 훨씬 더 작게
                ),
              ),
              SizedBox(height: 3.h),

              // 부제목
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9.sp, // 훨씬 더 작게
                ),
              ),
              SizedBox(height: 3.h), // 간격도 줄임
              // 시간
              Text(
                timestamp,
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.8),
                  fontSize: 8.sp, // 훨씬 더 작게
                ),
              ),
            ],
          ),
        ),

        // ▶ 닫기(X) 버튼: 클릭하기 쉽게 조금 키움
        if (onDelete != null)
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(6.r),
            child: Padding(
              padding: EdgeInsets.all(2.w), // 클릭 영역 확보
              child: Icon(
                Icons.close,
                size: 14.sp, // 클릭하기 쉽게 조금 키움
                color: const Color(0xFFB0B8C1),
              ),
            ),
          ),
      ],
    );
  }

  void _showInfoDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: const TextScaler.linear(1.0),
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textScaler: const TextScaler.linear(1.0),
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        '확인',
                        textScaler: const TextScaler.linear(1.0),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onStatusCardTap(int idx) {
    if (widget.onCardTap != null) {
      widget.onCardTap!(idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body:
          _isLoading
              ? Center(
                child: SizedBox(
                  height: 60.h,
                  width: 60.h,
                  child: const CircularProgressIndicator(),
                ),
              )
              : RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_studentName님, 안녕하세요! \u{1F44B}',
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      _buildRollCallButton(context),
                      SizedBox(height: 32.h),
                      _buildSectionTitle(
                        '나의 기숙사 정보',
                        Icons.maps_home_work_outlined,
                      ),
                      SizedBox(height: 16.h),
                      _buildDormInfoCard(),
                      SizedBox(height: 32.h),
                      _buildSectionTitle('나의 신청 현황', Icons.fact_check_outlined),
                      SizedBox(height: 16.h),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16.w,
                        mainAxisSpacing: 16.h,
                        childAspectRatio: 0.82,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStatusCard(
                            context,
                            icon: Icons.bed_outlined,
                            title: '외박 신청',
                            value: '${_outingApproved + _outingPending}건',
                            details: '승인 $_outingApproved / 대기 $_outingPending',
                            color: AppColors.success,
                            onTap: () => _onStatusCardTap(1),
                          ),
                          _buildStatusCard(
                            context,
                            icon: Icons.build_outlined,
                            title: 'A/S 요청',
                            value: '${_asInProgress}건',
                            details: '신청',
                            color: AppColors.warning,
                            onTap: () => _onStatusCardTap(0),
                          ),
                          _buildStatusCard(
                            context,
                            icon: Icons.restaurant_menu_outlined,
                            title: '석식 신청',
                            value: '완료',
                            details: '이번 달',
                            color: AppColors.primary,
                            onTap: () => _onStatusCardTap(3),
                          ),
                          _buildStatusCard(
                            context,
                            icon: Icons.swap_vert_circle_outlined,
                            title: '상/벌점',
                            value:
                                '${_totalPoints > 0 ? '+' : ''}$_totalPoints점',
                            details: '상점 7 / 벌점 2',
                            color: AppColors.danger,
                            onTap: () => _onStatusCardTap(4),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20.sp),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildRollCallButton(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.primary.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: InkWell(
        onTap: () => _handleRollCall(),
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘의 점호',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '버튼을 눌러 현재 위치로 점호하세요',
                    style: TextStyle(fontSize: 14.sp, color: Colors.white70),
                  ),
                ],
              ),
              Icon(Icons.my_location, color: Colors.white, size: 40.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDormInfoCard() {
    return Card(
      elevation: 0,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _infoItem('기숙사 건물', _dormBuilding, Icons.apartment_rounded),
            _infoItem('호실', _dormRoom, Icons.meeting_room_rounded),
          ],
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 28.sp),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
            SizedBox(height: 2.h),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String details,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey.shade200, width: 1.w),
      ),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, color: color, size: 24.sp),
                  ),
                  SizedBox(height: 30.h),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                details,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
