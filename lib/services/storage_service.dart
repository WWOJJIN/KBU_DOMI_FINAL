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

    // 세션 유효성 검사
    if (!await _isSessionValid()) {
      await clearAll();
      return null;
    }

    final encrypted = _prefs!.getString(_keyStudentInfo);
    if (encrypted == null) return null;

    try {
      final decrypted = _decrypt(encrypted);
      await _updateLastActivity();
      return json.decode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      print('학생 정보 복호화 실패: $e');
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
    await _prefs!.setInt(_keyStudentPageIndex, index);
    await _updateLastActivity();
  }

  /// 학생 페이지 인덱스 불러오기
  static Future<int> getStudentPageIndex() async {
    await init();
    if (!await _isSessionValid()) return 2; // 홈 페이지 기본값
    return _prefs!.getInt(_keyStudentPageIndex) ?? 2;
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
    if (lastActivity == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final difference = now - lastActivity;
    final minutes = difference / (1000 * 60);

    return minutes < _sessionTimeoutMinutes;
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

  /// 간단한 암호화 (실제 운영환경에서는 더 강력한 암호화 사용 권장)
  static String _encrypt(String text) {
    final bytes = utf8.encode(text);
    final digest = sha256.convert(bytes);
    final key = digest.toString().substring(0, 16);

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
    final tempBytes = utf8.encode('temp'); // 실제로는 고정된 키 사용
    final digest = sha256.convert(tempBytes);
    final key = digest.toString().substring(0, 16);

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
