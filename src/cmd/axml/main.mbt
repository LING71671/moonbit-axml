///|
/// Minimal Node host adapter; binary decoding remains entirely in MoonBit.
extern "js" fn read_file(path : String, limit : Int32) -> Bytes? =
  #| function(path, limit) {
  #|   let fd;
  #|   try {
  #|     const fs = require('node:fs');
  #|     fd = fs.openSync(path, 'r');
  #|     const stat = fs.fstatSync(fd);
  #|     if (!stat.isFile()) throw new Error('input must be a regular file');
  #|     if (stat.size > limit) throw new Error('input exceeds 16 MiB limit');
  #|     const buffer = Buffer.alloc(stat.size + 1);
  #|     let count = 0;
  #|     while (count < buffer.length) {
  #|       const n = fs.readSync(fd, buffer, count, buffer.length - count, null);
  #|       if (n === 0) break;
  #|       count += n;
  #|     }
  #|     if (count !== stat.size) throw new Error('input changed during reading');
  #|     return new Uint8Array(buffer.buffer, buffer.byteOffset, count);
  #|   } catch (error) {
  #|     globalThis.__axmlReadError = String(error.message || error);
  #|     return null;
  #|   } finally {
  #|     if (fd !== undefined) require('node:fs').closeSync(fd);
  #|   }
  #| }

///|
extern "js" fn read_error() -> String =
  #| () => globalThis.__axmlReadError || 'cannot read input'

///|
extern "js" fn stderr(text : String) -> Unit =
  #| (text) => { process.stderr.write(text + '\n'); }

///|
extern "js" fn exit_code(code : Int32) -> Unit =
  #| (code) => { process.exitCode = code; }

///|
fn main {
  let args = @env.args()
  let args = if args.length() >= 2 { args[2:].to_owned() } else { [] }
  let command = @cli.parse_args(args) catch {
    @cli.Usage(message) => {
      stderr("axml: \{message}\n\{@cli.usage}")
      exit_code(2)
      return
    }
  }
  guard command.path() is Some(path) else {
    println(if command is @cli.Version { @cli.version } else { @cli.usage })
    return
  }
  guard read_file(path, @codec.Limits::default().max_input_bytes) is Some(data) else {
    stderr("axml: \{path}: \{read_error()}")
    exit_code(1)
    return
  }
  println(@cli.execute(command, data)) catch {
    @codec.Invalid(offset, message) => {
      stderr("axml: \{path}: byte \{offset}: \{message}")
      exit_code(1)
    }
  }
}
