# 本地浏览器工作台

[English](DEMO.md) | [项目](../README_zh.md) | [桥接协议](BROWSER_zh.md)

## 从仓库启动

安装项目 README 固定的 MoonBit 工具链、Node.js 22.18+ 和 pnpm 11.14.0。
不需要 Mooncakes 账号。在仓库根目录运行：

```sh
cd playground
pnpm install --frozen-lockfile
pnpm dev
```

打开 Vite 输出的本机地址。准备过程编译实际的 MoonBit release ESM，复制类型声明，
并按 `fixtures/manifest.json` 校验自有样例哈希。生成代码、样例、依赖和 `dist/` 保持忽略。

选择样例、打开本机已提取的 AXML 文件，或将文件拖入页面。模块 Worker 解析文件，
所选字节不会上传。应用只请求自身静态资源和内置样例。重新选择文件或点击取消会停止
之前的任务。语言按钮切换中英文，本地仅保存该偏好。

## 按自有样例演示

六份语料均为仓库自有 Apache-2.0 材料。准确来源、许可、大小和 SHA-256 哈希保留在语料清单中。

| 选项 | 文件 | 检查路径 |
| --- | --- | --- |
| 基础 Manifest | `manifest_basic.axml` | XML、包名/版本、SDK 声明、权限与四个组件 |
| Unicode Manifest | `manifest_unicode.axml` | Unicode 字面名称与元数据 |
| 资源引用 | `manifest_references.axml` | 原始类型化资源 ID 与 Manifest 属性 |
| 菜单 XML | `menu.axml` | XML 与四个引用；Manifest 检查报告根元素不符 |
| UTF-16 字符串池 | `synthetic_utf16.axml` | UTF-16 解码、Unicode 与 XML 转义 |
| 截断文件头 | `truncated_header.axml` | 带原始字节偏移的解码阶段错误 |

切换 XML、Manifest、结构、引用视图，无需重新解码。Manifest 包含已声明的 Intent Filter
（如果存在）。源位置按钮会选中预览范围内的对应事件摘要。ID 保持数值形式，不查询资源表
或推断 Android 运行时默认值。APK 条目需要自行提取：工作台接收 AXML，不读取 APK
压缩包或普通文本 XML。

## 理解限制

| 边界 | 工作台行为 |
| --- | --- |
| 输入与处理 | 读取前拒绝超过 16 MiB 的文件；10 秒超时监测覆盖读取、Worker 启动和分析 |
| XML 生成 | 浏览器桥接预算为 2,097,152 个 UTF-16 单元；超出时返回 XML 视图错误 |
| XML 显示 | 预览前 100,000 个 UTF-16 单元，默认换行；复制/下载使用成功生成的完整 XML |
| 事件和引用 | 保留前 1,000 条事件摘要；事件、引用表每页显示 50 条 |
| Manifest 集合 | 权限、组件、Intent Filter 各预览 50 条并显示总数；完整 JSON 可通过复制/下载获取 |

统计覆盖完整解码文档。结构 JSON 包含有限事件预览，不会补回省略的事件。
详情 JSON 在展开时渲染。XML、Manifest、Intent 分别报告错误，非 Manifest XML 解码成功
不代表其是有效 Manifest。核心库有独立可配置预算，包括更大的默认 XML 输出上限。
显示换行与预览截断不会改变原始下载内容。复制能否执行取决于浏览器的剪贴板访问权限。

## 测试并预览生产构建

在 `playground/` 中执行：

```sh
pnpm test
pnpm build
pnpm preview
```

前端有 12 项 Node 测试，覆盖限制、取消/竞态、Worker 错误、样例复制、无需账号的贡献者
环境和实际编译桥接。`build` 执行严格 TypeScript 检查和 Vite 构建；`preview` 在本机提供
生成的 `dist/`。当前本地 MoonBit 测试为 JavaScript 117 项（含仅面向 JS 的桥接），
wasm-gc 和 Windows native 各 114 项。

本机浏览器已检查 Unicode 文件、用畸形输入错误替换旧结果、菜单与 Manifest 的独立结果、
源位置选择、语言状态、键盘标签切换和准确的 XML 下载内容。生产构建也已在本机
`/moonbit-axml/` 子路径下加载并解码。这些观察不代表已核实剪贴板载荷内容。

## GitHub Pages 部署

生产产物使用相对路径（`base: "./"`），包含自身字体、Worker 和样例，适配 GitHub Pages
等仓库子路径。部署目标为
[LING71671 AXML 工作台](https://ling71671.github.io/moonbit-axml/)。
**已于 2026-11-02 部署并验证。** 线上地址通过基础 Manifest、菜单样例、本机 Unicode
文件解析、引用到事件选择及 XML 下载检查，见[部署记录](https://github.com/LING71671/moonbit-axml/actions/runs/41399307093)。

[Pages 工作流](../.github/workflows/pages.yml) 在 `main` 推送时运行。手动重跑时，打开仓库
Actions，选择 **Deploy browser workbench**，在 `main` 分支使用 **Run workflow**。
仓库 Pages 来源须设为 GitHub Actions；发布设置与本机构建分别管理。

构建任务固定 Node.js 22、pnpm 11.14.0 和项目 MoonBit 工具链，按冻结锁文件安装依赖，
运行前端测试并构建工作台。仅上传 `playground/dist`。部署任务依赖构建成功，并使用
`github-pages` 环境；测试或构建失败时不会执行该部署。每次发布后检查工作流给出的
部署地址并加载一个样例。`pnpm preview` 仍然只提供本机服务，不发布站点。
