// 파일명: ad_in_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:math' as math;
import 'application_data_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ad_home.dart'; // adHomePageKey 사용을 위해 import 추가

// --- AppColors 클래스 (변경 없음) ---
class AppColors {
  static const Color primary = Color(0xFF0D47A1);
  static const Color fontPrimary = Color(0xFF333333);
  static const Color fontSecondary = Color(0xFF757575);
  static const Color border = Color(0xFFE0E0E0);
  static const Color statusWaiting = Color(0xFFFFA726);
  static const Color statusConfirmed = Color(0xFF66BB6A);
  static const Color statusAssigned = Color(0xFF42A5F5);
  static const Color statusUnassigned = Color(0xFF757575);
  static const Color statusCheckedOut = Color(0xFFBDBDBD);
  static const Color statusRejected = Color(0xFFEF5350);
  static const Color statusMovedOut = Color(0xFF757575);
  static const Color disabledBackground = Color(0xFFF5F5F5);
  static const Color genderFemale = Color(0xFFEC407A);
  static const Color roomFull = Color(0xFF0D47A1);
  static const Color activeBorder = Color(0xFF0D47A1);
  static const Color roomPartiallyFilled = Color.fromARGB(255, 106, 176, 252);
  static const Color roomSpecial = Color(0xFFBBDEFB);
}

class AdInPage extends StatefulWidget {
  // 생성자를 수정하여 인자를 직접 받도록 변경합니다.
  final String? studentIdToSelect;
  final String? initialTab;

  const AdInPage({super.key, this.studentIdToSelect, this.initialTab});

  @override
  State<AdInPage> createState() => _AdInPageState();
}

