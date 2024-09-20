import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import './close_button.dart';
import './username_field.dart';
import './password_field.dart';
import './terms_checkbox.dart';
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

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // 权限请求逻辑
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  CloseButtonWidget(),
                  SizedBox(height: 20),
                  Text(
                    '欢迎使用校园出行',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  Text(
                    '最先进的校园出行工具',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                  UsernameField(
                    onSaved: (value) => _username = value!,
                    validator: (value) => value!.isEmpty ? '请输入用户名' : null,
                  ),
                  SizedBox(height: 20),
                  PasswordField(
                    onSaved: (value) => _password = value!,
                    validator: (value) => value!.isEmpty ? '请输入密码' : null,
                  ),
                  SizedBox(height: 20),
                  TermsCheckbox(
                    agreeToTerms: _agreeToTerms,
                    onChanged: (bool? value) {
                      setState(() {
                        _agreeToTerms = value ?? false;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          if (!_agreeToTerms) {
                            showErrorDialog(context, '请同意用户协议');
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                      child: Text(
                        '登录',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
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
    );
  }

  void _login() async {
    try {
      await context.read<AuthProvider>().login(_username, _password);
      if (mounted) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => MainPage()));
      }
    } catch (error) {
      if (mounted) {
        showErrorDialog(context, error.toString());
      }
    }
  }
}
