# CursorUsage

macOS 菜单栏应用：实时查看 Cursor 用量与花费，额度将满时提醒。

不读取 Cursor 自己的登录态。用量来自你创建的 User API Key，Key 只保存在本机钥匙串。

> 使用的是 Cursor 非公开 Dashboard 接口，字段或地址变更时可能失效。

## 功能

- **菜单栏**：仪表盘图标随用量转动；旁边显示百分比，或已消耗金额
- **弹窗**：总用量（与官网一致）、Auto / API / Grok 分项、今日消耗与 tokens、套餐额度、按需用量、账期与 Grok 重置倒计时
- **通知**：所选指标越过警告线 / 严重线时提醒；同一账期每一档只发一次
- **开机自启**（需以 `.app` 运行）
- 睡眠唤醒后自动刷新；账期刚重置时立刻拉一次新数据

## 要求

- macOS 13 或更高
- Swift 5.9+（Xcode Command Line Tools 即可）
- 一个 Cursor User API Key（`crsr_` 开头）

## 安装

```bash
./scripts/build-app.sh
open build/CursorUsage.app
```

需要长期使用时拷到应用程序目录：

```bash
cp -R build/CursorUsage.app /Applications/
```

脚本会做 ad-hoc 签名。钥匙串反复询问授权时，可在钥匙串里创建名为 `CursorUsage Dev` 的代码签名证书，或设置环境变量 `CODESIGN_IDENTITY`，这样重新打包后签名身份不变。

通知和开机自启只在打包后的 `.app` 里可用，`swift run` 没有这些能力。

## 使用

1. 打开应用，菜单栏会出现仪表盘图标。
2. 点图标，在弹窗里粘贴 API Key。
3. 没有 Key 时点「去创建 Key」，或打开 [cursor.com/dashboard](https://cursor.com/dashboard) → **API Keys（Integrations）** 新建。

Key 以 `crsr_` 开头，只写入本应用自己的钥匙串条目，不会去读 Cursor 客户端的任何凭据。命令行调试也可以设环境变量 `CURSOR_API_KEY`（优先于钥匙串）。

点齿轮可以改：

| 设置 | 默认 |
| --- | --- |
| 刷新间隔 | 5 分钟（1 / 2 / 5 / 15 / 30） |
| 菜单栏 / 通知指标 | API 用量（也可选 Auto、Grok Bot、总用量、已消耗金额） |
| 警告线 / 严重线 | 80% / 90% |
| 超过阈值时通知 | 开 |
| 开机自动启动 | 关 |

弹窗大数字始终是**总用量**，和官网一致。「菜单栏 / 通知指标」只影响菜单栏数字、图标进度和通知。

## 隐私

- API Key 存在钥匙串（`com.colin.cursor-usage` / `user-api-key`），兑换出的 access token 只留在内存里
- 本地只缓存用量数字，不含凭据
- 不读取、不修改 Cursor 官方应用的登录数据

## 开发

```bash
swift run CursorUsage            # 菜单栏运行（无通知 / 开机自启）
swift run CursorUsage --selftest # 离线自检，不读 Key、不联网
swift run CursorUsage --dump     # 打印接口原始 JSON（需要已配置 Key）
```

`--dump` 方便核对接口字段；stderr 只打状态码，不含凭据。

## 许可

[MIT](LICENSE)
