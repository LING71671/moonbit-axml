# AXML 选题复查

[English](RESEARCH.md) | [项目说明](../README_zh.md) | [机器证据](../evidence/recheck.json)

最新复查：**2026-11-02，UTC+8**；首次复查：**2026-11-01**。结论：建议以完整 AXML 读取库和离线 CLI 在本地立项；不代表已获赛方认可。

## 2026-11-02 再次复查

[Mooncakes 模块接口](https://mooncakes.io/api/v0/modules) 当前返回 **3,520 条**记录，首次复查为 3,518 条。元数据忽略大小写搜索 `axml`、`resxml`、`arsc`、`aapt` 均无匹配。五个 `android` 命中分别涉及 JNI、配件通信、WASI 宿主、应用脚手架或 UI 集成；binary XML 与 APK 相关命中仍为 Apple plist、Windows EVTX/BINXML、Alpine 包。这是元数据发现，不是对所有源码的穷尽审计。

GitHub 代码重新检索：`RES_XML_TYPE`、`RES_STRING_POOL_TYPE` 配合 `language:MoonBit`，以及 `ResXMLTree`、`RES_XML_START_ELEMENT_TYPE`、`AXMLParser`、`AXMLPrinter`、`binary_xml` 配合 `extension:mbt`，均无匹配。宽泛 `AXML` 查询有 27 个命中，逐项核对为 RAxML/PDF 标识符、Base64 内容或旧式非 MoonBit XML。五个 AndroidManifest 命中属于应用构建器或文本模板，不是二进制解码器。公开 issue/PR 标题及正文中未找到同时涉及 AXML 与 MoonBit 的提案，放宽到评论后的命中也无关；这些查询不覆盖非公开报名及全部开发分支。

网页重新检索项目名、AndroidManifest、binary XML、格式常量、中英文别名，以及已被索引的 Gitee/GitLink 结果。补充阅读的近似项目：[xml-mbt](https://github.com/moonbit-community/xml-mbt) 明确通过 `Reader::from_string` 接收文本 XML；[thy1016/moonxml](https://www.gitlink.org.cn/thy7/mbt.xml) 解析、序列化文本 XML。两者 README 均未描述 Android 二进制 chunk 解码。[androguard/axml-parser](https://github.com/androguard/axml-parser) 已用 Rust 提供 AXML/ARSC 和 CLI，并提供可选 Python 绑定；本题潜在缺口限定为 MoonBit 实现。

证据：[登记库查询](../evidence/registry-recheck-2026-11-02.json)、[GitHub 查询与源码复核](../evidence/github-recheck-2026-11-02.json)、[网页查询与已读来源](../evidence/web-recheck-2026-11-02.json)。保留首次证据，不覆盖其历史查询结果。上述检查未定位到等价 MoonBit Android AXML 库或 CLI；私有工作、未索引仓库、非默认分支和非公开报名资料不在证据范围内。

## 首次检索方式：2026-11-01

已刷新 Mooncakes 公开模块端点，共 3,518 条。对全量 name、description、keywords、repository 元数据搜索 AXML、APK、Android、XML、plist 等名称和别名。元数据不能证明源码具备哪些功能，也不覆盖所有未发布项目。

GitHub connector 仓库搜索包含 `MoonBit axml`、`android language:MoonBit`、`"binary xml" language:MoonBit`。代码搜索包含 `AXML language:MoonBit`、`"RES_XML_TYPE" language:MoonBit`、`"RES_STRING_POOL_TYPE" language:MoonBit`、`"AndroidManifest" language:MoonBit`、`"binary xml" language:MoonBit`。AXML 常量查询没有索引命中；宽泛 AXML 只命中 RAxML 生物学包装及 PdfMetadataXml 子串。

网页还查了 `MoonBit AXML AndroidManifest binary XML`、`MoonBit "binary XML" Android`、`MoonBit AXML parser`。详细查询和实际结果见机器证据。公开索引不覆盖私有仓库、未建立索引的新项目、全部分支，因此不能由“没搜到”推出“绝对不存在”。

## 已阅读的近似项目

| 项目及实际阅读来源 | 实际能力 | 与本题差别 |
| --- | --- | --- |
| [moonbitstack/moonxml README](https://github.com/moonbitstack/moonxml/blob/master/README.md) | XML 1.0 文本和 HTML 树、CSS/XPath | 没有描述 Android ResXMLTree chunk/字符串池 |
| [MoonPlist README](https://github.com/Han-Wentao/moonplist/blob/codex/moonplist/README.md) | Apple bplist00 与 plist XML | 二进制格式和对象模型不同 |
| [MoonEvtx README](https://github.com/kekeshuo/moonevtx/blob/main/README.md) | 微软 EVTX/BINXML | 文件头、token 流和事件模型不同 |
| [linuxpkg README](https://github.com/pxgt/linuxpkg/blob/main/README.md) | Linux 包构建，包含 Alpine .apk | Alpine .apk 与 Android .apk 无关 |
| [still.fail APK 工具源码](https://github.com/AFK-surf/still.fail/blob/main/apps/mbui/mbui/tools/apk/main.mbt) | 调用 SDK aapt2，处理源码/AAR 文本 Manifest | 是构建编排器，不是进程内二进制 Manifest 解析库 |

本轮公开范围未定位到等价实现。有价值的交付是可复用的类型化解码和真实 Manifest 工作流，只识别格式头不够。

## 成熟上游和固定版本

| 参考 | 修订及许可 | 用途 |
| --- | --- | --- |
| [AOSP ResourceTypes.h](https://github.com/aosp-mirror/platform_frameworks_base/blob/d67e90e8a8301a87726420a1071fca8e52172bd4/libs/androidfw/include/androidfw/ResourceTypes.h) | d67e90e8a8301a87726420a1071fca8e52172bd4；Apache-2.0 | chunk、字符串池、属性和类型值的格式依据 |
| [Java apk-parser](https://github.com/hsiafan/apk-parser/tree/4d5a08e4d28fa2fce7fa356394c62c5e51a192e2) | 4d5a08e4d28fa2fce7fa356394c62c5e51a192e2；BSD-2-Clause | 成熟 API；查询时 1,284 stars；已归档，不能作为唯一格式依据 |
| [androguard/axml-parser](https://github.com/androguard/axml-parser/tree/93d008a7ce337fb9bafb708bc8ce93ecdc25f80b) | 93d008a7ce337fb9bafb708bc8ce93ecdc25f80b；Apache-2.0 | 解码参考实现与 tests/AXML 语料 |
| [官方 APK Analyzer](https://developer.android.com/studio/debug/apk-analyzer) | Android 官方文档 | 证明“还原并检查最终合并 Manifest”是真实开发任务 |

已阅读 Rust 测试文件，包含 UTF-8、命名空间、CDATA/text、畸形字符串池头、空字节、未终止字符串等。部分语料面向宽松修复；MVP 要逐项记录支持、明确拒绝或有文档的策略差异，不能承诺所有修复都与其一致。

## 测试语料方案

用固定版本 aapt2 编译自有源码语料：最小 Manifest、多语言、命名空间/属性组合、菜单 XML。记录 binary SHA-256、源 XML、aapt2 参考 dump、预期语义、参考版本和生成命令。

固定 androguard 语料作为额外差分来源，但须先逐文件记录出处和可再分发状态，不能因为 APK 出现在上游测试目录就直接打包分发。畸形输入独立构造，覆盖截断、数量/偏移溢出、字符串索引错误、UTF-16 代理对和事件不平衡。

本轮没有下载测试二进制、构建 aapt2、执行或通过实现测试，也没有测量 MoonBit 性能。以上 commit 是复现锚点，不代表上游所有路径都已验证。

## 申报与验收门槛

申报前重新查重，说明计划范围和资源引用限制；验收前按参考数据跑通三个场景，有真实 CI 记录后再发布。立项、验收和奖金由赛方判断。
