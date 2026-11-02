# MoonBit AXML

[English](README.md) | [贡献指南](CONTRIBUTING_zh.md) | [验收记录](docs/ACCEPTANCE_zh.md) | [测试语料](fixtures/README_zh.md) | [账号隔离](docs/ACCOUNTS_zh.md)

用纯 MoonBit 解码 Android 二进制 XML，提供经过边界检查的字节解析、类型化事件、
XML 重建和 Manifest 元数据。离线 CLI 读取已提取的 AXML 文件。模块名为
**LING71671/axml**。

**状态：已按 Apache-2.0 公开源码，尚未发布到 Mooncakes。**
选题研究及有范围限制的查重记录见 [docs/RESEARCH_zh.md](docs/RESEARCH_zh.md)。

## 浏览器工作台

使用下文固定版本的 MoonBit 工具链、Node.js **22.18+** 和 pnpm **11.14.0**：

```sh
cd playground
pnpm install --frozen-lockfile
pnpm dev
```

打开 Vite 输出的本机地址。选择自有样例、打开已提取的本机 AXML 文件，或将文件拖入页面。
模块 Worker 执行实际编译的 MoonBit 解码器；所选文件字节不会上传。页面会请求自身的静态
资源和样例。XML、Manifest/Intent 声明、结构统计和类型化引用共用一次分析结果。
重新选择文件或点击取消会终止之前的任务。

输入上限为 **16 MiB**，分析设置 **10 秒**超时监测。浏览器 XML 生成预算为
**2,097,152 个 UTF-16 单元**；屏幕预览前 **100,000 个单元**，复制/下载使用成功生成的
完整 XML。事件保留前 **1,000 条摘要**；事件、引用表均**每页 50 条**。权限、组件、
Intent Filter 各预览前 **50 条**，显示总数，完整 JSON 可通过复制/下载获取。
这些浏览器限制与下文的库默认值分别设置。

内置 6 份 Apache-2.0 自有语料：基础、Unicode、资源引用 Manifest，菜单 XML，
UTF-16 字符串池，以及故意截断的文件头。来源与哈希保留在[语料清单](fixtures/manifest.json)。
工作台不提取 APK，也不查询 ARSC 资源表。

