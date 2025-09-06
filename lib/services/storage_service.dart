import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

/// 로컬 저장소 관리 서비스
/// 새로고침 시 페이지 상태 유지 및 보안 기능 제공
class StorageService {
  static const String _keyStudentInfo = 'student_info';
  static const String _keyAdminPageIndex = 'admin_page_index';
  static const String _keyStudentPageIndex = 'student_page_index';
  static const String _keyLoginToken = 'login_token';
  static const String _keyLastActivity = 'last_activity';
  static const String _keyIsLoggedIn = 'is_logged_in';

  // 세션 타임아웃 (30분)
  static const int _sessionTimeoutMinutes = 30;

  static SharedPreferences? _prefs;

  /// SharedPreferences 초기화
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 학생 정보 저장 (암호화)
  static Future<void> saveStudentInfo(Map<String, dynamic> studentInfo) async {
    await init();
    final jsonString = json.encode(studentInfo);
    final encrypted = _encrypt(jsonString);
    await _prefs!.setString(_keyStudentInfo, encrypted);
    await _prefs!.setBool(_keyIsLoggedIn, true);
    await _updateLastActivity();
  }

  /// 학생 정보 불러오기 (복호화)
  static Future<Map<String, dynamic>?> getStudentInfo() async {
    await init();
    print('🔍 StorageService.getStudentInfo 호출됨');

    // 세션 유효성 검사
    final sessionValid = await _isSessionValid();
    print('🔍 세션 유효성: $sessionValid');

    if (!sessionValid) {
      print('❌ 세션이 만료되어 데이터 삭제');
      await clearAll();
      return null;
    }

    final encrypted = _prefs!.getString(_keyStudentInfo);
    print('🔍 암호화된 데이터 존재 여부: ${encrypted != null}');

    if (encrypted == null) {
      print('❌ 저장된 학생 정보가 없음');
      return null;
    }

    try {
      final decrypted = _decrypt(encrypted);
      await _updateLastActivity();
      final studentInfo = json.decode(decrypted) as Map<String, dynamic>;
      print(
        '✅ 학생 정보 복호화 성공: ${studentInfo['name']} (${studentInfo['student_id']})',
      );
      return studentInfo;
    } catch (e) {
      print('❌ 학생 정보 복호화 실패: $e - 기존 데이터 삭제 후 재시도 필요');
      // 복호화 실패 시 기존 잘못된 데이터 삭제
      await _prefs!.remove(_keyStudentInfo);
      return null;
    }
  }

  /// 관리자 페이지 인덱스 저장
  static Future<void> saveAdminPageIndex(int index) async {
    await init();
    await _prefs!.setInt(_keyAdminPageIndex, index);
    await _updateLastActivity();
  }

  /// 관리자 페이지 인덱스 불러오기
  static Future<int> getAdminPageIndex() async {
    await init();
    if (!await _isSessionValid()) return 0;
    return _prefs!.getInt(_keyAdminPageIndex) ?? 0;
  }

  /// 학생 페이지 인덱스 저장
  static Future<void> saveStudentPageIndex(int index) async {
    await init();

    // 🚨 A/S 페이지(인덱스 6) 저장 방지 - 의도하지 않은 이동 방지
    if (index == 6) {
      print('⚠️ AS 페이지(6) 인덱스 저장 차단 - 내기숙사(0)로 변경');
      index = 0; // 내기숙사로 강제 변경
    }

    print('💾 학생 페이지 인덱스 저장: $index');
    await _prefs!.setInt(_keyStudentPageIndex, index);
    await _updateLastActivity();
  }

  /// 학생 페이지 인덱스 불러오기
  static Future<int> getStudentPageIndex() async {
    await init();
    if (!await _isSessionValid()) {
      print('⚠️ 세션이 만료되어 기본 페이지 인덱스 반환: 0');
      return 0; // 내기숙사 기본값
    }

    final index = _prefs!.getInt(_keyStudentPageIndex) ?? 0;

    // 🚨 A/S 페이지(인덱스 6) 로드 방지 - 기존에 잘못 저장된 값 정리
    if (index == 6) {
      print('⚠️ 저장된 AS 페이지(6) 인덱스 감지 - 내기숙사(0)로 변경');
      await saveStudentPageIndex(0); // 올바른 값으로 재저장
      return 0;
    }

    print('📖 학생 페이지 인덱스 로드: $index');
    return index;
  }

  /// 로그인 상태 확인
  static Future<bool> isLoggedIn() async {
    await init();
    final isLoggedIn = _prefs!.getBool(_keyIsLoggedIn) ?? false;
    if (!isLoggedIn) return false;

    return await _isSessionValid();
  }

  /// 마지막 활동 시간 업데이트
  static Future<void> _updateLastActivity() async {
    await init();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _prefs!.setInt(_keyLastActivity, now);
  }

  /// 세션 유효성 검사
  static Future<bool> _isSessionValid() async {
    await init();
    final lastActivity = _prefs!.getInt(_keyLastActivity);
    print('🔍 마지막 활동 시간: $lastActivity');

    if (lastActivity == null) {
      print('❌ 마지막 활동 시간이 없음 - 세션 무효');
      return false;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = now - lastActivity;
    final minutes = difference / (1000 * 60);
    final remainingMinutes = (_sessionTimeoutMinutes - minutes).round();

    print('🔍 세션 경과 시간: ${minutes.round()}분, 남은 시간: ${remainingMinutes}분');

    final isValid = minutes < _sessionTimeoutMinutes;
    print('🔍 세션 유효성 결과: $isValid');

    return isValid;
  }

  /// 모든 저장된 데이터 삭제
  static Future<void> clearAll() async {
    await init();
    await _prefs!.clear();
  }

  /// 로그아웃
  static Future<void> logout() async {
    await init();
    await _prefs!.remove(_keyStudentInfo);
    await _prefs!.remove(_keyLoginToken);
    await _prefs!.remove(_keyLastActivity);
    await _prefs!.setBool(_keyIsLoggedIn, false);
  }

  /// 고정된 키 생성
  static String _getFixedKey() {
    const fixedSeed = 'kbu_domi_storage_key_2025'; // 고정된 시드
    final digest = sha256.convert(utf8.encode(fixedSeed));
    return digest.toString().substring(0, 16);
  }

  /// 간단한 암호화 (실제 운영환경에서는 더 강력한 암호화 사용 권장)
  static String _encrypt(String text) {
    final bytes = utf8.encode(text);
    final key = _getFixedKey(); // 고정된 키 사용

    // 간단한 XOR 암호화 (실제로는 AES 등 사용 권장)
    final encrypted = <int>[];
    for (int i = 0; i < bytes.length; i++) {
      encrypted.add(bytes[i] ^ key.codeUnitAt(i % key.length));
    }

    return base64.encode(encrypted);
  }

  /// 복호화
  static String _decrypt(String encryptedText) {
    final encrypted = base64.decode(encryptedText);
    final key = _getFixedKey(); // 동일한 고정된 키 사용

    final decrypted = <int>[];
    for (int i = 0; i < encrypted.length; i++) {
      decrypted.add(encrypted[i] ^ key.codeUnitAt(i % key.length));
    }

    return utf8.decode(decrypted);
  }

  /// 세션 만료까지 남은 시간 (분)
  static Future<int> getRemainingSessionTime() async {
    await init();
    final lastActivity = _prefs!.getInt(_keyLastActivity);
    if (lastActivity == null) return 0;

    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = now - lastActivity;
    final minutes = difference / (1000 * 60);

    return (_sessionTimeoutMinutes - minutes.round()).clamp(
      0,
      _sessionTimeoutMinutes,
    );
  }
}
