import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/error_dialog.dart';
import '../main/main_page.dart'; // 添加这行，确保路径正确

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
                  // 关闭按钮
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: Icon(Icons.close,
                          color: Theme.of(context).colorScheme.onSurface),
                      onPressed: () {
                        // 关闭操作
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  // 标题
                  Text(
                    'Welcome to Marchkov Helper',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 10),
                  // 描述
                  Text(
                    'The most advanced tool for Marchkov algorithms',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 30),
                  // 用户名输入
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Username',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6)),
                    ),
                    onSaved: (value) => _username = value!,
                    validator: (value) => value!.isEmpty ? '请输入用户名' : null,
                  ),
                  SizedBox(height: 20),
                  // 密码输入
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Password',
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6)),
                    ),
                    obscureText: true,
                    onSaved: (value) => _password = value!,
                    validator: (value) => value!.isEmpty ? '请输入密码' : null,
                  ),
                  SizedBox(height: 20),
                  // 同意条款
                  Row(
                    children: [
                      Checkbox(
                        value: _agreeToTerms,
                        onChanged: (bool? value) {
                          setState(() {
                            _agreeToTerms = value!;
                          });
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'I agree to the terms of service',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                            Text(
                              'By continuing, you agree to our Privacy Policy and Terms of Service',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  // 登录按钮
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
                        'Log in',
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
