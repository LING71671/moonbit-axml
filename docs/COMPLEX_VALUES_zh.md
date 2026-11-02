# 尺寸与分数值

[English](COMPLEX_VALUES.md) | [类型视图](VALUES_zh.md) | [项目](../README_zh.md)

`TypedValue::as_dimension()` 为 TYPE_DIMENSION 返回可选的
`Dimension { magnitude, unit }`；单位为 `Px`、`Dip`、`Sp`、`Pt`、`Inch`、`Mm`。
`TypedValue::as_fraction()` 为 TYPE_FRACTION 返回可选的
`Fraction { ratio, unit }`，区分 `Base` 与 `Parent`。50% 对应比值 `0.5`，
而不是显示百分数 `50`。

```moonbit
match attribute.value.as_dimension() {
  Some(dimension) => println(dimension.magnitude)
  None => ()
}
```

两个视图按 [AOSP TypedValue](https://github.com/aosp-mirror/platform_frameworks_base/blob/master/core/java/android/util/TypedValue.java)
解码有符号定点尾数及四种基数。接口保留编码单位，不执行资源查找、密度换算、字体缩放、
百分数基数选择或整数像素取整。`TypedValue` 上的原始类型和载荷保持可用。

类型不匹配或单位未知时返回 `None`，不做字符串转换。XML 输出仍会为非法尺寸或分数单位
返回诊断。尾数、基数及单位掩码以外的保留位被忽略，与平台的位域解释一致。

运行 `moon test src/complex_values_test.mbt --target wasm-gc --deny-warn`，
并以 `js`、`native` 重复。测试覆盖全部单位和基数、负值及尾数边界、非法单位、保留位
以及百分数输出。
