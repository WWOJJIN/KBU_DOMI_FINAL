import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../student_provider.dart';
import 'package:kbu_domi/env.dart';

class RoommatePage extends StatefulWidget {
  const RoommatePage({super.key});

  @override
  State<RoommatePage> createState() => _RoommatePageState();
}

class _RoommatePageState extends State<RoommatePage> {
  // 컨트롤러들
  final TextEditingController roommateIdController = TextEditingController();
  final TextEditingController roommateNameController = TextEditingController();

  // 데이터 리스트
  List<Map<String, dynamic>> myRequestedRoommates = [];
  List<Map<String, dynamic>> requestedMeRoommates = [];

  // 로딩 상태
  bool _isLoading = false;

  // ===== 공지사항 관련 변수 추가 =====
  String _noticeContent = '룸메이트 신청은 학기별 1회만 가능합니다. 학번(7자리)과 이름을 정확히 입력해주세요.';

  Map<String, dynamic>? _adInPageArguments;

  @override
  void initState() {
    super.initState();
    _loadRoommateData();
    _loadNotice(); // 공지사항 로드
  }

  @override
  void dispose() {
    roommateIdController.dispose();
    roommateNameController.dispose();
    super.dispose();
  }

  // 룸메이트 데이터 로드
  Future<void> _loadRoommateData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final student = Provider.of<StudentProvider>(context, listen: false);
      final studentId = student.studentId;

      print('🔍 웹 룸메이트 - _loadRoommateData 호출, studentId: $studentId');

      if (studentId == null) {
        print('❌ 웹 룸메이트 - studentId가 null입니다!');
        return;
      }

      final myReqUrl = Uri.parse(
        '$apiBase/api/roommate/my-requests?student_id=$studentId',
      );
      final reqMeUrl = Uri.parse(
        '$apiBase/api/roommate/requests-for-me?student_id=$studentId',
      );

      print('🔍 웹 룸메이트 - 내 신청 API 호출: $myReqUrl');
      print('🔍 웹 룸메이트 - 나를 신청한 API 호출: $reqMeUrl');

      final myRes = await http.get(myReqUrl);
      final meRes = await http.get(reqMeUrl);

      print('🔍 웹 룸메이트 - 내 신청 API 응답: ${myRes.statusCode}');
      print('🔍 웹 룸메이트 - 내 신청 응답 데이터: ${myRes.body}');
      print('🔍 웹 룸메이트 - 나를 신청한 API 응답: ${meRes.statusCode}');
      print('🔍 웹 룸메이트 - 나를 신청한 응답 데이터: ${meRes.body}');

