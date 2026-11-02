# 项目筛选总览：四项保留，Sonic 暂缓

[English](PORTFOLIO.md)

状态更正：2026-11-02。**Sonic 因与 [MoonMel 核心功能重合](https://github.com/1zhouhaoran1/MoonMel/blob/b49eb6d239ae148a9782f4495332090bc1ee727c/src/features/effects/effects.mbt#L110) 暂缓，原“通过查重”结论撤回。** 五个文件夹仍保留，当前为四项保留候选加一项暂缓研究；本轮未重新审查其他四项，实施进度以各项目 README 为准。

| 建议顺序 | 项目 | 预算（8 小时/人日） | 说明 |
| --- | --- | --- | --- |
| 1 | [Android 二进制 XML](../../moonbit-axml/README_zh.md) | 7–10 人日 | 保留原候选状态；进度见 README |
| 2 | [Beanstalkd 任务队列客户端](../../moonbit-beanstalkd/README_zh.md) | 6–9 人日 | 保留原候选状态；进度见 README |
| — | [Sonic 语音保调变速](../../moonbit-sonic/README_zh.md) | 不计入当前预算 | 暂缓：与 MoonMel 重合，独立价值未证实 |
| 4 | [标准 EDN 读写](../../moonbit-edn/README_zh.md) | 8–10 人日 | 保留原候选状态；进度见 README |
| 5 | [Android 稀疏镜像工具库](../../moonbit-android-sparse/README_zh.md) | 7–10 人日 | 保留原候选状态；进度见 README |

排除暂缓的 Sonic，四项原始预算合计 **28–39 人日（224–312 小时）**，未扣除后续已完成工作，另有返工预算。这不是本轮重新估算的剩余工时；各项目当前进度和剩余工作以其 README/验收记录为准。

## 保留候选的原筛选标准（Sonic 已撤回）

1. 已有成熟的其他语言实现或权威标准，且存在明确使用者。
2. 公开检索未定位到覆盖本次范围的同等 MoonBit 实现；相关库已检查功能差异。
3. 交付可复用库，包含实际调用示例及互操作验证，不只完成字符串匹配或头部解析。
4. 范围、错误语义和完成条件明确，可以用参考实现或固定语料复核。
5. 每项应独立满足价值门槛；Sonic 现已不满足该判断；不把同一项目拆成多项。

这是选题评估结论，不是赛方对价值、资格或奖金的批准。五位申报者应如实说明各自贡献与协作关系；作者、仓库归属和报名身份尚未配置。

## 已排除的方向

| 方向 | 证据与结论 |
| --- | --- |
| Avro 模式演进 | [未进入本次包索引的 MoonAvro](https://github.com/ppyj663/MoonAvro) 已有 writer→reader resolution，不再当作空白题。 |
| Memcached Meta | [已有客户端](https://github.com/lexchb/moonbit-memcached)；Meta 可以作为扩展，但不是全新客户端空白题。 |
| NPZ 压缩 | [已有 NPY/NPZ 库](https://github.com/ShunjunGu/moon-npy)；仅补 DEFLATE 的独立项目体量偏薄。 |
| EditorConfig / gettext / URI Template / semver range | 已有 MoonBit 实现，不恢复为新项目候选。 |
| Binary logcat | 有真实用途，但原筛选时范围偏窄，暂不立项。 |

## 查重边界与赛事日期

查询覆盖 Mooncakes 3518 条公开模块元数据、GitHub 仓库/代码以及网页别名检索；查询、近似实现和来源记录见本项目 RESEARCH 文档与 evidence 文件。公开搜索无法排除私有仓库、未索引分支和正在开发但尚未公开的项目；结论只能写成“截至检索日未定位到同等实现”。

[官方赛事页面](https://moonbitlang.github.io/Hackathon2026/) 的 [页面源码](https://github.com/moonbitlang/Hackathon2026/blob/main/src/App.tsx) 在本轮仍显示十月赛和 10 月 31 日截止；十一月细则与日期尚未核实。不要沿用旧截止日期。

正式申报前，申报者应阅读并独立理解选题；本批文件是 AI 辅助研究材料，不应伪称为人工手写申报书。发布前重跑查重，确认许可证和身份信息，按新赛期规则建立公开开发记录。


## 本次漏项带来的查重修正

不能把全量元数据匹配当作全量源码检查。MoonMel 已出现在旧 audio 匹配结果中，但摘要只强调特征提取，音效 API 被漏读。后续对每个相关库枚举子包、公开接口及实现，包含 `time_stretch`、`timeStretch`、`phase_vocoder` 等拼写；零搜索命中不能代替 API 审阅。
