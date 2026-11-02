# 批量目录 API

[English](CATALOG.md)

## 导入与输入

将 `LING71671/axml/catalog` 导入为 `@catalog`。本包接收已经提取的二进制 XML
字节，不执行宿主文件 I/O、APK 提取或网络请求。名称仅用作标签；重复名称、空名称
和输入顺序都会保留。调用方负责提供字节和标识每份输入。

```moonbit
let inputs : Array[@catalog.NamedInput] = [
  { name: "AndroidManifest.xml", data: manifest_bytes },
  { name: "res/menu/main.xml", data: menu_bytes },
]
let records = @catalog.inspect_batch(inputs)
for record in records {
  match record.outcome {
    @catalog.Success(manifest) => println(manifest.package_name)
    @catalog.Failure(diagnostic) =>
      println("\{record.name}:\{diagnostic.offset}: \{diagnostic.message}")
  }
}
```

`manifest_bytes` 与 `menu_bytes` 是应用提供的 `Bytes`。这个示例会为清单返回成功，
为有效的菜单 XML 返回元数据检查失败。

## 操作与结果

| 函数 | 成功载荷 | 校验范围 |
| --- | --- | --- |
| `decode_batch(inputs, limits~)` | `@axml.Document` | 与 `@axml.decode` 相同的结构检查 |
| `inspect_batch(inputs, limits~)` | `@axml.Manifest` | 解码、XML 渲染检查、清单元数据检查 |

两个函数都返回 `Record[T]` 数组，每份输入对应一条记录，不向调用方抛出
`DecodeError`。每条记录包含 `name`、`byte_length`，以及 `Success(payload)` 或
`Failure(Diagnostic)`。失败保留原始字节 `offset` 与 `message`；`stage` 区分
`Decode` 和 `InspectManifest`。某份输入失败不会丢弃或跳过后续输入。

`Record`、`Outcome`、`Diagnostic` 和 `FailureStage` 均派生 `ToJson`。
`records.to_json().stringify(indent=2)` 可以直接序列化整个批次，无需解析异常显示文本。
偏移始终对应当前输入，不是多份文件拼接后的偏移。

## 资源限制

通过可选的 `limits` 参数传入核心包的 `@axml.Limits`。默认值与 `@axml.decode`
一致；每份输入独立应用限制。限制配置无效时，每份输入都会得到偏移为零的
`Decode` 失败。空输入数组始终返回空数组。

本包会将所有成功载荷保留在内存中，不限制整个批次的输入或输出总量。处理大型集合时，
由宿主应用将输入划分为有界批次。资源 ID 解析和 Android 平台默认值推断仍由外部负责。

## 验证

运行 `moon test src/catalog --target wasm-gc --deny-warn`，再分别使用 `js` 和
`native` 重复运行。测试构造自有的小型二进制文档，覆盖成功与失败混合批次、命名空间
错误偏移、非清单 XML、缺少包名、重复标签、空批次和自定义资源限制。
