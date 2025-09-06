// lib/app/env_app.dart
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://ctrl-bent-fort-lip.trycloudflare.com', // 👍 프로덕션 기본값
);

Uri api(String path, [Map<String, dynamic>? qp]) {
  final base = Uri.parse(apiBase);
  return base.replace(path: '${base.path}/api$path', queryParameters: qp);
}
