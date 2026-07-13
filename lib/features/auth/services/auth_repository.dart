import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/auth_failure.dart';
import '../models/auth_user.dart';

/// Firebase Auth와 Firestore 접근을 감싸는 인증 repository.
///
/// firebase_auth의 `User`를 외부로 노출하지 않고 [AuthUser] 경계 모델로 변환해
/// 반환한다. firebase_auth의 예외 또한 [AuthFailure] 경계 예외로 승격해 노출하여,
/// 화면/테스트가 firebase_auth에 의존하지 않게 한다. 생성자에 fake 인스턴스를
/// 주입할 수 있어 테스트가 실제 Firebase에 닿지 않게 할 수 있다.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// 인증 상태 변화를 [AuthUser] 스트림으로 방출한다.
  ///
  /// 로그아웃 상태는 null로 표현한다.
  Stream<AuthUser?> authStateChanges() {
    return _auth.authStateChanges().map(
          (user) => user == null
              ? null
              : AuthUser(uid: user.uid, email: user.email ?? ''),
        );
  }

  /// 이메일/비밀번호로 로그인한다.
  ///
  /// firebase_auth의 [FirebaseAuthException]은 [AuthFailure] 경계 예외로 승격해
  /// 던진다 — 화면/테스트가 firebase_auth에 의존하지 않게 하기 위함이다.
  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  /// 이메일/비밀번호로 회원가입하고 프로필 문서를 생성한다.
  ///
  /// [createUserWithEmailAndPassword]가 던지는 FirebaseAuthException은
  /// [AuthFailure] 경계 예외로 승격해 화면에서 사용자에게 안내한다. 다만 프로필
  /// 문서 생성 실패는 가입 실패로 전파하지 않는다 — 프로필 화면에서 재생성
  /// 가능하기 때문이다.
  Future<void> signUp(String email, String password) async {
    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
    final uid = credential.user?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // 프로필 문서 생성 실패는 가입 실패로 전파하지 않는다 — 프로필 화면에서
      // 재생성 가능.
      debugPrint('프로필 문서 생성 실패 — 무시합니다: $e');
    }
  }

  /// 로그아웃한다.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
