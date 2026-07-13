import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/auth/models/auth_failure.dart';

void main() {
  group('AuthFailure.fromCode', () {
    const codes = [
      'invalid-email',
      'user-not-found',
      'wrong-password',
      'invalid-credential',
      'email-already-in-use',
      'weak-password',
      'network-request-failed',
      'too-many-requests',
    ];

    test('알려진 8개 코드 모두 비어 있지 않은 한국어 메시지를 반환한다', () {
      for (final code in codes) {
        final message = AuthFailure.fromCode(code).message;
        expect(message, isNotEmpty, reason: '$code 코드 메시지가 비어 있음');
      }
    });

    test('알 수 없는 코드는 비어 있지 않은 기본 메시지를 반환한다', () {
      final message = AuthFailure.fromCode('some-unknown-code').message;
      expect(message, isNotEmpty);
    });

    test('주요 코드들의 메시지는 서로 구별된다', () {
      final messages = {
        for (final code in codes) AuthFailure.fromCode(code).message,
      };
      // 8개 코드가 모두 고유한 메시지로 매핑되는지 확인한다.
      expect(messages.length, codes.length);
    });
  });
}
