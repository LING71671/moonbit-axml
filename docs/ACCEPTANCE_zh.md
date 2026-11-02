# 验收清单

[English](ACCEPTANCE.md) | [项目说明](../README_zh.md)

状态：**截至 2026-11-02，功能已实现并通过本地验证；发布关卡仍未完成**。这是仓库的交付清单，不是赛方认可的标准。GitHub 仓库为私有；`LING71671/axml` 尚未发布到 Mooncakes。

## 验证快照

| 检查 | 已验证结果 | 证据 |
| --- | --- | --- |
| MoonBit 测试 | wasm-gc、JavaScript、Windows native、Linux native 各通过 46/46 项 | 同目录的 `src/*_test.mbt`、`src/*_wbtest.mbt`；Linux 快照见下 |
| CLI 语料 | 19 份语料哈希、7 棵 XML 语义树、3 份 Manifest 记录、12 个畸形输入错误 | `scripts/verify_cli.py`、`fixtures/manifest.json` |
| CLI 宿主 | Node.js、Windows native、Linux native | 相同语料；[Linux 执行记录](../evidence/verification-linux.json) |
| 独立参考 | aapt2 2.20-13193326、Android Build Tools 36.0.0 / android-36、androguard 4.1.3 | `fixtures/reference/`、[复现步骤](../fixtures/README_zh.md) |

Linux 验证在 WSL2 的 Debian 中运行 native 可执行文件，不代表远程 CI 结果。证据文件记录对应工具链版本与源码哈希；修改代码后须重新执行相关检查。

## 格式与行为

- [x] 解析 MVP 全部 chunk、UTF-8/UTF-16 字符串池、命名空间、resource-map、CDATA 及原始/类型化属性；检查索引、chunk 边界和文档作用域。
- [x] 保留原始值、类型数据与未解析资源 ID。资源引用保留为数字，不隐含 ARSC 查表能力。
- [x] 输出转义正确、扩展名称和属性值等价的 XML。独立 ElementTree 检查比较标准化语义树，覆盖命名空间遮蔽和 Unicode。
- [x] 提取包名/版本、SDK、权限、application 属性和组件；三个自有编译 Manifest 与独立参考逐字段比较。
- [x] 畸形输入返回带字节偏移的错误。12 份非法语料及白盒截断、Unicode、命名空间、限制、逐字节变异测试已通过；这是有限测试，不是穷尽 fuzzing。

## 端到端流程

- [x] 构建检查场景：解码并检查提取后的编译 Manifest，包名、SDK、权限和组件记录在本地与参考一致。
- [x] 目录场景：校验脚本分别处理合法与非法文件；合法结果正常产出，每个非法调用标识文件及原因。
- [x] 资源 XML 场景：编译菜单 AXML 转成 XML 后，由独立 parser 验证命名空间语义等价。

CLI 每次接受一个已提取的 AXML 文件；尚未实现 APK 提取或持久化的批量目录应用。

## 限制与复现

- [x] 默认限制为 16 MiB 输入、100,000 个字符串、深度 256、500,000 个事件、每元素 65,535 个属性、字符串池合计 4 Mi 个解码 UTF-16 单元；配置限制测试覆盖拒绝路径。
- [x] XML 输出默认限制为 32 Mi 个 UTF-16 单元。输出限制测试及共享字符串/style 偏移用例约束展开；白盒 32,768 单元字符串与语料 33,000 单元字符串验证扩展 UTF-16 长度。
- [x] 自有语料附来源、许可、哈希、XML 源文件、参考输出与生成脚本。不再分发第三方 APK；库本身不需要 Android/JVM 运行时。
- [ ] 建立大字符串池、最大深度、重复引用和畸形输入的时间/内存基准；目前不宣称吞吐量、峰值内存或零拷贝保证。
- [ ] 将实现、证据、许可和复现材料一起提交，并从该提交的干净 checkout 验证复现。

## 发布关卡

- [ ] 远程运行 `.github/workflows/ci.yml`，确认格式/接口/check/build/test 和 CLI 语料任务。工作流已存在，尚不宣称托管 CI 成功。
- [ ] 审查包内容及最终元数据，验证认证账号，并明确授权发布。使用 [ACCOUNTS_zh.md](ACCOUNTS_zh.md) 中的仓库账号封装脚本；禁止切换全局账号。
- [ ] 发布获准的 Mooncakes 版本，并验证从仓库安装；目前仍未发布。
- [ ] 参赛申报前重新查重，由参与者审阅资格、申请文字及 AI 使用声明；不隐含自动报名。
