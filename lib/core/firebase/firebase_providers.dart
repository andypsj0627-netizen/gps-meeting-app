import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

/// Firebase 초기화를 첫 프레임 경로 밖에서 수행하는 provider.
///
/// 초기화는 첫 프레임 이후 시작되어 스플래시가 그 시간을 가리고, auth가
/// 라우팅 게이트로서 초기화 완료를 기다린다.
/// 테스트에서는 no-op으로 override하여 실제 Firebase에 닿지 않게 한다.
final firebaseInitProvider = FutureProvider<void>((ref) async {
  // hang을 에러로 전환해, 스플래시에서 복구 UI(다시 시도)를 띄울 수 있게 한다.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).timeout(const Duration(seconds: 10));
});
