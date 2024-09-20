import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/error_dialog.dart';

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
      appBar: AppBar(title: Text('登录')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: '用户名'),
                onSaved: (value) => _username = value!,
                validator: (value) => value!.isEmpty ? '请输入用户名' : null,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: '密码'),
                obscureText: true,
                onSaved: (value) => _password = value!,
                validator: (value) => value!.isEmpty ? '请输入密码' : null,
              ),
              CheckboxListTile(
                title: Text('我同意用户协议'),
                value: _agreeToTerms,
                onChanged: (bool? value) {
                  setState(() {
                    _agreeToTerms = value!;
                  });
                },
              ),
              ElevatedButton(
                child: Text('登录'),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _login() async {
    try {
      await context.read<AuthProvider>().login(_username, _password);
    } catch (error) {
      if (mounted) {
        showErrorDialog(context, error.toString());
      }
    }
  }
}
