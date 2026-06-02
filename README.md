# CloudCLI + Claude Code Router + Comfly 中转站快速部署

这份文档用于在一台新的 Windows 电脑上复刻本机配置：

`CloudCLI 网页界面 -> Claude Code -> Claude Code Router -> ai.comfly.org -> 中转站模型`

当前推荐模型：

```text
claude-sonnet-4-6-thinking
```

注意：不要把真实 API key 提交到 GitHub。本目录里的脚本会运行时提示输入密钥，并写入 Windows 用户环境变量 `COMFLY_API_KEY`。

## 适用范围

- Windows 10/11
- Node.js 18 或更高版本
- npm 可用
- 有 `https://ai.comfly.org/` 的 API key

这不是官方 Claude Desktop 的第三方模型接入方案。官方 Claude Desktop 白屏或登录失败通常是访问 Anthropic 官方服务的问题；本方案使用 CloudCLI 的本地网页 UI。

## 一键安装

不想 clone 仓库时，直接在 PowerShell 运行这一条：

```powershell
powershell -ExecutionPolicy Bypass -Command "$p=Join-Path $env:TEMP 'setup-cloudcli-comfly.ps1'; Invoke-WebRequest 'https://raw.githubusercontent.com/kiki348/cloudcli-comfly-kit/main/setup-cloudcli-comfly.ps1' -OutFile $p; & $p"
```

脚本会提示输入中转站 API key。

如果已经 clone 了仓库，也可以在 PowerShell 中进入本目录，然后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-cloudcli-comfly.ps1
```

脚本会做这些事：

- 安装/更新 `@anthropic-ai/claude-code`
- 安装/更新 `@musistudio/claude-code-router`
- 安装/更新 `@cloudcli-ai/cloudcli`
- 写入 `C:\Users\<你>\.claude-code-router\config.json`
- 写入 `C:\Users\<你>\.claude\settings.json`
- 把中转站密钥写入用户环境变量 `COMFLY_API_KEY`
- 启动 `ccr`
- 启动 CloudCLI，本地访问地址为 `http://localhost:3001`

## 自定义模型

如果要换模型：

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-cloudcli-comfly.ps1 -Model "你的模型名"
```

如果中转站 endpoint 不是默认地址：

```powershell
powershell -ExecutionPolicy Bypass -File .\setup-cloudcli-comfly.ps1 -ApiBaseUrl "https://你的中转站/v1/chat/completions"
```

## 使用方法

1. 打开浏览器：

   ```text
   http://localhost:3001
   ```

2. 第一次打开 CloudCLI 时创建/登录本地账号。

3. 初始化向导里：

   - Git 名称/邮箱按需填写
   - Claude Code 看到 `Configured via settings.json` 或 `Connected` 即可

4. 进入项目，点击 `New Session`。

5. Provider 选择 `Claude`，模型建议选：

   ```text
   Sonnet
   ```

CloudCLI 前端只显示 Claude Code 的别名，例如 `Opus`、`Sonnet`、`Haiku`。实际模型由 `ccr` 后端统一路由到：

```text
claude-sonnet-4-6-thinking
```

## 常用命令

检查本地路由是否运行：

```powershell
ccr status
```

重启路由：

```powershell
ccr restart
```

启动 CloudCLI：

```powershell
cloudcli
```

终端直测 Claude Code 是否能通过中转站返回：

```powershell
claude -p "只回复 pong" --model sonnet
```

正常返回类似：

```text
pong
```

## 重要配置文件

Claude Code Router 配置：

```text
C:\Users\<你>\.claude-code-router\config.json
```

Claude Code 环境配置：

```text
C:\Users\<你>\.claude\settings.json
```

CloudCLI 本地数据库：

```text
C:\Users\<你>\.cloudcli\auth.db
```

CloudCLI 日志：

```text
%TEMP%\cloudcli-out.log
%TEMP%\cloudcli-err.log
```

## 不要这样做

不要把下面这些写到 Windows 全局用户环境变量里：

```text
ANTHROPIC_BASE_URL
ANTHROPIC_AUTH_TOKEN
NO_PROXY
DISABLE_TELEMETRY
DISABLE_COST_WARNINGS
API_TIMEOUT_MS
```

原因：官方 Claude Desktop 也可能读取这些环境变量，导致它误连本地代理或白屏。正确做法是只写入：

```text
C:\Users\<你>\.claude\settings.json
```

`COMFLY_API_KEY` 可以写入 Windows 用户环境变量，因为它只给本地路由器读取。

## 故障排查

### CloudCLI 页面打不开

运行：

```powershell
cloudcli
```

然后打开：

```text
http://localhost:3001
```

### 发送消息不回复

先确认路由器：

```powershell
ccr status
```

再终端直测：

```powershell
claude -p "只回复 pong" --model sonnet
```

如果终端能回复，但 CloudCLI 不回复，刷新页面并新建会话。

### `ccr` 请求失败

确认密钥已设置：

```powershell
[Environment]::GetEnvironmentVariable('COMFLY_API_KEY','User')
```

不要把输出贴到公开场合。

重启路由：

```powershell
ccr restart
```

### 官方 Claude Desktop 白屏

这通常不是本方案问题。检查是否能访问：

```text
https://claude.ai
https://api.anthropic.com
```

官方 Claude Desktop 主要走 Anthropic 官方服务，不等同于 CloudCLI 的中转配置。

## 上传到 GitHub 的建议

可以只上传以下两个文件：

```text
cloudcli-comfly-setup.md
setup-cloudcli-comfly.ps1
```

不要上传：

```text
.env
*.log
auth.db
任何包含 sk- 开头密钥的文件
```

最小 Git 命令：

```powershell
git init
git add cloudcli-comfly-setup.md setup-cloudcli-comfly.ps1
git commit -m "Add CloudCLI Comfly setup guide"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```
