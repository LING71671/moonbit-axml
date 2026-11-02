# 验收清单

[English](ACCEPTANCE.md) | [项目说明](../README_zh.md)

状态：**截至 2026-11-02，功能已实现并通过本地验证；发布关卡仍未完成**。这是仓库的交付清单，不是赛方认可的标准。GitHub 仓库已公开，采用 Apache-2.0；`LING71671/axml` 尚未发布到 Mooncakes。

## 验证快照

| 检查 | 已验证结果 | 证据 |
| --- | --- | --- |
| 最新本地 MoonBit 测试 | wasm-gc、JavaScript、Windows native 各通过 75/75 项 | [开发验证记录](../evidence/verification-development.json)；包含 `src/catalog/` 的同目录测试 |
| 最新托管 MoonBit 测试 | Linux、Windows 的 wasm-gc、JavaScript、native 各通过 75/75 项 | [`61279a8` 的 CI](https://github.com/LING71671/moonbit-axml/actions/runs/41391697996)、[结果记录](../evidence/verification-development.json) |
| CLI 语料 | 19 份语料哈希、7 棵 XML 语义树、3 份 Manifest 记录、12 个畸形输入错误 | `scripts/verify_cli.py`、`fixtures/manifest.json` |
| CLI 宿主 | Node.js、Windows native、Linux native | 相同语料；[Linux 执行记录](../evidence/verification-linux.json) |
| 独立参考 | aapt2 2.20-13193326、Android Build Tools 36.0.0 / android-36、androguard 4.1.3 | `fixtures/reference/`、[复现步骤](../fixtures/README_zh.md) |
| Windows 有限基准 | 四种场景，JS/native，各实测三次，24 次全部通过 | [方法与结果](BENCHMARKS_zh.md)、[原始记录](../evidence/benchmark.json) |

早期 46 项测试的 Linux 快照在 WSL2 的 Debian 中运行 native 可执行文件，与托管 CI 分开，且不覆盖后续新增接口。证据文件记录对应工具链版本与源码哈希；修改代码后须重新执行相关检查。

## 格式与行为

- [x] 解析 MVP 全部 chunk、UTF-8/UTF-16 字符串池、命名空间、resource-map、CDATA 及原始/类型化属性；检查索引、chunk 边界和文档作用域。
- [x] 保留原始值、类型数据与未解析资源 ID。资源引用保留为数字，不隐含 ARSC 查表能力。
- [x] 输出转义正确、扩展名称和属性值等价的 XML。独立 ElementTree 检查比较标准化语义树，覆盖命名空间遮蔽和 Unicode。
- [x] 提取包名/版本、SDK、权限、application 属性和组件；三个自有编译 Manifest 与独立参考逐字段比较。
- [x] 畸形输入返回带字节偏移的错误。12 份非法语料及白盒截断、Unicode、命名空间、限制、逐字节变异测试已通过；这是有限测试，不是穷尽 fuzzing。

## 端到端流程

- [x] 构建检查场景：解码并检查提取后的编译 Manifest，包名、SDK、权限和组件记录在本地与参考一致。
- [x] 目录场景：`LING71671/axml/catalog` 按顺序处理带名称的字节输入，保留成功结果，并为每份失败输入返回阶段及偏移诊断。测试覆盖混合批次、自定义限制、重复标签和非 Manifest XML；见[接口说明](CATALOG_zh.md)。
- [x] 资源 XML 场景：编译菜单 AXML 转成 XML 后，由独立 parser 验证命名空间语义等价。

CLI 每次接受一个已提取的 AXML 文件，支持帮助、版本参数和文件名 `--` 终止符。批量库不执行 I/O，也不限制保留数据的总量；尚未实现 APK 提取或持久化目录应用。

## 限制与复现

- [x] 默认限制为 16 MiB 输入、100,000 个字符串、深度 256、500,000 个事件、每元素 65,535 个属性、字符串池合计 4 Mi 个解码 UTF-16 单元；配置限制测试覆盖拒绝路径。
- [x] XML 输出默认限制为 32 Mi 个 UTF-16 单元。输出限制测试及共享字符串/style 偏移用例约束展开；白盒 32,768 单元字符串与语料 33,000 单元字符串验证扩展 UTF-16 长度。
- [x] 自有语料附来源、许可、哈希、XML 源文件、参考输出与生成脚本。不再分发第三方 APK；库本身不需要 Android/JVM 运行时。
- [x] 已在 Windows JS/native 测量大字符串池、最大深度、重复引用和畸形输入的时间/内存基准，核对独立预期 XML 哈希和精确错误偏移；见 [BENCHMARKS_zh.md](BENCHMARKS_zh.md)。结果限于实测场景，不代表跨平台吞吐、内存或零拷贝保证。
- [x] 实现、证据、许可和复现材料已一并提交。初始提交 `087beb9` 的干净检出通过格式检查、全部后端检查、46 项 JavaScript 测试、CLI 构建及完整语料验证，工作区保持干净。

## 发布关卡

- [x] 提交 `61279a8` 的最新托管 Linux、Windows 验证通过：每个后端 75 项测试，完整 JS/native CLI 语料及帮助、版本、终止符检查通过。[GitHub Actions](https://github.com/LING71671/moonbit-axml/actions/runs/41391697996)、[结果记录](../evidence/verification-development.json)。后续文档及证据提交不改变已测试源码。
- [x] 初始提交 `19c2e11` 的托管 Linux、Windows 格式/接口/check/build/test 及 JS/native CLI 语料任务全部通过：[GitHub Actions](https://github.com/LING71671/moonbit-axml/actions/runs/41377746057)、[结果记录](../evidence/verification-hosted.json)。每个宿主的每个后端均运行 46 项测试。该历史快照早于查询、批量及渲染新增功能；最新验证单独记录。
- [ ] 审查包内容及最终元数据，验证认证账号，并明确授权发布。使用 [ACCOUNTS_zh.md](ACCOUNTS_zh.md) 中的仓库账号封装脚本；禁止切换全局账号。
- [ ] 发布获准的 Mooncakes 版本，并验证从仓库安装；目前仍未发布。
- [ ] 参赛申报前重新查重，由参与者审阅资格、申请文字及 AI 使用声明；不隐含自动报名。
