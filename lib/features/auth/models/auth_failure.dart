/// 인증 실패를 나타내는 예외.
///
/// FirebaseAuthException 코드를 사용자에게 보여줄 한국어 메시지로 변환해 담는다.
/// firebase_auth에 의존하지 않는 값 객체로 두어, 화면/테스트가 firebase_auth를
/// import하지 않고도 인증 실패를 표현·검증할 수 있게 한다(경계 격리).
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  /// 에러 코드를 한국어 안내 메시지로 매핑해 AuthFailure를 만든다.
  factory AuthFailure.fromCode(String code) {
    switch (code) {
      case 'invalid-email':
        return const AuthFailure('올바른 이메일 형식이 아닙니다.');
      case 'user-not-found':
        return const AuthFailure('등록되지 않은 이메일입니다.');
      case 'wrong-password':
        return const AuthFailure('비밀번호가 올바르지 않습니다.');
      case 'invalid-credential':
        return const AuthFailure('이메일 또는 비밀번호가 올바르지 않습니다.');
      case 'email-already-in-use':
        return const AuthFailure('이미 사용 중인 이메일입니다.');
      case 'weak-password':
        return const AuthFailure('비밀번호가 너무 약합니다. 6자 이상으로 설정해주세요.');
      case 'network-request-failed':
        return const AuthFailure('네트워크 연결을 확인해주세요.');
      case 'too-many-requests':
        return const AuthFailure('요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
      default:
        return const AuthFailure(unknownMessage);
    }
  }

  /// 사용자에게 보여줄 한국어 안내 메시지.
  final String message;

  /// 알 수 없는 오류의 기본 안내 메시지.
  static const String unknownMessage = '문제가 발생했어요. 잠시 후 다시 시도해주세요.';

  /// 회원가입 최소 비밀번호 길이. login 화면 validator와 매핑 문구가 공유한다.
  static const int minPasswordLength = 6;

  @override
  String toString() => 'AuthFailure: $message';
}
