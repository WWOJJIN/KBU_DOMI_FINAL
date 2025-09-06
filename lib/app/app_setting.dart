import 'package:flutter/material.dart';
import 'package:kbu_domi/app/env_app.dart';

class AppSetting extends StatelessWidget {
  const AppSetting({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✨ 1. Scaffold의 배경색을 흰색으로 설정
      backgroundColor: Colors.white,
      appBar: AppBar(
        // ✨ 2. AppBar의 배경색을 흰색으로 설정
        backgroundColor: Colors.white,
        // ✨ 3. AppBar의 그림자 효과 제거
        elevation: 0,
        leading: IconButton(
          // 아이콘 색이 자동으로 검은색으로 변경됩니다.
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // 제목 색이 자동으로 검은색으로 변경됩니다.
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('알림 설정'),
            subtitle: Text('앱 알림을 켜거나 끄세요.'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.info),
            title: Text('앱 정보'),
            subtitle: Text('버전, 개발자 등 정보'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.payment),
            title: Text('결제 정보'),
            subtitle: Text('등록된 결제수단, 영수증 조회'),
          ),
        ],
      ),
    );
  }
}
