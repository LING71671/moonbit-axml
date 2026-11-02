///|
/// One already-extracted input. Names are opaque labels, not host file paths.
pub(all) struct NamedInput {
  name : String
  data : Bytes
} derive(Eq, @debug.Debug)

///|
/// The operation that rejected an input; byte offsets refer to that input.
pub(all) enum FailureStage {
  Decode
  InspectManifest
} derive(Eq, @debug.Debug, ToJson)

///|
/// A stable structured diagnostic rather than an exception's display string.
pub(all) struct Diagnostic {
  stage : FailureStage
  offset : Int32
  message : String
} derive(Eq, @debug.Debug, ToJson)

///|
/// Each input independently succeeds or fails without aborting the batch.
pub(all) enum Outcome[T] {
  Success(T)
  Failure(Diagnostic)
} derive(Eq, @debug.Debug, ToJson)

///|
/// Input-order record, including its original label and supplied byte length.
pub(all) struct Record[T] {
  name : String
  byte_length : Int32
  outcome : Outcome[T]
} derive(Eq, @debug.Debug, ToJson)

///|
/// Decode each input with independent per-input limits. Duplicate or empty
/// names remain unchanged; the record position identifies each occurrence.
/// This function performs no file I/O and does not validate rendered XML.
pub fn decode_batch(
  inputs : Array[NamedInput],
  limits~ : @axml.Limits = @axml.Limits::default(),
) -> Array[Record[@axml.Document]] {
  inputs.map(fn(input) {
    let outcome = Success(@axml.decode(input.data, limits~)) catch {
      @axml.DecodeError::Invalid(offset, message) =>
        Failure({ stage: Decode, offset, message, })
    }
    { name: input.name, byte_length: input.data.length(), outcome, }
  })
}

///|
/// Decode and inspect each manifest independently. A structurally valid XML
/// file without manifest metadata fails at InspectManifest, not Decode.
/// Inspection validates XML names and namespace use through inspect_manifest.
pub fn inspect_batch(
  inputs : Array[NamedInput],
  limits~ : @axml.Limits = @axml.Limits::default(),
) -> Array[Record[@axml.Manifest]] {
  inputs.map(fn(input) {
    let outcome = try {
      let document = @axml.decode(input.data, limits~)
      Success(@axml.inspect_manifest(document)) catch {
        @axml.DecodeError::Invalid(offset, message) =>
          Failure({ stage: InspectManifest, offset, message, })
      }
    } catch {
      @axml.DecodeError::Invalid(offset, message) =>
        Failure({ stage: Decode, offset, message, })
    }
    { name: input.name, byte_length: input.data.length(), outcome, }
  })
}
