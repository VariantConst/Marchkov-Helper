import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/auth_challenge.dart';

Future<AuthVerification?> showAuthVerificationDialog({
  required BuildContext context,
  required AuthChallenge challenge,
  required Future<String> Function() sendVerificationCode,
}) {
  return showDialog<AuthVerification>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AuthVerificationDialog(
      challenge: challenge,
      sendVerificationCode: sendVerificationCode,
    ),
  );
}

class AuthVerificationDialog extends StatefulWidget {
  final AuthChallenge challenge;
  final Future<String> Function() sendVerificationCode;

  const AuthVerificationDialog({
    super.key,
    required this.challenge,
    required this.sendVerificationCode,
  });

  @override
  State<AuthVerificationDialog> createState() => _AuthVerificationDialogState();
}

class _AuthVerificationDialogState extends State<AuthVerificationDialog> {
  final _codeController = TextEditingController();
  bool _rememberDevice = false;
  bool _isSending = false;
  String? _statusMessage;
  String? _errorMessage;

  bool get _isSms => widget.challenge.type == AuthVerificationType.sms;

  String get _codeLabel {
    if (!_isSms) {
      return '手机令牌';
    }
    return widget.challenge.emailVerification ? '邮件验证码' : '短信验证码';
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _isSending = true;
      _errorMessage = null;
      _statusMessage = null;
    });
    try {
      final message = await widget.sendVerificationCode();
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _submit() {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = '请输入$_codeLabel');
      return;
    }
    Navigator.of(context).pop(
      AuthVerification(
        type: widget.challenge.type,
        code: code,
        rememberDevice: _rememberDevice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('需要$_codeLabel'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isSms
                  ? '当前网络需要 IAAA 二次认证。请先获取验证码，再继续登录。'
                  : '当前网络需要 IAAA 手机令牌，请输入令牌中的动态验证码。',
            ),
            if (_isSms) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isSending ? null : _sendCode,
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_isSending ? '正在发送' : '获取$_codeLabel'),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              autofocus: !_isSms,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: _codeLabel,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (widget.challenge.canRememberDevice) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _rememberDevice,
                title: const Text('在此设备上记住本次验证'),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (value) {
                  setState(() => _rememberDevice = value ?? false);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('继续登录'),
        ),
      ],
    );
  }
}
