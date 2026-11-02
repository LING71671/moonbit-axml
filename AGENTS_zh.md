# 仓库贡献指南

[English](AGENTS.md)

## 项目结构与模块组织

`moon.mod` 定义模块 `LING71671/axml`，库源码位于 `src/`。`reader.mbt`、`string_pool.mbt`、`decoder.mbt` 负责字节解码；`model.mbt`、`render.mbt`、`manifest.mbt` 提供事件、XML 和元数据。`src/cli/` 处理命令，`src/cmd/axml/` 提供 Node.js I/O，`src/cmd/axml-native/` 提供 native I/O。测试与源码同目录。`fixtures/` 保存自有来源文件、二进制和独立参考结果；`scripts/` 负责复现与校验；`docs/`、`evidence/` 记录范围与验证证据。

## 构建、测试与开发命令

使用固定版本的 MoonBit 工具链，在仓库根目录执行：

- `moon fmt --check`、`moon info`：检查格式并重新生成公开接口；审查产生的 `.mbti` 改动。
- `moon check --target all --deny-warn`：检查全部后端，并将警告视为错误。
- `moon test --target wasm-gc --deny-warn`：运行测试；另以 `js`、`native` 重复执行。
- `moon build src/cmd/axml --target js --deny-warn`：构建 Node CLI；运行 `node _build/js/debug/build/cmd/axml/axml.js validate fixtures/valid/menu.axml`。
- `python scripts/verify_cli.py`：检查语料哈希、XML 语义、元数据及畸形输入诊断；重新生成步骤见 `fixtures/README_zh.md`。

## 代码风格与命名约定

使用两空格缩进与 `moon fmt`。函数和文件使用 snake_case，公开类型使用 UpperCamelCase。通过 `moon info` 同步生成的 `.mbti` 文件；不要手动修改生成的语料测试。主文档使用英文，中文独立保存为带双向链接的 `_zh.md` 文件。JSON 保持两空格缩进，文档文件沿用有明确含义的大写名称。

## 测试要求

使用 MoonBit 内置测试工具：`*_test.mbt` 验证公开行为，`*_wbtest.mbt` 验证内部逻辑。目前不设覆盖率百分比门槛。覆盖边界、编码、命名空间作用域、类型值、转义及错误偏移。与固定版本 aapt2/androguard 的扩展名称语义树和元数据比较。在 `fixtures/manifest.json` 保留来源、许可、哈希和复现命令。本地 wasm-gc、JavaScript、Windows native、Linux native 均已通过测试；远程 CI 仍待验证。

## 提交与拉取请求要求

采用 Conventional Commits，例如 `feat: decode string pools`。拉取请求须说明行为、关联验收项或 issue、列出实际执行的检查、指出限制，并同步两种语言的文档。提交前运行 `git diff --check`。

## 账号隔离与范围

遵循 `docs/ACCOUNTS_zh.md`：认证操作使用仓库账号封装脚本；禁止切换全局 Mooncakes/GitHub 账号或提交凭据。解码保持纯 MoonBit、离线运行。保留未解析资源 ID；APK 提取、ARSC 解析、签名和 DEX 解析不在范围内。
