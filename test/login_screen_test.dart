import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gps_meeting_app/features/auth/models/auth_failure.dart';
import 'package:gps_meeting_app/features/auth/models/auth_user.dart';
import 'package:gps_meeting_app/features/auth/providers/auth_providers.dart';
import 'package:gps_meeting_app/features/auth/screens/login_screen.dart';
import 'package:gps_meeting_app/features/auth/services/auth_repository.dart';

/// AuthRepository를 `implements`로 대체하는 fake.
///
/// `extends`가 아니라 `implements`를 쓰는 이유: extends는 슈퍼클래스 생성자를
/// 실행하므로 `FirebaseAuth.instance`가 평가되어 테스트가 실제 Firebase에 닿는다.
/// implements는 생성자를 실행하지 않아 그 문제가 없다.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.signInError, this.signInCompleter});

  /// signIn 호출 시 던질 예외(없으면 정상 완료).
  final Object? signInError;

  /// 로딩 상태 테스트용: 완료를 지연시킬 때 사용한다.
  final Completer<void>? signInCompleter;

  bool signInCalled = false;
  bool signUpCalled = false;
  bool signOutCalled = false;
  String? capturedEmail;
  String? capturedPassword;

  @override
  Future<void> signIn(String email, String password) async {
    signInCalled = true;
    capturedEmail = email;
    capturedPassword = password;
    if (signInCompleter != null) await signInCompleter!.future;
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> signUp(String email, String password) async {
    signUpCalled = true;
    capturedEmail = email;
    capturedPassword = password;
    if (signInError != null) throw signInError!;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Stream<AuthUser?> authStateChanges() => const Stream<AuthUser?>.empty();
}

Widget _wrap(_FakeAuthRepository fake) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
    child: const MaterialApp(home: LoginScreen()),
  );
}

void main() {
  testWidgets('빈 입력으로 제출하면 검증이 막아 repository를 호출하지 않는다',
      (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_wrap(fake));

    await tester.tap(find.byKey(const ValueKey('submit_button')));
    await tester.pump();

    expect(fake.signInCalled, isFalse);
    // 검증 에러 텍스트가 나타난다.
    expect(find.text('이메일을 입력해주세요'), findsOneWidget);
  });

  testWidgets('유효 입력으로 제출하면 입력값으로 signIn을 호출한다', (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_wrap(fake));

    await tester.enterText(
        find.byKey(const ValueKey('email_field')), 'test@example.com');
    await tester.enterText(
        find.byKey(const ValueKey('password_field')), 'password123');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('submit_button')));
    await tester.pumpAndSettle();

    expect(fake.signInCalled, isTrue);
    expect(fake.capturedEmail, 'test@example.com');
    expect(fake.capturedPassword, 'password123');
  });

  testWidgets('signIn이 AuthFailure를 던지면 에러 텍스트를 표시한다',
      (tester) async {
    final fake = _FakeAuthRepository(
      signInError: AuthFailure.fromCode('wrong-password'),
    );
    await tester.pumpWidget(_wrap(fake));

    await tester.enterText(
        find.byKey(const ValueKey('email_field')), 'test@example.com');
    await tester.enterText(
        find.byKey(const ValueKey('password_field')), 'password123');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('submit_button')));
    await tester.pumpAndSettle();

    final errorFinder = find.byKey(const ValueKey('auth_error_text'));
    expect(errorFinder, findsOneWidget);
    final errorText = tester.widget<Text>(errorFinder);
    expect(errorText.data, isNotEmpty);
  });

  testWidgets('모드 토글 시 제출 버튼 라벨이 로그인/회원가입으로 바뀐다',
      (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(_wrap(fake));

    // 초기: 로그인 모드
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('submit_button')),
        matching: find.text('로그인'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('toggle_mode_button')));
    await tester.pump();

    // 토글 후: 회원가입 모드
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('submit_button')),
        matching: find.text('회원가입'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('제출 중에는 submit_button의 onPressed가 null이다', (tester) async {
    final completer = Completer<void>();
    final fake = _FakeAuthRepository(signInCompleter: completer);
    await tester.pumpWidget(_wrap(fake));

    await tester.enterText(
        find.byKey(const ValueKey('email_field')), 'test@example.com');
    await tester.enterText(
        find.byKey(const ValueKey('password_field')), 'password123');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('submit_button')));
    await tester.pump();

    // 완료 전: 버튼이 비활성화되어 있다.
    final button = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('submit_button')),
    );
    expect(button.onPressed, isNull);

    completer.complete();
    await tester.pumpAndSettle();
  });
}
