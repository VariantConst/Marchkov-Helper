import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MyApp(),
    ),
  );
}

class AppState extends ChangeNotifier {
  bool isLoggedIn = false;
  String token = '';
  String username = '';
  String loginResponse = '';

  Future<void> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('https://iaaa.pku.edu.cn/iaaa/oauthlogin.do'),
        body: {
          'appid': 'wproc',
          'userName': username,
          'password': password,
          'redirUrl':
              'https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/',
        },
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
        },
      );

      loginResponse = const JsonEncoder.withIndent('  ')
          .convert(json.decode(response.body));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        token = jsonResponse['token'];
        isLoggedIn = true;
        this.username = username;
        await _saveUsername(username);
        notifyListeners();
      } else {
        throw Exception('登录失败');
      }
    } catch (e) {
      throw Exception('登录失败: $e');
    }
  }

  Future<void> logout() async {
    isLoggedIn = false;
    token = '';
    username = '';
    loginResponse = '';
    await _removeUsername();
    notifyListeners();
  }

  Future<void> _saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
  }

  Future<void> _removeUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
  }

  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username') ?? '';
    notifyListeners();
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '校园出行',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<AppState>(
        builder: (context, appState, child) {
          return appState.isLoggedIn ? MainPage() : LoginPage();
        },
      ),
    );
  }
}

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
    await Permission.location.request();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('错误'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('确定'),
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
                      _showErrorDialog('请同意用户协议');
                    } else {
                      _formKey.currentState!.save();
                      context
                          .read<AppState>()
                          .login(_username, _password)
                          .catchError((error) {
                        _showErrorDialog(error.toString());
                      });
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
}

class MainPage extends StatefulWidget {
  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  static List<Widget> _widgetOptions = <Widget>[
    ReservationPage(),
    RidePage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () {
          setState(() {
            _selectedIndex = 1; // 直接设置索引为1，对应RidePage
          });
        },
        child: Icon(Icons.directions_car),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: Icon(Icons.book),
              onPressed: () => _onItemTapped(0),
              color: _selectedIndex == 0 ? Colors.blue : null,
            ),
            SizedBox(width: 48),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () => _onItemTapped(2),
              color: _selectedIndex == 2 ? Colors.blue : null,
            ),
          ],
        ),
      ),
    );
  }
}

class ReservationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('预约页面'));
  }
}

class RidePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('乘车页面'));
  }
}

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用户名: ${appState.username}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 16),
            Text('登录响应:', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(appState.loginResponse,
                  style: TextStyle(fontFamily: 'Courier')),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              child: Text('退出登录'),
              onPressed: () {
                appState.logout();
                Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => LoginPage()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
