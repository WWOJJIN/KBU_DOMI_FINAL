import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../student_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:kbu_domi/env.dart';

class CheckoutApplyPage extends StatefulWidget {
  const CheckoutApplyPage({super.key});

  @override
  _CheckoutApplyPageState createState() => _CheckoutApplyPageState();
}

class _CheckoutApplyPageState extends State<CheckoutApplyPage> {
  String selectedYear = '2025';
  String selectedSemester = '1학기';

  final List<String> years = ['2024', '2025', '2026'];
  final List<String> semesters = ['1학기', '2학기'];

  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();
  final TextEditingController etcReasonController = TextEditingController();
  final TextEditingController bankController = TextEditingController();
  final TextEditingController accountController = TextEditingController();
  final TextEditingController accountHolderController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController guardianContactController =
      TextEditingController();
  final TextEditingController emergencyContactController =
      TextEditingController();

  DateTime? checkoutDate;
  bool guardianAgree = false;
  File? _selectedFile;
  File? _proofFile;
  Uint8List? _proofFileBytes;
  String? _proofFileName;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, String>> requests = [];

  final List<String> banks = ['국민은행', '신한은행', '우리은행', '하나은행', '농협은행'];
  String? selectedBank;

  final List<String> reasonOptions = ['졸업', '자퇴', '휴학', '개인사정', '기타'];
  String? selectedReason;
  bool agreePrivacy = false;
  bool checklistClean = false;
  bool checklistKey = false;
  bool checklistBill = false;

  bool _submitted = false;

  // ===== 유효성 검사 에러 메시지 =====
  String? reasonError;
  String? bankError;
  String? accountError;
  String? accountHolderError;
  String? contactError;
  String? emergencyContactError;
  String? checkoutDateError;
  String? guardianAgreeError;
  String? agreePrivacyError;
  String? checklistError;

  List<ProofFile> proofFiles = [];
  List<String> uploadedProofPaths = [];
  bool isProofUploading = false;

  // ===== 공지사항 관련 변수 추가 =====
  String _noticeContent = '퇴실 신청 후 담당자 확인 및 승인 절차가 진행됩니다. 문의사항은 행정실로 연락 바랍니다.';

  bool showStepper = false;
  List<StepInfo> stepperSteps = [];
  String stepperTitle = '';
  String stepperOverallStatus = '';

  String? originBank;
  String? originAccount;
  String? originHolder;

  String? _actualRequestStatus; // 실제 API에서 가져온 상태 저장

  @override
  void initState() {
    super.initState();
    final student = Provider.of<StudentProvider>(context, listen: false);
    studentIdController.text = student.studentId ?? '';
    nameController.text = student.name ?? '';
    contactController.text = student.phoneNum ?? '';
    guardianContactController.text = student.parPhone ?? '';
    bankController.text = student.paybackBank ?? '';
    accountHolderController.text = student.paybackName ?? '';
    accountController.text = student.paybackNum ?? '';
    _loadStudentRefundInfo();
    _fetchCheckoutRequests();
    _loadNotice(); // 공지사항 로드 추가
  }

