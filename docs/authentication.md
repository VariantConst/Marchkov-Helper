# IAAA 与 WProc 认证流程

Marchkov Helper 使用北京大学 IAAA 完成身份认证，再用一次性令牌在
WProc 建立预约会话。IAAA 在 2025 年 12 月更新了网页登录流程，客户端
必须保留同一登录会话、使用服务器公钥加密密码，并处理短信、邮件或 OTP
二次认证。

## 登录接口

| 顺序 | 方法 | 接口 | 用途 |
| --- | --- | --- | --- |
| 1 | `GET` | `https://iaaa.pku.edu.cn/iaaa/oauth.jsp` | 建立 IAAA 会话并取得 `JSESSIONID` |
| 2 | `GET` | `/iaaa/isShowCode.do` | 检查是否需要图形验证码 |
| 3 | `GET` | `/iaaa/getPublicKey.do` | 获取 RSA 公钥 |
| 4 | `GET` | `/iaaa/isMobileAuthen.do` | 查询账号当前是否需要 SMS、邮件或 OTP |
| 5 | `GET` | `/iaaa/sendSMSCode.do` | 用户确认后发送短信或邮件验证码 |
| 6 | `POST` | `/iaaa/oauthlogin.do` | 提交 RSA 加密后的密码和可选验证码 |
| 7 | `GET` | `https://wproc.pku.edu.cn/site/login/cas-login` | 用 IAAA 返回的 `token` 建立 WProc 会话 |
| 8 | `GET` | `/site/reservation/list-page` | 验证 WProc 会话并读取班车数据 |

第 1 至 6 步必须携带同一个 IAAA Cookie。第 6 步只有在响应中的
`success` 为 `true` 且 `token` 是非空字符串时才算成功。IAAA 失败时也会
返回 HTTP 200，因此不能只检查状态码。

校外网络更容易触发二次认证。客户端应先调用 `isMobileAuthen.do`，根据
`authenMode` 显示 SMS 或 OTP 输入框，而不是直接提交空验证码。

## 班车接口

登录后的请求均使用 WProc Cookie：

| 方法 | 接口 | 用途 |
| --- | --- | --- |
| `GET` | `/site/reservation/list-page` | 查询日期和路线下的班车 |
| `POST` | `/site/reservation/launch` | 创建预约 |
| `GET` | `/site/reservation/my-list-time` | 查询当前或历史预约 |
| `GET` | `/site/reservation/get-sign-qrcode` | 获取预约或临时乘车码 |
| `POST` | `/site/reservation/single-time-cancel` | 取消预约 |

WProc 业务失败通常同样返回 HTTP 200。客户端还需要检查 JSON 字段 `e`；
它可能是数字 `0` 或字符串 `"0"`。`e` 为 `"10042"` 表示会话未登录或
已经失效。

## 安全约束

- 不记录密码、IAAA `token`、Cookie 或完整认证响应。
- RSA 使用服务器当前返回的公钥和 PKCS#1 v1.5 填充，与 IAAA 网页保持一致。
- 验证码只保留在当前登录流程的内存中。
- 不绕过 IAAA 二次认证；客户端只复现官方网页公开的认证步骤。
