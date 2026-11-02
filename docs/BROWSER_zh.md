# 浏览器分析桥接层

[English](BROWSER.md) | [统计](STATS_zh.md) | [资源引用](REFERENCES_zh.md)

## 构建与调用

```sh
moon build src/browser --target js --release --deny-warn
node --experimental-vm-modules scripts/verify_browser.mjs
```

仅支持 JS 的外部库包生成独立 ES 模块
`_build/js/release/build/browser/browser.js`，命名导出为 `analyze_bytes`。
同目录包含生成的 `browser.d.ts` 与 `moonbit.d.ts`。MoonBit `Bytes` 对应 JavaScript
`Uint8Array`，`String` 对应 JavaScript 字符串。函数不使用 Node 全局对象、文件 I/O
或网络，不在调用间保留状态，也不修改输入。

```js
import { analyze_bytes } from "./browser.js";
const report = JSON.parse(analyze_bytes(new Uint8Array(arrayBuffer)));
```

在模块 Worker 中执行这个同步调用，避免大型分析占用 UI 线程。每次选中文件仅解码一次，
切换视图时复用解析后的报告。支持 `Uint8Array` 子视图，仅解码其可见字节。调用方不再
需要缓冲区时，可向 Worker 转移独占的 `ArrayBuffer`。

## 第 1 版响应结构

每次返回 JSON 文本，包含 `schema_version`、`ok` 和 `input_bytes`。顶层 `ok` 表示
二进制解码是否成功，与各派生视图独立。解码失败时返回顶层 `error`，包含
`stage: "decode"`、原始字节 `offset` 和 `message`，不附带部分视图载荷。

解码成功的响应包含以下字段：

| 字段 | 结构与含义 |
| --- | --- |
| `xml` | `{ok, value}` 或 `{ok, error}`；始终附带 `limit_utf16_units: 2097152` |
| `manifest`、`intents` | 各自独立的 `{ok: true, value}` 或 `{ok: false, error}` 结果 |
| `stats` | [DocumentStats](STATS_zh.md)；`attributes` 与 `string_utf16_units` 为十进制 JSON 字符串 |
| `references` | [ResourceUsage](REFERENCES_zh.md) 数组，保留数字 ID 与原始事件位置 |
| `events` | `{total, preview, limit: 1000, truncated}`，包含有序事件摘要 |

视图错误阶段为 `xml`、`manifest` 或 `intents`，附带字节 `offset` 和 `message`。
因此，有效菜单在清单与意图检查失败时，仍保留 XML、统计、资源引用和事件摘要。
XML 预览超限也会保留其他视图。读取 `value` 前检查对应视图的 `ok`；顶层 `ok`
不代表 XML 或清单校验成功。

## 事件预览与限制

每条摘要包含 `index`、`offset`、`line_number`、`kind`、`namespace_uri`、`name`、
`attribute_count` 和 `text_utf16_units`。类型名为 `StartNamespace`、`EndNamespace`、
`StartElement`、`EndElement`、`Text`。命名空间事件将前缀放入 `name`；缺失或不适用的
名称、URI 为 `null`，不适用的计数为零。索引对应原始事件数组，不是过滤后的表格。
仅预览前 1,000 个事件。

摘要不重复属性与文本载荷，也不导出字符串池或资源池。引用与清单属性保留现有派生
JSON 表示，包括可选位置参数命名空间数组。解码采用核心默认限制，输入上限为 16 MiB。
XML 视图另设 2 Mi 个 UTF-16 单元的输出预算；超限返回错误，不返回部分 XML。
桥接层没有额外设置元数据或 JSON 总量预算，Worker 宿主应支持终止并替换耗时分析。
清单和意图 API 当前会在内部自行检查 XML，因此桥接层避免重复字节解码，但可能多次
执行同一文档的渲染检查。

## 验证范围

验证脚本在没有 `process`、`require`、`Buffer` 的 VM 沙箱中执行编译后的 ESM，
并拒绝模块导入和 Node 依赖。覆盖自有菜单、基础清单、资源引用、Unicode 语料，畸形输入，
带偏移的类型数组，精确事件摘要，1,000 事件边界，XML 禁用字符，输入限制，以及 XML
预算失败隔离。这些检查验证桥接层的宿主边界；浏览器 Worker/UI 集成需另行验证。
