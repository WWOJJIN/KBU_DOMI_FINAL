// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// 웹에서 postMessage 수신
void listenMessage(void Function(dynamic data) onMessage) {
  html.window.onMessage.listen((event) => onMessage(event.data));
}

/// 새 탭 열기
void openNewTab(String url) {
  html.window.open(url, '_blank');
}

/// 팝업 창 열기
void openPopup(String url, String name, String features) {
  html.window.open(url, name, features);
}