      if (mounted) {
        if (myRes.statusCode == 200) {
          final dynamic myData = json.decode(myRes.body);
          print('🔍 웹 룸메이트 - 내 신청 파싱된 데이터: $myData');

          List<Map<String, dynamic>> myList = [];
          if (myData is List) {
            myList = List<Map<String, dynamic>>.from(myData);
          } else if (myData is Map && myData.containsKey('requests')) {
            myList = List<Map<String, dynamic>>.from(myData['requests']);
          }

          // 상태값 번역
          myRequestedRoommates =
              myList.map((item) {
                return {
                  'status': _translateStatus(item['status'] ?? 'pending'),
                  'roommate_id': item['requested_id']?.toString() ?? '',
                  'roommate_name': item['roommate_name'] ?? '',
                  'request_date': item['request_date'] ?? '',
                  'id': item['id'],
                };
              }).toList();

          print('✅ 웹 룸메이트 - 내 신청 데이터 처리 완료: ${myRequestedRoommates.length}건');
        }

        if (meRes.statusCode == 200) {
          final dynamic meData = json.decode(meRes.body);
          print('🔍 웹 룸메이트 - 나를 신청한 파싱된 데이터: $meData');

          List<Map<String, dynamic>> meList = [];
          if (meData is List) {
            meList = List<Map<String, dynamic>>.from(meData);
          } else if (meData is Map && meData.containsKey('requests')) {
            meList = List<Map<String, dynamic>>.from(meData['requests']);
          }

          // 상태값 번역
          requestedMeRoommates =
              meList.map((item) {
                return {
                  'status': _translateStatus(item['status'] ?? 'pending'),
                  'requester_id': item['requester_id']?.toString() ?? '',
                  'requester_name': item['requester_name'] ?? '',
                  'request_date': item['request_date'] ?? '',
                  'id': item['id'],
                };
              }).toList();

          print('✅ 웹 룸메이트 - 나를 신청한 데이터 처리 완료: ${requestedMeRoommates.length}건');
        }
      }
    } catch (e) {
      print('❌ 웹 룸메이트 - 룸메이트 목록을 가져오는 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('데이터를 불러오는 중 오류가 발생했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===== 공지사항 로드 함수 =====
  Future<void> _loadNotice() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/notice?category=roommate'),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _noticeContent =
              data['content'] ??
              '룸메이트 신청은 학기별 1회만 가능합니다. 학번(7자리)과 이름을 정확히 입력해주세요.';
        });
        print('룸메이트 공지사항 로드 완료: [32m[1m[4m$_noticeContent[0m');
      } else {
        print('룸메이트 공지사항 로딩 실패: [31m${response.statusCode}[0m');
      }
    } catch (e) {
      print('룸메이트 공지사항 로딩 중 에러: $e');
    }
  }

  // 상태값 한국어 번역
  String _translateStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '대기';
      case 'accepted':
      case 'confirmed':
        return '확정';
      case 'rejected':
        return '반료';
      default:
        return status;
    }
  }

  // 룸메이트 신청
  Future<void> _submitRoommate() async {
    final student = Provider.of<StudentProvider>(context, listen: false);
    final data = {
      'requester_id': student.studentId ?? '',
      'requester_name': student.name ?? '',
      'requested_id': roommateIdController.text,
      'requested_name': roommateNameController.text,
    };

    print('🔍 웹 룸메이트 - _submitRoommate 호출');
    print('🔍 웹 룸메이트 - 신청 데이터: $data');

    if (data['requested_id']!.isEmpty || data['requested_name']!.isEmpty) {
      print('❌ 웹 룸메이트 - 입력 데이터 부족');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('학번과 이름을 모두 입력해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      print('🔍 웹 룸메이트 - API 호출 시도');
      final response = await http.post(
        Uri.parse('$apiBase/api/roommate/apply'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );

      print('🔍 웹 룸메이트 - API 응답: ${response.statusCode}');
      print('🔍 웹 룸메이트 - 응답 데이터: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        print('✅ 웹 룸메이트 - 신청 성공');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('룸메이트 신청 완료!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadRoommateData();
        roommateIdController.clear();
        roommateNameController.clear();
      } else {
        print('❌ 웹 룸메이트 - 신청 실패: ${response.statusCode}');
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('신청 실패: ${errorData['error'] ?? '알 수 없는 오류'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ 웹 룸메이트 - 신청 중 오류: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height, // 🔑 핵심: 명확한 높이 제약
      width: MediaQuery.of(context).size.width, // 🔑 핵심: 명확한 너비 제약
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.white,
          centerTitle: false,
          automaticallyImplyLeading: false,
          // 외박신청과 동일한 메인타이틀 스타일 적용
          title: _mainTitle('룸메이트 신청'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStudentInfoSection(), // 상단 기본정보
              const Divider(thickness: 1),
              _buildNoticeCard(), // 공지사항 카드 추가
              const SizedBox(height: 24),
              _buildRoommateApplicationCard(), // 룸메이트 신청 카드 (목록 포함)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfoSection() {
    final student = Provider.of<StudentProvider>(context, listen: false);
    const year = "2024";
    const semester = "1학기";
    final studentId = student.studentId ?? "정보 없음";
    final studentName = student.name ?? "정보 없음";

    return Row(
      children: [
        Expanded(child: _infoField("년도", year)),
        const SizedBox(width: 12),
        Expanded(child: _infoField("학기", semester)),
        const SizedBox(width: 12),
        Expanded(child: _infoField("학번", studentId)),
        const SizedBox(width: 12),
        Expanded(child: _infoField("이름", studentName)),
      ],
    );
  }

  Widget _infoField(String label, String value) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        initialValue: value,
        enabled: false,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade700),
          filled: true,
          fillColor: Colors.grey[100],
          disabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.black),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRoommateApplicationCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 룸메이트 신청 입력 필드와 버튼을 한 줄에 배치 (flex 속성 사용)
          Row(
            children: [
              // 룸메이트 학번 입력 필드 (flex5)
              Expanded(
                flex: 5,
                child: _textField(
                  '룸메이트 학번',
                  roommateIdController,
                  numberOnly: true,
                ),
              ),
              const SizedBox(width: 10),
              // 룸메이트 이름 입력 필드 (flex5)
              Expanded(
                flex: 5,
                child: _textField('룸메이트 이름', roommateNameController),
              ),
              const SizedBox(width: 10),
              // 룸메이트 신청 버튼 (flex1)
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  style: _smallNavyButtonStyle(),
                  onPressed: _submitRoommate,
                  child: const Text('룸메이트 신청'),
                ),
              ),
            ],
          ),
          Divider(height: 22, thickness: 1),
          // 룸메이트 목록 섹션 (좌우 배치)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 내가 신청한 룸메이트 목록 (왼쪽)
              Expanded(
                child: _buildListSection(
                  '내가 신청한 룸메이트 목록',
                  myRequestedRoommates,
                  isMyRequest: true,
                ),
              ),
              const SizedBox(width: 20),
              // 나를 신청한 룸메이트 목록 (오른쪽)
              Expanded(
                child: _buildListSection(
                  '나를 신청한 룸메이트 목록',
                  requestedMeRoommates,
                  isMyRequest: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListSection(
    String title,
    List<Map<String, dynamic>> list, {
    required bool isMyRequest,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목을 카드 안으로 이동
        _buildListBoxWithTitle(title, list, isMyRequest: isMyRequest),
      ],
    );
  }

  // 제목이 포함된 리스트 박스 위젯
  Widget _buildListBoxWithTitle(
    String title,
    List<Map<String, dynamic>> list, {
    required bool isMyRequest,
  }) {
    final List<String> headers =
        isMyRequest
            ? ['상태', '순번', '학번', '성명', '신청일자', '신청취소']
            : ['상태', '순번', '학번', '성명', '신청일자', '동의', '동의취소'];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 제목 (카드 안에 소제목으로 배치)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          ),
          // 리스트 내용
          Container(
            height: 400,
            padding: const EdgeInsets.all(16),
            child:
                list.isEmpty
                    ? const Center(
                      child: Text(
                        '데이터가 없습니다.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                    : Column(
                      children: [
                        // 헤더 (고정)
                        SizedBox(height: 40, child: _buildHeaderRow(headers)),
                        const Divider(height: 1),
                        // 리스트 (스크롤 가능)
                        Expanded(
                          child: ListView.separated(
                            itemCount: list.length,
                            separatorBuilder:
                                (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = list[index];
                              return SizedBox(
                                height: 50,
                                child: _buildDataRow(item, index, isMyRequest),
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

  Widget _buildHeaderRow(List<String> headers) {
    return Row(
      children:
          headers
              .map(
                (header) => Expanded(
                  flex:
                      (header == '학번' || header == '성명' || header == '신청일자')
                          ? 2
                          : 1,
                  child: Center(
                    child: Text(
                      header,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildDataRow(Map<String, dynamic> item, int index, bool isMyRequest) {
    Color statusColor;
    String statusText = item['status'] ?? '대기';
    switch (statusText) {
      case '확정':
        statusColor = Colors.green.shade600;
        break;
      case '대기':
        statusColor = Colors.orange.shade700;
        break;
      case '반료':
        statusColor = Colors.red.shade600;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Expanded(flex: 1, child: Center(child: Text((index + 1).toString()))),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                isMyRequest
                    ? item['roommate_id'] ?? ''
                    : item['requester_id'] ?? '',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                isMyRequest
                    ? item['roommate_name'] ?? ''
                    : item['requester_name'] ?? '',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(child: Text(item['request_date'] ?? '')),
          ),
          // 작업 버튼들
          if (isMyRequest) ...[
            Expanded(
              flex: 1,
              child: Center(
                child:
                    statusText == '대기'
                        ? TextButton(
                          onPressed: () => _cancelRequest(item['id']),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
            ),
          ] else ...[
            Expanded(
              flex: 1,
              child: Center(
                child:
                    statusText == '대기'
                        ? TextButton(
                          onPressed: () => _acceptRequest(item['id']),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            '동의',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
            ),
            Expanded(
              flex: 1,
              child: Center(
                child:
                    statusText == '대기'
                        ? TextButton(
                          onPressed: () => _rejectRequest(item['id']),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            '동의취소',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle _smallNavyButtonStyle({bool isDestructive = false}) {
    return ElevatedButton.styleFrom(
      backgroundColor:
          isDestructive ? Colors.red.shade700 : const Color(0xFF0A2463),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  Future<void> _confirmDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('신청취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('확인', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
    if (result == true) onConfirm();
  }

  Future<void> _cancelRequest(int requestId) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBase/api/roommate/requests/$requestId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          myRequestedRoommates.removeWhere((item) => item['id'] == requestId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('신청이 취소되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('취소 실패: ${errorData['error'] ?? '알 수 없는 오류'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _acceptRequest(int requestId) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBase/api/roommate/requests/$requestId/accept'),
      );

      if (response.statusCode == 200) {
        setState(() {
          myRequestedRoommates.firstWhere(
                (item) => item['id'] == requestId,
              )['status'] =
              '확정';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('룸메이트 신청에 동의했습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동의 실패: ${errorData['error'] ?? '알 수 없는 오류'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectRequest(int requestId) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBase/api/roommate/requests/$requestId/reject'),
      );

      if (response.statusCode == 200) {
        setState(() {
          requestedMeRoommates.removeWhere((item) => item['id'] == requestId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('룸메이트 신청을 반료했습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('반료 실패: ${errorData['error'] ?? '알 수 없는 오류'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류 발생: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _textField(
    String label,
    TextEditingController controller, {
    bool numberOnly = false,
  }) {
    const Color focusedPurpleColor = Color(0xFF6A5ACD);

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: SizedBox(
        height: 55,
        child: TextFormField(
          controller: controller,
          keyboardType: numberOnly ? TextInputType.number : TextInputType.text,
          inputFormatters:
              numberOnly
                  ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ]
                  : [],
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue[900]!),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  // ===== 외박신청과 동일한 메인타이틀 위젯 =====
  Widget _mainTitle(String title) => Row(
    children: [
      Container(
        width: 4,
        height: 24,
        color: Colors.blue[900],
        margin: const EdgeInsets.only(right: 8),
      ),
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
      ),
    ],
  );

  // ===== 공지사항 카드 위젯 =====
  Widget _buildNoticeCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: Colors.blue[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공지사항',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _noticeContent,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
