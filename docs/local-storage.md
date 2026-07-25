# 本地数据与 SharedPreferences

`SharedPreferences` 是 Flutter 对各平台简单键值存储的封装。它适合保存主题、
开关、上次刷新时间和小型缓存，不提供机密数据加密，也不应作为关键数据的
唯一存储。

## 本项目保存的内容

| 存储 | 键/内容 | 含义与安全处理 |
| --- | --- | --- |
| 系统安全存储 | `iaaa_password` | IAAA 密码；Android Keystore / Apple Keychain 加密，Web 不持久化 |
| SharedPreferences | `username`、`isLoggedIn`、`lastCookieRefreshDate` | 账号名和本机会话状态；应用沙箱内明文，不含密码 |
| SharedPreferences | `name`、`studentId`、`college`、`selectedEmoji` | 个人资料界面缓存；Android 禁止云备份 |
| SharedPreferences | `autoReservationEnabled`、`safariStyleEnabled` | 自动预约及仿官网二维码页开关；后者默认关闭 |
| SharedPreferences | `brightnessMode`、`dayBrightness`、`nightBrightness` | 亮度模式与日夜覆盖值；默认跟随系统 |
| SharedPreferences | `themeMode`、`selectedColor`、`selectedMainPageIndex` | 主题、主题色和上次选中的页面 |
| SharedPreferences | `cachedBusData`、`cachedDate`、`cachedReservedBuses` | 当日本地班车及预约缓存 |
| SharedPreferences | `cachedRideHistory`、`selected_time_range` | 乘车历史及统计页面范围 |
| SharedPreferences | `skipVersion`、年度总结提示键 | 更新提示和一次性界面提示状态 |
| SharedPreferences | `dauInstallationId`、`lastDauSentDate` | 与账号无关的随机安装标识及最近统计日期 |
| CookieJar 文件 | WProc 会话 Cookie | 应用私有目录，不输出日志，Android 禁止云备份 |

升级时，应用会把旧版 SharedPreferences 中的 `password` 迁移到系统安全存储，
随后删除明文键。退出登录也会同时清除安全存储、旧明文键和认证 Cookie。

## 文件位置与可见性

- Android 通常位于应用私有目录
  `/data/user/0/com.variantconst.marchkov_helper/shared_prefs/`。
- iOS/macOS 使用 `NSUserDefaults`，密码另存于 Keychain。
- Windows 使用当前用户的 roaming AppData。
- Web 使用 LocalStorage，但本项目不会在 Web 持久化密码。

Android 普通用户和其他应用不能直接读取应用私有目录。Root、调试版应用、
系统级恶意软件或已解锁设备仍可能访问，因此 SharedPreferences 不能替代安全
存储。卸载应用通常会删除这些数据；为避免认证数据随系统备份迁移，本项目在
Android 上设置了 `allowBackup="false"`。

仓库和 APK 只包含上述键名及默认值，不包含某台手机运行后产生的真实值。要
查看实际值，需要连接对应设备并具备该应用沙箱的调试或 Root 权限。
