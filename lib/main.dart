import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:permission_handler/permission_handler.dart';
// 删除未使用的导入
// import 'package:geolocator/geolocator.dart';

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

  void login(String username, String password) async {
    // 这里实现实际的登录请求
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

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      token = jsonResponse['token'];
      isLoggedIn = true;
      notifyListeners();
    } else {
      throw Exception('登录失败');
    }
  }

  void logout() {
    isLoggedIn = false;
    token = '';
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
    // 删除 internet 权限请求，因为它不是 Permission 类的一部分
    // await Permission.internet.request();
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
                  if (_formKey.currentState!.validate() && _agreeToTerms) {
                    _formKey.currentState!.save();
                    context.read<AppState>().login(_username, _password);
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
          // 实现乘车功能
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
                icon: Icon(Icons.book), onPressed: () => _onItemTapped(0)),
            SizedBox(width: 48),
            IconButton(
                icon: Icon(Icons.settings), onPressed: () => _onItemTapped(1)),
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

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        child: Text('退出登录'),
        onPressed: () {
          context.read<AppState>().logout();
        },
      ),
    );
  }
}