class _AdInPageState extends State<AdInPage>
    with AutomaticKeepAliveClientMixin {
  int _selectedIndex = -1;
  int _hoveredIndex = -1;
  String _searchText = '';
  String _currentRightPanelTab = '서류심사';
  bool _isEditMode = false;
  bool _isLoading = true;

  // ▼▼▼▼▼ [변경] 지원생구분 필터 추가 ▼▼▼▼▼
  final Map<String, Set<String>> _selectedFilters = {
    '상태': {'전체'},
    '지원생구분': {'전체'}, // 추가된 부분
  };
  // ▲▲▲▲▲ [변경] 지원생구분 필터 추가 ▲▲▲▲▲

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _adminMemoController = TextEditingController();

  String? _selectedBuildingForRooms;
  String? _selectedFloorForRooms;
  String? _highlightedRoomNumber;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAndInitializeData();

    // 생성자를 통해 전달받은 인자가 있을 경우 처리
    if (widget.initialTab != null) {
      _currentRightPanelTab = widget.initialTab!;
    }
    if (widget.studentIdToSelect != null) {
      // 데이터 로드 완료 후 인자 처리
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        if (ApplicationDataService.applications.isEmpty) {
          // 데이터가 아직 로드되지 않았다면 재시도
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!mounted) return;
            _selectStudentFromArguments(
              widget.studentIdToSelect!,
              widget.initialTab,
            );
          });
        } else {
          _selectStudentFromArguments(
            widget.studentIdToSelect!,
            widget.initialTab,
          );
        }
      });
    }
  }

  // didChangeDependencies는 이제 사용하지 않으므로 제거하거나 주석 처리
  /*
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argumentsHandled) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final String? studentIdToSelect = args['studentId'];
        final String? initialTab = args['initialTab'];

        if (studentIdToSelect != null) {
          Future.delayed(const Duration(milliseconds: 150), () {
            if (!mounted) return;
            if (ApplicationDataService.applications.isEmpty) {
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _selectStudentFromArguments(studentIdToSelect, initialTab);
              });
            } else {
              _selectStudentFromArguments(studentIdToSelect, initialTab);
            }
          });
        }
        _argumentsHandled = true;
      }
    }
  }
  */

  // 전달받은 학생 ID로 학생을 찾아 선택하는 함수
  void _selectStudentFromArguments(
    String studentIdToSelect,
    String? initialTab,
  ) {
    final allApplications = ApplicationDataService.applications;
    int indexInListItems = -1;

    Map<String, dynamic>? targetApp;
    for (var app in allApplications) {
      if (app['studentId'] == studentIdToSelect) {
        targetApp = app;
        break;
      }
    }

    if (targetApp != null) {
      if (initialTab != null) {
        _currentRightPanelTab = initialTab;
      }

      final List<Map<String, dynamic>> listItems =
          _currentRightPanelTab == '방배정'
              ? _getGroupedRoomAssignmentList()
              : _filteredApplications;

      for (int i = 0; i < listItems.length; i++) {
        final item = listItems[i];
        if (item['isPair'] == true) {
          if (item['student1']['studentId'] == studentIdToSelect ||
              item['student2']['studentId'] == studentIdToSelect) {
            indexInListItems = i;
            break;
          }
        } else if (item['student'] != null &&
            item['student']['studentId'] == studentIdToSelect) {
          indexInListItems = i;
          break;
        } else if (item['studentId'] == studentIdToSelect) {
          indexInListItems = i;
          break;
        }
      }

      if (indexInListItems != -1) {
        setState(() {
          _selectedIndex = indexInListItems;
          _updateSelection();
        });
      } else {
        setState(() {
          _selectedFilters['상태'] = {'전체'};
          _selectedFilters['지원생구분'] = {'전체'}; // 추가된 부분: 필터 리셋
          _searchText = '';
          _searchController.clear();
        });
        Future.delayed(const Duration(milliseconds: 50), () {
          if (!mounted) return;
          final List<Map<String, dynamic>> refreshedListItems =
              _currentRightPanelTab == '방배정'
                  ? _getGroupedRoomAssignmentList()
                  : _filteredApplications;

          for (int i = 0; i < refreshedListItems.length; i++) {
            final item = refreshedListItems[i];
            if (item['isPair'] == true) {
              if (item['student1']['studentId'] == studentIdToSelect ||
                  item['student2']['studentId'] == studentIdToSelect) {
                indexInListItems = i;
                break;
              }
            } else if (item['student'] != null &&
                item['student']['studentId'] == studentIdToSelect) {
              indexInListItems = i;
              break;
            } else if (item['studentId'] == studentIdToSelect) {
              indexInListItems = i;
              break;
            }
          }

          if (indexInListItems != -1) {
            setState(() {
              _selectedIndex = indexInListItems;
              _updateSelection();
            });
          } else {
            print(
              "AdInPage: Student $studentIdToSelect not found after refresh.",
            );
          }
        });
      }
    }
  }

  void _loadAndInitializeData() async {
    setState(() => _isLoading = true);

    try {
      // 실제 API에서 데이터 로드
      await ApplicationDataService.initializeData();

      if (!mounted) return;

      // 방 점유율 계산
      await ApplicationDataService.updateRoomOccupancy();
      _updateSelection();

      // 기본 건물/층 설정
      if (_selectedBuildingForRooms == null && _buildingOptions.isNotEmpty) {
        _selectedBuildingForRooms = _buildingOptions.first;
        _selectedFloorForRooms =
            _getFloorOptionsForBuilding(_selectedBuildingForRooms).firstOrNull;
      }
    } catch (e) {
      // 에러 처리
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 로딩 중 오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ▼▼▼▼▼ [변경] 지원생구분 필터 로직 추가 ▼▼▼▼▼
  List<Map<String, dynamic>> get _filteredApplications {
    return ApplicationDataService.applications.where((app) {
      // 상태 필터 로직 (개선된 3단계 구분)
      bool statusMatch;
      final selectedStatusSet = _selectedFilters['상태']!;

      if (selectedStatusSet.contains('전체')) {
        statusMatch = true;
      } else {
        // 실제 학생 상태를 3단계로 구분
        String actualStatus;
        if (app['status'] == '미확인') {
          actualStatus = '서류 미확인';
        } else if (app['status'] == '확인' &&
            (app['assignedRoomNumber'] == null ||
                app['assignedRoomNumber'] == '')) {
          actualStatus = '서류 확인완료';
        } else if (app['assignedRoomNumber'] != null &&
            app['assignedRoomNumber'] != '') {
          actualStatus = '방 배정완료';
        } else {
          actualStatus = '서류 미확인'; // 기본값
        }

        statusMatch = selectedStatusSet.contains(actualStatus);
      }

      // 지원생구분 필터 로직
      final selectedApplicantTypeSet = _selectedFilters['지원생구분']!;
      final bool applicantTypeMatch =
          selectedApplicantTypeSet.contains('전체') ||
          selectedApplicantTypeSet.contains(app['applicantType']);

      // 검색어 필터 로직
      final bool searchMatch =
          _searchText.isEmpty ||
          app['studentId'].toString().contains(_searchText) ||
          app['studentName'].toString().contains(_searchText);

      return statusMatch && applicantTypeMatch && searchMatch;
    }).toList();
  }
  // ▲▲▲▲▲ [변경] 지원생구분 필터 로직 추가 ▲▲▲▲▲

  List<Map<String, dynamic>> _getGroupedRoomAssignmentList() {
    final filtered = _filteredApplications;
    final List<Map<String, dynamic>> result = [];
    final Set<String> processedIds = {};
    for (final app in filtered) {
      if (processedIds.contains(app['id'])) continue;
      final pairId = app['pairId'];
      if (pairId != null) {
        final partner = filtered.firstWhere(
          (p) => p['pairId'] == pairId && p['id'] != app['id'],
          orElse: () => {},
        );
        if (partner.isNotEmpty) {
          result.add({
            'isPair': true,
            'student1': app,
            'student2': partner,
            'id': pairId,
            'status': app['status'],
          });
          processedIds.add(app['id']);
          processedIds.add(partner['id']);
        } else {
          result.add({
            'isPair': false,
            'student': app,
            'id': app['id'],
            'status': app['status'],
          });
          processedIds.add(app['id']);
        }
      } else {
        result.add({
          'isPair': false,
          'student': app,
          'id': app['id'],
          'status': app['status'],
        });
        processedIds.add(app['id']);
      }
    }
    return result;
  }

  List<String> get _buildingOptions {
    return ApplicationDataService.dormRooms
        .map((room) => room['building'] as String)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> _getFloorOptionsForBuilding(String? building) {
    if (building == null) return [];
    return ApplicationDataService.dormRooms
        .where(
          (room) =>
              room['building'] == building &&
              room['floor'] != null &&
              room['floor'] >= 6 &&
              room['floor'] <= 10,
        )
        .map((room) => (room['floor'] as int).toString())
        .toSet()
        .toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
  }

  String _getRoomTypeByFloor(String floor) {
    switch (floor) {
      case '6':
        return '1인실';
      case '7':
        return '2인실';
      case '8':
        return '3인실';
      case '9':
        return '룸메이트';
      case '10':
        return '방학이용';
      default:
        return '';
    }
  }

  void _updateSelection() {
    final listItems =
        _currentRightPanelTab == '방배정'
            ? _getGroupedRoomAssignmentList()
            : _filteredApplications;
    if (listItems.isNotEmpty) {
      if (_selectedIndex >= listItems.length || _selectedIndex == -1) {
        _selectedIndex = 0;
      }
      final selectedItem = listItems[_selectedIndex];
      Map<String, dynamic> selectedApp;
      if (_currentRightPanelTab == '방배정') {
        selectedApp =
            selectedItem['isPair']
                ? selectedItem['student1']
                : selectedItem['student'];
      } else {
        selectedApp = selectedItem;
      }
      _checkAndUpdateStudentStatus(selectedApp, showPopup: false);
      _adminMemoController.text = selectedApp['adminMemo'] ?? '';
      _isEditMode = false;
    } else {
      _selectedIndex = -1;
      _adminMemoController.text = '';
      _isEditMode = false;
    }
    if (mounted) setState(() {});
  }

  void _handleStudentTap(int index, Map<String, dynamic> studentApp) {
    final startingTab = _currentRightPanelTab;
    setState(() {
      _selectedIndex = index;
      _adminMemoController.text = studentApp['adminMemo'] ?? '';
      _isEditMode = false;
      if (startingTab == '방배정' && _getDisplayStatus(studentApp) == '서류 미확인') {
        _currentRightPanelTab = '서류심사';
      } else if (startingTab == '방배정' &&
          _getDisplayStatus(studentApp) == '방 배정완료' &&
          studentApp['assignedRoomNumber'] != null) {
        _selectedBuildingForRooms = studentApp['assignedBuilding'];
        final roomNumberStr = studentApp['assignedRoomNumber'].replaceAll(
          '호',
          '',
        );
        _selectedFloorForRooms =
            (int.parse(roomNumberStr) / 100).floor().toString();
        _highlightedRoomNumber = studentApp['assignedRoomNumber'];
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _highlightedRoomNumber = null);
        });
      }
    });
  }

  void _assignStudentToRoom(
    Map<String, dynamic> application,
    Map<String, dynamic> room,
  ) {
    print(
      '🔄 방 배정 시작: ${application['studentName']} → ${room['building']} ${room['roomNumber']}',
    );

    try {
      application['assignedBuilding'] = room['building'];
      application['assignedRoomNumber'] = room['roomNumber'];
      application['status'] = '배정완료';

      print(
        '✅ 방 배정 완료: ${application['studentName']} → ${room['building']} ${room['roomNumber']}',
      );
    } catch (e) {
      print('❌ 방 배정 중 오류 발생: $e');
    }
  }

  void _cancelAssignment(Map<String, dynamic> studentApp) async {
    print(
      '🔄 배정 취소 시작: ${studentApp['studentName']} (${studentApp['studentId']})',
    );

    try {
      // 1. 서버 API 호출로 DB에서 배정 취소
      print('📡 서버 API 호출 중...');
      await ApplicationDataService.cancelAssignment(studentApp['studentId']);
      print('✅ 서버 배정 취소 완료');

      // 2. 클라이언트 상태 업데이트
      setState(() {
        var mainStudent = ApplicationDataService.applications.firstWhere(
          (app) => app['id'] == studentApp['id'],
        );

        print('📍 메인 학생 찾음: ${mainStudent['studentName']}');

        // 룸메이트가 있는 경우 파트너도 함께 처리
        if (mainStudent['pairId'] != null) {
          try {
            var partner = ApplicationDataService.applications.firstWhere(
              (app) =>
                  app['pairId'] == mainStudent['pairId'] &&
                  app['id'] != mainStudent['id'],
            );
            print('📍 파트너 찾음: ${partner['studentName']}');
            partner['assignedBuilding'] = null;
            partner['assignedRoomNumber'] = null;
            partner['status'] = '확인';
          } catch (e) {
            print("❌ 배정 취소 중 파트너를 찾을 수 없습니다: $e");
          }
        }

        // 메인 학생 배정 취소
        mainStudent['assignedBuilding'] = null;
        mainStudent['assignedRoomNumber'] = null;
        mainStudent['status'] = '확인';

        print('✅ 클라이언트 상태 업데이트 완료');
      });

      // 3. 방 점유율 업데이트
      await ApplicationDataService.updateRoomOccupancy();

      // 4. UI 새로고침
      setState(() => _updateSelection());

      print('✅ 배정 취소 완료');
    } catch (e) {
      print('❌ 배정 취소 중 오류 발생: $e');

      // 사용자에게 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('배정 취소 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleCancelAssignmentFromList() {
    final listItems = _getGroupedRoomAssignmentList();
    if (_selectedIndex < 0 || listItems.isEmpty) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              title: const Text('알림'),
              content: const Text('목록에서 학생을 먼저 선택해주세요.'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
      return;
    }
    final selectedItem = listItems[_selectedIndex];
    final selectedApp =
        selectedItem['isPair']
            ? selectedItem['student1']
            : selectedItem['student'];
    if (_getDisplayStatus(selectedApp) != '방 배정완료') {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              title: const Text('알림'),
              content: const Text('배정이 완료된 학생만 취소할 수 있습니다.'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
      return;
    }
    _cancelAssignment(selectedApp);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("'${selectedApp['studentName']}' 학생의 배정이 취소되었습니다."),
      ),
    );
  }

  void _performAutoAssignment() async {
    try {
      // 로딩 상태 표시
      setState(() => _isLoading = true);

      // 자동배정 전에 데이터 새로고침 (배정 취소된 학생들 포함)
      print('🔄 자동배정 전 데이터 새로고침 중...');
      await ApplicationDataService.initializeData(forceRefresh: true);

      // 서버 자동배정 API 호출
      final result = await ApplicationDataService.executeAutoAssignment(
        dryRun: false,
      );

      if (result['success'] == true) {
        // 성공 시 데이터 강제 새로고침
        await ApplicationDataService.initializeData(forceRefresh: true);
        setState(() {
          _isLoading = false;
          _updateSelection();
        });

        // 성공 메시지 표시
        showDialog(
          context: context,
          builder:
              (dialogContext) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                title: Text(
                  '자동 배정 완료',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                    color: AppColors.fontPrimary,
                  ),
                ),
                content: Text(
                  result['message'] ?? '방 배정이 완료되었습니다.',
                  style: TextStyle(color: AppColors.fontSecondary),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusConfirmed,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('확인'),
                  ),
                ],
              ),
        );
      } else {
        throw Exception(result['error'] ?? '자동배정에 실패했습니다.');
      }
    } catch (e) {
      setState(() => _isLoading = false);

      // 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('자동배정 실행 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildLeftPanel()),
                        VerticalDivider(width: 1.w, color: AppColors.border),
                        Expanded(flex: 5, child: _buildRightPanel()),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  // ▼▼▼▼▼ 이 아래의 UI 빌드 함수들이 수정되었습니다. ▼▼▼▼▼

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 20.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            '입실 관리',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.fontPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    final bool isRoomAssignmentTab = _currentRightPanelTab == '방배정';
    final List<Map<String, dynamic>> listItems =
        isRoomAssignmentTab
            ? _getGroupedRoomAssignmentList()
            : _filteredApplications;
    final Map<String, List<String>> filterOptions = {
      '상태':
          _currentRightPanelTab == '방배정'
              ? ['전체', '서류 미확인', '서류 확인완료', '방 배정완료']
              : ['전체', '서류 미확인', '서류 확인완료'],
    };
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ▼▼▼▼▼ [변경] 필터 UI 구조 변경 ▼▼▼▼▼
                Text(
                  "필터", // 제목 변경
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.fontPrimary,
                  ),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  // 상태 필터
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children:
                      filterOptions['상태']!.map((option) {
                        final bool isSelected = _selectedFilters['상태']!
                            .contains(option);
                        return ChoiceChip(
                          label: Text(
                            option,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color:
                                  isSelected
                                      ? const Color.fromRGBO(68, 138, 255, 1)
                                      : AppColors.fontSecondary,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected:
                              (selected) => setState(() {
                                _selectedFilters['상태'] = {option};
                                _updateSelection();
                              }),
                          selectedColor: const Color.fromRGBO(
                            68,
                            138,
                            255,
                            0.15,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? const Color.fromRGBO(68, 138, 255, 1)
                                      : AppColors.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                SizedBox(height: 12.h),
                Wrap(
                  // 지원생구분 필터 (추가된 부분)
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children:
                      ['전체', '신입생', '재학생'].map((option) {
                        final bool isSelected = _selectedFilters['지원생구분']!
                            .contains(option);
                        return ChoiceChip(
                          label: Text(
                            option,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color:
                                  isSelected
                                      ? const Color.fromRGBO(68, 138, 255, 1)
                                      : AppColors.fontSecondary,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          selected: isSelected,
                          showCheckmark: false,
                          onSelected:
                              (selected) => setState(() {
                                _selectedFilters['지원생구분'] = {option};
                                _updateSelection();
                              }),
                          selectedColor: const Color.fromRGBO(
                            68,
                            138,
                            255,
                            0.15,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            side: BorderSide(
                              color:
                                  isSelected
                                      ? const Color.fromRGBO(68, 138, 255, 1)
                                      : AppColors.border,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                SizedBox(height: 16.h),
                // ▲▲▲▲▲ [변경] 필터 UI 구조 변경 ▲▲▲▲▲
                SizedBox(
                  height: 40.h,
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    onChanged:
                        (value) => setState(() {
                          _searchText = value;
                          _updateSelection();
                        }),
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20.sp,
                        color: AppColors.fontSecondary,
                      ),
                      hintText: '이름 또는 학번으로 검색',
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.fontSecondary.withOpacity(0.7),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: EdgeInsets.only(left: 14.w),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${listItems.length}개 항목',
                style: TextStyle(
                  fontSize: 15.sp,
                  color: AppColors.fontSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_currentRightPanelTab == '방배정')
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _handleCancelAssignmentFromList,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.fontSecondary,
                        side: BorderSide(color: AppColors.border),
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 12.h,
                        ),
                        textStyle: TextStyle(fontSize: 15.sp),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: const Text('배정 취소'),
                    ),
                    SizedBox(width: 8.w),
                    ElevatedButton(
                      onPressed: _performAutoAssignment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 12.h,
                        ),
                        textStyle: TextStyle(fontSize: 15.sp),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      child: const Text('자동 배정'),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: ListView.builder(
              itemCount: listItems.length,
              itemBuilder: (context, index) {
                final item = listItems[index];
                if (isRoomAssignmentTab && item['isPair'] == true) {
                  return _buildPairedApplicationListItem(item, index);
                } else {
                  final student = isRoomAssignmentTab ? item['student'] : item;
                  return _buildApplicationListItem(student, index);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusWidget(Map<String, dynamic> app) {
    if (app['assignedBuilding'] != null && app['assignedRoomNumber'] != null) {
      return Text(
        '${app['assignedBuilding']} ${app['assignedRoomNumber']}',
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.statusAssigned,
        ),
      );
    } else {
      final String displayStatus = _getDisplayStatus(app);
      return Text(
        displayStatus,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(displayStatus),
        ),
      );
    }
  }

  String _getDisplayStatus(Map<String, dynamic> app) {
    // 실제 학생 상태를 3단계로 명확하게 구분하여 표시
    if (app['status'] == '미확인') {
      return '서류 미확인';
    } else if (app['status'] == '확인' &&
        (app['assignedRoomNumber'] == null ||
            app['assignedRoomNumber'] == '')) {
      return '서류 확인완료';
    } else if (app['assignedRoomNumber'] != null &&
        app['assignedRoomNumber'] != '') {
      return '방 배정완료';
    } else {
      return '서류 미확인'; // 기본값
    }
  }

  Color _getStatusColor(String displayStatus) {
    switch (displayStatus) {
      case '서류 미확인':
        return AppColors.statusWaiting;
      case '서류 확인완료':
        return AppColors.statusConfirmed;
      case '방 배정완료':
        return AppColors.statusAssigned;
      case '반려':
        return AppColors.statusRejected;
      case '퇴소':
        return AppColors.statusMovedOut;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPairedApplicationListItem(
    Map<String, dynamic> pairData,
    int index,
  ) {
    final bool isSelected = _selectedIndex == index;
    final bool isHovered = _hoveredIndex == index;
    final Map<String, dynamic> student1 = pairData['student1'];
    final Map<String, dynamic> student2 = pairData['student2'];
    final Color bgColor =
        isHovered ? Colors.grey.withOpacity(0.1) : Colors.white;
    final Border border = Border.all(
      color: isSelected ? AppColors.activeBorder : AppColors.border,
      width: isSelected ? 1.5 : 1.0,
    );
    final bool isReviewTab = _currentRightPanelTab == '서류심사';
    return MouseRegion(
      onEnter: (event) => setState(() => _hoveredIndex = index),
      onExit: (event) => setState(() => _hoveredIndex = -1),
      child: GestureDetector(
        onTap: () => _handleStudentTap(index, student1),
        child: Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8.r),
            border: border,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '룸메이트',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fontPrimary,
                    ),
                  ),
                  _buildStatusWidget(student1),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${student1['studentName']}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.fontPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        isReviewTab
                            ? Text(
                              '${student1['studentId']} | ${student1['department']}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.fontSecondary,
                              ),
                            )
                            : Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.fontSecondary,
                                ),
                                children: [
                                  TextSpan(text: '${student1['studentId']} | '),
                                  TextSpan(
                                    text: student1['gender'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          student1['gender'] == '남'
                                              ? AppColors.primary
                                              : AppColors.genderFemale,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' | ${student1['department']} | ${student1['smokingStatus']}',
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${student2['studentName']}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.fontPrimary,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        isReviewTab
                            ? Text(
                              '${student2['studentId']} | ${student2['department']}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: AppColors.fontSecondary,
                              ),
                            )
                            : Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.fontSecondary,
                                ),
                                children: [
                                  TextSpan(text: '${student2['studentId']} | '),
                                  TextSpan(
                                    text: student2['gender'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          student2['gender'] == '남'
                                              ? AppColors.primary
                                              : AppColors.genderFemale,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' | ${student2['department']}',
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationListItem(Map<String, dynamic> app, int index) {
    final bool isSelected = _selectedIndex == index;
    final bool isHovered = _hoveredIndex == index;
    final String memo = app['adminMemo'] ?? '';
    final bool isReviewTab = _currentRightPanelTab == '서류심사';
    return MouseRegion(
      onEnter: (event) => setState(() => _hoveredIndex = index),
      onExit: (event) => setState(() => _hoveredIndex = -1),
      child: GestureDetector(
        onTap: () => _handleStudentTap(index, app),
        child: Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isHovered ? Colors.grey.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected ? AppColors.activeBorder : AppColors.border,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${app['studentName']}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.fontPrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  _buildStatusWidget(app),
                ],
              ),
              SizedBox(height: 4.h),
              isReviewTab
                  ? Text(
                    '${app['studentId']} | ${app['department']}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: AppColors.fontSecondary,
                    ),
                  )
                  : Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.fontSecondary,
                      ),
                      children: [
                        TextSpan(text: '${app['studentId']} | '),
                        TextSpan(
                          text: app['gender'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                app['gender'] == '남'
                                    ? AppColors.primary
                                    : AppColors.genderFemale,
                          ),
                        ),
                        TextSpan(
                          text:
                              ' | ${app['department']} | ${app['roomType']} | ${app['smokingStatus']}',
                        ),
                      ],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              if (memo.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Row(
                    children: [
                      Icon(Icons.comment, size: 14.sp, color: Colors.blueGrey),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: Text(
                          memo,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.blueGrey,
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
    );
  }

  Widget _buildRightPanel() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 24.w),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1.h),
            ),
          ),
          child: Row(
            children: [
              _buildRightPanelTabButton('서류심사'),
              SizedBox(width: 20.w),
              _buildRightPanelTabButton('방배정'),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.w),
            child:
                _currentRightPanelTab == '서류심사'
                    ? _buildStudentApplicationDetails()
                    : _buildAvailableRoomsList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanelTabButton(String tabName) {
    final bool isSelected = _currentRightPanelTab == tabName;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentRightPanelTab = tabName;
          _selectedFilters['상태'] = {'전체'};
          if (tabName == '방배정' && _selectedBuildingForRooms == null) {
            String? firstBuilding =
                _buildingOptions.isNotEmpty ? _buildingOptions.first : null;
            if (firstBuilding != null) {
              _selectedBuildingForRooms = firstBuilding;
              _selectedFloorForRooms =
                  _getFloorOptionsForBuilding(firstBuilding).firstOrNull;
            }
          }
          _updateSelection();
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tabName,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.primary : AppColors.fontSecondary,
            ),
          ),
          SizedBox(height: 6.h),
          if (isSelected)
            Container(width: 40.w, height: 3.h, color: AppColors.primary),
        ],
      ),
    );
  }

  void _checkAndUpdateStudentStatus(
    Map<String, dynamic> studentApp, {
    bool showPopup = false,
  }) {
    if (studentApp['status'] != '미확인' || !showPopup) return;
    final List<dynamic> documents = studentApp['documents'] ?? [];
    final bool allVerified = documents.every(
      (doc) => doc['isVerified'] == true,
    );
    if (allVerified) {
      showDialog(
        context: context,
        builder:
            (dCtx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              title: Text(
                '서류 확인 완료',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                  color: AppColors.fontPrimary,
                ),
              ),
              content: SizedBox(
                width: 380.w,
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: AppColors.fontSecondary,
                      fontSize: 16.sp,
                      height: 1.6,
                    ),
                    children: [
                      const TextSpan(text: '모든 서류를 확인했습니다.\n'),
                      TextSpan(
                        text: '${studentApp['studentName']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.fontPrimary,
                        ),
                      ),
                      const TextSpan(text: ' 학생의 상태를 \'확인\'으로 변경하시겠습니까?'),
                    ],
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: AppColors.fontSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dCtx);
                    setState(() => studentApp['status'] = '확인');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusConfirmed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: const Text('확인'),
                ),
              ],
            ),
      );
    }
  }

  Widget _buildAvailableRoomsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '건물별 방 현황',
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.fontPrimary,
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildBuildingSelector(),
            SizedBox(width: 16.w),
            Expanded(
              child: SizedBox(
                height: 48.h,
                child: DropdownButtonFormField<String>(
                  value: _selectedFloorForRooms,
                  hint: const Text('층 선택'),
                  isDense: true,
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 8.h,
                    ),
                  ),
                  items:
                      _getFloorOptionsForBuilding(_selectedBuildingForRooms)
                          .map(
                            (String floor) => DropdownMenuItem<String>(
                              value: floor,
                              child: Text(
                                '${floor}층 (${_getRoomTypeByFloor(floor)})',
                                style: TextStyle(fontSize: 15.sp),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (String? newValue) =>
                          setState(() => _selectedFloorForRooms = newValue),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 24.h),
        _buildRoomGrid(),
      ],
    );
  }

  Widget _buildBuildingSelector() {
    return Wrap(
      spacing: 10.w,
      children:
          _buildingOptions.map((building) {
            final bool isSelected = _selectedBuildingForRooms == building;
            return ElevatedButton(
              onPressed: () {
                setState(() {
                  final previousFloor = _selectedFloorForRooms;
                  _selectedBuildingForRooms = building;
                  final newFloorOptions = _getFloorOptionsForBuilding(building);
                  if (previousFloor != null &&
                      newFloorOptions.contains(previousFloor)) {
                    _selectedFloorForRooms = previousFloor;
                  } else {
                    _selectedFloorForRooms = newFloorOptions.firstOrNull;
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? AppColors.primary : Colors.white,
                foregroundColor: isSelected ? Colors.white : AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                side: isSelected ? null : BorderSide(color: AppColors.border),
                elevation: isSelected ? 2 : 0,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
              ),
              child: Text(
                building == '숭례원'
                    ? '숭례원(남)'
                    : building == '양덕원'
                    ? '양덕원(여)'
                    : building,
                style: TextStyle(fontSize: 14.sp),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildRoomGrid() {
    if (_selectedBuildingForRooms == null || _selectedFloorForRooms == null) {
      return Center(
        child: Text(
          '건물과 층을 선택하여 방 현황을 확인하세요.',
          style: TextStyle(fontSize: 16.sp, color: AppColors.fontSecondary),
        ),
      );
    }
    final int selectedFloorInt = int.parse(_selectedFloorForRooms!);
    final List<Map<String, dynamic>> roomsOnSelectedFloor =
        ApplicationDataService.dormRooms
            .where(
              (room) =>
                  room['building'] == _selectedBuildingForRooms &&
                  room['floor'] == selectedFloorInt,
            )
            .toList();
    roomsOnSelectedFloor.sort((a, b) {
      int roomNumA = int.parse((a['roomNumber'] as String).replaceAll('호', ''));
      int roomNumB = int.parse((b['roomNumber'] as String).replaceAll('호', ''));
      return roomNumA.compareTo(roomNumB);
    });
    if (roomsOnSelectedFloor.isEmpty) {
      return Center(
        child: Text(
          '선택된 층에 방이 없습니다.',
          style: TextStyle(fontSize: 16.sp, color: AppColors.fontSecondary),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: math.max(
          1,
          (MediaQuery.of(context).size.width / 200).floor(),
        ),
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 1.2, // 1.0에서 1.2로 변경하여 카드 높이를 줄임
      ),
      itemCount: roomsOnSelectedFloor.length,
      itemBuilder: (context, index) {
        final room = roomsOnSelectedFloor[index];
        final bool isFull = room['currentOccupancy'] >= room['capacity'];
        final bool isPartiallyFilled = room['currentOccupancy'] > 0 && !isFull;
        final bool isSpecialNonAssignable = room['roomType'] == '방학이용';
        final bool isHighlighted = room['roomNumber'] == _highlightedRoomNumber;
        Color cardColor;
        Color textColor;
        VoidCallback? onTapCallback;
        if (isFull) {
          cardColor = AppColors.roomFull;
          textColor = Colors.white;
          onTapCallback = () => _showOccupancyDetails(context, room);
        } else if (isPartiallyFilled) {
          cardColor = AppColors.roomPartiallyFilled;
          textColor = Colors.white;
          onTapCallback = () => _showOccupancyDetails(context, room);
        } else if (isSpecialNonAssignable) {
          cardColor = Colors.white;
          textColor = AppColors.fontPrimary;
          onTapCallback = null;
        } else {
          cardColor = Colors.white;
          textColor = AppColors.fontPrimary;
          onTapCallback = () => _showStudentsForRoomAssignment(context, room);
        }
        return InkWell(
          borderRadius: BorderRadius.circular(8.r),
          onTap: onTapCallback,
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
              side:
                  isHighlighted
                      ? const BorderSide(
                        color: Color.fromARGB(255, 35, 255, 240),
                        width: 3.0,
                      )
                      : BorderSide(
                        color:
                            (isFull || isPartiallyFilled)
                                ? Colors.transparent
                                : AppColors.border,
                        width: 1.0,
                      ),
            ),
            color: cardColor,
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(8.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min, // 추가: 최소 크기로 설정
                    children: [
                      Expanded(
                        // 추가: Expanded로 감싸서 공간 활용
                        child: Center(
                          child: Text(
                            room['roomNumber'] as String,
                            style: TextStyle(
                              fontSize: 18.sp, // 20.sp에서 18.sp로 축소
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            textAlign: TextAlign.center, // 추가: 텍스트 중앙 정렬
                            overflow: TextOverflow.ellipsis, // 추가: 오버플로우 처리
                          ),
                        ),
                      ),
                      SizedBox(height: 2.h), // 4.h에서 2.h로 축소
                      Text(
                        '(${room['currentOccupancy']}/${room['capacity']})',
                        style: TextStyle(
                          fontSize: 12.sp, // 14.sp에서 12.sp로 축소
                          color: textColor.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center, // 추가: 텍스트 중앙 정렬
                        overflow: TextOverflow.ellipsis, // 추가: 오버플로우 처리
                      ),
                    ],
                  ),
                ),
                if (!isSpecialNonAssignable)
                  Positioned(
                    top: 3.h, // 5.h에서 3.h로 축소
                    right: 3.w, // 5.w에서 3.w로 축소
                    child: Icon(
                      isFull
                          ? Icons.lock
                          : (isPartiallyFilled
                              ? Icons.person_add_alt_1
                              : Icons.check_circle_outline),
                      color:
                          isFull || isPartiallyFilled
                              ? Colors.white.withOpacity(0.8)
                              : AppColors.fontSecondary.withOpacity(0.7),
                      size: 16.sp, // 20.sp에서 16.sp로 축소
                    ),
                  )
                else
                  Positioned(
                    top: 3.h, // 5.h에서 3.h로 축소
                    right: 3.w, // 5.w에서 3.w로 축소
                    child: Icon(
                      Icons.apartment,
                      color: AppColors.fontSecondary.withOpacity(0.7),
                      size: 16.sp, // 20.sp에서 16.sp로 축소
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStudentApplicationDetails() {
    final listItems =
        _currentRightPanelTab == '방배정'
            ? _getGroupedRoomAssignmentList()
            : _filteredApplications;
    if (_selectedIndex == -1 || listItems.isEmpty) {
      return Center(
        child: Text(
          '왼쪽에서 학생을 선택해주세요.',
          style: TextStyle(fontSize: 18.sp, color: AppColors.fontSecondary),
        ),
      );
    }
    final selectedItem = listItems[_selectedIndex];
    final selectedApp =
        (_currentRightPanelTab == '방배정' && selectedItem['isPair'])
            ? selectedItem['student1']
            : (_currentRightPanelTab == '방배정'
                ? selectedItem['student']
                : selectedItem);

    final displayStatus = _getDisplayStatus(selectedApp);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '학생 신청 정보',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.fontPrimary,
              ),
            ),
            Text(
              displayStatus,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(displayStatus),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        // ▼▼▼▼▼ [변경] 지원생구분 필드 추가 ▼▼▼▼▼
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '학년도',
              selectedApp['academicYear'] ?? 'N/A',
              isGreyed: true,
            ),
            _buildInfoFieldWithLabelAbove(
              '학기',
              selectedApp['semester'] ?? 'N/A',
              isGreyed: true,
            ),
            _buildInfoFieldWithLabelAbove(
              '모집구분',
              selectedApp['recruitmentType'] ?? 'N/A',
              isGreyed: true,
            ),
            _buildInfoFieldWithLabelAbove(
              '지원생구분', // 추가된 필드
              selectedApp['applicantType'] ?? 'N/A', // applicantType 키 사용
              isGreyed: true,
            ),
          ],
        ),
        // ▲▲▲▲▲ [변경] 지원생구분 필드 추가 ▲▲▲▲▲
        SizedBox(height: 8.h),
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '성명',
              selectedApp['studentName'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '학번',
              selectedApp['studentId'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '학과',
              selectedApp['department'] ?? 'N/A',
            ),
          ],
        ),
        SizedBox(height: 8.h),
        _buildInfoFieldContainer(
          children: [
            _buildInfoFieldWithLabelAbove(
              '건물',
              selectedApp['dormBuilding'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove('성별', selectedApp['gender'] ?? 'N/A'),
            _buildInfoFieldWithLabelAbove(
              '흡연 여부',
              selectedApp['smokingStatus'] ?? 'N/A',
            ),
            _buildInfoFieldWithLabelAbove(
              '방 타입',
              selectedApp['roomType'] ?? 'N/A',
            ),
          ],
        ),
        SizedBox(height: 24.h),
        _buildSectionTitle('제출 서류'),
        SizedBox(height: 8.h),
        _buildDocumentList(selectedApp),
        SizedBox(height: 24.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '관리자 메모',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.fontPrimary,
              ),
            ),
            if (!_isEditMode)
              TextButton(
                onPressed: () => setState(() => _isEditMode = true),
                child: const Text('작성'),
              ),
          ],
        ),
        SizedBox(height: 8.h),
        _buildMemoField(
          _adminMemoController,
          hintText: '메모를 입력하려면 \'수정\' 또는 \'작성\' 버튼을 눌러주세요.',
          enabled: _isEditMode,
        ),
        SizedBox(height: 32.h),
        _buildBottomActionArea(),
      ],
    );
  }

  // 각 섹션의 타이틀을 빌드하는 함수 (RoomStatusPage에서 복사)
  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.fontPrimary,
          ),
        ),
        SizedBox(height: 8.h),
        Divider(color: AppColors.border, thickness: 1.h),
      ],
    );
  }

  // 라벨이 필드 위에 걸쳐지는 TextFormField 형태의 정보 필드를 빌드하는 함수 (RoomStatusPage에서 복사)
  Widget _buildInfoFieldWithLabelAbove(
    String label,
    String value, {
    bool isGreyed = false,
  }) {
    final TextEditingController _tempController = TextEditingController(
      text: value,
    );

    return SizedBox(
      height: 38.h, // 고정 높이 적용
      child: TextFormField(
        controller: _tempController,
        readOnly: true, // 수정 불가능하게 설정
        style: TextStyle(
          fontSize: 13.sp, // 값 폰트 크기
          color: AppColors.fontPrimary,
          fontWeight: FontWeight.normal,
        ),
        decoration: InputDecoration(
          labelText: label, // 라벨 텍스트
          labelStyle: TextStyle(
            fontSize: 10.sp, // 라벨 폰트 크기
            color: AppColors.fontSecondary,
          ),
          floatingLabelBehavior:
              FloatingLabelBehavior.always, // 라벨을 항상 위로 띄웁니다.
          contentPadding: EdgeInsets.fromLTRB(
            10.w,
            15.h,
            10.w,
            5.h,
          ), // 내부 패딩 조정 (상단 패딩 줄여 라벨 공간 확보)
          filled: isGreyed, // 회색 배경 여부
          fillColor: isGreyed ? AppColors.disabledBackground : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(color: AppColors.border, width: 1.0),
          ),
          enabledBorder: OutlineInputBorder(
            // readOnly일 때의 테두리
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(color: AppColors.border, width: 1.0),
          ),
          focusedBorder: OutlineInputBorder(
            // 포커스 시 테두리 (readOnly여도 포커스 스타일 적용 가능)
            borderRadius: BorderRadius.circular(6.r),
            borderSide: BorderSide(
              color: AppColors.primary,
              width: 1.0,
            ), // 클릭 시 색상 변경
          ),
        ),
      ),
    );
  }

  // 여러 정보 필드를 가로로 배열하는 Row (RoomStatusPage에서 복사)
  Widget _buildInfoFieldContainer({required List<Widget> children}) {
    List<Widget> rowChildren = [];
    for (int i = 0; i < children.length; i++) {
      rowChildren.add(Expanded(child: children[i]));
      if (i < children.length - 1) {
        rowChildren.add(SizedBox(width: 8.w));
      }
    }
    return Row(children: rowChildren);
  }

  // 제출 서류 목록을 빌드하는 함수 (Table 형태로 변경, RoomStatusPage에서 복사 및 수정)
  Widget _buildDocumentList(Map<String, dynamic> studentApp) {
    final List<dynamic> documents = studentApp['documents'] ?? [];

    // 디버깅: 서류 데이터 확인
    print('🔍 _buildDocumentList 호출됨');
    print('  - 학생: ${studentApp['studentName']}');
    print('  - documents 필드: ${studentApp['documents']}');
    print('  - documents 개수: ${documents.length}');

    if (documents.isEmpty) {
      print('  - 서류가 비어있음');
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '제출된 서류가 없습니다.',
          style: TextStyle(fontSize: 14.sp, color: AppColors.fontSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }

    print('  - 서류 목록 테이블 생성 중...');
    return Table(
      border: TableBorder.all(color: AppColors.border),
      columnWidths: const {
        0: FixedColumnWidth(40.0), // 체크박스
        1: FlexColumnWidth(1), // 서류명
        2: FlexColumnWidth(1.5), // 파일명
        3: FixedColumnWidth(80.0), // 상태
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppColors.disabledBackground),
          children: [
            _buildTableCell('✔', isHeader: true),
            _buildTableCell('서류명', isHeader: true),
            _buildTableCell('첨부파일명', isHeader: true),
            _buildTableCell('상태', isHeader: true),
          ],
        ),
        ...documents.map((doc) {
          final bool isVerified = doc['isVerified'] == true;
          print('  - 서류 처리 중: ${doc['fileName']}, 확인여부: $isVerified');
          return TableRow(
            children: [
              // 체크박스 (onChanged를 null로 하여 ReadOnly로 설정)
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Center(
                  child: Checkbox(
                    value: isVerified,
                    onChanged: null, // ReadOnly로 설정
                    activeColor: AppColors.primary, // 체크된 상태의 색상
                  ),
                ),
              ),
              _buildTableCell(doc['name'] ?? 'N/A'),
              _buildTableCell(doc['fileName'] ?? 'N/A'),
              // 확인 상태에 따라 다른 UI 표시
              TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: GestureDetector(
                  onTap: () => _showDocumentPreviewDialog(studentApp, doc),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isVerified
                              ? AppColors.statusConfirmed.withOpacity(0.1)
                              : AppColors.statusWaiting.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color:
                            isVerified
                                ? AppColors.statusConfirmed
                                : AppColors.statusWaiting,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isVerified ? Icons.check_circle : Icons.visibility,
                          size: 12.sp,
                          color:
                              isVerified
                                  ? AppColors.statusConfirmed
                                  : AppColors.statusWaiting,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          isVerified ? '확인완료' : '확인',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color:
                                isVerified
                                    ? AppColors.statusConfirmed
                                    : AppColors.statusWaiting,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  // 테이블 셀을 빌드하는 함수 (RoomStatusPage에서 복사)
  Widget _buildTableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isHeader ? 13.sp : 12.sp,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? AppColors.fontPrimary : AppColors.fontSecondary,
        ),
      ),
    );
  }

  // _showDocumentPreviewDialog 함수를 _AdInPageState 클래스 내부에 정의
  Future<void> _showDocumentPreviewDialog(
    Map<String, dynamic> studentApp,
    Map<String, dynamic> document,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          title: Text(
            '${document['name']} 미리보기',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
              color: AppColors.fontPrimary,
            ),
          ),
          content: SizedBox(
            width: 500.w,
            height: 400.h,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 파일 정보
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.disabledBackground,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '파일명: ${document['fileName'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          '파일 형식: ${document['fileType'] ?? 'N/A'}',
                          style: TextStyle(fontSize: 13.sp),
                        ),
                        if (document['uploadedAt'] != null)
                          Text(
                            '업로드 시간: ${document['uploadedAt']}',
                            style: TextStyle(fontSize: 13.sp),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // 파일 미리보기 영역
                  Container(
                    width: double.infinity,
                    height: 250.h,
                    decoration: BoxDecoration(
                      color: AppColors.disabledBackground,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: AppColors.border),
                    ),
                    child:
                        document['fileUrl'] != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: _buildFilePreview(document),
                            )
                            : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.description,
                                    size: 48.sp,
                                    color: AppColors.fontSecondary,
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    '미리보기를 사용할 수 없습니다',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: AppColors.fontSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),

                  SizedBox(height: 16.h),

                  // 파일 다운로드 버튼
                  if (document['fileUrl'] != null)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadFile(document['fileUrl']),
                        icon: Icon(Icons.download, size: 16.sp),
                        label: Text('파일 다운로드'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                '닫기',
                style: TextStyle(color: AppColors.fontSecondary),
              ),
            ),
            // 이미 확인된 문서인지 여부에 따라 버튼 표시 변경
            if (document['isVerified'] == true)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: AppColors.statusConfirmed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: AppColors.statusConfirmed),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16.sp,
                      color: AppColors.statusConfirmed,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '확인완료',
                      style: TextStyle(
                        color: AppColors.statusConfirmed,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _verifyDocument(studentApp, document);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusConfirmed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: const Text('확인'),
              ),
          ],
        );
      },
    );
  }

  // 파일 미리보기 위젯
  Widget _buildFilePreview(Map<String, dynamic> document) {
    final String? fileType = document['fileType']?.toLowerCase();
    final String? fileUrl = document['fileUrl'];

    if (fileUrl == null) {
      return Center(child: Text('파일 URL이 없습니다.'));
    }

    // 이미지 파일인 경우
    if (fileType != null &&
        (fileType.contains('jpg') ||
            fileType.contains('jpeg') ||
            fileType.contains('png') ||
            fileType.contains('gif'))) {
      return Image.network(
        'http://localhost:5050$fileUrl',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48.sp, color: Colors.red),
                SizedBox(height: 8.h),
                Text('이미지를 불러올 수 없습니다'),
              ],
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value:
                  loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
            ),
          );
        },
      );
    }

    // PDF나 기타 파일인 경우
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            fileType?.contains('pdf') == true
                ? Icons.picture_as_pdf
                : Icons.description,
            size: 64.sp,
            color: AppColors.primary,
          ),
          SizedBox(height: 16.h),
          Text(
            '${document['fileName'] ?? '파일'}',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            '파일을 다운로드하여 확인하세요',
            style: TextStyle(fontSize: 14.sp, color: AppColors.fontSecondary),
          ),
        ],
      ),
    );
  }

  // 파일 다운로드 함수
  void _downloadFile(String fileUrl) {
    // 웹에서는 새 탭으로 파일 열기
    // html.window.open('http://localhost:5050$fileUrl', '_blank');

    // 임시로 URL을 클립보드에 복사
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('파일 URL: http://localhost:5050$fileUrl'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // 서류 확인 API 호출
  Future<void> _verifyDocument(
    Map<String, dynamic> studentApp,
    Map<String, dynamic> document,
  ) async {
    try {
      final response = await http.put(
        Uri.parse(
          'http://localhost:5050/api/admin/checkin/document/${studentApp['checkin_id'] ?? studentApp['id']}/verify',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'fileName': document['fileName'],
          'isVerified': true,
        }),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        setState(() {
          document['isVerified'] = true;

          // 모든 서류가 확인되었으면 학생 상태도 업데이트
          if (result['allVerified'] == true) {
            studentApp['status'] = '확인';
            _checkAndUpdateStudentStatus(studentApp, showPopup: true);
          }
        });

        // 이미 확인된 문서인지 여부에 따라 다른 메시지 표시
        String message =
            document['isVerified'] == true ? '이미 확인된 서류입니다.' : '서류가 확인되었습니다.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.statusConfirmed,
          ),
        );
      } else {
        throw Exception('서류 확인 실패: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('서류 확인 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMemoField(
    TextEditingController controller, {
    String hintText = '',
    bool enabled = true,
  }) {
    return SizedBox(
      height: 100.h,
      child: TextField(
        controller: controller,
        enabled: enabled,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(fontSize: 16.sp, color: AppColors.fontPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontSize: 16.sp,
            color: AppColors.fontSecondary.withOpacity(0.6),
          ),
          contentPadding: EdgeInsets.all(12.w),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: AppColors.primary),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.r),
            borderSide: BorderSide(color: AppColors.border),
          ),
          filled: !enabled,
          fillColor: AppColors.disabledBackground,
        ),
      ),
    );
  }

  Widget _buildBottomActionArea() {
    final listItems =
        _currentRightPanelTab == '방배정'
            ? _getGroupedRoomAssignmentList()
            : _filteredApplications;
    if (_selectedIndex < 0 || listItems.isEmpty) return const SizedBox.shrink();
    final selectedItem = listItems[_selectedIndex];
    final selectedApp =
        (_currentRightPanelTab == '방배정' && selectedItem['isPair'])
            ? selectedItem['student1']
            : (_currentRightPanelTab == '방배정'
                ? selectedItem['student']
                : selectedItem);
    final bool isAssigned = selectedApp['status'] == '배정완료';
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_currentRightPanelTab == '방배정' && isAssigned)
          OutlinedButton(
            onPressed: () => _cancelAssignment(selectedApp),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.border),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
              textStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: Text(
              '배정 취소',
              style: TextStyle(color: AppColors.fontSecondary),
            ),
          ),
        SizedBox(width: 12.w),
        ElevatedButton(
          onPressed: () {
            if (_isEditMode) {
              // 여기에 메모 저장 로직 추가
              setState(() {
                selectedApp['adminMemo'] = _adminMemoController.text;
                _isEditMode = false;
              });
            } else {
              setState(() => _isEditMode = true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 14.h),
            textStyle: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: Text(_isEditMode ? '저장' : '수정'),
        ),
      ],
    );
  }

  void _showOccupancyDetails(
    BuildContext parentContext,
    Map<String, dynamic> room,
  ) {
    final List<Map<String, dynamic>> occupants =
        ApplicationDataService.applications
            .where(
              (app) =>
                  app['assignedBuilding'] == room['building'] &&
                  app['assignedRoomNumber'] == room['roomNumber'],
            )
            .toList();
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${room['building']} ${room['roomNumber']} 배정 현황',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.sp,
                  color: AppColors.fontPrimary,
                ),
              ),
              if (occupants.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    '학생 카드를 클릭하면 학생관리에서 상세 정보를 확인할 수 있습니다.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.fontSecondary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: 380.w,
            child:
                occupants.isEmpty
                    ? Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.h),
                        child: Text(
                          '배정된 학생이 없습니다.',
                          style: TextStyle(
                            color: AppColors.fontSecondary,
                            fontSize: 15.sp,
                          ),
                        ),
                      ),
                    )
                    : ListView.builder(
                      shrinkWrap: true,
                      itemCount: occupants.length,
                      itemBuilder: (context, index) {
                        final student = occupants[index];
                        return InkWell(
                          onTap: () {
                            // 팝업창 닫기
                            Navigator.of(dialogContext).pop();

                            // 학생관리 페이지로 이동
                            final int adRoomStatusPageIndex = adHomePageKey
                                .currentState!
                                .getMenuIndexByTitle('학생 관리');
                            adHomePageKey.currentState?.selectMenuByIndex(
                              adRoomStatusPageIndex,
                              arguments: {
                                'studentId': student['studentId'],
                                'initialTab': '학생 조회',
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(8.r),
                          child: Container(
                            margin: EdgeInsets.only(bottom: 8.h),
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8.r),
                              // 호버 효과를 위한 색상 추가
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${student['studentName']} (${student['studentId']})',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.fontPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text.rich(
                                        TextSpan(
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            color: AppColors.fontSecondary,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: student['gender'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    student['gender'] == '남'
                                                        ? AppColors.primary
                                                        : AppColors
                                                            .genderFemale,
                                              ),
                                            ),
                                            TextSpan(
                                              text:
                                                  ' | ${student['department']} | ${student['roomType']} | ${student['smokingStatus']}',
                                            ),
                                          ],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                // 클릭 가능함을 나타내는 아이콘 추가
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16.sp,
                                  color: AppColors.fontSecondary.withOpacity(
                                    0.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
          actionsPadding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 16.h),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  void _showStudentsForRoomAssignment(
    BuildContext parentContext,
    Map<String, dynamic> room,
  ) {
    if (room['roomType'] == '방학이용') {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        const SnackBar(content: Text('해당 호실은 이 페이지에서 직접 배정할 수 없습니다.')),
      );
      return;
    }
    final Set<String> selectedStudentIds = {};
    final List<Map<String, dynamic>> eligibleStudents =
        ApplicationDataService.applications
            .where(
              (app) =>
                  app['status'] == '확인' &&
                  app['assignedRoomNumber'] == null &&
                  app['dormBuilding'] == room['building'] &&
                  app['roomType'] == room['roomType'] &&
                  app['gender'] == room['gender'],
            )
            .toList();
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            final int remainingCapacity =
                room['capacity'] - room['currentOccupancy'];
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
              title: Text(
                '${room['building']} ${room['roomNumber']}에 학생 배정',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                  color: AppColors.fontPrimary,
                ),
              ),
              content: SizedBox(
                width: 380.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusAssigned.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: AppColors.statusAssigned),
                      ),
                      child: Text(
                        '남은 정원: $remainingCapacity명',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    eligibleStudents.isEmpty
                        ? Expanded(
                          child: Center(
                            child: Text(
                              '배정 가능한 학생이 없습니다. (\'확인\' 상태 확인)',
                              style: TextStyle(
                                color: AppColors.fontSecondary,
                                fontSize: 15.sp,
                              ),
                            ),
                          ),
                        )
                        : Flexible(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 300.h),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: eligibleStudents.length,
                              itemBuilder: (context, index) {
                                final student = eligibleStudents[index];
                                return CheckboxListTile(
                                  title: Text(
                                    '${student['studentName']} (${student['studentId']})',
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      color: AppColors.fontPrimary,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${student['dormBuilding']} ${student['roomType']}',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: AppColors.fontSecondary,
                                    ),
                                  ),
                                  value: selectedStudentIds.contains(
                                    student['id'],
                                  ),
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        if (selectedStudentIds.length <
                                            remainingCapacity) {
                                          selectedStudentIds.add(student['id']);
                                        } else {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '방 정원을 초과하여 선택할 수 없습니다.',
                                              ),
                                            ),
                                          );
                                        }
                                      } else {
                                        selectedStudentIds.remove(
                                          student['id'],
                                        );
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: AppColors.fontSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedStudentIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('배정할 학생을 선택해주세요.')),
                      );
                      return;
                    }
                    if (selectedStudentIds.length > remainingCapacity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('선택된 학생 수가 방 정원을 초과합니다.')),
                      );
                      return;
                    }
                    for (var studentId in selectedStudentIds) {
                      final studentToAssign = ApplicationDataService
                          .applications
                          .firstWhere((app) => app['id'] == studentId);
                      _assignStudentToRoom(studentToAssign, room);
                    }
                    ApplicationDataService.updateRoomOccupancy();
                    this.setState(() => _updateSelection());
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text('선택한 ${selectedStudentIds.length}명 배정'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
