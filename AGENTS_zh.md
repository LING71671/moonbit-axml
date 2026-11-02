# 仓库贡献指南

[English](AGENTS.md)

## 项目结构与模块组织

`moon.mod` 定义模块 `LING71671/axml`。核心解码、渲染与清单检查位于 `src/`，同时提供查询/类型辅助、`stats.mbt`、`resource_usage.mbt` 和 `intent_filters.mbt`。`src/catalog/` 独立处理具名输入批次。`src/cli/` 处理参数，`src/cmd/axml/` 和 `src/cmd/axml-native/` 提供 Node.js 与 native I/O。测试与源码同目录。`fixtures/` 保存自有样本和独立参考结果；`scripts/` 负责复现与校验；`docs/`、`evidence/` 记录范围与验证证据。

## 构建、测试与开发命令

使用固定版本的 MoonBit 工具链，在仓库根目录执行：

- `moon fmt --check`、`moon info`：检查格式并重新生成公开 `.mbti` 接口。
- `moon check --target all --deny-warn`：检查全部后端，并将警告视为错误。
- `moon test --target wasm-gc --deny-warn`：运行测试；另以 `js`、`native` 重复执行。
- `moon build src/cmd/axml --target js --deny-warn`：构建 Node CLI。使用 `moon build src/cmd/axml-native --target native --deny-warn` 构建 native CLI。
- `python scripts/verify_cli.py`：检查语料与 CLI 行为。构建两个 CLI 后运行 `python scripts/benchmark.py --backend all --repeats 3`；可执行文件路径与测量限制见 `docs/BENCHMARKS_zh.md`。

## 代码风格与命名约定

使用两空格缩进与 `moon fmt`。函数和文件使用 snake_case，公开类型使用 UpperCamelCase。审查生成的 `.mbti` 改动；通过脚本重新生成语料测试。维护英文文档及带双向链接的 `_zh.md` 中文对照，JSON 保持两空格缩进，文档文件沿用有明确含义的大写名称。

## 测试要求

使用 MoonBit 内置测试工具：`*_test.mbt` 验证公开行为，`*_wbtest.mbt` 验证内部逻辑。目前不设覆盖率百分比门槛。覆盖边界、编码、命名空间、类型值、转义、批次隔离及错误偏移。与固定版本 aapt2/androguard 的语义树和元数据比较。在 `fixtures/manifest.json` 保留语料来源和哈希。逐提交验证证据见 `docs/ACCEPTANCE_zh.md`。

## 提交与拉取请求要求

采用 Conventional Commits，例如 `feat: decode string pools`。拉取请求须说明行为、关联验收项或 issue、列出实际执行的检查、指出限制，并同步两种语言的文档。提交前运行 `git diff --check`。

## 账号隔离与范围

遵循 `docs/ACCOUNTS_zh.md`：认证操作使用 `scripts/moon.ps1` 和 `scripts/github.ps1`，身份固定为 `LING71671`。禁止切换全局账号或提交凭据。解码保持纯 MoonBit、离线运行。保留未解析资源 ID；APK 提取、ARSC 解析、签名和 DEX 解析不在范围内。
