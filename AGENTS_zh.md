# 仓库贡献指南

[English](AGENTS.md)

## 项目结构与模块组织

`moon.mod` 定义 `LING71671/axml`。`src/` 提供解码、渲染、清单检查、统计、引用与 Intent。`src/catalog/` 处理批次；`src/cli/`、`src/cmd/` 提供参数与宿主 I/O。`src/browser/` 导出 JS 桥接。`playground/` 包含 Vite/TypeScript/Tailwind 工作台、Worker 控制器和 Node 测试。MoonBit 测试与源码同目录。`fixtures/`、`scripts/`、`docs/`、`evidence/` 保存语料、复现工具、说明与验证记录。

## 构建、测试与开发命令

使用 README 固定的 MoonBit 版本；前端需要 Node.js 22.18+ 和 pnpm 11.14.0。在仓库根目录运行：

- `moon fmt --check`、`moon info`：检查格式，重新生成公开 `.mbti` 接口。
- `moon check --target all --deny-warn`；`moon test --target wasm-gc --deny-warn`：检查/测试；另以 `js`、`native` 测试。
- `python scripts/verify_cli.py`：验证独立语料；构建两个 CLI 后可运行 `python scripts/benchmark.py`。
- `pnpm --dir playground install --frozen-lockfile`；`pnpm --dir playground dev`：准备 ESM/样例并启动 Vite。
- `pnpm --dir playground test`、`pnpm --dir playground build`、`pnpm --dir playground preview`：测试、类型检查及构建，或在本机提供已有产物。详见 `docs/DEMO_zh.md`。

## 代码风格与命名约定

使用两空格缩进与 `moon fmt`。MoonBit 函数、文件采用 snake_case，公开类型采用 UpperCamelCase。TypeScript 沿用现有 camelCase 函数与 kebab-case 文件名。审查生成接口；通过脚本重新生成语料测试。同步英文说明与带双向链接的 `_zh.md` 中文版本。

## 测试要求

`*_test.mbt` 验证公开行为，`*_wbtest.mbt` 验证内部逻辑，不设覆盖率百分比门槛。本地测试为 wasm-gc 114 项、JS 117 项、Windows native 114 项、前端 Node 12 项。覆盖边界、命名空间、类型数据、诊断、取消、旧结果及实际桥接集成。保留语料来源、哈希和独立参考结果。前端生成代码、样例、依赖与 `dist/` 保持忽略。浏览器检查分别记录。

## 提交与拉取请求要求

采用 Conventional Commits。PR 说明行为、关联 issue/验收项，列出实际执行的检查和限制，并同步两种文档语言。运行 `git diff --check`。

## 账号隔离与范围

认证操作遵循 `docs/ACCOUNTS_zh.md` 的封装入口；禁止切换全局账号或提交凭据。公开构建无需登录。解析保持本地运行，资源 ID 不解析。浏览器输入上限为 16 MiB，超时监测为 10 秒。APK 提取和 ARSC 解析不在范围内。`.github/workflows/pages.yml` 仅将 `playground/dist` 发布到 GitHub Pages。
