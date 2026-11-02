# Batch Catalog API

[中文](CATALOG_zh.md)

## Import and input

Import `LING71671/axml/catalog` as `@catalog`. The package accepts extracted
binary XML bytes and performs no host file I/O, APK extraction, or networking.
Names are opaque labels: duplicate names, empty names, and input order are
preserved. The caller supplies bytes and decides how to identify each input.

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

`manifest_bytes` and `menu_bytes` are application-supplied `Bytes`. This example
returns a manifest success and a metadata failure for the valid menu document.

## Operations and results

| Function | Successful payload | Validation |
| --- | --- | --- |
| `decode_batch(inputs, limits~)` | `@axml.Document` | Same structural checks as `@axml.decode` |
| `inspect_batch(inputs, limits~)` | `@axml.Manifest` | Decode, XML rendering checks, then manifest metadata |

Both functions return an array of `Record[T]`, one per input, without raising
`DecodeError`. Each record contains `name`, `byte_length`, and either
`Success(payload)` or `Failure(Diagnostic)`. Failure preserves the original
byte `offset` and `message`; `stage` distinguishes `Decode` from
`InspectManifest`. A failure does not discard or skip later inputs.

`Record`, `Outcome`, `Diagnostic`, and `FailureStage` derive `ToJson`. For example,
`records.to_json().stringify(indent=2)` serializes a batch without scraping
formatted exception strings. Offsets always refer to the corresponding input,
never a concatenation of files.

## Resource limits

Pass the core `@axml.Limits` through the optional `limits` argument. Defaults
match `@axml.decode`; limits apply independently to every input. Invalid limits
produce a `Decode` failure at offset zero for each supplied input. Empty input
arrays always return empty arrays.

The package retains all successful payloads in memory and does not cap the
aggregate input or output size. For large collections, call it with bounded
slices chosen by the host application. It does not resolve resource IDs or
infer Android platform defaults.

## Verification

Run `moon test src/catalog --target wasm-gc --deny-warn`, repeating with `js`
and `native`. Tests assemble small owned binary documents and cover mixed
success/failure batches, namespace offsets, non-manifest XML, missing package
metadata, duplicate labels, empty batches, and custom resource limits.
