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
      // HomeShell에 새로고침 콜백 등록
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
      // 앱이 다시 포그라운드로 돌아올 때 데이터 새로고침
      print('🔄 앱이 다시 활성화되어 대시보드 데이터를 새로고침합니다.');
      _fetchDashboardData();
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);

    // StudentProvider에서 실제 학생 ID 가져오기
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );
    final studentId = studentProvider.studentId;

    if (studentId == null) {
      print('❌ 학생 ID가 없습니다. 로그인 페이지로 이동합니다.');
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    print('🔄 학생 ID: $studentId로 대시보드 데이터 로딩 시작...');

    try {
      print('🔄 대시보드 데이터 로딩 시작...');

      // API 병렬 호출
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
        // 각 API 응답 상태 확인
        print('📊 API 응답 상태:');
        print('  - 학생 정보: ${responses[0].statusCode}');
        print('  - 외박 현황: ${responses[1].statusCode}');
        print('  - AS 현황: ${responses[2].statusCode}');
        print('  - 상점 내역: ${responses[3].statusCode}');
        print('  - 벌점 내역: ${responses[4].statusCode}');

        // 학생 정보 처리
        if (responses[0].statusCode == 200) {
          try {
            final data = json.decode(responses[0].body);
            print('👤 학생 정보 데이터: $data');

            // success 키가 있는 경우와 없는 경우 모두 처리
            if (data is Map<String, dynamic>) {
              Map<String, dynamic> userData;

              if (data.containsKey('success') && data['success'] == true) {
                // 새로운 API 형식: {success: true, user: {...}}
                userData = data['user'] ?? {};
              } else if (data.containsKey('student_id')) {
                // 기존 API 형식: {...} (직접 사용자 데이터)
                userData = data;
              } else {
                print('❌ 학생 정보 형식이 올바르지 않습니다: $data');
                userData = {};
              }

              if (userData.isNotEmpty) {
                _studentName = userData['name']?.toString() ?? '학생';
                _dormBuilding = userData['dorm_building']?.toString() ?? '기숙사';
                _dormRoom = userData['room_num']?.toString() ?? '호실';
                print(
                  '✅ 학생 정보 설정 완료: $_studentName, $_dormBuilding $_dormRoom',
                );
              } else {
                print('❌ 학생 정보가 비어있습니다');
              }
            } else {
              print('❌ 학생 정보 응답이 올바른 형식이 아닙니다');
            }
          } catch (e) {
            print('❌ 학생 정보 파싱 오류: $e');
          }
        } else {
          print('❌ 학생 정보 API 오류: ${responses[0].statusCode}');
        }

        // 외박 현황 처리
        if (responses[1].statusCode == 200) {
          try {
            final data = json.decode(responses[1].body);
            print('🏠 외박 현황 데이터: $data');
            _outingApproved = data['approved'] ?? 0;
            _outingPending = data['pending'] ?? 0;
            print('✅ 외박 현황 설정 완료: 승인 $_outingApproved, 대기 $_outingPending');
          } catch (e) {
            print('❌ 외박 현황 파싱 오류: $e');
          }
        } else {
          print('❌ 외박 현황 API 오류: ${responses[1].statusCode}');
        }

        // AS 현황 처리
        if (responses[2].statusCode == 200) {
          try {
            final data = json.decode(responses[2].body);
            print('🔧 AS 현황 데이터: $data');
            // 전체 AS 신청 건수 표시 (신청됨 + 처리중 + 완료)
            _asInProgress = data['total'] ?? 0;
            print('✅ AS 현황 설정 완료: 전체 $_asInProgress건');
          } catch (e) {
            print('❌ AS 현황 파싱 오류: $e');
          }
        } else {
          print('❌ AS 현황 API 오류: ${responses[2].statusCode}');
        }

        // 상벌점 합계 계산
        int totalPoints = 0;
        if (responses[3].statusCode == 200) {
          try {
            final data = json.decode(responses[3].body);
            print('⭐ 상점 데이터: $data');

            List<dynamic> pointsData = [];

            if (data is Map<String, dynamic> &&
                data.containsKey('success') &&
                data['success'] == true) {
              // 새로운 API 형식: {success: true, points: [...]}
              pointsData = data['points'] ?? [];
            } else if (data is List<dynamic>) {
              // 기존 API 형식: [...] (직접 배열)
              pointsData = data;
            } else {
              print('❌ 상점 데이터 형식이 올바르지 않습니다: ${data.runtimeType}');
            }

            for (var point in pointsData) {
              if (point is Map<String, dynamic>) {
                final score = point['score'];
                if (score is int) {
                  totalPoints += score;
                } else if (score is String) {
                  totalPoints += int.tryParse(score) ?? 0;
                }
              }
            }
          } catch (e) {
            print('❌ 상점 데이터 파싱 오류: $e');
          }
        } else {
          print('❌ 상점 API 오류: ${responses[3].statusCode}');
        }

        if (responses[4].statusCode == 200) {
          try {
            final data = json.decode(responses[4].body);
            print('⚠️ 벌점 데이터: $data');

            List<dynamic> pointsData = [];

            if (data is Map<String, dynamic> &&
                data.containsKey('success') &&
                data['success'] == true) {
              // 새로운 API 형식: {success: true, points: [...]}
              pointsData = data['points'] ?? [];
            } else if (data is List<dynamic>) {
              // 기존 API 형식: [...] (직접 배열)
              pointsData = data;
            } else {
              print('❌ 벌점 데이터 형식이 올바르지 않습니다: ${data.runtimeType}');
            }

            for (var point in pointsData) {
              if (point is Map<String, dynamic>) {
                final score = point['score'];
                if (score is int) {
                  totalPoints += score;
                } else if (score is String) {
                  totalPoints += int.tryParse(score) ?? 0;
                }
              }
            }
          } catch (e) {
            print('❌ 벌점 데이터 파싱 오류: $e');
          }
        } else {
          print('❌ 벌점 API 오류: ${responses[4].statusCode}');
        }

        _totalPoints = totalPoints;
        print('✅ 총 상벌점: $_totalPoints');
        print('🎉 대시보드 데이터 로딩 완료!');
      }
    } catch (e) {
      print('💥 대시보드 데이터 로딩 중 예외 발생: $e');
      print('📍 예외 타입: ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 로딩 실패: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRollCall() async {
    // StudentProvider에서 실제 학생 ID 가져오기
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
      // 점호 시간 확인
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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 실제 점호 API 호출
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
          String distanceStr;
          if (distance < 1000) {
            distanceStr = '${distance.toStringAsFixed(0)}m';
          } else {
            distanceStr = '${(distance / 1000).toStringAsFixed(2)}km';
          }

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

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            title: const Text(
              '알림',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 24.sp,
                    ),
                    title: Text(
                      '외박 신청이 승인되었습니다.',
                      style: TextStyle(fontSize: 15.sp),
                    ),
                    subtitle: Text(
                      '2025-06-22',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(
                      Icons.build,
                      color: AppColors.warning,
                      size: 24.sp,
                    ),
                    title: Text(
                      'A/S 요청이 접수되었습니다.',
                      style: TextStyle(fontSize: 15.sp),
                    ),
                    subtitle: Text(
                      '2025-06-21',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(
                      Icons.info,
                      color: AppColors.primary,
                      size: 24.sp,
                    ),
                    title: Text(
                      '새로운 공지사항이 등록되었습니다.',
                      style: TextStyle(fontSize: 15.sp),
                    ),
                    subtitle: Text(
                      '2025-06-20',
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '닫기',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
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
      builder:
          (_) => Dialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconColor.withOpacity(0.1),
                    ),
                    child: Icon(icon, color: iconColor, size: 40.sp),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        '확인',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
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
                  child: CircularProgressIndicator(),
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
                      SizedBox(height: 24.h),
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
              // 1. 아이콘 + 제목 부분만 따로
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(icon, color: color, size: 24.sp),
                  ),
                  SizedBox(height: 30.h), // ← 이게 진짜 아이콘~제목 사이 간격
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
              SizedBox(height: 8.h), // 아이콘+제목 아래 전체 내용과의 간격
              // 2. 아래쪽 Flexible로 값/상세 내용
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
