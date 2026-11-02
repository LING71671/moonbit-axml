///|
/// Parsed offline CLI operation, independent of host file I/O.
pub(all) enum Command {
  Decode(String)
  Inspect(String)
  Validate(String)
  Help
  Version
} derive(Eq, @debug.Debug)

///|
/// Invalid command-line usage.
pub suberror UsageError {
  Usage(String)
} derive(@debug.Debug)

///|
/// Release identity shared by both CLI host adapters.
pub let version : String = "axml 0.1.0"

///|
/// The command accepts already-extracted binary XML, not APK archives.
pub let usage : String =
  #|Usage: axml decode FILE
  #|       axml inspect [--json] FILE
  #|       axml validate FILE
  #|       axml --help
  #|       axml --version
  #|
  #|Read an extracted Android binary XML file (maximum 16 MiB).
  #|inspect writes JSON with raw and typed manifest attributes.
  #|Use -- before a literal filename that begins with --.
  #|Exit codes: 0 success, 1 data/I/O error, 2 invalid arguments.

///|
/// Parse user arguments without an executable or script prefix.
pub fn parse_args(args : Array[String]) -> Command raise UsageError {
  match args[:] {
    ["--help"] | ["-h"] => Help
    ["--version"] | ["-V"] => Version
    ["decode", "--help"]
    | ["decode", "-h"]
    | ["inspect", "--help"]
    | ["inspect", "-h"]
    | ["validate", "--help"]
    | ["validate", "-h"] => Help
    ["decode", "--", path] if !path.is_empty() => Decode(path)
    ["inspect", "--", path] | ["inspect", "--json", "--", path] if !path.is_empty() =>
      Inspect(path)
    ["validate", "--", path] if !path.is_empty() => Validate(path)
    ["decode", path] if !path.is_empty() && !path.has_prefix("--") =>
      Decode(path)
    ["inspect", path] if !path.is_empty() && !path.has_prefix("--") =>
      Inspect(path)
    ["inspect", "--json", path] if !path.is_empty() && !path.has_prefix("--") =>
      Inspect(path)
    ["validate", path] if !path.is_empty() && !path.has_prefix("--") =>
      Validate(path)
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
    Help | Version => None
  }
}

///|
/// Execute against bytes supplied by a bounded host adapter.
pub fn execute(
  command : Command,
  data : Bytes,
) -> String raise @axml.DecodeError {
  match command {
    Decode(_) => @axml.to_xml(@axml.decode(data))
    Inspect(_) =>
      @axml.inspect_manifest(@axml.decode(data)).to_json().stringify(indent=2)
    Validate(_) => {
      let _ = @axml.to_xml(@axml.decode(data))
      "valid"
    }
    Help => usage
    Version => version
  }
}
