# Run MoonBit with this repository's Mooncakes identity, without global switching.
param()
$ErrorActionPreference = 'Stop'
$moonArguments = $args
if ($moonArguments.Count -eq 0 -or $moonArguments[0] -notin @('check', 'build', 'test', 'fmt', 'info', 'run', 'bench', 'clean', 'package', 'publish', 'whoami', 'version', 'doc', 'tree', 'add', 'remove', 'update', 'install')) {
  throw 'Start with a build/package/identity command; leading global options and account-changing commands are disabled.'
}
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$toolchainRoot = Join-Path $env:USERPROFILE '.moon'
$profileRoot = Join-Path $toolchainRoot 'profiles\LING71671'
$moonExecutable = Join-Path $toolchainRoot 'bin\moon.exe'
$credentialPath = Join-Path $profileRoot 'credentials.json'
if (-not (Test-Path -LiteralPath $credentialPath)) {
  throw 'Missing Mooncakes profile: LING71671. Configure that profile before continuing.'
}
$credential = Get-Content -Raw -LiteralPath $credentialPath | ConvertFrom-Json
if ($credential.username -cne 'LING71671') {
  throw 'Mooncakes profile identity does not match LING71671.'
}
$credential = $null
$previousHome = $env:MOON_HOME
$previousToolchain = $env:MOON_TOOLCHAIN_ROOT
$previousLocation = Get-Location
try {
  $env:MOON_HOME = $profileRoot
  $env:MOON_TOOLCHAIN_ROOT = $toolchainRoot
  Set-Location -LiteralPath $repositoryRoot
  & $moonExecutable @moonArguments
  $commandExitCode = $LASTEXITCODE
} finally {
  $env:MOON_HOME = $previousHome
  $env:MOON_TOOLCHAIN_ROOT = $previousToolchain
  Set-Location -LiteralPath $previousLocation.Path
}
exit $commandExitCode
