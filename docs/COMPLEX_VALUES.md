# Dimension and fraction values

[中文](COMPLEX_VALUES_zh.md) | [Typed views](VALUES.md) | [Project](../README.md)

`TypedValue::as_dimension()` returns an optional `Dimension { magnitude, unit }`
for TYPE_DIMENSION. Units are `Px`, `Dip`, `Sp`, `Pt`, `Inch`, and `Mm`.
`TypedValue::as_fraction()` returns an optional `Fraction { ratio, unit }` for
TYPE_FRACTION; `Base` and `Parent` remain distinct. A 50% fraction has ratio
`0.5`, rather than the display percentage `50`.

```moonbit
match attribute.value.as_dimension() {
  Some(dimension) => println(dimension.magnitude)
  None => ()
}
```

Both views decode the signed fixed-point mantissa and four radices specified by
[AOSP TypedValue](https://github.com/aosp-mirror/platform_frameworks_base/blob/d67e90e8a8301a87726420a1071fca8e52172bd4/core/java/android/util/TypedValue.java).
They retain the encoded unit and perform no resource lookup, density conversion,
font scaling, percentage-base selection, or rounding to integer pixels. The
original type and payload remain available on `TypedValue`.

A wrong type or unknown unit returns `None`; no string coercion is performed.
XML rendering continues to reject unknown dimension/fraction units with a
diagnostic. Reserved bits outside the mantissa/radix/unit masks are ignored,
matching the platform's bit-field interpretation.

Run `moon test src/complex_values_test.mbt --target wasm-gc --deny-warn` and
repeat with `js` and `native`. Tests cover every unit and radix, negative and
endpoint mantissas, invalid units, reserved bits, and percentage rendering.
