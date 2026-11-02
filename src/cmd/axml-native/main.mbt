///|
/// Exit after flushing asynchronous stdout or stderr writes.
extern "C" fn exit(code : Int32) -> Unit = "exit"

///|
/// Native host I/O uses MoonBit's standard asynchronous filesystem API.
async fn main {
  let args = @env.args()
  let args = if args.length() > 0 { args[1:].to_owned() } else { [] }
  let command = @cli.parse_args(args) catch {
    @cli.Usage(message) => {
      @stdio.stderr.text.write("axml: \{message}\n\{@cli.usage}\n")
      exit(2)
      return
    }
  }
  guard command.path() is Some(path) else {
    @stdio.stdout.text.write("\{@cli.usage}\n")
    return
  }
  try {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    guard file.kind() == Regular else {
      @stdio.stderr.text.write("axml: \{path}: input must be a regular file\n")
      exit(1)
      return
    }
    let size = file.size()
    guard size >= 0L &&
      size <= @codec.Limits::default().max_input_bytes.to_int64() else {
      @stdio.stderr.text.write("axml: \{path}: input exceeds 16 MiB limit\n")
      exit(1)
      return
    }
    let data = file.read_exactly(size.to_int())
    let extra : FixedArray[Byte] = FixedArray::make(1, b'\x00')
    guard file.read_into(extra) == 0 else {
      @stdio.stderr.text.write("axml: \{path}: input changed during reading\n")
      exit(1)
      return
    }
    @stdio.stdout.text.write("\{@cli.execute(command, data)}\n")
  } catch {
    @codec.Invalid(offset, message) => {
      @stdio.stderr.text.write("axml: \{path}: byte \{offset}: \{message}\n")
      exit(1)
    }
    error => {
      @stdio.stderr.text.write("axml: \{path}: \{error.to_string()}\n")
      exit(1)
    }
  }
}
