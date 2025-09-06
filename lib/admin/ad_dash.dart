import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:kbu_domi/env.dart';

// ----------- 컬러 및 텍스트 스타일 상수 -----------
const Color kNavy = Color(0xFF1C2946);
const Color kPink = Color(0xFFF284B7);
const Color kGreen = Color(0xFF43C48C); // 초록(메인)
const Color kBlueGray = Color(0xFFE7ECF3);
const Color kLightGray = Color(0xFFF0F2F5);
const Color kWhite = Colors.white;
const Color kBg = Color(0xFFF6F7FA);
const Color kOrange = Color(0xFFFAA632); // 오렌지(점호)

// ----------------- 텍스트 스타일 -----------------
TextStyle dashNumberStyle = TextStyle(
  fontSize: 38.sp,
  fontWeight: FontWeight.bold,
  color: kNavy,
  height: 1.2,
);
TextStyle dashTitleStyle = TextStyle(
  fontSize: 22.sp,
  fontWeight: FontWeight.bold,
  color: kNavy,
);

final _kCardBorderRadius = BorderRadius.circular(24.r);
final _kCardPadding = EdgeInsets.all(24.w);
final _kCardBoxShadow = [
  BoxShadow(
    color: Colors.grey.withOpacity(0.08),
    spreadRadius: 2,
    blurRadius: 10,
    offset: const Offset(0, 4),
  ),
];

// --------------- AdDashPage (StatefulWidget으로 변경) ---------------
class AdDashPage extends StatefulWidget {
  final Function(int)? onMenuChange;

  const AdDashPage({Key? key, this.onMenuChange}) : super(key: key);

  @override
  _AdDashPageState createState() => _AdDashPageState();
}

class _AdDashPageState extends State<AdDashPage> {
  Map<String, dynamic> _summaryData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('AdDashPage initState 호출됨');
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    print('🔄 _fetchDashboardData 시작 - mounted: $mounted');
    if (!mounted) return;

    setState(() => _isLoading = true);
    print('🔄 로딩 상태 설정 완료');

