import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart'; // 新增
import 'package:path/path.dart' as path; // 新增
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart'; // 新增
import '../login/login_page.dart';
import '../../services/user_service.dart';
import 'theme_settings_page.dart'; // 新增
import 'visualization_page.dart'; // 新增

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
    Provider.of<ThemeProvider>(context); // 修改这一行

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    width: double.infinity, // 设置卡片宽度为无限
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.8),
                                backgroundImage: _avatarPath != null
                                    ? FileImage(File(_avatarPath!))
                                    : null,
                                child: _avatarPath == null
                                    ? Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                            fontSize: 48, color: Colors.white),
                                      )
                                    : null,
                              ),
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Theme.of(context).primaryColor,
                                child: Icon(Icons.camera_alt,
                                    color: Colors.white, size: 20),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          name,
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 12),
                        Text(
                          college,
                          style:
                              TextStyle(fontSize: 20, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 16),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.school,
                                  size: 24,
                                  color: Theme.of(context).primaryColor),
                              SizedBox(width: 8),
                              Text(
                                studentId,
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),
                // 主题设置按钮
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ThemeSettingsPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('主题设置'),
                      Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // 可视化设置按钮
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => VisualizationSettingsPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    minimumSize: Size(double.infinity, 50),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('可视化设置'),
                      Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // 退出登录按钮
                ElevatedButton.icon(
                  icon: Icon(Icons.exit_to_app),
                  label: Text('退出登录'),
                  onPressed: () async {
                    final navigator =
                        Navigator.of(context); // 在异步操作前获取 navigator
                    await _clearUserInfo();
                    await authProvider.logout();
                    if (!mounted) return; // 检查组件是否仍然挂载
                    navigator.pushReplacement(
                        MaterialPageRoute(builder: (_) => LoginPage()));
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    minimumSize: Size(double.infinity, 50),
                    backgroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('name');
    await prefs.remove('studentId');
    await prefs.remove('college');
    await prefs.remove('avatarPath');
  }
}
