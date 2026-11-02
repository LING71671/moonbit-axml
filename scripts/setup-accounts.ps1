# Configure only this checkout. Credentials remain in the existing external stores.
param()
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$helper = (Join-Path $PSScriptRoot 'git-credential.ps1').Replace('\', '/')
$previousLocation = Get-Location
try {
  Set-Location -LiteralPath $repositoryRoot
  $actualRoot = & git rev-parse --show-toplevel
  if ($LASTEXITCODE -ne 0 -or
      [IO.Path]::GetFullPath($actualRoot) -ine [IO.Path]::GetFullPath($repositoryRoot)) {
    throw 'Run account setup from this repository checkout.'
  }
  & git config --local user.name LING71671
  & git config --local user.email '231181387+LING71671@users.noreply.github.com'
  & git config --local credential.https://github.com.useHttpPath true
  & git config --local --replace-all credential.https://github.com.helper ''
  & git config --local --add credential.https://github.com.helper ('!pwsh -NoProfile -File "' + $helper + '"')
  if ($LASTEXITCODE -ne 0) { throw 'Could not set repository-local credential helper.' }
  Write-Output 'Configured repository-local Git identity and LING71671 credential helper.'
} finally {
  Set-Location -LiteralPath $previousLocation.Path
}
