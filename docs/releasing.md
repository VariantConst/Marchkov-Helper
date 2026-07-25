# 发布 Android 版本

Android 的应用标识为 `com.variantconst.marchkov_helper`。新 APK 必须沿用历史
Release 的签名证书，否则 Android 会拒绝覆盖升级。

## 签名要求

当前正式签名证书的 SHA-256 指纹为：

```text
7CE270503976BA420800C44C3E7DC8A8D7B305FBA8C515074ED0EBC9D79F4AA6
```

私钥和密码不得提交到 Git。构建前通过本机环境变量提供：

```text
MARCHKOV_KEYSTORE_PATH
MARCHKOV_KEYSTORE_PASSWORD
MARCHKOV_KEY_ALIAS
MARCHKOV_KEY_PASSWORD
```

如果缺少任一变量，Gradle 会拒绝生成 Release，避免误用 Debug 证书发布。

## 发布检查

1. 运行 `flutter test` 和 `flutter analyze`。
2. 使用对应版本的 Flutter 执行 `flutter build apk --release`。
3. 用 Android SDK 的 `apksigner verify --print-certs` 检查 APK。
4. 确认证书 SHA-256 与上面的历史指纹完全一致。
5. 确认 APK 中的 `versionName`、`versionCode` 和 Git 标签一致。
6. 创建 `vX.Y.Z` 标签和 GitHub Release，再上传验证过的 APK。

如果历史私钥已经丢失，只能更换应用标识并作为新应用发布；不能从已有 APK
或证书指纹恢复私钥。
