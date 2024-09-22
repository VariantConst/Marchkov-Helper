import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart'; // 新增
import '../login/login_page.dart';
import '../../services/user_service.dart';
import 'theme_settings_page.dart'; // 新增

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState(); // 修改这一行
}

class _SettingsPageState extends State<SettingsPage> {
  String name = '';
  String studentId = '';
  String college = '';
  late UserService _userService;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _userService = UserService(context.read<AuthProvider>());
    fetchUserInfo();
  }

  Future<void> fetchUserInfo() async {
    try {
      final userInfo = await _userService.fetchUserInfo();
      setState(() {
        name = userInfo['name'] ?? '';
        studentId = userInfo['studentId'] ?? '';
        college = userInfo['college'] ?? '';
      });
    } catch (e) {
      print('获取用户信息失败: $e');
    }
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

        setState(() {
          _imageFile = File(croppedFile.path);
        });
        // 这里可以添加上传图片到服务器的逻辑
        // await _userService.uploadAvatar(_imageFile);
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
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Theme.of(context).primaryColor,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : null,
                            child: _imageFile == null
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        fontSize: 32, color: Colors.white),
                                  )
                                : null,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          name,
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          college,
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.school,
                                size: 20, color: Colors.grey[600]),
                            SizedBox(width: 8),
                            Text(
                              studentId,
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
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
                // 退出登录按钮
                ElevatedButton.icon(
                  icon: Icon(Icons.exit_to_app),
                  label: Text('退出登录'),
                  onPressed: () {
                    authProvider.logout();
                    Navigator.of(context).pushReplacement(
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
}
