import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../models/auth_user.dart';
import '../services/auth_repository.dart';

/// 인증 repository provider. 테스트에서 fake로 override한다.
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

/// 인증 상태 변화를 방출하는 provider.
///
/// Firebase 초기화 전에 `FirebaseAuth.instance`에 닿으면 안 되므로,
/// [firebaseInitProvider].future를 먼저 await한 뒤 authStateChanges 스트림을
/// 흘려보낸다.
final authStateChangesProvider = StreamProvider<AuthUser?>((ref) async* {
  await ref.watch(firebaseInitProvider.future);
  yield* ref.watch(authRepositoryProvider).authStateChanges();
});
