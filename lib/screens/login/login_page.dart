import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/auth_challenge.dart';
import './username_field.dart';
import './password_field.dart';
import './auth_verification_dialog.dart';
import '../main/main_page.dart';
import '../../widgets/error_dialog.dart';

class LoginPage extends StatefulWidget {
  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  bool _agreeToTerms = false;
  bool _isLoggingIn = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // 权限请求逻辑
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('用户须知'),
          content: SingleChildScrollView(
            child: Text(
              '我们将采集以SHA256加密后的用户名、版本号及设备类型，用于统计每日活跃用户数。您的用户名和密码将始终安全保存在您的设备上，不会上传至服务器。',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('关闭'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Marchkov Helper',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      '新燕园人的出行助手',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 30),
                    UsernameField(
                      onSaved: (value) => _username = value!,
                      validator: (value) =>
                          value!.isEmpty ? '请输入学号/职工号/手机号' : null,
                    ),
                    SizedBox(height: 20),
                    PasswordField(
                      onSaved: (value) => _password = value!,
                      validator: (value) => value!.isEmpty ? '请输入密码' : null,
                    ),
                    SizedBox(height: 20),
                    AnimatedTermsCheckbox(
                      value: _agreeToTerms,
                      onChanged: (bool? value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                        });
                      },
                      onTermsTap: _showTermsDialog,
                    ),
                    SizedBox(height: 30),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoggingIn
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  if (!_agreeToTerms) {
                                    showErrorDialog(context, '请同意用户须知');
                                  } else {
                                    _formKey.currentState!.save();
                                    _login();
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        child: _isLoggingIn
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                ),
                              )
                            : Text(
                                '登录',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_isLoggingIn) {
      return;
    }
    setState(() => _isLoggingIn = true);

    final authProvider = context.read<AuthProvider>();
    try {
      final challenge = await authProvider.prepareLogin(_username);
      if (!mounted) {
        return;
      }

      AuthVerification? verification;
      if (challenge.requiresVerification) {
        verification = await showAuthVerificationDialog(
          context: context,
          challenge: challenge,
          sendVerificationCode: () =>
              authProvider.sendVerificationCode(_username),
        );
        if (verification == null || !mounted) {
          return;
        }
      }

      await authProvider.login(
        _username,
        _password,
        verification: verification,
      );
      if (mounted) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => MainPage()));
      }
    } catch (error) {
      if (mounted) {
        showErrorDialog(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingIn = false);
      }
    }
  }
}

class AnimatedTermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTermsTap;

  const AnimatedTermsCheckbox({
    required this.value,
    required this.onChanged,
    required this.onTermsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: value
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            border: Border.all(
              color: value
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha((0.6 * 255).toInt()),
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => onChanged(!value),
            child: Center(
              child: value
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Icon(
                            Icons.check,
                            size: 18,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        );
                      },
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: onTermsTap,
            child: RichText(
              text: TextSpan(
                text: '我已阅读并同意',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                children: [
                  TextSpan(
                    text: '用户须知',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
