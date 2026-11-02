# XML 渲染

[English](RENDERING.md)

`to_xml(document)` 输出紧凑的 XML 1.0。`to_xml_pretty(document)` 复用相同的命名空间、名称、属性值与转义检查，在只含子元素的内容中添加每层两个空格的缩进与 LF 换行。空元素保留显式结束标签；不添加 XML 声明或末尾换行。

```moonbit
let compact = @axml.to_xml(document)
let readable = @axml.to_xml_pretty(
  document,
  max_output_chars=2 * 1024 * 1024,
  max_depth=256,
)
```

## 内容保留

预扫描会在输出前识别直接文本事件。只要元素直接包含文本，其整个子树就保持紧凑输出，即使文本位于子元素之后。空字符串与仅含空白的 AXML CDATA 事件也视为文本。转义使用字符引用保留回车与属性中的空白。

包含扩展属性 `{http://www.w3.org/XML/1998/namespace}space="preserve"` 的子树同样保持紧凑。此保守规则覆盖带有 `xml:space="default"` 的后代。如果父元素仅包含子元素，格式化仍可在这些保留子树的前后添加分隔符。

格式化会在元素之间引入空白文本节点，因此需要显式启用，结果不属于规范化 XML，也不与紧凑结果逐字节等同。需要精确文本节点序列的使用方应选择紧凑渲染。CDATA 块的内容以转义文本保留，不重建 CDATA 分隔符。参见 [XML 空白规则](https://www.w3.org/TR/xml/#sec-white-space)。

## 限制与诊断

两个函数默认均限制输出为 32 Mi 个 UTF-16 码元。`max_output_chars` 包括所有新增换行与缩进；非 BMP 字符计为两个码元。超过限制会抛出 `DecodeError::Invalid`，携带对应事件的源文件字节偏移。

格式化渲染还默认限制 `max_depth=256`，同时适用于手动构造的文档与保持紧凑的子树。两个限制都必须为正数。显式提高 `max_depth` 可支持使用更大 `Limits` 解码的文档；缩进会在乘法与写入之前检查输出预算。渲染使用迭代栈，不进行递归遍历。

运行 `moon test src --target wasm-gc --deny-warn` 验证渲染测试；分别替换为 `js` 与 `native` 验证其他支持的目标。
