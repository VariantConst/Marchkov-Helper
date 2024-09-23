import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // 新增
import 'package:path/path.dart' as path; // 新增
import '../../providers/auth_provider.dart';
// 新增
import '../login/login_page.dart';
import '../../services/user_service.dart';
import 'theme_settings_page.dart'; // 新增
import '../visualization/visualization_page.dart'; // 新增
import 'about_page.dart'; // 新增

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState(); // 修改这一行
}

class _SettingsPageState extends State<SettingsPage> {
  String name = '';
  String studentId = '';
  String college = '';
  late UserService _userService;
  String? _avatarPath; // 修改：存储头像的本地路径

  @override
  void initState() {
    super.initState();
    _userService = UserService(context.read<AuthProvider>());
    _loadUserInfo();
    _loadAvatarPath(); // 确保加载头像路径
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name = prefs.getString('name') ?? '';
      studentId = prefs.getString('studentId') ?? '';
      college = prefs.getString('college') ?? '';
    });

    if (name.isEmpty || studentId.isEmpty || college.isEmpty) {
      await fetchUserInfo();
    }
  }

  Future<void> fetchUserInfo() async {
    try {
      final userInfo = await _userService.fetchUserInfo();
      setState(() {
        name = userInfo['name'] ?? '';
        studentId = userInfo['studentId'] ?? '';
        college = userInfo['college'] ?? '';
      });
      _saveUserInfo();
    } catch (e) {
      print('获取用户信息失败: $e');
    }
  }

  Future<void> _saveUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', name);
    await prefs.setString('studentId', studentId);
    await prefs.setString('college', college);
  }

  Future<void> _loadAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    final fileName = prefs.getString('avatarFileName');
    if (fileName != null) {
      final appDir = await getApplicationDocumentsDirectory();
      setState(() {
        _avatarPath = path.join(appDir.path, fileName);
      });
    }
  }

  Future<void> _saveAvatarFileName(String fileName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatarFileName', fileName);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (!mounted) return; // 添加这行检查

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 100,
        maxWidth: 256,
        maxHeight: 256,
        compressFormat: ImageCompressFormat.png,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: '裁剪图片',
            toolbarColor: Theme.of(context).primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: '裁剪图片',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        if (!mounted) return; // 再次添加检查

        // 获取应用的文档目录
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(croppedFile.path);

        // 将裁剪后的图片复制到文档目录
        final savedImage =
            await File(croppedFile.path).copy('${appDir.path}/$fileName');

        setState(() {
          _avatarPath = savedImage.path;
        });

        await _saveAvatarFileName(fileName); // 保存头像文件名
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.white, // 设置背景颜色为白色
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Profile',
                style: TextStyle(
                  color: Color(0xFF111418),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 头像和用户信息
            SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Color(0xFFF0F2F5),
                backgroundImage:
                    _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
                child: _avatarPath == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style:
                            TextStyle(fontSize: 48, color: Color(0xFF60708A)),
                      )
                    : null,
              ),
            ),
            SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                color: Color(0xFF111418),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              college,
              style: TextStyle(
                color: Color(0xFF111418),
                fontSize: 16,
              ),
            ),
            Text(
              'ID: $studentId',
              style: TextStyle(
                color: Color(0xFF60708A),
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            // 设置选项列表
            Expanded(
              child: ListView(
                children: [
                  _buildSettingOption(
                    title: '主题设置',
                    icon: Icons.palette,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ThemeSettingsPage()),
                      );
                    },
                  ),
                  _buildSettingOption(
                    title: '乘车历史',
                    icon: Icons.history,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => VisualizationSettingsPage()),
                      );
                    },
                  ),
                  _buildSettingOption(
                    title: '关于',
                    icon: Icons.info,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AboutPage()),
                      );
                    },
                  ),
                  SizedBox(height: 16),
                  // 退出登录按钮
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.logout),
                      label: Text('退出登录'),
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await _clearUserInfo();
                        await authProvider.logout();
                        if (!mounted) return;
                        navigator.pushReplacement(
                            MaterialPageRoute(builder: (_) => LoginPage()));
                      },
                      style: ElevatedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        minimumSize: Size(double.infinity, 50),
                        backgroundColor: Color(0xFFF0F2F5),
                        foregroundColor: Color(0xFF111418),
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingOption(
      {required String title,
      required IconData icon,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Color(0xFF111418)),
      title: Text(
        title,
        style: TextStyle(
          color: Color(0xFF111418),
          fontSize: 16,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, color: Color(0xFF111418)),
      onTap: onTap,
    );
  }

  Future<void> _clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('name');
    await prefs.remove('studentId');
    await prefs.remove('college');
    await prefs.remove('avatarPath');
    // 添加以下代码，清除历史乘车记录的缓存
    await prefs.remove('cachedRideHistory');
  }
}
