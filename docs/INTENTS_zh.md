# Manifest Intent Filter 检查

[English](INTENTS.md)

`inspect_intent_filters(document)` 按文档顺序返回声明，不修改 `Manifest`，也不推断 Android 运行时行为。

## 检查声明

```moonbit
let filters = @axml.inspect_intent_filters(document)
for filter in filters {
  let declares_view = filter.has_action("android.intent.action.VIEW")
  let declares_browsable = filter.has_category("android.intent.category.BROWSABLE")
  // Inspect filter.component_name and filter.data for the original typed values.
}
```

检查器只选择 `manifest/application` 下无命名空间的 `activity`、`activity-alias`、`service`、`receiver` 声明中直接包含的无命名空间 `intent-filter`。Provider 过滤器暂不在此 API 的提取范围。带命名空间的扩展元素或额外包装层不能冒充这些祖先。嵌套声明不会合并到结果中，包括 `uri-relative-filter-group` 内的 data。

Android 的 [intent-filter 参考文档](https://developer.android.com/guide/topics/manifest/intent-filter-element)介绍平台声明规则。此 API 仅报告上述子集，不实现 Android 的 Intent 解析，也不校验完整 Manifest 模式。

## 保留的信息

| 字段 | 含义 |
| --- | --- |
| `component_kind`、`component_name` | 原始父组件类型及可选的 Android 命名空间 `name` 属性；相对类名与资源引用保持原样。 |
| `offset`、`line_number` | 过滤器开始元素的原始位置。 |
| `attributes` | 过滤器的全部原始属性，包括未知属性。 |
| `actions`、`categories` | 无命名空间直接子元素中 Android 命名空间的 `name` 属性；保留顺序、重复项、原始值与类型化引用。缺少此属性的子元素会被略过。 |
| `data` | 每个无命名空间直接 `data` 子元素对应一个属性数组；保留空声明、顺序及所有命名空间属性。 |

各过滤器的 action、category、data 数组相互独立。从事件保留的属性数组与原文档共享；需要保留原始检查结果时，应将其视为只读数据。

`has_action` 与 `has_category` 仅对类型为字符串字面量的 `android:name` 做区分大小写的匹配。空查询、未解析的引用、非字符串值均不匹配；原始文本不会被当作解析结果。
这些辅助方法只检查声明，不判断组件是否可启动、exported/enabled 状态、App Links 验证、URI 匹配或平台默认值。

## 校验与测试

提取前会调用一次 `inspect_manifest`。其 Manifest 与 XML 校验、携带偏移的 `DecodeError` 诊断、XML 输出上限同样适用于手动构造的文档。合法 Manifest 中没有符合范围的过滤器时返回空数组；空过滤器会被保留，不强制要求 action 声明。

```sh
moon test src/intent_filters_test.mbt --target wasm-gc --deny-warn
```

将目标替换为 `--target js` 和 `--target native` 可检查其他受支持后端。
