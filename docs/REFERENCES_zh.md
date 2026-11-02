# 类型化资源引用清单

[English](REFERENCES.md) | [类型化值](VALUES_zh.md) | [项目](../README_zh.md)

## 收集引用

`Document::resource_references() -> Array[ResourceUsage]` 列出类型化资源引用和主题属性引用，不解析资源表：

```moonbit
let document = @axml.decode(bytes)
for usage in document.resource_references() {
  // The original event location, not an offset inside its attribute record.
  println("byte \{usage.offset}, line \{usage.line_number}")
  match usage.reference {
    Resource(id) => println("resource \{id}")
    ThemeAttribute(id) => println("theme attribute \{id}")
    DynamicResource(id) => println("dynamic resource \{id}")
    DynamicThemeAttribute(id) => println("dynamic theme attribute \{id}")
  }
}
```

## 记录与顺序

`ResourceUsage` 包含 `offset: Int32`、`line_number: UInt32`、`origin: ResourceUsageOrigin` 和 `reference: ValueReference`。来源为 `Attribute(namespace_uri, local_name)` 或 `Text`。属性来源保留原始命名空间 URI 和区分大小写的本地名称；不会将所属元素的默认命名空间套用到无命名空间的属性上。

记录按文档事件数组的顺序排列。同一个开始元素内按原有属性数组顺序排列。重复 ID 保留为独立记录，同一类型的重复出现也不会合并。不会按偏移排序或去重。文本来源使用文本事件的类型化负载，即使可读文本与负载不同。

## 边界

该方法通过 `TypedValue::reference()` 分类，区分 Android 类型码 1、2、7、8。数字 ID 按原样保留，包括零。不会解析看起来像引用的原始字符串，不会将整数或字符串值转换为引用，也不会将属性名称的 `resource_id` 当作属性值引用。未被使用的字符串池条目和资源映射条目不计入清单。

这是只读事件查询，不解析 ARSC、不推断资源名称、不提取 APK，也不验证手工构造的文档。不可信输入应先经过解码；有效解码文档中的位置指向原始事件块及源码行。返回独立的新数组，不修改文档。

## 验证

```sh
moon test src --target wasm-gc --filter '*resource*usage*' --deny-warn
moon test src --target js --filter '*resource*usage*' --deny-warn
```

测试覆盖属性与文本中的全部四种引用类型、事件及属性顺序、重复 ID、精确命名空间、位置、零 ID、空清单，以及不会转换外观类似引用的字符串或数字值。
