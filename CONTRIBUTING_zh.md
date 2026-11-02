# 贡献指南

[English](CONTRIBUTING.md) | [项目说明](README_zh.md)

## 准备开发环境

克隆仓库，安装 `README_zh.md` 固定版本的 MoonBit。JavaScript CLI 需要 Node.js 22+；
独立语料验证脚本需要 Python 3.12+。只有重新生成语料时才需要 Android SDK 和 androguard。
构建及测试无需 Mooncakes 账号或登记库令牌。

## 提交可审查的独立改动

使用能描述改动的分支名。二进制解析与宿主 I/O 分离，保留原始资源 ID，并为畸形输入
提供带字节偏移的结构化诊断。公开行为测试放在 `*_test.mbt`，内部回归测试放在
`*_wbtest.mbt`。同步更新英文文档和 `_zh.md` 中文对照。

在仓库根目录执行：

```sh
moon fmt
moon info
moon check --target all --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
python scripts/verify_cli.py
```

公开 API 改动须同时提交生成的 `.mbti`。自有语料测试通过
`scripts/generate_fixtures.py` 重新生成，并保留源码、参考结果的哈希和来源记录。
生成步骤见 [fixtures/README_zh.md](fixtures/README_zh.md)。

## 提交拉取请求

标题采用 Conventional Commits，说明可观察的问题和修改后的行为，列出实际测试过的
命令与平台，关联问题或验收项。明确限制及未解析的资源引用。改动合入前须通过
Linux 和 Windows CI。

贡献按照本仓库 [Apache-2.0 许可](LICENSE) 分发。外部语料须附来源及可再分发依据。
优先使用自有的小型样本或合成语料，避免附带来源不明的 APK。

## 报告问题

提供 `moon version --all`、后端和操作系统、最小命令、预期与实际行为，以及完整的
偏移诊断。分享经过清理的最小语料或复现脚本；公开附件前移除凭据和私有应用信息。
