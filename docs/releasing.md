# 发布 Android 版本

Android 的应用标识为 `com.variantconst.marchkov_helper`。新 APK 必须沿用历史
Release 的签名证书，否则 Android 会拒绝覆盖升级。

## 签名要求

当前正式签名证书的 SHA-256 指纹为：

```text
7CE270503976BA420800C44C3E7DC8A8D7B305FBA8C515074ED0EBC9D79F4AA6
```

该指纹是公钥证书的摘要，只能验证签名，不能生成签名。构建正式 APK 仍需要
包含对应私钥的 keystore。证书、APK 或上面的指纹都无法还原私钥。

私钥和密码不得提交到 Git。构建前通过本机环境变量提供：

```text
MARCHKOV_KEYSTORE_PATH
MARCHKOV_KEYSTORE_PASSWORD
MARCHKOV_KEY_ALIAS
MARCHKOV_KEY_PASSWORD
```

如果缺少任一变量，Gradle 会拒绝生成 Release，避免误用 Debug 证书发布。

## GitHub Actions

`Android CI` 会在 PR 和 `main` 更新时运行测试、静态分析并生成短期 Debug APK，
不接触正式签名材料。

`Android Release` 只在推送 `vX.Y.Z` 标签或手动触发时运行。正式签名材料应配置
在名为 `release` 的 GitHub Environment 中，并建议由仓库所有者设置 required
reviewer。需要以下四个加密 Secret：

```text
MARCHKOV_KEYSTORE_BASE64
MARCHKOV_KEYSTORE_PASSWORD
MARCHKOV_KEY_ALIAS
MARCHKOV_KEY_PASSWORD
```

其中 `MARCHKOV_KEYSTORE_BASE64` 是原 keystore 文件的 Base64 内容，不是证书
指纹。工作流会将其临时解码到 Runner，先检查 keystore 证书，再构建 APK，并对
最终 APK 再检查一次相同指纹。任何 Secret 缺失或指纹不匹配都会阻止 Release。

工作流发布成功后，还需确认 `https://shuttle.variantconst.com/api/version` 和
`https://shuttle.variantconst.com/api/android_url` 已指向新版本；该站点的当前
源码与部署配置不在本仓库的 `main` 分支中。

## 发布检查

1. 运行 `flutter test` 和 `flutter analyze`。
2. 使用对应版本的 Flutter 执行 `flutter build apk --release`。
3. 用 Android SDK 的 `apksigner verify --print-certs` 检查 APK。
4. 确认证书 SHA-256 与上面的历史指纹完全一致。
5. 确认 APK 中的 `versionName`、`versionCode` 和 Git 标签一致。
6. 创建 `vX.Y.Z` 标签和 GitHub Release，再上传验证过的 APK。

如果历史私钥已经丢失，只能更换应用标识并作为新应用发布；不能从已有 APK
或证书指纹恢复私钥。
