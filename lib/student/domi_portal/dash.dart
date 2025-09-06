import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../../student_provider.dart'; // Assuming this path is correct
import 'package:kbu_domi/env.dart';

// 석식 신청 상태를 관리하기 위한 열거형(enum) 정의
enum DinnerApplicationStatus {
  notApplied, // 신청 안 함
  pending, // 신청 완료 (처리/승인 대기중)
  completed, // 신청 및 승인 최종 완료
}

// App-wide Colors
class AppColors {
  static const Color primary = Color(0xFF2C3E50); // A calm, professional navy
  static const Color accent = Color(0xFF4A69E2); // Accent blue for general use
  static const Color success = Color(
    0xFF27AE60,
  ); // A clear green for success states
  static const Color warning = Color(0xFFF2994A); // A soft orange
  static const Color danger = Color(0xFFE74C3C); // A slightly softer red
  static const Color neutral = Color(0xFF828282); // A neutral gray
  static const Color background = Color(0xFFF8F9FA);
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(
    0xFF2C3E50,
  ); // Dark navy for primary text
  static const Color textSecondary = Color(0xFF828282);
}

class DashPage extends StatefulWidget {
  final String? studentId;
  final bool searchMode; // <-- 필수!!
  const DashPage({super.key, this.studentId, this.searchMode = false});

  @override
  State<DashPage> createState() => _DashPageState();
}

class _DashPageState extends State<DashPage> {
  // API로부터 가져온 데이터를 위한 상태 변수
  int outingTotal = 0,
      outingApproved = 0,
      outingRejected = 0,
      outingPending = 0;

  // A/S 상태를 위한 변수 (API 연동 필요)
  int asTotal = 0, asRequested = 0, asInProgress = 0, asCompleted = 0;

  // 점수는 실제 데이터가 없으므로 임시 데이터를 사용합니다.
  int plusScore = 0, minusScore = 0;
  bool isLoading = true;

  // 석식 신청 상태 - 실제 API에서 가져옴
  DinnerApplicationStatus _dinnerStatus = DinnerApplicationStatus.notApplied;

  // GPS 점호 관련 상수 - 실제 API에서 설정값을 가져와 사용
  static const double _kCampusLat = 37.735700;
  static const double _kCampusLng = 127.210523;
  static const double _kAllowedDistance = 50.0; // 50m 이내면 승인 (요구사항에 맞게 변경)

  @override
  void initState() {
    super.initState();
    // 위젯 첫 프레임 렌더링 후 데이터 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final studentProvider = Provider.of<StudentProvider>(
        context,
        listen: false,
      );
      final studentIdFromProvider = studentProvider.studentId;
      final targetId = widget.studentId ?? studentIdFromProvider;

      print('🔍 웹 대시보드 initState:');
      print('  - widget.studentId: ${widget.studentId}');
      print('  - provider.studentId: $studentIdFromProvider');
      print('  - targetId: $targetId');
      print('  - provider.name: ${studentProvider.name}');

