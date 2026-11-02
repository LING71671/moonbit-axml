# 文档统计

[English](STATS.md)

## CLI

```sh
moon build src/cmd/axml --target js --deny-warn
node _build/js/debug/build/cmd/axml/axml.js stats --json fixtures/valid/menu.axml
```

`stats FILE` 和 `stats --json FILE` 输出相同的缩进 JSON。文件名以 `--` 开头时，
使用 `stats -- --leading-dash.axml` 或 `stats --json -- --leading-dash.axml`。
`stats --help` 和 `stats -h` 显示用法。native CLI 接受相同参数。计数前先执行二进制
解码；畸形输入退出码为一，并输出带字节偏移的诊断。统计不渲染 XML，也不要求清单根元素。

## 汇总已解码的文档

```moonbit
let document = @axml.decode(input_bytes)
let stats = document.stats()
println(stats.max_depth)
println(stats.to_json().stringify(indent=2))
```

`Document::stats() -> DocumentStats` 直接读取现有池与事件，不渲染 XML、解析资源或
执行 I/O。时间复杂度为 `O(strings + events)`，额外空间为常数。不复制或修改文档，
不分配树结构，也不重新验证输入。

## 计数含义

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `strings` | `Int32` | 已保存的字符串池条目数，包括空值和重复条目 |
| `string_utf16_units` | `Int64` | 所有已保存字符串的 UTF-16 代码单元数之和 |
| `resource_ids` | `Int32` | 已保存的资源映射条目数，包括零值和重复条目 |
| `events` | `Int32` | 全部事件数，包括命名空间开始与结束 |
| `start_elements` | `Int32` | 元素开始事件数 |
| `attributes` | `Int64` | 所有元素开始事件的属性总数 |
| `text_events` | `Int32` | 文本事件数，包括空文本 |
| `namespace_declarations` | `Int32` | 命名空间开始事件数，结束事件不重复计入 |
| `max_depth` | `Int32` | 同时打开的元素最大层数，根元素深度为一 |

两个累加总量使用 `Int64`，避免手动构造的文档共享长字符串或属性数组时超出有符号
32 位整数范围。`DocumentStats` 派生 `Eq`、`Debug` 和 `ToJson`。MoonBit 将其
`Int64` 字段序列化为十进制 JSON 字符串，`Int32` 字段则为 JSON 数字。
补充平面字符占两个 UTF-16 单元。重复的事件引用不会增加 `string_utf16_units`；
每个字符串池位置计算一次。共享属性数组在每个元素开始事件中分别计数。

## 手动构造的事件流

空文档的全部计数与深度均为零。统计不检查 XML 名称、命名空间、属性唯一性、根元素
数量或元素名称配对。每个元素开始事件增加深度；元素结束事件仅在当前深度大于零时
减少深度。在深度为零时遇到多余结束事件，会忽略它对深度的影响；未闭合的开始事件
仍影响最大深度。结果是已保存事件的汇总，不能证明手动文档可以渲染或提取清单信息。

自有语料 `fixtures/valid/menu.axml` 的统计为：11 个字符串、108 个 UTF-16 单元、
6 个资源 ID、8 个事件、3 个元素开始、8 个属性、0 个文本事件、1 个命名空间声明，
最大深度为 2。

## 验证

运行 `moon test src/stats_test.mbt --target wasm-gc --deny-warn`，再使用 `js` 和
`native` 重复运行。测试涵盖已提交的 aapt2 菜单语料、空池、补充平面字符、命名空间、
文本、嵌套与同级元素、共享属性数组、不平衡的手动事件流和超过 `Int32` 范围的总量。
`python scripts/verify_cli.py` 另行检查 CLI 菜单统计、JSON 字段类型、信息参数和畸形语料拒绝行为。