在 `playground/` 中，`pnpm test` 运行 12 项 Node 测试，`pnpm build` 执行类型检查并生成
静态构建，`pnpm preview` 在本机预览该构建。准备过程重新编译 MoonBit ESM，校验复制
语料的哈希；不需要 Mooncakes 账号。相对资源路径适配 GitHub Pages 等仓库子路径。
[Pages 工作流](.github/workflows/pages.yml) 在 `main` 推送或手动运行时测试、构建，
随后仅发布 `playground/dist`。部署目标为
[LING71671 AXML 工作台](https://ling71671.github.io/moonbit-axml/)。
**已于 2026-11-02 部署并通过浏览器验证：**样例、本机 Unicode 输入、引用源位置选择与 XML 下载。
详见[演示说明](docs/DEMO_zh.md)和[浏览器桥接协议](docs/BROWSER_zh.md)。

## 运行 CLI

使用 MoonBit **0.10.18+6c83a7f62**，对应 moon **0.1.20261028**。
JavaScript CLI 需要 Node.js **22+**；原生 CLI 需要受支持的原生编译器。
在本仓库根目录运行：

```sh
moon run src/cmd/axml --target js -- decode fixtures/valid/manifest_unicode.axml
moon run src/cmd/axml --target js -- decode --pretty fixtures/valid/manifest_basic.axml
moon run src/cmd/axml --target js -- inspect --json fixtures/valid/manifest_basic.axml
moon run src/cmd/axml --target js -- validate fixtures/valid/menu.axml
moon run src/cmd/axml --target js -- stats --json fixtures/valid/menu.axml
moon run src/cmd/axml --target js -- refs --json fixtures/valid/menu.axml
```

原生版本使用 `src/cmd/axml-native --target native`：

```sh
moon run src/cmd/axml-native --target native -- inspect --json fixtures/valid/manifest_basic.axml
```

处理 APK 时，先从 ZIP 中提取 `AndroidManifest.xml` 条目。CLI 本地读取文件，
输入上限为 16 MiB。`decode` 输出带命名空间的 XML，`inspect` 输出 JSON，
`validate` 检查二进制结构与 XML 可输出性。退出码：成功为 0，输入或 I/O 错误为 1，
参数错误为 2。诊断包含字节偏移，CLI 错误写入 stderr。

`decode --pretty` 在仅含子元素的位置加入两空格缩进。含文本或 `xml:space="preserve"`
的子树保持紧凑。此可选输出会增加空白文本节点；需要原始文本序列时使用普通 `decode`。

`stats` 报告字符串池、事件、属性数量及嵌套深度。`refs` 按原始位置列出类型化资源或主题
引用，不解析资源 ID。两者均输出 JSON，可选写上 `--json`。

`--version` 显示包版本，`decode --help` 等子命令帮助显示用法。`--` 后的参数按文件名
处理，例如 `axml decode -- --help` 读取名为 `--help` 的文件。

## 库接口

仓库中的库以 `LING71671/axml` 导入，别名为 `@axml`：

```moonbit
let document = @axml.decode(input)
let xml = @axml.to_xml(document)
let manifest = @axml.inspect_manifest(document)
```

这些操作可能抛出 `DecodeError::Invalid(offset, message)`。`Document` 提供字符串池、
资源映射及按输入顺序排列的命名空间、元素和文本事件，并保留输入偏移及行号。
属性保留命名空间 URI、名称、可选资源 ID、可选原始字符串，以及包含 Android 类型码、
原始 32 位载荷和可选解码字符串的 `TypedValue`。

Manifest 接口提取包名、版本及 versionCodeMajor、显式 SDK 声明、权限、application
属性，以及 activity/alias/service/receiver/provider 记录。缺失的可选 JSON 字段不输出。
资源引用保留数值 ID，检查操作不推断组件完整名称或 Android 默认值。

其他接口见各自说明：

| 接口 | 用途 |
| --- | --- |
| [XML 渲染](docs/RENDERING_zh.md) | 选择紧凑 `to_xml` 或有预算限制的 `to_xml_pretty`，保留混合文本子树 |
| [文档查询](docs/QUERIES_zh.md)与[统计](docs/STATS_zh.md) | 按扩展名称查询，并统计字符串池、事件及嵌套深度 |
| [类型值视图](docs/VALUES_zh.md)与[尺寸/分数](docs/COMPLEX_VALUES_zh.md) | 读取类型化载荷与编码单位，不强制转换或应用显示参数 |
| [Manifest 辅助接口](docs/MANIFEST_zh.md)与[Intent Filter](docs/INTENTS_zh.md) | 检查组件、权限、action/category 和 data 声明，不推断平台默认值 |
| [资源引用](docs/REFERENCES_zh.md) | 保留每个引用的类型、ID、位置及属性或文本来源 |
| [批量目录接口](docs/CATALOG_zh.md) | 导入 `LING71671/axml/catalog`，逐份处理带名称的字节输入并独立返回结果或诊断 |

## 构建与验证

```sh
moon fmt --check
moon check --target all --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
python scripts/verify_cli.py
```

验证脚本只依赖 Python 标准库。重新生成测试语料另需固定版本的 aapt2 和 androguard，
详见[语料说明](fixtures/README_zh.md)。最新本地测试为 wasm-gc **130 项**、JavaScript
**133 项**（包括浏览器桥接）、Windows native **130 项**；Node 和原生 CLI 另通过 **19 份语料**、
**7 棵独立 XML 语义树的紧凑及缩进形式**、**3 份 Manifest 记录**、**菜单统计和类型引用位置**、
**12 类畸形输入**检查。
参考输出来自 aapt2/androguard，生成过程不依赖本解析器。各提交的 Linux、Windows
GitHub Actions 结果记录在
[验收清单](docs/ACCEPTANCE_zh.md)。

[有限压力基准](docs/BENCHMARKS_zh.md)覆盖 100,000 个字符串、256 层嵌套、重复字符串
引用及在末尾出现的非法索引。Windows 快照校验输出哈希、耗时及进程峰值内存，
不代表跨平台性能保证。构建两个 CLI 后，运行 `python scripts/benchmark.py`，
新报告默认写入 `_build/benchmarks/`。

## 限制与支持范围

| 限制 | 默认值 |
| --- | --- |
| 输入 | 16 MiB |
| 字符串池 | 100,000 条；累计 4,194,304 个 UTF-16 单元 |
| 元素深度 | 256 层 |
| 事件与属性 | 500,000 个事件；每元素 65,535 个属性 |
| XML 输出 | 33,554,432 个 UTF-16 单元 |

可通过 `decode(input, limits=...)`、`to_xml(document, max_output_chars=...)` 指定预算。
支持 UTF-8/UTF-16 字符串、资源映射、命名空间作用域、类型化属性和 CDATA。
校验字符串样式 span，但输出 XML 时不保留富文本样式。未知 chunk、畸形编码或作用域
会被拒绝。本版不含资源表解析、AXML 写入、APK 签名、DEX 解码、加固 Manifest 修复
或 APK 压缩包读取。核心不依赖 Android/JVM；CLI 宿主适配层只负责文件 I/O。

## 账号与许可

GitHub 公开仓库为 [LING71671/moonbit-axml](https://github.com/LING71671/moonbit-axml)。
在已配置的 Windows 开发机上，涉及账号的操作使用 `scripts/moon.ps1`、
`scripts/github.ps1`，固定选择 LING71671 并保持其他任务的登录状态。
详见[账号隔离](docs/ACCOUNTS_zh.md)。

采用 [Apache-2.0](LICENSE)。自有语料来源、工具版本、哈希及外部参考许可见
[THIRD_PARTY_zh.md](THIRD_PARTY_zh.md)。
