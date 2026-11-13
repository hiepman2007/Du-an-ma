import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../services/study_account.dart';

enum _AccountAction { signIn, signUp, reset }

class StudyAccountScreen extends StatefulWidget {
  const StudyAccountScreen({super.key});

  @override
  State<StudyAccountScreen> createState() => _StudyAccountScreenState();
}

class _StudyAccountScreenState extends State<StudyAccountScreen> {
  final _account = StudyAccount.current;
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  _AccountAction _action = _AccountAction.signIn;
  bool _busy = false;
  bool _showPassword = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _name.text = _account.displayName;
    _account.addListener(_accountChanged);
  }

  void _accountChanged() {
    if (!mounted) return;
    setState(() {
      if (_account.userId != null && _name.text.isEmpty) _name.text = _account.displayName;
      if (_account.recoveryPending) _message = null;
    });
  }

  @override
  void dispose() {
    _account.removeListener(_accountChanged);
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  void _setAction(_AccountAction action) {
    setState(() {
      _action = action;
      _message = null;
      _password.clear();
    });
  }

  String _authMessage(AuthException error) => switch (error.code) {
        'invalid_credentials' => 'Email hoặc mật khẩu chưa đúng.',
        'email_not_confirmed' => 'Hãy mở email xác nhận để kích hoạt tài khoản.',
        'over_email_send_rate_limit' => 'Đã gửi nhiều email. Vui lòng thử lại sau.',
        'weak_password' => 'Mật khẩu chưa đạt yêu cầu. Hãy chọn mật khẩu khác.',
        'same_password' => 'Hãy chọn mật khẩu khác mật khẩu cũ.',
        'otp_expired' => 'Liên kết email đã hết hạn. Hãy yêu cầu liên kết mới.',
        _ => 'Không thể thực hiện thao tác tài khoản. Vui lòng thử lại.',
      };

  Future<void> _run(Future<String?> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      message = await task();
    } on AuthException catch (error) {
      message = _authMessage(error);
    } catch (_) {
      message = 'Chưa kết nối được dịch vụ tài khoản. Vui lòng thử lại.';
    }
    if (!mounted) return;
    setState(() {
      _message = message;
      _busy = false;
    });
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final email = _email.text.trim();
    final password = _password.text;
    await _run(() async {
      if (_account.recoveryPending) {
        await _account.setPassword(password);
        _password.clear();
        return 'Đã cập nhật mật khẩu.';
      }
      switch (_action) {
        case _AccountAction.signIn:
          await _account.signIn(email, password);
          _password.clear();
          return null;
        case _AccountAction.signUp:
          final signedIn = await _account.signUp(email, password);
          _password.clear();
          return signedIn ? null : 'Hãy kiểm tra email để xác nhận tài khoản.';
        case _AccountAction.reset:
          await _account.requestPasswordReset(email);
          return 'Nếu email đã đăng ký, bạn sẽ nhận được liên kết đặt lại mật khẩu.';
      }
    });
  }

  Widget _passwordField({required bool newPassword}) => TextFormField(
        controller: _password,
        enabled: !_busy,
        obscureText: !_showPassword,
        autofillHints: [newPassword ? AutofillHints.newPassword : AutofillHints.password],
        decoration: InputDecoration(
          labelText: newPassword ? 'Mật khẩu mới' : 'Mật khẩu',
          suffixIcon: IconButton(
            tooltip: _showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Nhập mật khẩu.';
          if (newPassword && value.length < 8) return 'Dùng ít nhất 8 ký tự.';
          return null;
        },
        onFieldSubmitted: (_) => _submit(),
      );

  @override
  Widget build(BuildContext context) {
    final signedIn = _account.userId != null;
    final recovering = _account.recoveryPending;
    final actionLabel = switch (_action) {
      _AccountAction.signIn => 'Đăng nhập',
      _AccountAction.signUp => 'Đăng ký',
      _AccountAction.reset => 'Gửi liên kết đặt lại mật khẩu',
    };
    final authError = _account.authError;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              if (!_account.enabled)
                const Text('Tài khoản và đồng bộ chưa được cấu hình. Bạn vẫn có thể học trên thiết bị này.')
              else if (signedIn && !recovering) ...[
                Text(_account.email ?? '', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Tên hiển thị'),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _run(() async {
                    await _account.setDisplayName(_name.text.trim());
                    return 'Đã lưu hồ sơ.';
                  }),
                  child: const Text('Lưu hồ sơ'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(() async {
                    await _account.signOut();
                    _name.clear();
                    return 'Đã đăng xuất.';
                  }),
                  child: const Text('Đăng xuất'),
                ),
              ] else ...[
                Text(recovering ? 'Đặt mật khẩu mới' : actionLabel, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (!recovering) TextFormField(
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '') ? null : 'Nhập địa chỉ email hợp lệ.',
                      ),
                      if (recovering || _action != _AccountAction.reset) ...[
                        const SizedBox(height: 12),
                        _passwordField(newPassword: recovering || _action == _AccountAction.signUp),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _busy ? null : _submit, child: Text(recovering ? 'Lưu mật khẩu' : actionLabel)),
                    ]),
                  ),
                ),
                if (!recovering) ...[
                  if (_action != _AccountAction.signIn)
                    TextButton(onPressed: _busy ? null : () => _setAction(_AccountAction.signIn), child: const Text('Quay lại đăng nhập')),
                  if (_action == _AccountAction.signIn) ...[
                    TextButton(onPressed: _busy ? null : () => _setAction(_AccountAction.signUp), child: const Text('Tạo tài khoản')),
                    TextButton(onPressed: _busy ? null : () => _setAction(_AccountAction.reset), child: const Text('Quên mật khẩu')),
                  ],
                ],
              ],
              if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
              if (_message != null || authError is AuthException)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(liveRegion: true, child: Text(_message ?? _authMessage(authError as AuthException))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
