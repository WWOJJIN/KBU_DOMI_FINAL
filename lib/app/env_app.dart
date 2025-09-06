// lib/app/env_app.dart
const String apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://web-nine-beta-10.vercel.app', // 👍 프로덕션 기본값
);
