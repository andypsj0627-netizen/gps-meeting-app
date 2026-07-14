import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/my_profile_provider.dart';

/// 마이 탭 — 프로필/설정 진입점.
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  /// 성별 코드('m'/'f')를 한국어 라벨로 바꾼다. 미지정이면 빈 문자열.
  String _genderLabel(String gender) {
    switch (gender) {
      case 'm':
        return '남';
      case 'f':
        return '여';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final genderLabel = _genderLabel(profile.gender);
    final subtitle = genderLabel.isEmpty
        ? '${profile.age}세'
        : '${profile.age}세 · $genderLabel';

    final children = <Widget>[
      ListTile(
        leading: CircleAvatar(
          child: Text(
            profile.name.isEmpty ? '?' : profile.name.characters.first,
          ),
        ),
        title: Text(profile.name),
        subtitle: Text(subtitle),
      ),
      const Divider(height: 0),
      const ListTile(
        enabled: false,
        leading: Icon(Icons.edit),
        title: Text('프로필 수정'),
        subtitle: Text('준비중'),
      ),
    ];

    if (ref.watch(requireLoginProvider)) {
      children.add(
        ListTile(
          key: const ValueKey('logout_button'),
          leading: const Icon(Icons.logout),
          title: const Text('로그아웃'),
          onTap: () async {
            try {
              await ref.read(authRepositoryProvider).signOut();
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('로그아웃에 실패했어요. 다시 시도해주세요.'),
                  ),
                );
              }
            }
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('마이')),
      body: ListView(children: children),
    );
  }
}
