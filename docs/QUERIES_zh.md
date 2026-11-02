# 按命名空间查询文档

[English](QUERIES.md) | [项目说明](../README_zh.md)

`Document::root()` 返回首个开始元素事件，保留原始字节偏移和行号；没有元素时返回
`None`。`Document::elements(namespace_uri, local_name)` 按文档顺序返回匹配的开始
事件。`Event::attribute(namespace_uri, local_name)` 查询开始事件上的属性；其他类型
事件返回 `None`。

```moonbit
let document = @axml.decode(input)
let applications = document.elements(None, "application")
for application in applications {
  let label = application.attribute(
    Some("http://schemas.android.com/apk/res/android"), "label",
  )
  ignore(label)
}
```

查询使用命名空间 URI 与区分大小写的本地名称。`None`、`Some("")` 均表示没有命名空间。
元素的默认命名空间不作用于未加前缀的属性。查询 `android:name` 时传入 Android
命名空间 URI，输入采用何种前缀不影响结果。

这些接口直接查询现有事件，不重新解析字节或解析资源 ID，也不校验手工构造的文档。
返回的事件保留原有属性数组，不进行深拷贝。处理不可信输入时应先调用解码器。
