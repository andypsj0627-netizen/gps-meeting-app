/// 인증 경계 모델.
///
/// firebase_auth의 `User`를 앱 내부로 그대로 노출하지 않기 위한 경량 값 객체다.
/// 이렇게 firebase_auth와 분리해 두면 테스트에서 실제 Firebase에 닿지 않고도
/// 인증 상태를 표현할 수 있어 테스트 용이성이 높아진다.
class AuthUser {
  const AuthUser({required this.uid, required this.email});

  /// Firebase 사용자 고유 식별자.
  final String uid;

  /// 사용자 이메일. Firebase User.email이 null이면 빈 문자열로 대체한다.
  final String email;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser && other.uid == uid && other.email == email;

  @override
  int get hashCode => Object.hash(uid, email);

  @override
  String toString() => 'AuthUser(uid: $uid, email: $email)';
}
