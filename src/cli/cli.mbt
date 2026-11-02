///|
/// Parsed offline CLI operation, independent of host file I/O.
pub(all) enum Command {
  Decode(String)
  DecodePretty(String)
  Inspect(String)
  Stats(String)
  Refs(String)
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
  #|Usage: axml decode [--pretty] FILE
  #|       axml inspect [--json] FILE
  #|       axml stats [--json] FILE
  #|       axml refs [--json] FILE
  #|       axml validate FILE
  #|       axml --help
  #|       axml --version
  #|
  #|Read an extracted Android binary XML file (maximum 16 MiB).
  #|decode --pretty indents element-only content and preserves mixed text.
  #|inspect writes JSON with raw and typed manifest attributes.
  #|stats writes JSON counts from decoded pools and events.
  #|refs writes JSON typed resource usages with source locations.
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
    | ["stats", "--help"]
    | ["stats", "-h"]
    | ["refs", "--help"]
    | ["refs", "-h"]
    | ["validate", "--help"]
    | ["validate", "-h"] => Help
    ["decode", "--", path] if !path.is_empty() => Decode(path)
    ["decode", "--pretty", "--", path] if !path.is_empty() => DecodePretty(path)
    ["decode", "--pretty", path] if !path.is_empty() && !path.has_prefix("--") =>
      DecodePretty(path)
    ["inspect", "--", path] | ["inspect", "--json", "--", path] if !path.is_empty() =>
      Inspect(path)
    ["stats", "--", path] | ["stats", "--json", "--", path] if !path.is_empty() =>
      Stats(path)
    ["refs", "--", path] | ["refs", "--json", "--", path] if !path.is_empty() =>
      Refs(path)
    ["validate", "--", path] if !path.is_empty() => Validate(path)
    ["decode", path] if !path.is_empty() && !path.has_prefix("--") =>
      Decode(path)
    ["inspect", path] if !path.is_empty() && !path.has_prefix("--") =>
      Inspect(path)
    ["inspect", "--json", path] if !path.is_empty() && !path.has_prefix("--") =>
      Inspect(path)
    ["stats", path] if !path.is_empty() && !path.has_prefix("--") => Stats(path)
    ["stats", "--json", path] if !path.is_empty() && !path.has_prefix("--") =>
      Stats(path)
    ["refs", path] if !path.is_empty() && !path.has_prefix("--") => Refs(path)
    ["refs", "--json", path] if !path.is_empty() && !path.has_prefix("--") =>
      Refs(path)
    ["validate", path] if !path.is_empty() && !path.has_prefix("--") =>
      Validate(path)
    _ =>
      raise Usage(
        "expected decode [--pretty], inspect [--json], stats [--json], refs [--json], or validate with one file",
      )
  }
}

///|
/// Return the selected input path, or None for informational commands.
pub fn Command::path(self : Command) -> String? {
  match self {
    Decode(path)
    | DecodePretty(path)
    | Inspect(path)
    | Stats(path)
    | Refs(path)
    | Validate(path) => Some(path)
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
    DecodePretty(_) => @axml.to_xml_pretty(@axml.decode(data))
    Inspect(_) =>
      @axml.inspect_manifest(@axml.decode(data)).to_json().stringify(indent=2)
    Stats(_) => @axml.decode(data).stats().to_json().stringify(indent=2)
    Refs(_) =>
      Json(@axml.decode(data).resource_references()).stringify(indent=2)
    Validate(_) => {
      let _ = @axml.to_xml(@axml.decode(data))
      "valid"
    }
    Help => usage
    Version => version
  }
}
