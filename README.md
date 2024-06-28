## 三、二、一，马池口！

倒数三个数，出示乘车码从未如此优雅。

![demo](public/demo.gif)

尽管我提供[在线 demo](https://marchkov.variantconst.com/)，但并没有办法验证后端代码和开源代码的一致性。基于零信任原则，建议在私有服务器上自行部署服务。

### 动机

乘坐往返燕园和马池口的班车需要通过官方网站或 APP 进行预约。然而，官方网站的预约流程繁琐，难以找到想要预约的班车。随着基于客户端浏览器的预约脚本（如 [pku-eutopia](https://github.com/xmcp/pku-eutopia)）的开发，预约的流程得到了简化，但仍然需要进行 IAAA 认证，且用户界面具有太多冗余信息。通过官网预约并获取一个乘车码，至少需要在 7 个页面之间进行跳转并点击 6 次屏幕，而 [pku-eutopia](https://github.com/xmcp/pku-eutopia) 也至少需要点击 5 次屏幕。由于每天两次的预约操作是对心智的无意义消耗，我希望将通过在服务器端进行预约操作，绕开 IAAA，并根据当前时刻智能选择班车预约，将点击屏幕的次数下降到 0，让出示乘车码成为一种优雅的享受。

### 方法

后端用 python playwright 库进行浏览器操纵，根据当前时间自动选择一个合理的班车，服务端进行预约操作并将乘车码转发给客户端。用户首次登陆时，需要输入用户名、密码，并选择“临界时间”。其后账号和预约配置会保存在浏览器 cookie 中。判断逻辑：

1. 过去 10 分钟内是否有过期的班车，如果有，返回临时码；
2. 否则获取下面最近的一班班车的乘车码。

### 本地部署

1. 克隆项目到本地

```bash
git clone https://github.com/VariantConst/3-2-1-Marchkov.git && cd 3-2-1-Marchkov
```

2. 安装依赖

首先安装 python（略）和 pnpm

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
nvm install 18
nvm use 18
npm install -g pnpm@latest
```

安装 node 依赖

```bash
pnpm install
```

安装 playwright

```bash
pip install pytest-playwright
playwright install
```

3. 启动项目

```bash
chmod +x ./run.sh
./run.sh
```

之后访问 `http://localhost:3000` 即可。如果是内网服务器，你后续可能需要通过 Frp、[Cloudflare tunnels](https://www.cloudflare.com/zh-cn/products/tunnel/) 等工具将服务暴露到公网上。

### TODO

- [ ] 支持取消预约
- [ ] 支持不退出账号就修改配置信息
- [ ] 根据历史喜好智能推荐乘坐的班次
- [ ] 支持 docker 部署
