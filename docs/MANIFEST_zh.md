# Manifest 辅助接口

[English](MANIFEST.md)

`inspect_manifest(document)` 保留声明中的属性和类型值。以下辅助接口提供可选查询，
不会修改检查所得的原始数据。

## 筛选组件

```moonbit
let manifest = @axml.inspect_manifest(document)
let activities = manifest.components_of_kind("activity")
```

筛选严格匹配元素名称，并保留声明顺序。`activity-alias` 与 `activity` 不同，未知
类型返回空数组。组件列表只收集 `application` 的直接子元素。

## 显式展开组件名称

```moonbit
let name = @axml.resolve_component_name("example.app", ".ui.MainActivity")
// name == "example.app.ui.MainActivity"
for component in activities {
  let qualified = component.qualified_name(manifest.package_name)
  // qualified: String?
}
```

调用方显式提供包名。`.MainActivity` 展开为 `example.app.MainActivity`；不含点号的
`MainActivity` 同样添加包名前缀。`other.app.MainActivity` 保持原样。规则来自
[AOSP PackageParser](https://android.googlesource.com/platform/frameworks/base/+/a86290891a661ecdc8115fd441b44dcebedb9e3d/core/java/android/content/pm/PackageParser.java)
中的 Manifest 名称展开逻辑。接口只做语法展开，不验证 Java 标识符、不加载类，也不
解析资源。检查尚未合并的源码或经过构建期命名空间改写的清单时，调用方需要提供正确
的包名上下文。

`qualified_name` 只读取 Android 命名空间中类型为字符串的 `android:name` 字面值。
缺失属性、未解析资源和非字符串值返回 `None`，不会将原始符号文本当作已解析结果。
空字符串名称和显式提供的空包名抛出 `DecodeError::Invalid(-1, message)`；偏移 `-1`
表示辅助接口没有原始字节位置。原始 `.name`、`.exported` 和 `.enabled` 属性不变。

## 查询申请的权限

```moonbit
let requests_camera = manifest.requests_permission("android.permission.CAMERA")
```

查询区分大小写，只匹配 `uses-permission`、`uses-permission-sdk-23` 和
`uses-permission-sdk-m` 声明中的 `android:name` 字面值。空查询返回 `false`。
资源引用、其他命名空间的属性和权限定义不参与匹配。参见 Android 官方的
[uses-permission 文档](https://developer.android.com/guide/topics/manifest/uses-permission-element)。

结果仅表示声明存在，不计算 `maxSdkVersion`、设备 SDK、目标 SDK、安装过滤或运行时
授权。`false` 表示没有找到匹配的字面值声明；仍可能存在未解析的资源引用。

## 验证

在仓库根目录运行辅助接口测试：

```sh
moon test src/manifest_helpers_test.mbt --target wasm-gc --deny-warn
```

将后端分别替换为 `--target js` 和 `--target native`，验证其他已支持后端。
