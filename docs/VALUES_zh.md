# Android 类型值读取接口

[English](VALUES.md) | [项目说明](../README_zh.md)

`TypedValue` 始终保留 `data_type`、完整 32 位 `data`，以及适用时的字符串池解码结果
`string_value`。便捷接口只解释对应类型：

| 方法 | 匹配类型 | 结果 |
| --- | --- | --- |
| `as_string()` | TYPE_STRING | 可选的解码字符串 |
| `as_integer()` | TYPE_INT_DEC / TYPE_INT_HEX | 可选的有符号 Int32，保留负数位模式 |
| `as_boolean()` | TYPE_INT_BOOLEAN | 可选 Bool；零为假，非零为真 |
| `as_float()` | TYPE_FLOAT | 可选 IEEE-754 Float |
| `reference()` | 资源、主题及动态引用 | 含种类和数值 ID 的可选 `ValueReference` |

类型不匹配时返回 `None`，不进行字符串强制转换。包含 `"42"` 的字符串仍是字符串，
形似资源编号的整数仍是整数。资源引用和主题引用分别保留，动态种类明确表示可能需要
外部资源加载器重新绑定包 ID。

```moonbit
match attribute.value.reference() {
  Some(@axml.ValueReference::Resource(id)) => ignore(id)
  Some(_) => ()
  None => ignore(attribute.value.as_string())
}
```

浮点读取接口保留 NaN、无穷值供调用方检查，XML 输出仍拒绝非有限浮点数。
这些接口不补充 Android 默认值或解析 ARSC，调用方仍可读取原始数据实施自己的策略。
