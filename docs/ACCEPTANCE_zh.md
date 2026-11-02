# 验收清单

[English](ACCEPTANCE.md) | [项目说明](../README_zh.md)

状态：**截至 2026-11-02，功能已实现并通过本地验证；发布关卡仍未完成**。这是仓库的交付清单，不是赛方认可的标准。GitHub 仓库已公开，采用 Apache-2.0；`LING71671/axml` 尚未发布到 Mooncakes。

## 验证快照

| 检查 | 已验证结果 | 证据 |
| --- | --- | --- |
| 两轮开发后的本地测试 | wasm-gc、Windows native 各通过 130/130 项；JavaScript 通过 133/133 项；前端 18/18 项，严格 TypeScript/构建及浏览器沙箱通过 | [两轮验证记录](../evidence/verification-two-rounds.json) |
| `ef6591b` 托管测试及 Pages | Linux/Windows 各通过 wasm-gc 130 项、JS 133 项、native 130 项、前端 18 项；紧凑/格式化 CLI 语料、浏览器沙箱及每宿主八种压力组合通过。线上搜索、完整引用下载和源位置选择已验证 | [CI](https://github.com/LING71671/moonbit-axml/actions/runs/41406894685)、[Pages](https://github.com/LING71671/moonbit-axml/actions/runs/41406894944)、[两轮证据](../evidence/verification-two-rounds.json) |
| `8dffd5b` 浏览器工作台 | 12 项前端测试、严格 TypeScript/构建、隔离 ESM 检查、本地浏览器流程与子路径加载 | [工作台验证](../evidence/verification-workbench.json)、[演示说明](DEMO_zh.md) |
| `b1dd568` 托管测试 | Linux、Windows 各通过 wasm-gc 114 项、JS 117 项、native 114 项、前端 12 项；完整 CLI 语料、浏览器沙箱及每宿主八种压力组合通过 | [CI](https://github.com/LING71671/moonbit-axml/actions/runs/41399307068)、[工作台托管证据](../evidence/verification-workbench-hosted.json) |
| GitHub Pages 工作台 | 构建及部署成功；线上样例、本机 Unicode 输入、引用选择及精确 XML 下载验证通过 | [线上工作台](https://ling71671.github.io/moonbit-axml/)、[部署记录](https://github.com/LING71671/moonbit-axml/actions/runs/41399307093) |
| CLI 语料 | 19 份语料哈希、7 棵 XML 语义树、3 份 Manifest 记录、菜单统计、精确类型引用来源、12 份畸形输入 | `scripts/verify_cli.py`、`fixtures/manifest.json` |
| CLI 宿主 | Node.js、Windows native、Linux native | 相同扩展语料；[各宿主结果](../evidence/verification-extension.json) |
| 独立参考 | aapt2 2.20-13193326、Android Build Tools 36.0.0 / android-36、androguard 4.1.3 | `fixtures/reference/`、[复现步骤](../fixtures/README_zh.md) |
| Windows 有限基准 | 四种场景，JS/native，各实测三次，24 次全部通过 | [方法与结果](BENCHMARKS_zh.md)、[原始记录](../evidence/benchmark.json) |
| 托管压力正确性 | Linux、Windows 上各四种场景 × JS/native，16 次全部通过 | [CI 与日志核验](../evidence/verification-extension.json)；不设置耗时阈值 |

早期 46 项测试的 Linux 快照在 WSL2 的 Debian 中运行 native 可执行文件，与托管 CI 分开，且不覆盖后续新增接口。证据文件记录对应工具链版本与源码哈希；修改代码后须重新执行相关检查。

## 格式与行为

- [x] 解析 MVP 全部 chunk、UTF-8/UTF-16 字符串池、命名空间、resource-map、CDATA 及原始/类型化属性；检查索引、chunk 边界和文档作用域。
- [x] 保留原始值、类型数据与未解析资源 ID。资源引用保留为数字，不隐含 ARSC 查表能力。
- [x] 输出转义正确、扩展名称和属性值等价的 XML。独立 ElementTree 检查比较标准化语义树，覆盖命名空间遮蔽和 Unicode。
- [x] 提供可选的 `to_xml_pretty` / `decode --pretty`，含文本及 `xml:space="preserve"` 的子树保持紧凑。格式化会增加空白文本节点；默认仍为紧凑输出。七份语料通过紧凑及格式化树比较，见[渲染规则](RENDERING_zh.md)。
- [x] 提取包名/版本、SDK、权限、application 属性和组件；三个自有编译 Manifest 与独立参考逐字段比较。
- [x] 畸形输入返回带字节偏移的错误。12 份非法语料及白盒截断、Unicode、命名空间、限制、逐字节变异测试已通过；这是有限测试，不是穷尽 fuzzing。
- [x] 检查显式 Intent Filter 声明、统计文档、列出带位置的资源/主题引用，并暴露尺寸/分数的编码单位。接口保留原始数据，不执行 Android 运行时 Intent 匹配、资源查找或显示参数换算。

## 端到端流程

- [x] 构建检查场景：解码并检查提取后的编译 Manifest，包名、SDK、权限和组件记录在本地与参考一致。
- [x] 目录场景：`LING71671/axml/catalog` 按顺序处理带名称的字节输入，保留成功结果，并为每份失败输入返回阶段及偏移诊断。测试覆盖混合批次、自定义限制、重复标签和非 Manifest XML；见[接口说明](CATALOG_zh.md)。
- [x] 资源 XML 场景：编译菜单 AXML 转成 XML 后，由独立 parser 验证命名空间语义等价。
- [x] 工作台搜索：按协议字段及十进制/十六进制值在本地筛选结构与引用；保持每页 50 条，源位置跳转清除结构筛选，导出不受筛选影响。1,210 条事件输入验证了 1,000 条预览边界，见[筛选说明](DEMO_zh.md#筛选事件与引用)。

CLI 每次接受一个已提取的 AXML 文件，支持帮助、版本参数、可选的 `decode --pretty` 和文件名 `--` 终止符。批量库不执行 I/O，也不限制保留数据的总量；尚未实现 APK 提取或持久化目录应用。

## 限制与复现

- [x] 默认限制为 16 MiB 输入、100,000 个字符串、深度 256、500,000 个事件、每元素 65,535 个属性、字符串池合计 4 Mi 个解码 UTF-16 单元；配置限制测试覆盖拒绝路径。
- [x] XML 输出默认限制为 32 Mi 个 UTF-16 单元，包含格式化缩进及分隔符。格式化在展开前检查默认深度 256。输出限制测试及共享字符串/style 偏移用例约束展开；白盒 32,768 单元字符串与语料 33,000 单元字符串验证扩展 UTF-16 长度。
- [x] 自有语料附来源、许可、哈希、XML 源文件、参考输出与生成脚本。不再分发第三方 APK；库本身不需要 Android/JVM 运行时。
- [x] 已在 Windows JS/native 测量大字符串池、最大深度、重复引用和畸形输入的时间/内存基准，核对独立预期 XML 哈希和精确错误偏移；见 [BENCHMARKS_zh.md](BENCHMARKS_zh.md)。结果限于实测场景，不代表跨平台吞吐、内存或零拷贝保证。
- [x] 实现、证据、许可和复现材料已一并提交。初始提交 `087beb9` 的干净检出通过格式检查、全部后端检查、46 项 JavaScript 测试、CLI 构建及完整语料验证，工作区保持干净。

## 发布关卡

- [x] `ef6591b` 的托管 Linux/Windows 验证及 Pages 部署通过，包含两轮开发；上表及关联证据标明精确运行。后续文档及证据提交不改变已测试源码。
- [x] 提交 `6bc076b` 的历史托管 Linux、Windows 验证通过：每个后端 114 项测试、完整扩展 JS/native CLI 语料，每个宿主八种压力组合通过。[GitHub Actions](https://github.com/LING71671/moonbit-axml/actions/runs/41392861059)、[结果记录](../evidence/verification-extension.json)。
- [x] 保留历史托管快照：`61279a8` 每个后端 75 项（[CI](https://github.com/LING71671/moonbit-axml/actions/runs/41391697996)、[证据](../evidence/verification-development.json)）；`19c2e11` 为 46 项（[CI](https://github.com/LING71671/moonbit-axml/actions/runs/41377746057)、[证据](../evidence/verification-hosted.json)）。两个宿主均通过对应的格式、接口、检查、构建、测试及 CLI 语料；这些快照不覆盖之后的新增接口。
- [ ] 审查包内容及最终元数据，验证认证账号，并明确授权发布。使用 [ACCOUNTS_zh.md](ACCOUNTS_zh.md) 中的仓库账号封装脚本；禁止切换全局账号。
- [ ] 发布获准的 Mooncakes 版本，并验证从仓库安装；目前仍未发布。
- [ ] 参赛申报前重新查重，由参与者审阅资格、申请文字及 AI 使用声明；不隐含自动报名。
