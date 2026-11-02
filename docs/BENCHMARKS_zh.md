# 有界压力基准

[English](BENCHMARKS.md) | [验收](ACCEPTANCE_zh.md) | [项目](../README_zh.md)

## 复现

使用固定版本的 MoonBit 工具链、Python 3.10+ 和 Node.js 22。无需 Python 第三方包、Android SDK、网络连接或账号凭据。

```sh
moon build src/cmd/axml --target js --deny-warn
moon build src/cmd/axml-native --target native --deny-warn
python scripts/benchmark.py --output _build/benchmarks/report.json
```

在仓库根目录运行。通过 `--backend js` 或 `--backend native` 单独测量后端。`--js PATH` 和 `--native PATH` 可指定其他构建产物；比较结果时应注明构建配置。原生默认路径在 Linux 和 Windows 上均以 `.exe` 结尾，与 MoonBit 的构建输出一致。需要有意替换已提交快照时，使用 `--output evidence/benchmark.json`。

## 场景与正确性

生成器直接构造 AOSP 二进制 XML 块结构，独立于 MoonBit 实现。生成文件和临时输出均保存在已忽略的 `_build/benchmarks/` 中。

| 场景 | 工作负载 | 必须满足的结果 |
| --- | --- | --- |
| `large_pool` | 恰好 100,000 个 UTF-8 字符串池条目、一个根元素 | 成功输出与独立预期字节一致的 XML |
| `max_depth` | 恰好 256 层嵌套元素、512 个事件 | 在默认深度上限成功输出 XML |
| `repeated_strings` | 2,048 个属性引用同一个需要转义的 4,096 单元字符串，输出 8,454,158 字节 | 正确展开引用并转义 XML |
| `malformed_input` | 完整 100,000 条字符串池，最后的结束元素名称索引无效 | 退出码 1、标准输出为空、错误字节偏移与索引诊断准确 |

每次有效输入执行均将输出长度与 SHA-256 和独立构造的 XML 比较；无效输入执行检查错误。JSON 报告记录输入大小、SHA-256、字符串数、UTF-16 单元数、深度、事件数、产物哈希、源码哈希、版本、命令及每次实测数据。

## 测量方法

每个后端、每个场景默认先执行一次不计入结果的预热，再测量三个新进程。预热只影响文件系统缓存，不会预热持久运行的虚拟机。墙钟时间包括子进程启动、输入 I/O、解码、渲染及写入临时文件。生成输入、Python 父进程内存、正确性检查和后代进程均不在测量范围。输出写入磁盘，避免测量期间父进程保留捕获的 XML。

Windows 使用 `GetProcessMemoryInfo.PeakWorkingSetSize` 获取子进程全生命周期峰值工作集字节数，并在退出后再次查询。Linux/macOS 使用 `wait4.ru_maxrss` 获取子进程 RSS 高水位，并统一换算为字节。不支持的平台明确记录内存未测量。Windows 退出后查询失败时标记为仅轮询结果，不能证明完整生命周期峰值。RSS 是进程驻留内存，并非 V8 堆大小。

每次执行设置 30 秒超时和 1 GiB RSS 监测阈值。Windows 每 5 毫秒轮询；POSIX 在退出时检查 RSS。这些是监测措施，不是硬资源上限。Node 另传入 `--max-old-space-size=256`，限制 V8 老生代堆，而非总 RSS。`--timeout`、`--max-rss-mib`、`--repeats` 和 `--warmup` 可在规定范围内调整。

## 已记录的 Windows 快照

[原始证据](../evidence/benchmark.json) 记录了 Windows x86-64、Python 3.13.14、Node.js v22.22.1 下的 debug 构建。24 次计入结果的执行均通过正确性检查，并取得退出后的全生命周期峰值计数。下表时间为中位数，内存为三次实测峰值的最大值。

| 场景 | JS 秒数 / 峰值 MiB | 原生秒数 / 峰值 MiB |
| --- | --- | --- |
| 大字符串池 | 0.136794 / 71.5 | 0.104191 / 15.8 |
| 最大深度 | 0.093046 / 47.4 | 0.021781 / 9.4 |
| 重复字符串 | 0.222790 / 70.4 | 0.172407 / 41.5 |
| 畸形输入 | 0.136351 / 71.7 | 0.104101 / 15.7 |

这些数据只代表单台主机上的有界回归观测，不构成跨平台吞吐量、常量内存、零拷贝或硬性最坏情况保证。启动开销和主机并发活动会显著影响较短的执行。测量可能早于添加报告的提交，因此报告同时记录源码提交号、源码哈希与产物哈希。

实现保留原始片段的 XML 转义前，这个 2,048 次引用场景曾在探索运行中耗尽 JS debug 构建的 256 MiB V8 堆。本次快照在渲染修复后重新执行相同负载并通过。默认 XML 输出上限仍不能保证在所有外部堆限制下或对上限以内的所有输入均成功；更大输出规模的性能需要单独测量。