    try {
      print('🌐 API 호출 시작: $apiBase/api/admin/dashboard/summary');
      final response = await http.get(
        Uri.parse('$apiBase/api/admin/dashboard/summary'),
      );

      print('🌐 API 응답 상태: ${response.statusCode}');
      print('🌐 API 응답 바디: ${response.body}');

      if (!mounted) {
        print('❌ mounted가 false, 중단');
        return;
      }

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('📊 파싱된 데이터: $responseData');

        setState(() {
          _summaryData = responseData;
          _isLoading = false;
        });

        print('✅ 대시보드 데이터 저장 완료');
        print('✅ totalResidents: ${_summaryData['totalResidents']}');
        print('✅ todayOutsCount: ${_summaryData['todayOutsCount']}');
        print('✅ rollcallStats: ${_summaryData['rollcallStats']}');
        print('✅ dinnerCounts: ${_summaryData['dinnerCounts']}');
        print('✅ buildingOccupancy: ${_summaryData['buildingOccupancy']}');
        print('✅ recentApplications: ${_summaryData['recentApplications']}');
      } else {
        throw Exception(
          'Failed to load dashboard data: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ 대시보드 데이터 로드 실패: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Widget _actionButton(
    String label, {
    required Color bgColor,
    required Color fgColor,
    bool isOutlined = false,
    VoidCallback? onPressed,
  }) =>
      isOutlined
          ? OutlinedButton(
            onPressed: onPressed ?? () {},
            child: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: fgColor,
              side: BorderSide(color: fgColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              minimumSize: Size(65.w, 40.h),
              textStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
          : ElevatedButton(
            onPressed: onPressed ?? () {},
            child: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: fgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
              minimumSize: Size(65.w, 40.h),
              textStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
              elevation: 0,
            ),
          );

  List<Widget> getButtonsByType(String type) {
    switch (type) {
      case '외박':
        return [
          _actionButton(
            "조회",
            bgColor: Colors.transparent,
            fgColor: kNavy.withOpacity(0.7),
            isOutlined: true,
            onPressed: () {
              // 외박 관리 페이지로 이동 - AdHomePage의 메뉴를 외박관리(인덱스 6)로 설정
              if (widget.onMenuChange != null) {
                widget.onMenuChange!(6);
              }
            },
          ),
        ];
      case 'AS':
        return [
          _actionButton(
            "조회",
            bgColor: Colors.transparent,
            fgColor: kNavy.withOpacity(0.7),
            isOutlined: true,
            onPressed: () {
              // AS 관리 페이지로 이동 - AdHomePage의 메뉴를 AS신청관리(인덱스 7)로 설정
              if (widget.onMenuChange != null) {
                widget.onMenuChange!(7);
              }
            },
          ),
        ];
      case '퇴소':
        return [
          _actionButton(
            "조회",
            bgColor: Colors.transparent,
            fgColor: kNavy.withOpacity(0.7),
            isOutlined: true,
            onPressed: () {
              // 퇴소 관리 페이지로 이동 - AdHomePage의 메뉴를 퇴실관리(인덱스 9)로 설정
              if (widget.onMenuChange != null) {
                widget.onMenuChange!(9);
              }
            },
          ),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      'AdDashPage build 호출됨 - _isLoading: $_isLoading, 데이터 키: ${_summaryData.keys}',
    );

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // API로부터 받은 데이터 사용
    final totalResidents = _summaryData['totalResidents'] ?? 0;
    final todayOuts = _summaryData['todayOutsCount'] ?? 0;
    final rollcallStats = _summaryData['rollcallStats'] ?? {};
    final dinnerCounts = _summaryData['dinnerCounts'] ?? {};
    final buildingOccupancy = _summaryData['buildingOccupancy'] ?? {};
    final recentApplications = List<Map<String, dynamic>>.from(
      _summaryData['recentApplications'] ?? [],
    );

    print('🎯 UI 렌더링 데이터:');
    print('🎯 totalResidents: $totalResidents');
    print('🎯 todayOuts: $todayOuts');
    print('🎯 rollcallStats: $rollcallStats');
    print('🎯 dinnerCounts: $dinnerCounts');
    print('🎯 buildingOccupancy: $buildingOccupancy');
    print('🎯 recentApplications 개수: ${recentApplications.length}');

    // 점호 데이터 추출
    final rollcallTarget = rollcallStats['target'] ?? 0;
    final rollcallDone = rollcallStats['done'] ?? 0;
    final rollcallPending = rollcallStats['pending'] ?? 0;

    print(
      '📋 점호 데이터: target=$rollcallTarget, done=$rollcallDone, pending=$rollcallPending',
    );

    // 석식 데이터 추출
    final currentMonth = dinnerCounts['current_month'] ?? DateTime.now().month;
    final prevMonth =
        dinnerCounts['prev_month'] ??
        (currentMonth == 1 ? 12 : currentMonth - 1);
    final nextMonth =
        dinnerCounts['next_month'] ??
        (currentMonth == 12 ? 1 : currentMonth + 1);
    final currentDinnerCount = dinnerCounts['current_count'] ?? 0;
    final prevDinnerCount = dinnerCounts['prev_count'] ?? 0;
    final nextDinnerCount = dinnerCounts['next_count'] ?? 0;

    print(
      '🍽️ 석식 데이터: prev=$prevDinnerCount($prevMonth월), current=$currentDinnerCount($currentMonth월), next=$nextDinnerCount($nextMonth월)',
    );

    // 기숙사별 입주 현황 데이터 추출 (안전하게 처리)
    final yangdeokwonData = buildingOccupancy['yangdeokwon'] ?? {};
    final sunglyewonData = buildingOccupancy['sunglyewon'] ?? {};
    final yangdeokwonVacant = yangdeokwonData['vacant'] ?? 0;
    final sunglyewonVacant = sunglyewonData['vacant'] ?? 0;

    print('🏠 기숙사 데이터:');
    print('🏠 yangdeokwonData: $yangdeokwonData');
    print('🏠 sunglyewonData: $sunglyewonData');
    print('🏠 yangdeokwonVacant: $yangdeokwonVacant');
    print('🏠 sunglyewonVacant: $sunglyewonVacant');

    // rate 값을 안전하게 double로 변환
    double yangdeokwonRate = 0.0;
    double sunglyewonRate = 0.0;

    try {
      final yangRate = yangdeokwonData['rate'];
      if (yangRate != null) {
        yangdeokwonRate = (yangRate is num ? yangRate.toDouble() : 0.0) / 100.0;
        yangdeokwonRate = yangdeokwonRate.clamp(0.0, 1.0); // 0-1 범위로 제한
      }

      final sungRate = sunglyewonData['rate'];
      if (sungRate != null) {
        sunglyewonRate = (sungRate is num ? sungRate.toDouble() : 0.0) / 100.0;
        sunglyewonRate = sunglyewonRate.clamp(0.0, 1.0); // 0-1 범위로 제한
      }

      print(
        '🏠 계산된 입주율: 양덕원=${(yangdeokwonRate * 100).round()}%, 숭례원=${(sunglyewonRate * 100).round()}%',
      );
    } catch (e) {
      print('❌ 기숙사 입주율 계산 오류: $e');
      yangdeokwonRate = 0.0;
      sunglyewonRate = 0.0;
    }

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Text(
              '관리자 대시보드',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: kNavy,
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {
                print('🔄 새로고침 버튼 클릭됨');
                _fetchDashboardData();
              },
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('새로고침'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 1600.w,
            padding: EdgeInsets.symmetric(vertical: 30.h, horizontal: 30.w),
            child: Column(
              children: [
                // ───── 상단 카드 4개 ─────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopCardLarge(
                      color: kNavy,
                      number: "$totalResidents",
                      label: "총 입주자",
                    ),
                    _TopCardLarge(
                      color: kPink,
                      number: "$todayOuts",
                      label: "금일 외박",
                    ),
                    _RollcallWithSide(
                      target: rollcallTarget,
                      done: rollcallDone,
                      pending: rollcallPending,
                    ),
                    _DinnerWithSide(
                      prevMonth: prevMonth,
                      prevCount: prevDinnerCount,
                      currentMonth: currentMonth,
                      currCount: currentDinnerCount,
                      nextMonth: nextMonth,
                      nextCount: nextDinnerCount,
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                // ───── 두 번째 줄: 최근신청내역 + 국적성비 Pie 2개 ─────
                SizedBox(
                  height: 380.h,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 최근신청내역
                      Expanded(
                        flex: 7,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: _kCardBorderRadius,
                            boxShadow: _kCardBoxShadow,
                          ),
                          padding: _kCardPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text("최근 신청 내역", style: dashTitleStyle),
                                  const Spacer(),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: 5.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kGreen.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20.r),
                                    ),
                                    child: Text(
                                      "${recentApplications.length}건",
                                      style: TextStyle(
                                        color: kGreen,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.sp,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              const Divider(color: kLightGray),
                              Expanded(
                                child:
                                    recentApplications.isEmpty
                                        ? Center(
                                          child: Text(
                                            "최근 신청 내역이 없습니다.",
                                            style: TextStyle(
                                              fontSize: 16.sp,
                                              color: kNavy.withOpacity(0.6),
                                            ),
                                          ),
                                        )
                                        : ListView.builder(
                                          itemCount: recentApplications.length,
                                          itemBuilder: (context, index) {
                                            final app =
                                                recentApplications[index];
                                            return ListTile(
                                              leading: CircleAvatar(
                                                backgroundColor:
                                                    app['type'] == '외박'
                                                        ? kOrange.withOpacity(
                                                          0.15,
                                                        )
                                                        : app['type'] == 'AS'
                                                        ? kGreen.withOpacity(
                                                          0.15,
                                                        )
                                                        : app['type'] == '퇴소'
                                                        ? kPink.withOpacity(
                                                          0.15,
                                                        )
                                                        : kNavy.withOpacity(
                                                          0.15,
                                                        ),
                                                child: Text(
                                                  app['type'],
                                                  style: TextStyle(
                                                    color:
                                                        app['type'] == '외박'
                                                            ? kOrange
                                                            : app['type'] ==
                                                                'AS'
                                                            ? kGreen
                                                            : app['type'] ==
                                                                '퇴소'
                                                            ? kPink
                                                            : kNavy,
                                                    fontSize: 12.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              title: Text(
                                                "${app['name']} (${app['student_id']})",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16.sp,
                                                ),
                                              ),
                                              subtitle: Text(
                                                "${app['reason']}",
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  color: kNavy.withOpacity(0.7),
                                                ),
                                              ),
                                              trailing: SizedBox(
                                                width: 80.w,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: getButtonsByType(
                                                    app['type'],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 20.w),
                      // 국적 및 성비 Pie 차트 두 개 나란히 (더미 데이터 유지)
                      Expanded(
                        flex: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: _kCardBorderRadius,
                            boxShadow: _kCardBoxShadow,
                          ),
                          padding: _kCardPadding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("국적 및 성비 현황", style: dashTitleStyle),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: _PieTwoValues(
                                        percent1: 0.2,
                                        color1: kPink,
                                        label1: "외국인",
                                        percent2: 0.8,
                                        color2: kNavy,
                                        label2: "한국인",
                                        size: 150,
                                        section1Text: "20%",
                                        section2Text: "80%",
                                      ),
                                    ),
                                    SizedBox(width: 20.w),
                                    Flexible(
                                      child: _PieTwoValues(
                                        percent1: 0.6,
                                        color1: kNavy,
                                        label1: "남",
                                        percent2: 0.4,
                                        color2: kPink,
                                        label2: "여",
                                        size: 150,
                                        section1Text: "60%",
                                        section2Text: "40%",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                // ───── 하단 카드 (그래프 2개만) ─────
                SizedBox(
                  height: 410.h,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Container(
                          padding: _kCardPadding,
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: _kCardBorderRadius,
                            boxShadow: _kCardBoxShadow,
                          ),
                          child: Column(
                            children: [
                              Text("기숙사별 입주 현황", style: dashTitleStyle),
                              SizedBox(height: 20.h),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Flexible(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "양덕원",
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.bold,
                                              color: kNavy.withOpacity(0.8),
                                            ),
                                          ),
                                          SizedBox(height: 10.h),
                                          _PieTwoValues(
                                            percent1: yangdeokwonRate.clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            color1: kGreen,
                                            label1: "입주",
                                            percent2: (1.0 - yangdeokwonRate)
                                                .clamp(0.0, 1.0),
                                            color2: kLightGray,
                                            label2: "공실",
                                            centerText:
                                                "${(yangdeokwonRate * 100).round()}%",
                                            size: 140,
                                            section1Text:
                                                '${(yangdeokwonRate * 100).round()}%',
                                            section2Text:
                                                '${yangdeokwonVacant}개',
                                          ),
                                        ],
                                      ),
                                    ),
                                    Flexible(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "숭례원",
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.bold,
                                              color: kNavy.withOpacity(0.8),
                                            ),
                                          ),
                                          SizedBox(height: 10.h),
                                          _PieTwoValues(
                                            percent1: sunglyewonRate.clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            color1: kPink,
                                            label1: "입주",
                                            percent2: (1.0 - sunglyewonRate)
                                                .clamp(0.0, 1.0),
                                            color2: kLightGray,
                                            label2: "공실",
                                            centerText:
                                                "${(sunglyewonRate * 100).round()}%",
                                            size: 140,
                                            section1Text:
                                                '${(sunglyewonRate * 100).round()}%',
                                            section2Text:
                                                '${sunglyewonVacant}개',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 20.w),
                      Expanded(
                        flex: 8,
                        child: Container(
                          padding: _kCardPadding,
                          decoration: BoxDecoration(
                            color: kWhite,
                            borderRadius: _kCardBorderRadius,
                            boxShadow: _kCardBoxShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("연도별 기숙사 입주율", style: dashTitleStyle),
                              SizedBox(height: 10.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _LegendItem(color: kGreen, text: "양덕원"),
                                  SizedBox(width: 16.w),
                                  _LegendItem(color: kPink, text: "숭례원"),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              const Expanded(child: _AnnualOccupancyChart()),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------- 색상 원 위젯 --------
class _ColorDot extends StatelessWidget {
  final Color color;
  final double size;
  const _ColorDot({required this.color, this.size = 40.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.sp,
      height: size.sp,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// -------- 상단 카드(흰색+컬러 글씨) --------
class _TopCardLarge extends StatelessWidget {
  final Color color;
  final String number;
  final String label;
  const _TopCardLarge({
    required this.color,
    required this.number,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Container(
        margin: EdgeInsets.only(top: 20.h),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: 190.h,
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              padding: _kCardPadding,
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: _kCardBorderRadius,
                boxShadow: _kCardBoxShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Opacity(
                        opacity: 0,
                        child: _StatusInfo(
                          label: ' ',
                          value: 0,
                          color: Colors.transparent,
                        ),
                      ),
                      Text(
                        number,
                        style: dashNumberStyle.copyWith(color: kNavy),
                      ),
                      Opacity(
                        opacity: 0,
                        child: _StatusInfo(
                          label: ' ',
                          value: 0,
                          color: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    label,
                    style: dashTitleStyle.copyWith(
                      fontSize: 18.sp,
                      color: kNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(top: -20.h, child: _ColorDot(color: color, size: 40)),
          ],
        ),
      ),
    );
  }
}

// -------- 점호 카드(흰배경+오렌지 컬러) --------
class _RollcallWithSide extends StatelessWidget {
  final int target, done, pending;
  const _RollcallWithSide({
    required this.target,
    required this.done,
    required this.pending,
  });
  @override
  Widget build(BuildContext context) {
    final Color mainColor = kOrange;
    final Color sideColor = kNavy.withOpacity(0.7);
    return Expanded(
      flex: 1,
      child: Container(
        margin: EdgeInsets.only(top: 20.h),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: 190.h,
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              padding: _kCardPadding,
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: _kCardBorderRadius,
                boxShadow: _kCardBoxShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusInfo(label: "완료", value: done, color: sideColor),
                      Text(
                        "$target",
                        style: dashNumberStyle.copyWith(color: kNavy),
                      ),
                      _StatusInfo(
                        label: "미완료",
                        value: pending,
                        color: Colors.red,
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "금일 점호 현황",
                    style: dashTitleStyle.copyWith(
                      fontSize: 18.sp,
                      color: kNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -20.h,
              child: _ColorDot(color: mainColor, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}

// -------- 석식 카드(흰배경+초록 컬러) --------
class _DinnerWithSide extends StatelessWidget {
  final int prevMonth, prevCount, currentMonth, currCount, nextMonth, nextCount;
  const _DinnerWithSide({
    required this.prevMonth,
    required this.prevCount,
    required this.currentMonth,
    required this.currCount,
    required this.nextMonth,
    required this.nextCount,
  });
  @override
  Widget build(BuildContext context) {
    final Color mainColor = kGreen;
    final Color sideColor = kNavy.withOpacity(0.7);
    return Expanded(
      flex: 1,
      child: Container(
        margin: EdgeInsets.only(top: 20.h),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              height: 190.h,
              margin: EdgeInsets.symmetric(horizontal: 10.w),
              padding: _kCardPadding,
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: _kCardBorderRadius,
                boxShadow: _kCardBoxShadow,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _SideInfo(
                        month: prevMonth,
                        count: prevCount,
                        color: sideColor,
                      ),
                      Text(
                        "$currCount",
                        style: dashNumberStyle.copyWith(color: kNavy),
                      ),
                      _SideInfo(
                        month: nextMonth,
                        count: nextCount,
                        color: sideColor,
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "석식 현황 (${currentMonth}월)",
                    style: dashTitleStyle.copyWith(
                      fontSize: 17.5.sp,
                      color: kNavy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -20.h,
              child: _ColorDot(color: mainColor, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideInfo extends StatelessWidget {
  final int month, count;
  final Color color;
  const _SideInfo({
    required this.month,
    required this.count,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "$count",
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          "${month}월",
          style: TextStyle(
            fontSize: 14.sp,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusInfo extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatusInfo({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "$value",
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ===== 파이차트/범례 보조 위젯 (하단 그래프, 두 번째 줄에서 사용) =====
class _PieTwoValues extends StatelessWidget {
  final double percent1, percent2, size;
  final Color color1, color2;
  final String label1, label2;
  final String? centerText;
  final String? section1Text;
  final String? section2Text;

  _PieTwoValues({
    required double percent1,
    required this.color1,
    required this.label1,
    required double percent2,
    required this.color2,
    required this.label2,
    this.centerText,
    this.size = 150,
    this.section1Text,
    this.section2Text,
  }) : percent1 =
           percent1.isNaN || percent1.isInfinite
               ? 0.0
               : percent1.clamp(0.0, double.maxFinite),
       percent2 =
           percent2.isNaN || percent2.isInfinite
               ? 1.0
               : percent2.clamp(0.0, double.maxFinite);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size.w,
          height: size.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: centerText != null ? size.w * 0.35 : 0,
                  startDegreeOffset: -90,
                  sections: [
                    PieChartSectionData(
                      value: percent1,
                      color: color1,
                      radius: centerText != null ? 12.w : size.w * 0.45,
                      showTitle: section1Text != null,
                      title: section1Text,
                      titleStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: kWhite,
                      ),
                    ),
                    PieChartSectionData(
                      value: percent2,
                      color: color2,
                      radius: centerText != null ? 12.w : size.w * 0.45,
                      showTitle: section2Text != null,
                      title: section2Text,
                      titleStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color:
                            (color2 == kLightGray)
                                ? kNavy.withOpacity(0.7)
                                : kWhite,
                      ),
                    ),
                  ],
                ),
              ),
              if (centerText != null)
                Text(
                  centerText!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28.sp,
                    color: kNavy,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _LegendItem(color: color1, text: label1),
            SizedBox(width: 16.w),
            _LegendItem(color: color2, text: label2),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 16.sp,
            color: kNavy,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// --- 연도별 입주율 라인 그래프 위젯 ---
class _AnnualOccupancyChart extends StatelessWidget {
  const _AnnualOccupancyChart();

  @override
  Widget build(BuildContext context) {
    final yangdeokwonData = [
      const FlSpot(0, 85),
      const FlSpot(1, 88),
      const FlSpot(2, 92),
    ];

    final sunglyewonData = [
      const FlSpot(0, 82),
      const FlSpot(1, 85),
      const FlSpot(2, 86),
    ];

    Widget bottomTitleWidgets(double value, TitleMeta meta) {
      final style = TextStyle(
        color: kNavy.withOpacity(0.8),
        fontWeight: FontWeight.bold,
        fontSize: 14.sp,
      );
      String text;
      switch (value.toInt()) {
        case 0:
          text = '2023년';
          break;
        case 1:
          text = '2024년';
          break;
        case 2:
          text = '2025년';
          break;
        default:
          return Container();
      }

      return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 10,
        child: Text(text, style: style),
      );
    }

    Widget leftTitleWidgets(double value, TitleMeta meta) {
      if (value % 5 != 0) {
        return Container();
      }
      return Text(
        '${value.toInt()}%',
        style: TextStyle(
          color: kNavy.withOpacity(0.8),
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      );
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 2,
        minY: 75,
        maxY: 100,
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: kWhite,
            tooltipRoundedRadius: 12.r,
            tooltipPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 10.h,
            ),
            tooltipMargin: 12,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final flSpot = barSpot;
                final textStyle = TextStyle(
                  color: flSpot.bar.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                );
                return LineTooltipItem('${flSpot.y.toInt()}', textStyle);
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: kBlueGray.withOpacity(0.5), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 1,
              getTitlesWidget: bottomTitleWidgets,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: leftTitleWidgets,
              reservedSize: 40,
              interval: 5,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: yangdeokwonData,
            isCurved: true,
            color: kGreen,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [kGreen.withOpacity(0.3), kGreen.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          LineChartBarData(
            spots: sunglyewonData,
            isCurved: true,
            color: kPink,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [kPink.withOpacity(0.3), kPink.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
