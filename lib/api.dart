// lib/api.dart
import 'api_client.dart';

final dio = createDio(); // 또는 createDio(useCookies: true);

Future<Map<String, dynamic>> login({
  required String studentId,
  required String password,
}) async {
  final res = await dio.post(
    '/api/login',
    data: {
      'student_id': studentId,
      'password': password,
      'login_type': '재학생',
      'user_type': 'current_student',
      'redirect_to': 'portal',
    },
  );
  return Map<String, dynamic>.from(res.data);
}
