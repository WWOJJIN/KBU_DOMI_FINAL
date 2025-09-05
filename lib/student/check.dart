import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'first.dart'; // 홈(처음화면)
import 'domi_portal/in.dart'; // 입실신청
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdmitPage extends StatefulWidget {
  const AdmitPage({super.key});

  @override
  State<AdmitPage> createState() => _AdmitPageState();
}

class _AdmitPageState extends State<AdmitPage> {
  int userType = 0;
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _birthController = TextEditingController();
  final _examNumController = TextEditingController();
  final _pwController = TextEditingController();

  final String yearSemester = '2024학년도 2학기';

  bool _showResult = false;
  Map<String, String> _result = {};
  String _resultStatus = ''; // "합격" 또는 "불합격"

  // 높이 동기화 위한 key!
  final GlobalKey _resultKey = GlobalKey();
  double _boxHeight = 0;

  @override
  Widget build(BuildContext context) {
    Color kbuBlue = const Color(0xFF00408B);
    Color kbuPink = const Color(0xFFEC008C);

    // 결과 박스 높이 계산 (처음에는 0 → 조회 후 반영)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showResult && _resultKey.currentContext != null) {
        final box = _resultKey.currentContext!.findRenderObject() as RenderBox;
        if (box.size.height != _boxHeight) {
          setState(() {
            _boxHeight = box.size.height;
          });
        }
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 2.h),
              Image.asset(
                'imgs/bbogi_and_friend.png',
                height: 110.h,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 30.h),
              _showResult
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _noticeBox(height: _boxHeight),
                      SizedBox(width: 44.w),
                      _resultBox(context),
                    ],
                  )
                  : _inputCard(kbuBlue, kbuPink),
              SizedBox(height: 40.h),
              Image.asset('imgs/logo.png', height: 52.h, fit: BoxFit.contain),
              SizedBox(height: 14.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputCard(Color kbuBlue, Color kbuPink) {
    return Container(
      width: 420.w,
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 34.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '입주 ',
                    style: TextStyle(
                      fontSize: 32.sp,
                      color: kbuBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: '합격자',
                    style: TextStyle(
                      fontSize: 32.sp,
                      color: kbuPink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' 조회',
                    style: TextStyle(
                      fontSize: 32.sp,
                      color: kbuBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 26.h),
          Row(
            children: [
              Icon(Icons.calendar_today, color: kbuBlue, size: 22.sp),
              SizedBox(width: 8.w),
              Text(
                yearSemester,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: kbuBlue,
                ),
              ),
              const Spacer(),
              _customToggle(userType, (type) {
                setState(() {
                  userType = type;
                  _idController.clear();
                  _nameController.clear();
                  _birthController.clear();
                  _examNumController.clear();
                });
              }),
            ],
          ),
          SizedBox(height: 28.h),
          _inputSection(userType),
          SizedBox(height: 30.h),
          _rectButton(
            text: '조회',
            icon: Icons.search,
            color: kbuBlue,
            onTap: _onSearch,
          ),
        ],
      ),
    );
  }

  Widget _inputSection(int userType) {
    return Column(
      children: [
        if (userType == 0) ...[
          _labeledInput(
            '학번',
            '학번 입력',
            controller: _idController,
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 18.h),
          _labeledInput(
            '비밀번호',
            '비밀번호 입력',
            controller: _pwController,
            obscureText: true,
          ),
          SizedBox(height: 18.h),
          _labeledInput('이름', '이름 입력', controller: _nameController),
        ] else ...[
          _labeledInput('이름', '이름 입력', controller: _nameController),
          SizedBox(height: 18.h),
          _labeledInput(
            '생년월일',
            '6자리 (YYMMDD)',
            controller: _birthController,
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 18.h),
          _labeledInput(
            '수험번호',
            '수험번호 입력',
            controller: _examNumController,
            keyboardType: TextInputType.number,
          ),
        ],
      ],
    );
  }

  Widget _labeledInput(
    String label,
    String hint, {
    TextEditingController? controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    Color kbuBlue = const Color(0xFF00408B);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 65.w,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: kbuBlue,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 44.h,
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: TextStyle(fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[400],
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 16.h,
                    horizontal: 15.w,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide(color: kbuBlue, width: 2),
                  ),
                  isDense: true,
                ),
                obscureText: obscureText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customToggle(int userType, ValueChanged<int> onChanged) {
    Color kbuBlue = const Color(0xFF00408B);
    Color kbuPink = const Color(0xFFEC008C);

    return Container(
      width: 90.w,
      height: 38.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: userType == 1 ? kbuPink : kbuBlue,
          width: 1.3.w,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: userType == 0 ? kbuBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(15.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  '재학생',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: userType == 0 ? Colors.white : kbuBlue,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: userType == 1 ? kbuPink : Colors.transparent,
                  borderRadius: BorderRadius.circular(15.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  '신입생',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: userType == 1 ? Colors.white : kbuPink,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultBox(BuildContext context) {
    Color kbuPink = const Color(0xFFEC008C);

    return Container(
      key: _resultKey,
      width: 420.w,
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 32.h),
      margin: EdgeInsets.only(top: 0.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_rounded, color: kbuPink, size: 27.sp),
              SizedBox(width: 10.w),
              Text(
                '합격자 조회 결과',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: kbuPink,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Divider(thickness: 1, color: Colors.grey[300]),
          SizedBox(height: 10.h),
          _resultRow('신청일자', _result['application_date'] ?? '-'),
          _resultRow('성명', _result['name'] ?? ''),
          _resultRow('학번', _result['id'] ?? ''),
          if (_result['dormitory'] != null && _result['dormitory']!.isNotEmpty)
            _resultRow('배정기숙사', _result['dormitory']!),
          _resultRow('선발여부', _resultStatus),
          if (_result['rejection_reason'] != null &&
              _result['rejection_reason']!.isNotEmpty)
            _resultRow('반려사유', _result['rejection_reason']!),
          if (_resultStatus == '합격')
            Container(
              padding: EdgeInsets.all(16.w),
              margin: EdgeInsets.only(top: 16.h),
              decoration: BoxDecoration(
                color: kbuPink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: kbuPink.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '🎉 축하합니다! 입주가 승인되었습니다',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: kbuPink,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '입주신청 때 사용한 비밀번호로\n기숙사 포털에 로그인하세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 24.h),
          if (_resultStatus == '합격')
            _rectButton(
              text: '기숙사 포털 바로가기',
              icon: Icons.home,
              color: kbuPink,
              onTap: () {
                Navigator.pushNamed(context, '/login');
              },
            ),
          if (_resultStatus == '불합격' || _resultStatus == '조회실패')
            _rectButton(
              text: '홈으로',
              icon: Icons.home_rounded,
              color: Colors.grey[600]!,
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DormIntroPage()),
                  (route) => false,
                );
              },
            ),
          if (_resultStatus == '심사중')
            _rectButton(
              text: '다시 조회하기',
              icon: Icons.refresh,
              color: Colors.orange,
              onTap: () {
                setState(() {
                  _showResult = false;
                });
              },
            ),
          if (_resultStatus == '신청내역없음')
            _rectButton(
              text: '입주신청 하러가기',
              icon: Icons.edit_document,
              color: kbuPink,
              onTap: () {
                Navigator.pushNamed(context, '/login');
              },
            ),
          if (_resultStatus == '네트워크오류')
            _rectButton(
              text: '다시 시도',
              icon: Icons.refresh,
              color: Colors.red,
              onTap: () {
                _onSearch();
              },
            ),
        ],
      ),
    );
  }

  Widget _noticeBox({double? height}) {
    Color kbuBlue = const Color(0xFF00408B);
    return Container(
      width: 420.w,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 32.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.campaign_rounded, color: kbuBlue, size: 27.sp),
              SizedBox(width: 10.w),
              Text(
                '입실 안내 및 공지사항',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: kbuBlue,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Divider(thickness: 1, color: Colors.grey[300]),
          SizedBox(height: 8.h),
          Expanded(
            child: Center(
              child: Text(
                '입실 일정, 준비물, 주의사항 등\n'
                '자세한 내용은 학교 홈페이지와 문자로 안내됩니다.\n\n'
                '- 준비물: 침구류, 세면도구, 슬리퍼 등\n'
                '- 입실 시간 엄수, 외부인 출입 금지\n'
                '- 미입실 시 자동으로 입실 포기 처리될 수 있습니다.\n'
                '- 기타 문의: 02-1234-5678',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Colors.black87,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 88.w,
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          SizedBox(
            width: 150.w,
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 15.sp, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rectButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 40.h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9.r),
          ),
          shadowColor: color.withOpacity(0.18),
          elevation: 8,
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22.sp),
            SizedBox(width: 8.w),
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15.sp,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSearch() async {
    final id = _idController.text.trim();
    final pw = _pwController.text.trim();
    final name = _nameController.text.trim();
    final birth = _birthController.text.trim();
    final examNum = _examNumController.text.trim();

    // 재학생과 신입생 별로 다른 검증 로직
    bool hasValidInput = false;

    if (userType == 0) {
      // 재학생: 학번, 비밀번호, 이름 필수
      hasValidInput = id.isNotEmpty && pw.isNotEmpty && name.isNotEmpty;
    } else {
      // 신입생: 수험번호, 생년월일, 이름 필수
      hasValidInput = examNum.isNotEmpty && birth.isNotEmpty && name.isNotEmpty;
    }

    if (!hasValidInput) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 필드를 입력해 주세요.')));
      return;
    }

    try {
      String loginId;
      String loginPw;
      String loginType;

      if (userType == 0) {
        // 재학생: 학번 + 비밀번호
        loginId = id;
        loginPw = pw;
        loginType = 'current_student';
      } else {
        // 신입생: 수험번호 + 생년월일
        loginId = examNum.isNotEmpty ? examNum : id;
        loginPw = birth;
        loginType = 'new_student';
      }

      // 1. 먼저 로그인 검증
      final loginUrl = Uri.parse('http://localhost:5050/api/login');
      final loginResponse = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': loginId,
          'password': loginPw,
          'redirect_to': 'application',
          'user_type': loginType, // 사용자 타입 명시적 전달
        }),
      );

      if (loginResponse.statusCode != 200) {
        final loginError = json.decode(loginResponse.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loginError['message'] ?? '로그인에 실패했습니다.')),
          );
        }
        return;
      }

      // 2. 로그인 성공 후 입주신청 결과 조회
      final url = Uri.parse(
        'http://localhost:5050/api/firstin/result?student_id=$loginId&user_type=$loginType&name=${Uri.encodeComponent(name)}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _showResult = true;
          _result = {
            'id': data['student_id'] ?? (loginId ?? id),
            'name': data['name'] ?? name,
            'application_date': data['application_date'] ?? '',
            'status': data['status'] ?? '',
            'dormitory': data['dormitory'] ?? '',
            'portal_password': data['portal_password'] ?? '',
            'rejection_reason': data['rejection_reason'] ?? '',
            'message': data['message'] ?? '',
          };

          // 결과 상태 설정
          final result = data['result'];
          if (result == 'accepted') {
            _resultStatus = '합격';
          } else if (result == 'rejected') {
            _resultStatus = '불합격';
          } else if (result == 'pending') {
            _resultStatus = '심사중';
          } else {
            _resultStatus = '신청내역없음';
          }
        });
      } else {
        final error = json.decode(response.body);
        setState(() {
          _showResult = true;
          _result = {'id': loginId, 'name': name};
          _resultStatus = '조회실패';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error['error'] ?? '조회에 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _showResult = true;
        _result = {'id': id, 'name': name};
        _resultStatus = '네트워크오류';
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
      }
    }
  }
}
