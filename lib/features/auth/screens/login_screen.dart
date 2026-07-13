import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_failure.dart';
import '../providers/auth_providers.dart';

/// 로그인/회원가입 화면.
///
/// [_isSignUp] 플래그 하나로 로그인/회원가입 모드를 토글한다. 성공 시 별도
/// 네비게이션을 하지 않는다 — 인증 스트림 변화를 라우터 redirect가 감지해
/// 화면을 전환한다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// 회원가입 모드 여부. false면 로그인 모드.
  bool _isSignUp = false;

  /// 인증 요청 진행 중 여부. true 동안 버튼을 비활성화한다.
  bool _submitting = false;

  /// 마지막 인증 실패 안내 메시지. null이면 표시하지 않는다.
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 폼을 검증하고 로그인/회원가입을 수행한다.
  ///
  /// 성공 시 네비게이션하지 않는다(인증 스트림 + 라우터 redirect가 처리).
  /// [AuthFailure]는 코드별 한국어 메시지로, 그 외 예외는 기본 메시지로 안내한다.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final repo = ref.read(authRepositoryProvider);
      if (_isSignUp) {
        await repo.signUp(email, password);
      } else {
        await repo.signIn(email, password);
      }
    } on AuthFailure catch (f) {
      if (mounted) {
        setState(() => _errorMessage = f.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = AuthFailure.unknownMessage);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignUp ? '회원가입' : '로그인';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('email_field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '이메일'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return '이메일을 입력해주세요';
                    if (!text.contains('@')) return '올바른 이메일 형식이 아닙니다.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('password_field'),
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  validator: (value) {
                    final text = value ?? '';
                    if (text.isEmpty) return '비밀번호를 입력해주세요';
                    if (text.length < AuthFailure.minPasswordLength) {
                      return '비밀번호는 6자 이상이어야 합니다';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    key: const ValueKey('auth_error_text'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const ValueKey('submit_button'),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isSignUp ? '회원가입' : '로그인'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const ValueKey('toggle_mode_button'),
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                            _isSignUp = !_isSignUp;
                            _errorMessage = null;
                          }),
                  child: Text(
                    _isSignUp
                        ? '이미 계정이 있으신가요? 로그인'
                        : '계정이 없으신가요? 회원가입',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
