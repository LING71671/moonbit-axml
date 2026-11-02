# Git invokes this helper through stdin/stdout. Never run it to inspect a token.
param([string]$Operation)
$ErrorActionPreference = 'Stop'
if ($Operation -ne 'get') { exit 0 }
$request = @{}
while ($null -ne ($line = [Console]::ReadLine()) -and $line -ne '') {
  $separator = $line.IndexOf('=')
  if ($separator -gt 0) {
    $request[$line.Substring(0, $separator)] = $line.Substring($separator + 1)
  }
}
if ($request['protocol'] -ne 'https' -or $request['host'] -ne 'github.com' -or
    $request['path'] -notin @('LING71671/moonbit-axml', 'LING71671/moonbit-axml.git')) {
  exit 0
}
$env:GH_TOKEN = $null
$env:GITHUB_TOKEN = $null
$accountToken = & gh auth token --hostname github.com --user LING71671 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accountToken)) { exit 1 }
[Console]::WriteLine('username=LING71671')
[Console]::WriteLine('password=' + $accountToken.Trim())
[Console]::WriteLine()
$accountToken = $null