  Future<void> _loadStudentRefundInfo() async {
    final studentId = studentIdController.text;
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/student/info?student_id=$studentId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          final bankValue = data['payback_bank'] ?? '';
          selectedBank = banks.contains(bankValue) ? bankValue : null;
          accountController.text = data['payback_num'] ?? '';
          accountHolderController.text = data['payback_name'] ?? '';
          originBank = selectedBank;
          originAccount = data['payback_num'] ?? '';
          originHolder = data['payback_name'] ?? '';
        });
      }
    } catch (e) {
      // ignore error
    }
  }

  // ===== 공지사항 로드 =====
  Future<void> _loadNotice() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/notice?category=checkout'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        setState(() {
          _noticeContent =
              data['content'] ??
              '퇴실 신청 후 담당자 확인 및 승인 절차가 진행됩니다. 문의사항은 행정실로 연락 바랍니다.';
        });
        print('퇴실 공지사항 로드 완료: $_noticeContent');
      } else {
        print('퇴실 공지사항 로딩 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('퇴실 공지사항 로딩 중 에러: $e');
    }
  }

  Future<void> _fetchCheckoutRequests() async {
    final studentId = studentIdController.text;
    try {
      final response = await http.get(
        Uri.parse('$apiBase/api/checkout/requests?student_id=$studentId'),
      );
      print('퇴소신청 내역 API 응답: \\n${response.body}'); // 디버깅용
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          requests = List<Map<String, String>>.from(
            data.map(
              (e) => {
                'studentId': e['student_id']?.toString() ?? '',
                'name': e['name']?.toString() ?? '',
                'checkoutDate': _formatDateToKorean(
                  e['checkout_date']?.toString() ?? '',
                ),
                'bank': e['payback_bank']?.toString() ?? '',
                'account': e['payback_num']?.toString() ?? '',
                'accountHolder': e['payback_name']?.toString() ?? '',
              },
            ),
          );
          // 신청내역이 있어도 자동으로 Stepper를 표시하지 않음
          // 신청하기 버튼을 눌러야만 표시되도록 _submitted 상태에 따라 결정
          // 단, 기존 신청이 있는 경우에는 항상 표시
          if (requests.isNotEmpty) {
            showStepper = true;
            final latest = requests.first;
            final status = data.isNotEmpty ? data[0]['status'] ?? '대기' : '대기';
            final regDate =
                data.isNotEmpty ? data[0]['reg_dt']?.toString() ?? '' : '';
            final originalCheckoutDate =
                data.isNotEmpty
                    ? data[0]['checkout_date']?.toString() ?? ''
                    : '';

            // 실제 API에서 가져온 상태 저장 (취소 가능 여부 판단용)
            _actualRequestStatus = status;

            stepperTitle = '퇴소신청 현황';

            // 원본 날짜를 사용하여 진행상황용 날짜 형식 변환
            final formattedCheckoutDate = _formatDateToKorean(
              originalCheckoutDate,
            );
            final formattedRegDate = _formatRegDate(regDate);

            // 상태에 따른 진행 현황 업데이트
            if (status == '승인') {
              stepperOverallStatus = '승인 완료';
              stepperSteps = [
                StepInfo(
                  title: '신청서 제출',
                  detail: '신청일: $formattedRegDate',
                  status: StepStatus.completed,
                ),
                StepInfo(
                  title: '서류 확인',
                  detail: '서류 검토 완료',
                  status: StepStatus.completed,
                ),
                StepInfo(
                  title: '퇴실점검 체크리스트 확인',
                  detail: '체크리스트 확인 완료',
                  status: StepStatus.completed,
                ),
                StepInfo(
                  title: '최종 승인',
                  detail: '퇴실 예정일: $formattedCheckoutDate',
                  status: StepStatus.completed,
                ),
              ];
            } else if (status == '반려') {
              stepperOverallStatus = '반려됨';
              stepperSteps = [
                StepInfo(
                  title: '신청서 제출',
                  detail: '신청일: $formattedRegDate',
                  status: StepStatus.completed,
                ),
                StepInfo(
                  title: '서류 확인',
                  detail: '서류 검토 중 문제 발견',
                  status: StepStatus.completed,
                ),
                StepInfo(
                  title: '신청 반려',
                  detail: '퇴소 신청이 반려되었습니다. 관리자에게 문의하세요.',
                  status: StepStatus.completed,
                ),
              ];
            } else if (status == '서류확인중') {
              stepperOverallStatus = '서류 검토 중';
              stepperSteps = [
                StepInfo(
                  title: '신청서 제출',
                  detail: '신청일: $formattedRegDate',
                  status: StepStatus.completed,
                ),
                StepInfo(
                  title: '서류 확인 중',
                  detail: '관리자가 서류를 검토하고 있습니다. (예상 소요시간: 1~2일)',
                  status: StepStatus.inProgress,
                ),
                StepInfo(
                  title: '퇴실점검 체크리스트 확인',
                  detail: '퇴실 예정일: $formattedCheckoutDate',
                  status: StepStatus.pending,
                ),
                StepInfo(title: '최종 승인', status: StepStatus.pending),
              ];
            } else if (status == '점검대기') {
              stepperOverallStatus = '점검 대기 중';
              stepperSteps = [
                StepInfo(
                  title: '신청서 제출',
                  detail: '신청일: $formattedRegDate',
                  status: StepStatus.completed,
                ),
                StepInfo(
                  title: '서류 확인',
                  detail: '서류 검토 완료',
                  status: StepStatus.completed,
                ),
                StepInfo(
                  title: '퇴실점검 체크리스트 확인 중',
                  detail: '관리자가 퇴실 점검을 진행하고 있습니다.',
                  status: StepStatus.inProgress,
                ),
                StepInfo(
                  title: '최종 승인',
                  detail: '퇴실 예정일: $formattedCheckoutDate',
                  status: StepStatus.pending,
                ),
              ];
            } else {
              // 대기 상태
              stepperOverallStatus = '진행 중';
              stepperSteps = [
                StepInfo(
                  title: '신청서 제출',
                  detail: '신청일: $formattedRegDate',
                  status: StepStatus.completed,
                ),
                StepInfo(
                  title: '서류 확인 중',
                  detail: '담당자 확인 중입니다. (예상 소요시간: 1~2일)',
                  status: StepStatus.inProgress,
                ),
                StepInfo(
                  title: '퇴실점검 체크리스트 확인',
                  detail: '퇴실 예정일: $formattedCheckoutDate',
                  status: StepStatus.pending,
                ),
                StepInfo(title: '최종 승인', status: StepStatus.pending),
              ];
            }
          } else {
            // 기존 신청이 없으면 Stepper 숨김
            showStepper = false;
            stepperSteps.clear();
            stepperTitle = '';
            stepperOverallStatus = '';
          }
        });
      }
    } catch (e) {
      print('퇴소신청 내역 불러오기 에러: $e');
    }
  }

  bool isRefundInfoChanged() {
    return (selectedBank ?? '') != (originBank ?? '') ||
        accountController.text != (originAccount ?? '') ||
        accountHolderController.text != (originHolder ?? '');
  }

  // ===== 날짜 형식 변환 헬퍼 함수들 =====
  String _formatDateToKorean(String dateString) {
    if (dateString.isEmpty) return '';

    try {
      DateTime date;

      // GMT 형식인 경우 처리
      if (dateString.contains('GMT')) {
        // "Mon, 30 Jun 2025 00:00:00 GMT" 형식 처리
        final cleanDateString = dateString.replaceAll(' GMT', '');
        // RFC 2822 형식을 ISO 8601 형식으로 변환
        if (dateString.contains(',')) {
          // "Mon, 30 Jun 2025 00:00:00" -> DateTime 파싱
          final parts = cleanDateString.split(', ')[1].split(' ');
          final day = int.parse(parts[0]);
          final monthMap = {
            'Jan': 1,
            'Feb': 2,
            'Mar': 3,
            'Apr': 4,
            'May': 5,
            'Jun': 6,
            'Jul': 7,
            'Aug': 8,
            'Sep': 9,
            'Oct': 10,
            'Nov': 11,
            'Dec': 12,
          };
          final month = monthMap[parts[1]] ?? 1;
          final year = int.parse(parts[2]);
          date = DateTime(year, month, day);
        } else {
          date = DateTime.parse(cleanDateString);
        }
      } else {
        // 일반적인 ISO 형식
        date = DateTime.parse(dateString);
      }

      final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
      final weekday = weekdays[date.weekday % 7];
      return '${date.year.toString().substring(2)}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $weekday';
    } catch (e) {
      print('날짜 파싱 오류: $dateString -> $e');
      return dateString;
    }
  }

  String _formatRegDate(String dateString) {
    if (dateString.isEmpty) return '';

    try {
      DateTime date;

      // GMT 형식인 경우 처리
      if (dateString.contains('GMT')) {
        // "Thu, 26 Jun 2025 00:39:18 GMT" 형식 처리
        final cleanDateString = dateString.replaceAll(' GMT', '');
        if (dateString.contains(',')) {
          final parts = cleanDateString.split(', ')[1].split(' ');
          final day = int.parse(parts[0]);
          final monthMap = {
            'Jan': 1,
            'Feb': 2,
            'Mar': 3,
            'Apr': 4,
            'May': 5,
            'Jun': 6,
            'Jul': 7,
            'Aug': 8,
            'Sep': 9,
            'Oct': 10,
            'Nov': 11,
            'Dec': 12,
          };
          final month = monthMap[parts[1]] ?? 1;
          final year = int.parse(parts[2]);
          date = DateTime(year, month, day);
        } else {
          date = DateTime.parse(cleanDateString);
        }
      } else {
        date = DateTime.parse(dateString);
      }

      final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
      final weekday = weekdays[date.weekday % 7];
      return '${date.year.toString().substring(2)}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $weekday';
    } catch (e) {
      print('날짜 파싱 오류: $dateString -> $e');
      return dateString;
    }
  }

  Future<void> _pickFile() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickProofFile() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _proofFileBytes = bytes;
          _proofFileName = pickedFile.name;
        });
      } else {
        setState(() {
          _proofFile = File(pickedFile.path);
          _proofFileName = pickedFile.path.split('/').last;
        });
      }
    }
  }

  // ===== 필수 항목 유효성 검사 =====
  bool _checkValidation() {
    // 에러 상태 초기화 및 검사 (텍스트 없이 true/false만)
    reasonError =
        (selectedReason == null || selectedReason!.isEmpty) ? 'error' : null;
    if (selectedReason == '기타' && etcReasonController.text.isEmpty) {
      reasonError = 'error';
    }

    bankError =
        (selectedBank == null || selectedBank!.isEmpty) ? 'error' : null;
    accountError = accountController.text.isEmpty ? 'error' : null;
    accountHolderError = accountHolderController.text.isEmpty ? 'error' : null;
    contactError = contactController.text.isEmpty ? 'error' : null;
    emergencyContactError =
        emergencyContactController.text.isEmpty ? 'error' : null;
    checkoutDateError = checkoutDate == null ? 'error' : null;
    guardianAgreeError = !guardianAgree ? 'error' : null;
    agreePrivacyError = !agreePrivacy ? 'error' : null;

    // 체크리스트 검사
    if (!checklistClean || !checklistKey || !checklistBill) {
      checklistError = 'error';
    } else {
      checklistError = null;
    }

    // 증빙서류 첨부 검사 (기존 로직 유지)
    final proofAttached = proofFiles.isNotEmpty;
    if (!proofAttached) {
      checklistError = 'error';
    }

    return [
      reasonError,
      bankError,
      accountError,
      accountHolderError,
      contactError,
      emergencyContactError,
      checkoutDateError,
      guardianAgreeError,
      agreePrivacyError,
      checklistError,
    ].every((e) => e == null);
  }

  // ===== 폼 유효성 검사 및 상태 업데이트 (신청하기 버튼 클릭 시에만 호출) =====
  bool _isFormValid() {
    final isValid = _checkValidation();
    setState(() {}); // 에러 상태 업데이트
    return isValid;
  }

  // ===== 유효성 검사 없이 현재 상태만 확인 (UI 표시용) =====
  bool _hasValidationErrors() {
    return [
      reasonError,
      bankError,
      accountError,
      accountHolderError,
      contactError,
      emergencyContactError,
      checkoutDateError,
      guardianAgreeError,
      agreePrivacyError,
      checklistError,
    ].any((e) => e != null);
  }

  // 기존 퇴실 신청이 있는지 확인
  bool _hasExistingRequest() {
    return requests.isNotEmpty;
  }

  // 현재 신청 상태가 취소 가능한지 확인 (대기 상태만 취소 가능)
  bool _canCancelRequest() {
    if (requests.isEmpty) return false;

    // 실제 API 데이터에서 상태 확인 (디버그 로그에서 확인한 실제 상태)
    // 로그에서 "status": "\uc810\uac80\ub300\uae30" 형태로 나오는 것을 확인
    final latestStatus = _getCurrentRequestStatus();
    return latestStatus == '대기';
  }

  // 현재 신청의 상태를 가져오기
  String _getCurrentRequestStatus() {
    if (requests.isEmpty) return '';

    // stepperOverallStatus는 실제 API에서 가져온 상태를 기반으로 설정됨
    // 실제 상태를 확인하려면 원본 API 데이터를 참조해야 함
    // 여기서는 stepperOverallStatus로 판단
    if (stepperOverallStatus.contains('대기') || stepperOverallStatus == '진행 중') {
      return '대기';
    } else if (stepperOverallStatus.contains('서류') ||
        stepperOverallStatus.contains('검토')) {
      return '서류확인중';
    } else if (stepperOverallStatus.contains('점검')) {
      return '점검대기';
    } else if (stepperOverallStatus.contains('승인')) {
      return '승인';
    } else if (stepperOverallStatus.contains('반려')) {
      return '반료';
    }
    return '대기'; // 기본값
  }

  Future<void> _deleteRequest(int index) async {
    // 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('퇴소 신청 취소'),
          content: const Text('정말로 퇴소 신청을 취소하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('아니요'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('예, 취소합니다'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      // 해당 신청의 checkout_id 가져오기
      final requestData = requests[index];
      // checkout_id가 없으면 요청에서 찾기
      String? checkoutId;

      // API 호출로 실제 데이터에서 checkout_id 찾기
      final response = await http.get(
        Uri.parse(
          '$apiBase/api/checkout/requests?student_id=${studentIdController.text}',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && index < data.length) {
          checkoutId = data[index]['checkout_id']?.toString();
        }
      }

      if (checkoutId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('삭제할 신청을 찾을 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 서버에서 삭제
      final deleteResponse = await http.delete(
        Uri.parse('$apiBase/api/checkout/$checkoutId'),
      );

      if (deleteResponse.statusCode == 200) {
        // 성공적으로 삭제됨
        setState(() {
          requests.removeAt(index);
          // 진행 현황도 업데이트
          if (requests.isEmpty) {
            showStepper = false;
            stepperSteps.clear();
            stepperTitle = '';
            stepperOverallStatus = '';
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('퇴소 신청이 성공적으로 취소되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );

        // 목록 새로고침
        await _fetchCheckoutRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('퇴소 신청 취소에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('퇴소 신청 삭제 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('네트워크 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitCheckoutRequest() async {
    final url = Uri.parse('$apiBase/api/checkout/apply');
    final data = {
      'studentId': studentIdController.text,
      'name': nameController.text,
      'year': selectedYear,
      'semester': selectedSemester,
      'contact': contactController.text,
      'guardianContact': guardianContactController.text,
      'emergencyContact': emergencyContactController.text,
      'checkoutDate':
          checkoutDate != null
              ? DateFormat('yyyy-MM-dd').format(checkoutDate!)
              : '',
      'reason': selectedReason ?? '',
      'reasonDetail': reasonController.text,
      'paybackBank': selectedBank ?? '',
      'paybackNum': accountController.text,
      'paybackName': accountHolderController.text,
      'checklistClean': checklistClean,
      'checklistKey': checklistKey,
      'checklistBill': checklistBill,
      'guardianAgree': guardianAgree,
      'agreePrivacy': agreePrivacy,
      'proofFiles': [
        for (final path in uploadedProofPaths)
          {'filePath': path, 'fileName': path.split('/').last},
      ],
    };
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    if (response.statusCode == 200) {
      await _fetchCheckoutRequests();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신청이 완료되었습니다.')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('신청 실패')));
    }
  }

  Future<void> pickProofFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );
      if (result != null) {
        for (var file in result.files) {
          if (kIsWeb) {
            if (file.bytes != null) {
              proofFiles.add(
                ProofFile(
                  file: null,
                  name: file.name,
                  size: file.size,
                  webBytes: file.bytes,
                ),
              );
            }
          } else {
            if (file.path != null) {
              proofFiles.add(
                ProofFile(
                  file: File(file.path!),
                  name: file.name,
                  size: file.size,
                ),
              );
            }
          }
        }
        setState(() {});
        for (var file in proofFiles) {
          if (file.status == '대기') {
            await uploadProofFile(file);
          }
        }
      }
    } catch (e) {
      print('파일 선택 중 오류: $e');
    }
  }

  Future<void> uploadProofFile(ProofFile file) async {
    try {
      file.status = '업로드중';
      setState(() {});
      String fileName = file.name;
      FormData formData;
      if (kIsWeb) {
        formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(
            file.webBytes!,
            filename: fileName,
            contentType: MediaType.parse('image/jpeg'),
          ),
        });
      } else {
        formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            file.file!.path,
            filename: fileName,
          ),
        });
      }
      final dio = Dio();
      dio.options.baseUrl = '$apiBase';
      dio.options.connectTimeout = const Duration(seconds: 120);
      dio.options.receiveTimeout = const Duration(seconds: 120);
      final response = await dio.post(
        '/api/checkout/proof/upload',
        data: formData,
        onSendProgress: (sent, total) {
          file.progress = sent / total;
          setState(() {});
        },
      );
      if (response.statusCode == 200 && response.data['success']) {
        uploadedProofPaths.add(response.data['filePath']);
        file.status = '완료';
      } else {
        file.status = '에러';
        throw Exception(response.data['error'] ?? '파일 업로드 실패');
      }
    } catch (e) {
      file.status = '에러';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('파일 업로드 실패: ${e.toString()}')));
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(32.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mainTitle('퇴소 신청'),
          Divider(height: 22.h, thickness: 1),
          SizedBox(height: 10.h),
          // 상단 정보(카드 없이) - 기본정보만 (연락처, 보호자 동의 완전 제거)
          Row(
            children: [
              Expanded(child: _fixedField('년도', selectedYear)), // 년도
              SizedBox(width: 10.w),
              Expanded(child: _fixedField('학기', selectedSemester)), // 학기
              SizedBox(width: 10.w),
              Expanded(
                child: _fixedField('학번', studentIdController.text),
              ), // 학번
              SizedBox(width: 10.w),
              Expanded(child: _fixedField('이름', nameController.text)), // 이름
            ],
          ),

          SizedBox(height: 16.h),
          _buildNoticeCard(),
          Divider(height: 22.h, thickness: 1),
          // 카드 좌우 배치: 퇴실 신청 정보 | 환불계좌 정보
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽: 퇴실 신청 정보 + 증빙서류 첨부
              Expanded(
                flex: 1,
                child: Card(
                  margin: EdgeInsets.only(right: 12.w, bottom: 16.h),
                  elevation: 2,
                  color: Colors.white, // 흰색 배경
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 퇴실 신청 정보
                        _sectionTitle('퇴실 신청 정보'),
                        SizedBox(height: 16.h),

                        // 퇴실 예정일 선택 버튼과 퇴실사유 선택을 같은 행에 배치
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: ElevatedButton(
                                onPressed:
                                    _hasExistingRequest()
                                        ? null
                                        : _selectCheckoutDate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor:
                                      checkoutDateError != null
                                          ? Colors.red
                                          : Colors.indigo,
                                  side: BorderSide(
                                    color:
                                        checkoutDateError != null
                                            ? Colors.red
                                            : Colors.indigo,
                                    width: 2,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24.w,
                                    vertical: 12.h,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24.r),
                                  ),
                                ),
                                child: Text(
                                  checkoutDate == null
                                      ? '퇴실 예정일 선택'
                                      : DateFormat(
                                        'yyyy-MM-dd',
                                      ).format(checkoutDate!),
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        checkoutDateError != null
                                            ? Colors.red
                                            : Colors.indigo,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              flex: 1,
                              child: _dropdown(
                                '퇴실 사유',
                                selectedReason ?? '',
                                reasonOptions,
                                _hasExistingRequest()
                                    ? null
                                    : (val) =>
                                        setState(() => selectedReason = val),
                                errorMessage: reasonError,
                              ),
                            ),
                          ],
                        ),

                        // 퇴실 사유 상세 설명을 아래에 배치
                        SizedBox(height: 16.h),
                        _largeTextField(
                          '퇴실 사유 상세 설명',
                          reasonController,
                          required: true,
                          enabled: !_hasExistingRequest(),
                        ),

                        // 기타 사유 입력 필드
                        if (selectedReason == '기타')
                          Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: _textField(
                              '기타 사유 입력',
                              etcReasonController,
                              required: true,
                              enabled: !_hasExistingRequest(),
                              errorMessage:
                                  (selectedReason == '기타' &&
                                          reasonError != null)
                                      ? reasonError
                                      : null,
                            ),
                          ),

                        // 구분선
                        Divider(
                          height: 32.h,
                          thickness: 1,
                          color: Colors.grey.shade300,
                        ),

                        // 증빙서류 첨부
                        _sectionTitle('증빙서류 첨부'),
                        SizedBox(height: 16.h),
                        _miniProofUploadBox(),
                        SizedBox(height: 12.h),
                        CheckboxListTile(
                          value: agreePrivacy,
                          onChanged:
                              _hasExistingRequest()
                                  ? null
                                  : (val) {
                                    setState(() {
                                      agreePrivacy = val ?? false;
                                      if (agreePrivacy)
                                        agreePrivacyError = null;
                                    });
                                  },
                          title: Text(
                            '[필수] 개인정보 수집 및 이용에 동의합니다.',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color:
                                  agreePrivacyError != null ? Colors.red : null,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 오른쪽: 환불 계좌 정보 + 퇴실 전 점검 체크리스트
              Expanded(
                flex: 1,
                child: Card(
                  margin: EdgeInsets.only(left: 12.w, bottom: 16.h),
                  elevation: 2,
                  color: Colors.white, // 흰색 배경
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 연락처 정보
                        _sectionTitle('연락처 정보'),
                        SizedBox(height: 16.h),
                        // 첫 번째 행: 본인연락처 | 보호자연락처
                        Row(
                          children: [
                            Expanded(
                              child: _fixedField(
                                '본인 연락처',
                                contactController.text,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _fixedField(
                                '보호자 연락처',
                                guardianContactController.text,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        // 두 번째 행: 비상연락처 | 보호자동의
                        Row(
                          children: [
                            Expanded(
                              child: _textField(
                                '비상 연락처',
                                emergencyContactController,
                                required: true,
                                enabled: !_hasExistingRequest(),
                                errorMessage: emergencyContactError,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            // 보호자 동의 체크박스만 (네모 컨테이너 없이)
                            Expanded(
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: guardianAgree,
                                    onChanged:
                                        _hasExistingRequest()
                                            ? null
                                            : (val) {
                                              setState(() {
                                                guardianAgree = val!;
                                                if (guardianAgree)
                                                  guardianAgreeError = null;
                                              });
                                            },
                                  ),
                                  Text(
                                    '보호자 동의',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color:
                                          guardianAgreeError != null
                                              ? Colors.red
                                              : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // 구분선
                        Divider(
                          height: 32.h,
                          thickness: 1,
                          color: Colors.grey.shade300,
                        ),

                        // 환불 계좌 정보
                        _sectionTitle('환불 계좌 정보'),
                        SizedBox(height: 16.h),
                        _dropdown(
                          '은행명',
                          selectedBank ?? '',
                          banks,
                          _hasExistingRequest()
                              ? null
                              : (val) => setState(() => selectedBank = val),
                          errorMessage: bankError,
                        ),
                        if (isRefundInfoChanged())
                          Padding(
                            padding: EdgeInsets.only(top: 4.h, left: 2.w),
                            child: Text(
                              '기존 정보와 다릅니다. 변경된 정보로 환불이 진행됩니다.',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12.sp,
                              ),
                            ),
                          ),
                        SizedBox(height: 8.h),
                        _textField(
                          '계좌번호',
                          accountController,
                          required: true,
                          enabled: !_hasExistingRequest(),
                          errorMessage: accountError,
                        ),
                        SizedBox(height: 8.h),
                        _textField(
                          '예금주',
                          accountHolderController,
                          required: true,
                          enabled: !_hasExistingRequest(),
                          errorMessage: accountHolderError,
                        ),

                        // 구분선
                        Divider(
                          height: 32.h,
                          thickness: 1,
                          color: Colors.grey.shade300,
                        ),

                        // 퇴실 전 점검 체크리스트
                        _sectionTitle('퇴실전 점검 체크리스트'),
                        SizedBox(height: 12.h),
                        CheckboxListTile(
                          value: checklistClean,
                          onChanged:
                              _hasExistingRequest()
                                  ? null
                                  : (val) {
                                    setState(() {
                                      checklistClean = val ?? false;
                                      if (checklistClean &&
                                          checklistKey &&
                                          checklistBill) {
                                        checklistError = null;
                                      }
                                    });
                                  },
                          title: Text(
                            '방 청소 완료',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: checklistError != null ? Colors.red : null,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: checklistKey,
                          onChanged:
                              _hasExistingRequest()
                                  ? null
                                  : (val) {
                                    setState(() {
                                      checklistKey = val ?? false;
                                      if (checklistClean &&
                                          checklistKey &&
                                          checklistBill) {
                                        checklistError = null;
                                      }
                                    });
                                  },
                          title: Text(
                            '열쇠 반납 완료',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: checklistError != null ? Colors.red : null,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        CheckboxListTile(
                          value: checklistBill,
                          onChanged:
                              _hasExistingRequest()
                                  ? null
                                  : (val) {
                                    setState(() {
                                      checklistBill = val ?? false;
                                      if (checklistClean &&
                                          checklistKey &&
                                          checklistBill) {
                                        checklistError = null;
                                      }
                                    });
                                  },
                          title: Text(
                            '공과금 정산 완료',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: checklistError != null ? Colors.red : null,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 22.h, thickness: 1),
          SizedBox(height: 24.h),
          Center(
            child: Column(
              children: [
                // 기존 신청이 있을 때 안내 메시지
                if (_hasExistingRequest()) ...[
                  Container(
                    padding: EdgeInsets.all(12.w),
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange, size: 20.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            '이미 퇴실 신청이 진행 중입니다. 한 번에 하나의 신청만 가능합니다.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap:
                          _hasExistingRequest()
                              ? null // 기존 신청이 있으면 비활성화
                              : () async {
                                setState(() {
                                  _submitted = true;
                                });
                                if (_isFormValid()) {
                                  await _submitCheckoutRequest();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '모든 항목을 입력하고 파일을 첨부하세요.',
                                        style: TextStyle(fontSize: 14.sp),
                                      ),
                                    ),
                                  );
                                }
                              },
                      child: Container(
                        width: 150.w,
                        padding: EdgeInsets.symmetric(vertical: 6.h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24.r),
                          color:
                              _hasExistingRequest()
                                  ? Colors.grey
                                  : Colors.indigo,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueGrey.withOpacity(0.3),
                              blurRadius: 6.r,
                              offset: Offset(0, 3.h),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _hasExistingRequest() ? '신청 진행 중' : '신청하기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 기존 신청이 있거나 신청하기 버튼을 눌렀을 때 카드들 표시
          if (_hasExistingRequest() || _submitted) ...[
            Divider(height: 40.h, thickness: 1),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: _buildStepperCard(
                    stepperSteps,
                    stepperTitle,
                    stepperOverallStatus,
                  ),
                ),
                SizedBox(width: 24.w),
                Expanded(flex: 1, child: _buildRequestCard(context, 24.w)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
  );

  Widget _mainTitle(String title) => Row(
    children: [
      Container(
        width: 4.w,
        height: 24.h,
        color: Colors.blue[900],
        margin: EdgeInsets.only(right: 8.w),
      ),
      Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.sp),
      ),
    ],
  );

  // ===== 공지사항 카드 위젯 =====
  Widget _buildNoticeCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20.w, color: Colors.blue[600]),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공지사항',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    _noticeContent,
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?>? onChanged, {
    String? errorMessage,
  }) => DropdownButtonFormField2<String>(
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13.sp),
      errorText: null, // 에러 텍스트 제거
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      // 전역 테마 사용하되, 에러 상태일 때만 빨간색 오버라이드
      enabledBorder:
          errorMessage != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8.r),
              )
              : null, // null이면 전역 테마 사용
      focusedBorder:
          errorMessage != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8.r),
              )
              : null, // null이면 전역 테마 사용
    ),
    hint: Text('선택하세요', style: TextStyle(fontSize: 13.sp)),
    // value가 options에 포함되어 있지 않으면 null로 설정
    value: (value.isEmpty || !options.contains(value)) ? null : value,
    items:
        options
            .map(
              (option) => DropdownMenuItem(
                value: option,
                child: Text(option, style: TextStyle(fontSize: 13.sp)),
              ),
            )
            .toList(),
    onChanged:
        onChanged != null
            ? (newValue) {
              onChanged(newValue);
              // 선택 시 에러 상태 초기화
              setState(() {
                if (label.contains('은행')) bankError = null;
                if (label.contains('사유')) reasonError = null;
              });
            }
            : null,
    buttonStyleData: ButtonStyleData(
      height: 20.h,
      padding: EdgeInsets.only(left: 0, right: 0),
    ),
    dropdownStyleData: DropdownStyleData(
      maxHeight: 200.h,
      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
    ),
  );

  Widget _textField(
    String label,
    TextEditingController controller, {
    bool required = false,
    String? errorMessage,
    bool enabled = true,
  }) => TextField(
    controller: controller,
    enabled: enabled,
    style: TextStyle(fontSize: 14.sp, color: enabled ? null : Colors.grey),
    onChanged: (value) {
      // 입력 시 에러 상태 초기화
      setState(() {
        if (label.contains('연락처') && !label.contains('비상')) contactError = null;
        if (label.contains('비상')) emergencyContactError = null;
        if (label.contains('계좌번호')) accountError = null;
        if (label.contains('예금주')) accountHolderError = null;
      });
    },
    decoration: InputDecoration(
      labelText: label,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      // 에러 상태일 때 빨간 테두리, 정상일 때 기본 테두리
      border:
          errorMessage != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(4.r),
              )
              : OutlineInputBorder(),
      enabledBorder:
          errorMessage != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(4.r),
              )
              : null,
      focusedBorder:
          errorMessage != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(4.r),
              )
              : null,
      errorBorder:
          errorMessage != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(4.r),
              )
              : null,
    ),
  );

  Widget _largeTextField(
    String hint,
    TextEditingController controller, {
    bool required = false,
    String? errorMessage,
    bool enabled = true,
  }) => TextField(
    controller: controller,
    enabled: enabled,
    maxLines: 5,
    style: TextStyle(fontSize: 14.sp, color: enabled ? null : Colors.grey),
    decoration: InputDecoration(
      hintText: hint,
      // 에러 상태일 때 빨간 테두리, 정상일 때 기본 테두리
      border:
          errorMessage != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(4.r),
              )
              : OutlineInputBorder(),
      enabledBorder:
          errorMessage != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(4.r),
              )
              : null,
      focusedBorder:
          errorMessage != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(4.r),
              )
              : null,
      errorBorder:
          errorMessage != null
              ? OutlineInputBorder(
                borderSide: BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(4.r),
              )
              : null,
      contentPadding: EdgeInsets.all(12.w),
    ),
  );

  Widget _buildRequestCard(BuildContext context, double tableWidth) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('퇴실 신청 내역'),
            SizedBox(height: 8.h),
            _buildRequestSfDataGrid(context, tableWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestSfDataGrid(BuildContext context, double tableWidth) {
    final List<RequestRow> rowList = [
      for (final req in requests)
        RequestRow(
          req['studentId'] ?? '',
          req['name'] ?? '',
          req['checkoutDate'] ?? '',
          req['bank'] ?? '',
          req['account'] ?? '',
          req['accountHolder'] ?? '',
        ),
    ];
    final dataSource = RequestDataSource(
      rowList,
      (idx) {
        _deleteRequest(idx);
      },
      _canCancelRequest(), // 취소 가능 여부 전달
    );
    return Container(
      width: double.infinity,
      height: 240.h,
      child: SfDataGrid(
        source: dataSource,
        columnWidthMode: ColumnWidthMode.fill,
        columns: [
          GridColumn(
            columnName: 'studentId',
            label: Center(
              child: Text(
                '학번',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'name',
            label: Center(
              child: Text(
                '이름',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'checkoutDate',
            label: Center(
              child: Text(
                '퇴실예정일',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'bank',
            label: Center(
              child: Text(
                '은행',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'account',
            label: Center(
              child: Text(
                '계좌번호',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'accountHolder',
            label: Center(
              child: Text(
                '예금주',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ),
          ),
          GridColumn(
            columnName: 'cancel',
            width: 60.w,
            label: Center(
              child: Text(
                '취소',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
              ),
            ),
          ),
        ],
        gridLinesVisibility: GridLinesVisibility.horizontal,
        headerGridLinesVisibility: GridLinesVisibility.horizontal,
        rowHeight: 44.h,
        headerRowHeight: 40.h,
        allowSorting: false,
      ),
    );
  }

  Widget _miniProofUploadBox() {
    return Container(
      height: 200.h,
      decoration: BoxDecoration(
        border: Border.all(
          color: checklistError != null ? Colors.red : Colors.grey.shade400,
          width: checklistError != null ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: _hasExistingRequest() ? null : pickProofFiles,
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8.r),
                    bottomLeft: Radius.circular(8.r),
                  ),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 48.w,
                      color: Colors.blue.shade300,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '클릭하여 파일 선택',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Colors.grey.shade400)),
              ),
              child: _buildProofFileList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProofFileList() {
    if (proofFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Text(
            '업로드된 파일이 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14.sp),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(8.w),
      shrinkWrap: true,
      itemCount: proofFiles.length,
      itemBuilder: (context, index) {
        final file = proofFiles[index];
        return Container(
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // 이미지 미리보기
              ClipRRect(
                borderRadius: BorderRadius.circular(6.r),
                child: Container(
                  width: 50.w,
                  height: 50.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child:
                      kIsWeb && file.webBytes != null
                          ? Image.memory(
                            file.webBytes!,
                            width: 50.w,
                            height: 50.h,
                            fit: BoxFit.cover,
                          )
                          : file.file != null
                          ? Image.file(
                            file.file!,
                            width: 50.w,
                            height: 50.h,
                            fit: BoxFit.cover,
                          )
                          : SizedBox(width: 50.w, height: 50.h),
                ),
              ),
              SizedBox(width: 12.w),
              // 파일 정보 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 파일명
                    Text(
                      file.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    // 용량과 상태를 한 줄에 배치
                    Row(
                      children: [
                        Text(
                          '${(file.size / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          file.status == '완료'
                              ? '업로드 완료'
                              : file.status == '업로드중'
                              ? '업로드 대기 중'
                              : file.status == '에러'
                              ? '업로드 실패'
                              : '대기 중',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color:
                                file.status == '완료'
                                    ? Colors.green.shade600
                                    : file.status == '에러'
                                    ? Colors.red.shade600
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    // 업로드 중일 때 진행바 표시
                    if (file.status == '업로드중') ...[
                      SizedBox(height: 6.h),
                      LinearProgressIndicator(
                        value: file.progress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ],
                  ],
                ),
              ),
              // 삭제 버튼
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Colors.grey.shade500,
                  size: 20.sp,
                ),
                onPressed: () {
                  // 파일 삭제 로직
                  setState(() {
                    proofFiles.removeAt(index);
                    if (index < uploadedProofPaths.length) {
                      uploadedProofPaths.removeAt(index);
                    }
                  });
                },
                tooltip: '파일 삭제',
                padding: EdgeInsets.all(4.w),
                constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepperCard(
    List<StepInfo> steps,
    String title,
    String overallStatus,
  ) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
        side: BorderSide(color: Colors.grey.shade400, width: 1),
      ),
      margin: EdgeInsets.all(0),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 제목 + 전체 상태
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      overallStatus,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 15.sp,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(Icons.circle, color: Colors.orange, size: 16.w),
                  ],
                ),
              ],
            ),
            Divider(height: 28.h, thickness: 1),
            // Vertical Stepper
            ...steps.map((step) => _buildStepItem(step)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem(StepInfo step) {
    Color iconColor;
    IconData iconData;
    TextStyle titleStyle;
    TextStyle detailStyle;

    switch (step.status) {
      case StepStatus.completed:
        iconColor = Colors.green;
        iconData = Icons.check_circle;
        titleStyle = TextStyle(
          fontWeight: FontWeight.normal,
          color: Colors.black,
          fontSize: 15.sp,
        );
        detailStyle = TextStyle(color: Colors.grey, fontSize: 13.sp);
        break;
      case StepStatus.inProgress:
        iconColor = Colors.blue;
        iconData = Icons.radio_button_checked;
        titleStyle = TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue,
          fontSize: 15.sp,
        );
        detailStyle = TextStyle(
          color: Colors.blue,
          fontSize: 13.sp,
          fontWeight: FontWeight.bold,
        );
        break;
      case StepStatus.pending:
      default:
        iconColor = Colors.grey;
        iconData = Icons.radio_button_unchecked;
        titleStyle = TextStyle(color: Colors.grey, fontSize: 15.sp);
        detailStyle = TextStyle(color: Colors.grey[400], fontSize: 13.sp);
        break;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: iconColor, size: 22.w),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: titleStyle),
                if (step.detail != null) ...[
                  SizedBox(height: 2.h),
                  Text(step.detail!, style: detailStyle),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===== 읽기 전용 필드 위젯 (외박신청 페이지와 동일) =====
  Widget _fixedField(String label, String value) => TextField(
    controller: TextEditingController(text: value),
    readOnly: true,
    style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13.sp),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      border: OutlineInputBorder(),
      filled: true,
      fillColor: Colors.grey[100],
    ),
  );

  // ===== 캘린더 위젯 (외박신청 페이지와 동일) =====
  Widget _calendar() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(
        color:
            checkoutDateError != null
                ? Colors.red
                : Colors.grey.shade300, // 에러 시 빨간 테두리
        width: checkoutDateError != null ? 2 : 1,
      ),
      borderRadius: BorderRadius.circular(8.r),
    ),
    child: TableCalendar(
      firstDay: DateTime.now(), // 오늘부터 선택 가능
      lastDay: DateTime(DateTime.now().year + 1, 12, 31), // 내년 12월 31일까지
      focusedDay: checkoutDate ?? DateTime.now(),
      selectedDayPredicate: (day) {
        return isSameDay(checkoutDate, day);
      },
      // 캘린더 크기 조절 속성들
      daysOfWeekHeight: 30.h, // 요일 헤더 높이
      rowHeight: 40.h, // 각 주(row)의 높이
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          checkoutDate = selectedDay;
          checkoutDateError = null; // 날짜 선택 시 에러 상태 초기화
        });
      },
      headerStyle: HeaderStyle(
        titleTextStyle: TextStyle(fontSize: 17.sp),
        leftChevronIcon: Icon(Icons.chevron_left, size: 17.w),
        rightChevronIcon: Icon(Icons.chevron_right, size: 17.w),
        headerPadding: EdgeInsets.symmetric(vertical: 3.h), // 헤더 패딩
        formatButtonVisible: false, // 형식 전환 버튼(2 weeks) 숨기기
      ),
      calendarStyle: CalendarStyle(
        cellMargin: EdgeInsets.all(1.w),
        cellPadding: EdgeInsets.all(2.w), // 셀 내부 패딩
        defaultTextStyle: TextStyle(fontSize: 12.sp),
        weekendTextStyle: TextStyle(fontSize: 12.sp),
        outsideTextStyle: TextStyle(fontSize: 12.sp),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: TextStyle(fontSize: 12.sp), // 평일 요일 글씨 크기
        weekendStyle: TextStyle(fontSize: 12.sp), // 주말 요일 글씨 크기
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, date, _) {
          if (date.weekday == DateTime.saturday) {
            return Container(
              margin: EdgeInsets.all(2.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Text(
                '${date.day}',
                style: TextStyle(color: Colors.indigo, fontSize: 12.sp),
              ),
            );
          }
          return null;
        },
        outsideBuilder: (context, date, _) {
          if (date.weekday == DateTime.saturday) {
            return Container(
              margin: EdgeInsets.all(2.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: Colors.indigo.withOpacity(0.5),
                  fontSize: 12.sp,
                ),
              ),
            );
          }
          if (date.weekday == DateTime.sunday) {
            return Container(
              margin: EdgeInsets.all(2.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  color: Colors.red.withOpacity(0.5),
                  fontSize: 12.sp,
                ),
              ),
            );
          }
          return null;
        },
      ),
    ),
  );

  // ===== 날짜 선택 다이얼로그 함수 =====
  Future<void> _selectCheckoutDate() async {
    DateTime? tempSelectedDate = checkoutDate;
    DateTime focusedDay = checkoutDate ?? DateTime.now();

    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white, // 다이얼로그 배경색 하얀색
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Container(
                width: 380.w,
                constraints: BoxConstraints(maxHeight: 500.h),
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 다이얼로그 제목
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '퇴실 예정일 선택',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),

                      // 캘린더 (고정 크기로 설정)
                      Container(
                        height: 270.h, // 고정 높이 설정
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ), // 테두리 추가
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        padding: EdgeInsets.all(8.w),
                        child: TableCalendar<dynamic>(
                          firstDay: DateTime.now(), // 오늘부터 선택 가능
                          lastDay: DateTime(
                            DateTime.now().year + 1,
                            12,
                            31,
                          ), // 내년 12월 31일까지
                          focusedDay: focusedDay,
                          selectedDayPredicate: (day) {
                            return isSameDay(tempSelectedDate, day);
                          },
                          // 캘린더 크기 조절 속성들 (오버플로우 방지)
                          daysOfWeekHeight: 20.h, // 요일 헤더 높이 줄임
                          rowHeight: 28.h, // 각 주(row)의 높이 줄임
                          calendarFormat: CalendarFormat.month, // 월 단위로 고정
                          startingDayOfWeek: StartingDayOfWeek.sunday, // 일요일 시작
                          onDaySelected: (selectedDay, newFocusedDay) {
                            setDialogState(() {
                              tempSelectedDate = selectedDay;
                              focusedDay = newFocusedDay;
                            });
                          },
                          onPageChanged: (newFocusedDay) {
                            setDialogState(() {
                              focusedDay = newFocusedDay;
                            });
                          },
                          headerStyle: HeaderStyle(
                            titleTextStyle: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                            leftChevronIcon: Icon(
                              Icons.chevron_left,
                              size: 18.w,
                              color: Colors.grey[700],
                            ),
                            rightChevronIcon: Icon(
                              Icons.chevron_right,
                              size: 18.w,
                              color: Colors.grey[700],
                            ),
                            headerPadding: EdgeInsets.symmetric(
                              vertical: 4.h,
                            ), // 헤더 패딩 줄임
                            formatButtonVisible: false, // 형식 전환 버튼 숨기기
                            titleCentered: true, // 제목 중앙 정렬
                          ),
                          calendarStyle: CalendarStyle(
                            cellMargin: EdgeInsets.all(1.w),
                            cellPadding: EdgeInsets.all(2.w), // 셀 내부 패딩 줄임
                            defaultTextStyle: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.grey[800],
                            ),
                            weekendTextStyle: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.red[600],
                            ),
                            outsideTextStyle: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.grey[400],
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Colors.indigo,
                              shape: BoxShape.circle,
                            ),
                            selectedTextStyle: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: TextStyle(
                              color: Colors.indigo[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                            // 비활성화된 날짜 (과거 날짜) 스타일
                            disabledDecoration: BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            disabledTextStyle: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13.sp,
                            ),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ), // 평일 요일 글씨 크기
                            weekendStyle: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[600],
                            ), // 주말 요일 글씨 크기
                          ),
                          // 과거 날짜 비활성화
                          enabledDayPredicate: (day) {
                            return day.isAfter(
                              DateTime.now().subtract(Duration(days: 1)),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // 선택된 날짜 표시
                      if (tempSelectedDate != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: Colors.indigo.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '선택된 날짜: ${DateFormat('yyyy년 MM월 dd일').format(tempSelectedDate!)}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo[700],
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                      ],

                      // 버튼들
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 8.h,
                              ),
                            ),
                            child: Text(
                              '취소',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          ElevatedButton(
                            onPressed:
                                tempSelectedDate != null
                                    ? () {
                                      Navigator.of(
                                        context,
                                      ).pop(tempSelectedDate);
                                    }
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  tempSelectedDate != null
                                      ? Colors.indigo
                                      : Colors.grey[400],
                              padding: EdgeInsets.symmetric(
                                horizontal: 24.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                            child: Text(
                              '확인',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        checkoutDate = picked;
        checkoutDateError = null; // 날짜 선택 시 에러 상태 초기화
      });
    }
  }
}

class ProofFile {
  final File? file;
  final String name;
  final int size;
  double progress;
  String status; // '대기', '업로드중', '완료', '에러'
  Uint8List? webBytes;
  ProofFile({
    this.file,
    required this.name,
    required this.size,
    this.progress = 0,
    this.status = '대기',
    this.webBytes,
  });
}

enum StepStatus { completed, inProgress, pending }

class StepInfo {
  final String title;
  final String? detail;
  final StepStatus status;
  StepInfo({required this.title, this.detail, required this.status});
}

class RequestRow {
  final String studentId;
  final String name;
  final String checkoutDate;
  final String bank;
  final String account;
  final String accountHolder;
  RequestRow(
    this.studentId,
    this.name,
    this.checkoutDate,
    this.bank,
    this.account,
    this.accountHolder,
  );
}

class RequestDataSource extends DataGridSource {
  final List<RequestRow> rowsData;
  final void Function(int) onCancel;
  final bool canCancel; // 취소 가능 여부
  RequestDataSource(this.rowsData, this.onCancel, this.canCancel);

  @override
  List<DataGridRow> get rows =>
      rowsData
          .asMap()
          .entries
          .map(
            (entry) => DataGridRow(
              cells: [
                DataGridCell<String>(
                  columnName: 'studentId',
                  value: entry.value.studentId,
                ),
                DataGridCell<String>(
                  columnName: 'name',
                  value: entry.value.name,
                ),
                DataGridCell<String>(
                  columnName: 'checkoutDate',
                  value: entry.value.checkoutDate,
                ),
                DataGridCell<String>(
                  columnName: 'bank',
                  value: entry.value.bank,
                ),
                DataGridCell<String>(
                  columnName: 'account',
                  value: entry.value.account,
                ),
                DataGridCell<String>(
                  columnName: 'accountHolder',
                  value: entry.value.accountHolder,
                ),
                DataGridCell<int>(columnName: 'cancel', value: entry.key),
              ],
            ),
          )
          .toList();

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final idx = row.getCells().last.value as int;
    return DataGridRowAdapter(
      cells: [
        for (int i = 0; i < row.getCells().length - 1; i++)
          Container(
            alignment: Alignment.center,
            child: Text(
              row.getCells()[i].value.toString(),
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
        IconButton(
          icon: Icon(
            Icons.cancel,
            color: canCancel ? Colors.red : Colors.grey,
            size: 20.w,
          ),
          onPressed: canCancel ? () => onCancel(idx) : null,
          tooltip: canCancel ? '신청 취소' : '진행 중인 신청은 취소할 수 없습니다',
        ),
      ],
    );
  }
}