      if (targetId != null) {
        _fetchAllData(targetId);
      } else {
        print('❌ 웹 대시보드 - targetId가 null입니다!');
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    });
  }

  // GPS 기반 점호 (API 연동)
  Future<void> _handleRollCall() async {
    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _showRollCallDialog(
            icon: Icons.error_outline,
            iconColor: AppColors.danger,
            title: '위치 권한 필요',
            message: '점호를 위해 위치 서비스 권한을 허용해주세요.',
          );
          return;
        }
      }

      // 현재 위치 가져오기 (외박 승인 확인은 서버에서 처리하므로 위치는 여전히 필요)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 학생 ID 가져오기
      final studentIdFromProvider =
          Provider.of<StudentProvider>(context, listen: false).studentId;
      final targetId = widget.studentId ?? studentIdFromProvider;

      if (targetId == null) {
        _showRollCallDialog(
          icon: Icons.error_outline,
          iconColor: AppColors.danger,
          title: '오류',
          message: '학생 ID를 찾을 수 없습니다.',
        );
        return;
      }

      // 서버에 점호 제출
      final response = await http.post(
        Uri.parse('$apiBase/api/rollcall/check'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': targetId,
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // 외박 승인으로 점호 면제되는 경우 처리
        if (responseData['exempted'] == true) {
          String exemptMessage =
              responseData['message'] ?? '외박 승인으로 점호가 면제되었습니다!';

          _showRollCallDialog(
            icon: Icons.check_circle_outline,
            iconColor: AppColors.success,
            title: '점호 면제 🎉',
            message: exemptMessage,
          );
          return;
        }

        // 일반적인 점호 성공
        String successMessage = responseData['message'] ?? '점호가 완료되었습니다!';

        // 건물 정보가 있으면 추가 표시
        if (responseData['building'] != null) {
          successMessage += '\n건물: ${responseData['building']}';
        }

        successMessage +=
            '\n거리: ${responseData['distance']}km\n시간: ${responseData['time']}';

        _showRollCallDialog(
          icon: Icons.check_circle_outline,
          iconColor: AppColors.success,
          title: '점호 완료 🎉',
          message: successMessage,
        );
      } else {
        // 점호 실패
        String errorMessage = responseData['error'] ?? '점호 처리 중 오류가 발생했습니다.';

        // 건물 정보가 있는 경우 표시
        if (responseData['building'] != null) {
          errorMessage += '\n건물: ${responseData['building']}';
        }

        // 거리 정보가 있는 경우 표시
        if (responseData['distance'] != null) {
          final distance = responseData['distance'];
          final allowedDistance = responseData['allowed_distance'];
          errorMessage += '\n현재 거리: ${distance}km (허용: ${allowedDistance}km)';
        }

        _showRollCallDialog(
          icon: Icons.error_outline,
          iconColor: AppColors.danger,
          title: '점호 실패',
          message: errorMessage,
        );
      }
    } catch (e) {
      debugPrint('점호 처리 오류: $e');
      _showRollCallDialog(
        icon: Icons.error_outline,
        iconColor: AppColors.danger,
        title: '점호 오류',
        message: '점호 처리 중 오류가 발생했습니다.\n네트워크 연결을 확인하고 다시 시도해주세요.',
      );
    }
  }

  // 점호 결과 다이얼로그
  void _showRollCallDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 340,
                maxWidth: 500,
                minHeight: 300,
                maxHeight: 600,
              ),
              child: IntrinsicHeight(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconColor.withOpacity(0.1),
                        ),
                        child: Icon(icon, color: iconColor, size: 40),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
            ),
          ),
    );
  }

  // 상벌점 점수/건수 DB 연동
  Future<void> _fetchPointScores(String studentId) async {
    try {
      print('🔍 웹 대시보드 - _fetchPointScores 호출, studentId: $studentId');

      // 상점
      final plusRes = await http.get(
        Uri.parse('$apiBase/api/point/history?student_id=$studentId&type=상점'),
      );
      // 벌점
      final minusRes = await http.get(
        Uri.parse('$apiBase/api/point/history?student_id=$studentId&type=벌점'),
      );

      print('🔍 웹 대시보드 - 상점 API 응답: ${plusRes.statusCode}');
      print('🔍 웹 대시보드 - 벌점 API 응답: ${minusRes.statusCode}');

      int plus = 0, minus = 0;
      if (plusRes.statusCode == 200) {
        final dynamic plusData = json.decode(plusRes.body);
        print('🔍 웹 대시보드 - 상점 데이터: $plusData');

        // API 응답 형식 확인
        if (plusData is Map && plusData.containsKey('points')) {
          final List<dynamic> points = plusData['points'] as List<dynamic>;
          plus = points.fold(0, (sum, item) => sum + (item['score'] as int));
        } else if (plusData is List) {
          plus = (plusData as List<dynamic>).fold(
            0,
            (sum, item) => sum + (item['score'] as int),
          );
        }
      }

      if (minusRes.statusCode == 200) {
        final dynamic minusData = json.decode(minusRes.body);
        print('🔍 웹 대시보드 - 벌점 데이터: $minusData');

        // API 응답 형식 확인
        if (minusData is Map && minusData.containsKey('points')) {
          final List<dynamic> points = minusData['points'] as List<dynamic>;
          minus = points.fold(0, (sum, item) => sum + (item['score'] as int));
        } else if (minusData is List) {
          minus = (minusData as List<dynamic>).fold(
            0,
            (sum, item) => sum + (item['score'] as int),
          );
        }
      }

      if (mounted) {
        setState(() {
          plusScore = plus;
          minusScore = minus;
        });
        print('✅ 웹 대시보드 - 상벌점 설정 완료: +$plus, $minus');
      }
    } catch (e) {
      debugPrint('상벌점 합계 로딩 실패: $e');
      if (mounted) {
        setState(() {
          plusScore = 0;
          minusScore = 0;
        });
      }
    }
  }

  // 데이터 로딩 로직 통합
  Future<void> _fetchAllData(String studentId) async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      // 모든 데이터 요청을 병렬로 실행
      await Future.wait([
        _loadStudentData(studentId),
        _fetchOutingStatusCount(studentId),
        _fetchASStatusCount(studentId),
        _fetchPointScores(studentId), // 상벌점 점수도 병렬로 호출
        _fetchDinnerStatus(studentId), // 석식 신청 상태 추가
      ]);
    } catch (e) {
      debugPrint("데이터 로딩 중 오류 발생: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadStudentData(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/student/$studentId'),
      );
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('🔍 웹 대시보드 - 학생 정보 API 응답: $data');

        // StudentProvider에 최신 정보 업데이트 (연락처/환불 정보 포함)
        final studentProvider = Provider.of<StudentProvider>(
          context,
          listen: false,
        );
        studentProvider.setStudentInfo(data);
        print('✅ 웹 대시보드 - StudentProvider 업데이트 완료');
      }
    } catch (e) {
      debugPrint("학생 정보 로딩 실패: $e");
    }
  }

  Future<void> _fetchOutingStatusCount(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/overnight_status_count?student_id=$studentId'),
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          outingTotal = data['total'] ?? 0;
          outingApproved = data['approved'] ?? 0;
          outingRejected = data['rejected'] ?? 0;
          outingPending = data['pending'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("외박 상태 로딩 실패: $e");
    }
  }

  // A/S 상태별 카운트 Fetch (실제 API 호출)
  Future<void> _fetchASStatusCount(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/as_status_count?student_id=$studentId'),
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          asTotal = data['total'] ?? 0;
          asRequested = data['requested'] ?? 0;
          asInProgress = data['in_progress'] ?? 0;
          asCompleted = data['completed'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("AS 상태 로딩 실패: $e");
      // 에러 시 기본값 설정
      if (mounted) {
        setState(() {
          asTotal = 0;
          asRequested = 0;
          asInProgress = 0;
          asCompleted = 0;
        });
      }
    }
  }

  // 석식 신청 상태 확인 (실제 API 호출)
  Future<void> _fetchDinnerStatus(String studentId) async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/dinner/requests?student_id=$studentId'),
      );

      print('🔍 대시보드 - 석식 상태 API 응답: ${response.statusCode}');

      if (response.statusCode == 200 && mounted) {
        final responseData = json.decode(response.body);
        List<Map<String, dynamic>> dinnerRequests = [];

        // API 응답 형식 처리
        if (responseData is Map && responseData['success'] == true) {
          final List<dynamic> data = responseData['requests'] ?? [];
          dinnerRequests = List<Map<String, dynamic>>.from(data);
        } else if (responseData is List) {
          dinnerRequests = List<Map<String, dynamic>>.from(responseData);
        }

        // 다음 달 석식 신청 상태 확인
        final now = DateTime.now();
        final nextMonth = now.month < 12 ? now.month + 1 : 1;
        final nextYear = now.month < 12 ? now.year : now.year + 1;
        final semester = (nextMonth >= 3 && nextMonth <= 8) ? '1학기' : '2학기';

        // 다음 달 신청이 있는지 확인
        final nextMonthApplication =
            dinnerRequests.where((req) {
              return req['year'].toString() == nextYear.toString() &&
                  req['semester'] == semester &&
                  req['month'] == '${nextMonth}월';
            }).toList();

        DinnerApplicationStatus status;

        if (nextMonthApplication.isNotEmpty) {
          // 결제 상태 확인을 위해 결제 내역 API 호출
          final paymentResponse = await http.get(
            Uri.parse('$apiBase/api/dinner/payments?student_id=$studentId'),
          );

          if (paymentResponse.statusCode == 200) {
            final paymentData = json.decode(paymentResponse.body);
            final monthKey = '$nextYear-$semester-${nextMonth}월';

            // 해당 월의 최신 결제 내역 찾기
            final monthPayments =
                (paymentData as List).where((payment) {
                  final paymentMonthKey =
                      '${payment['year']}-${payment['semester']}-${payment['month']}';
                  return paymentMonthKey == monthKey;
                }).toList();

            if (monthPayments.isNotEmpty) {
              // 최신 결제 내역 확인
              monthPayments.sort(
                (a, b) => DateTime.parse(
                  b['pay_dt'],
                ).compareTo(DateTime.parse(a['pay_dt'])),
              );
              final latestPayment = monthPayments.first;

              if (latestPayment['pay_type'] == '환불') {
                status = DinnerApplicationStatus.notApplied; // 환불됨 = 미신청 상태
              } else {
                status = DinnerApplicationStatus.completed; // 결제 완료
              }
            } else {
              status = DinnerApplicationStatus.pending; // 신청만 하고 결제 안함
            }
          } else {
            status = DinnerApplicationStatus.pending; // 결제 정보 조회 실패 시 대기 상태로
          }
        } else {
          // 신청 기간인지 확인
          final isApplicationPeriod = now.day <= 15; // 매월 1-15일이 신청 기간
          status =
              isApplicationPeriod
                  ? DinnerApplicationStatus.notApplied
                  : DinnerApplicationStatus.notApplied;
        }

        setState(() {
          _dinnerStatus = status;
        });

        print('✅ 대시보드 - 석식 상태 설정 완료: $_dinnerStatus');
      }
    } catch (e) {
      debugPrint("석식 상태 로딩 실패: $e");
      if (mounted) {
        setState(() {
          _dinnerStatus = DinnerApplicationStatus.notApplied;
        });
      }
    }
  }

  // 외부에서 호출할 수 있는 새로고침 함수
  Future<void> refreshData() async {
    final studentProvider = Provider.of<StudentProvider>(
      context,
      listen: false,
    );
    final studentId = widget.studentId ?? studentProvider.studentId;

    if (studentId != null) {
      print('🔄 대시보드 - 데이터 새로고침 시작');
      await _fetchAllData(studentId);
      print('✅ 대시보드 - 데이터 새로고침 완료');
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = Provider.of<StudentProvider>(context);
    final String name = student.name ?? '학생';

    // Scaffold 제거하고 컨텐츠만 반환 (home.dart에서 렌더링되므로)
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : buildDashboardContent(student, name);
  }

  /// 대시보드 컨텐츠 빌드
  Widget buildDashboardContent(StudentProvider student, String name) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.searchMode) _buildGreetingHeader(name, context),
          if (!widget.searchMode) const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽 프로필 및 상/벌점 영역
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildProfileCard(student),
                    const SizedBox(height: 24),
                    _buildPointsCard(),
                    const SizedBox(height: 24),
                    _buildDinnerStatusCard(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // 오른쪽 메인 컨텐츠 영역
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildOvernightStatusSection(), // 외박 신청 현황
                    const SizedBox(height: 24),
                    _buildServiceRequestSection(), // A/S 현황
                    const SizedBox(height: 24),
                    _buildStudentDetailsSection(student), // 학생 상세 정보
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 위젯 빌더 함수들 ---

  /// 상단 인사말 헤더 + 점호 버튼
  Widget _buildGreetingHeader(String name, BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "안녕하세요, $name님!",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              const Text('👋', style: TextStyle(fontSize: 26)),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _handleRollCall,
          icon: const Icon(Icons.check_circle_outline, size: 20),
          label: const Text("점호 확인"),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  /// 프로필 카드
  Widget _buildProfileCard(StudentProvider student) {
    final roomNum = student.roomNum;
    final dormInfo =
        (roomNum != null && roomNum.isNotEmpty)
            ? '${roomNum[0]}동 $roomNum'
            : '호실 정보 없음';

    return _BaseCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.accent.withOpacity(0.1),
            child: Icon(
              Icons.person_rounded,
              size: 42,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            student.name ?? '데이터 없음',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '학번: ${student.studentId ?? '-'}',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Chip(
            avatar: Icon(
              Icons.school_rounded,
              size: 16,
              color: AppColors.accent,
            ),
            label: Text(
              student.department ?? '학과 정보 없음',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.accent.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          const SizedBox(height: 8),
          Text(
            dormInfo,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          Divider(height: 24, color: Colors.grey[200], thickness: 1),
          _buildRoommateInfo(student),
        ],
      ),
    );
  }

  /// 프로필 카드 내 룸메이트 정보 섹션
  Widget _buildRoommateInfo(StudentProvider student) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '룸메이트',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.groups_2_rounded,
              size: 22,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.roommate ?? '데이터 없음',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  student.roommateDept ?? '학과 정보 없음',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// 석식 신청 현황 카드 (별도 분리)
  Widget _buildDinnerStatusCard() {
    final now = DateTime.now();
    final targetDate = DateTime(now.year, now.month + 1, 1);
    final String title = "${targetDate.month}월 석식";
    final bool isApplicationPeriod = now.day <= 15;

    String statusText;
    Color statusColor;
    IconData statusIcon;
    bool isActionable = false;

    switch (_dinnerStatus) {
      case DinnerApplicationStatus.completed:
        statusText = "신청 완료";
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case DinnerApplicationStatus.pending:
        statusText = "신청 상태";
        statusColor = AppColors.success;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case DinnerApplicationStatus.notApplied:
        if (isApplicationPeriod) {
          statusText = "신청 가능";
          statusColor = AppColors.accent;
          statusIcon = Icons.edit_calendar_rounded;
          isActionable = true;
        } else {
          statusText = "미신청";
          statusColor = AppColors.danger;
          statusIcon = Icons.no_food_rounded;
        }
        break;
    }

    Widget cardContent = _BaseCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            statusText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: statusColor,
            ),
          ),
        ],
      ),
    );

    if (isActionable) {
      return GestureDetector(
        onTap: () {
          // 석식 신청 페이지로 이동
          Navigator.of(context).pushNamed('/dinner').then((_) {
            // 페이지에서 돌아올 때 데이터 새로고침
            refreshData();
          });
        },
        child: cardContent,
      );
    }

    return cardContent;
  }

  /// 외박 신청 현황 섹션
  Widget _buildOvernightStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_month_rounded,
              color: AppColors.accent,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              "외박 신청 현황",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Spacer(),
            Text(
              "총 $outingTotal건",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                icon: Icons.check_circle_outline_rounded,
                label: '승인',
                count: outingApproved,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatusCard(
                icon: Icons.hourglass_empty_rounded,
                label: '대기',
                count: outingPending,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatusCard(
                icon: Icons.cancel_outlined,
                label: '반려',
                count: outingRejected,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A/S 신청 현황 섹션
  Widget _buildServiceRequestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.build_circle_outlined,
              color: AppColors.warning,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              "A/S 신청 현황",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const Spacer(),
            Text(
              "총 $asTotal건",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                icon: Icons.note_alt_rounded,
                label: '신청완료',
                count: asRequested,
                color: AppColors.neutral,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatusCard(
                icon: Icons.construction_rounded,
                label: '수리중',
                count: asInProgress,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatusCard(
                icon: Icons.task_alt_rounded,
                label: '수리완료',
                count: asCompleted,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 상태 표시 카드 (A/S, 외박 공용)
  Widget _buildStatusCard({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return _BaseCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                "${count}건",
                style: TextStyle(
                  fontSize: 22,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 상/벌점 카드
  Widget _buildPointsCard() {
    return _BaseCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.leaderboard_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                "상/벌점 현황",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStatItem(
            icon: Icons.emoji_events_rounded,
            color: AppColors.accent,
            title: "상점",
            value: "$plusScore점",
            indicator: LinearPercentIndicator(
              percent: (plusScore / 100).clamp(0.0, 1.0),
              lineHeight: 8,
              backgroundColor: AppColors.accent.withOpacity(0.2),
              progressColor: AppColors.accent,
              barRadius: const Radius.circular(4),
            ),
          ),
          const SizedBox(height: 24),
          _buildStatItem(
            icon: Icons.warning_amber_rounded,
            color: AppColors.danger,
            title: "벌점",
            value: "$minusScore점",
          ),
        ],
      ),
    );
  }

  /// 스탯 아이템 (상점, 벌점 등)
  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    Widget? indicator,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        if (indicator != null) ...[const SizedBox(height: 8), indicator],
      ],
    );
  }

  /// 학생 상세정보 섹션 (탭으로 구성)
  Widget _buildStudentDetailsSection(StudentProvider student) {
    return DefaultTabController(
      length: 2,
      child: _BaseCard(
        child: Column(
          children: [
            Container(
              color: AppColors.background,
              child: TabBar(
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3.0,
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_pin_rounded),
                        SizedBox(width: 8),
                        Text(
                          "기본 정보",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.contact_phone_rounded),
                        SizedBox(width: 8),
                        Text(
                          "연락처/환불 정보",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 250, // 탭 뷰 높이 고정
              child: TabBarView(
                children: [
                  // 기본 정보 탭
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildDetailItem(
                        icon: Icons.badge_rounded,
                        label: "성명",
                        value: student.name,
                      ),
                      _buildDetailItem(
                        icon: Icons.school_rounded,
                        label: "학과",
                        value: student.department,
                      ),
                      _buildDetailItem(
                        icon: Icons.home_work_rounded,
                        label: "기숙사",
                        value:
                            (student.roomNum != null &&
                                    student.roomNum!.isNotEmpty)
                                ? '${student.roomNum![0]}동'
                                : null,
                      ),
                      _buildDetailItem(
                        icon: Icons.meeting_room_rounded,
                        label: "호실",
                        value: student.roomNum,
                      ),
                      _buildDetailItem(
                        icon: Icons.smoking_rooms_rounded,
                        label: "흡연여부",
                        value: student.smoking,
                      ),
                    ],
                  ),
                  // 연락처/환불 정보 탭
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildDetailItem(
                        icon: Icons.phone_android_rounded,
                        label: "연락처",
                        value: student.phoneNum,
                      ),
                      _buildDetailItem(
                        icon: Icons.family_restroom_rounded,
                        label: "보호자 연락처",
                        value: student.parPhone,
                      ),
                      _buildDetailItem(
                        icon: Icons.account_balance_rounded,
                        label: "환불 은행",
                        value: student.paybackBank,
                      ),
                      _buildDetailItem(
                        icon: Icons.payment_rounded,
                        label: "계좌번호",
                        value: student.paybackNum,
                      ),
                      _buildDetailItem(
                        icon: Icons.person_search_rounded,
                        label: "예금주",
                        value: student.paybackName,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상세 정보 항목 위젯
  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String? value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 16),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '데이터 없음',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 일관된 스타일을 위한 재사용 가능한 기본 카드 위젯
class _BaseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _BaseCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200.withOpacity(0.7),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        // ClipRRect for inner border radius consistency
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}
