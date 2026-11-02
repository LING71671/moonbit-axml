///|
/// Parsed offline CLI operation, independent of host file I/O.
pub(all) enum Command {
  Decode(String)
  Inspect(String)
  Validate(String)
  Help
} derive(Eq, @debug.Debug)

///|
/// Invalid command-line usage.
pub suberror UsageError {
  Usage(String)
} derive(@debug.Debug)

///|
/// The command accepts already-extracted binary XML, not APK archives.
pub let usage : String =
  #|Usage: axml decode FILE
  #|       axml inspect [--json] FILE
  #|       axml validate FILE
  #|       axml --help
  #|
  #|Read an extracted Android binary XML file (maximum 16 MiB).
  #|inspect writes JSON with raw and typed manifest attributes.
  #|Exit codes: 0 success, 1 data/I/O error, 2 invalid arguments.

///|
/// Parse user arguments without an executable or script prefix.
pub fn parse_args(args : Array[String]) -> Command raise UsageError {
  match args[:] {
    ["--help"] | ["-h"] => Help
    ["decode", path] if !path.has_prefix("--") => Decode(path)
    ["inspect", path] if !path.has_prefix("--") => Inspect(path)
    ["inspect", "--json", path] if !path.has_prefix("--") => Inspect(path)
    ["validate", path] if !path.has_prefix("--") => Validate(path)
    _ =>
      raise Usage(
        "expected decode, inspect [--json], or validate with one file",
      )
  }
}

///|
/// Return the selected input path, or None for help.
pub fn Command::path(self : Command) -> String? {
  match self {
    Decode(path) | Inspect(path) | Validate(path) => Some(path)
    Help => None
  }
}

///|
/// Execute against bytes supplied by a bounded host adapter.
pub fn execute(
  command : Command,
  data : Bytes,
) -> String raise @axml.DecodeError {
  let document = @axml.decode(data)
  match command {
    Decode(_) => @axml.to_xml(document)
    Inspect(_) => @axml.inspect_manifest(document).to_json().stringify(indent=2)
    Validate(_) => {
      let _ = @axml.to_xml(document)
      "valid"
    }
    Help => usage
  }
}
