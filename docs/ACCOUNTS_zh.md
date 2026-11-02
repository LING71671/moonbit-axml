# 仓库账号隔离

[English](ACCOUNTS.md) | [项目说明](../README_zh.md)

本仓库归属 **LING71671**。GitHub 远程地址为
`https://github.com/LING71671/moonbit-axml.git`，Mooncakes 模块名为
`LING71671/axml`。创建仓库与发布软件包是独立操作。

## Windows 专用命令入口

```powershell
pwsh -NoProfile -File scripts/setup-accounts.ps1
pwsh -NoProfile -File scripts/moon.ps1 whoami
pwsh -NoProfile -File scripts/github.ps1 api user --jq .login
```

两个身份命令均须返回 `LING71671`。涉及账号的 Mooncakes 命令使用
`scripts/moon.ps1`，GitHub 命令使用 `scripts/github.ps1`。普通构建和测试不需要登记库认证。

MoonBit 入口只在子进程中把 `MOON_HOME` 指向
`$env:USERPROFILE\.moon\profiles\LING71671`，把 `MOON_TOOLCHAIN_ROOT` 指向共享的
`$env:USERPROFILE\.moon` 工具链。复用仓库外已有的 `credentials.json`，核对用户名，
执行后还原环境变量。入口拒绝前置全局选项和修改登录的命令，不调用全局账号切换器。
`moon whoami` 只核对本地已保存身份，
不验证服务器端令牌有效性。

GitHub 入口读取凭据库中指定的 `LING71671` 条目，仅在当前进程设置 `GH_TOKEN`，
通过 GitHub API 核实登录用户名，再执行命令。读取指定凭据时临时清除已有
`GH_TOKEN`、`GITHUB_TOKEN`，结束后还原。执行期间固定 `GH_HOST`、`GH_REPO` 为
github.com 和本仓库，结束后恢复原值。入口只接受明确的仓库/API 命令，拒绝前置全局
选项、别名和修改全局登录或配置的命令。

## Git 配置范围

`setup-accounts.ps1` 只写本仓库 `.git/config`：提交身份、按 HTTPS 路径选择凭据，
以及仅服务于 `LING71671/moonbit-axml` 的凭据助手。Git 通过助手读取已有凭据库的
指定账号令牌；令牌不会写入仓库或命令行。移动仓库后重新运行设置脚本，更新本地的
凭据助手绝对路径。其他仓库与全局 Git 配置不受影响。

不提交凭据，不把令牌放进远程 URL，也不把账号配置复制到仓库内。开发流程不运行
`moon-switch` 或 `gh auth switch`。发布仍须单独授权，并具备配置所属账号的有效
Mooncakes 令牌。
