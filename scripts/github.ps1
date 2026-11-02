# Select a named keyring entry in this child process; never change active gh login.
param()
$ErrorActionPreference = 'Stop'
$githubArguments = $args
if ($githubArguments.Count -eq 0 -or $githubArguments[0] -notin @('api', 'repo', 'issue', 'pr', 'run', 'workflow', 'release', 'search', 'browse', 'status')) {
  throw 'Start with a repository/API command; global options, aliases and account/configuration commands are disabled.'
}
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$previousToken = $env:GH_TOKEN
$previousGithubToken = $env:GITHUB_TOKEN
$previousRepository = $env:GH_REPO
$previousHost = $env:GH_HOST
$previousLocation = Get-Location
try {
  $env:GH_TOKEN = $null
  $env:GITHUB_TOKEN = $null
  $env:GH_REPO = 'github.com/LING71671/moonbit-axml'
  $env:GH_HOST = 'github.com'
  $accountToken = & gh auth token --hostname github.com --user LING71671
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accountToken)) {
    throw 'No saved GitHub authentication for LING71671.'
  }
  $env:GH_TOKEN = $accountToken.Trim()
  $accountToken = $null
  $identity = & gh api --hostname github.com user --jq .login
  if ($LASTEXITCODE -ne 0 -or $identity -cne 'LING71671') {
    throw 'GitHub authentication is not LING71671; refusing the command.'
  }
  Set-Location -LiteralPath $repositoryRoot
  & gh @githubArguments
  $commandExitCode = $LASTEXITCODE
} finally {
  $env:GH_TOKEN = $previousToken
  $env:GITHUB_TOKEN = $previousGithubToken
  $env:GH_REPO = $previousRepository
  $env:GH_HOST = $previousHost
  Set-Location -LiteralPath $previousLocation.Path
}
exit $commandExitCode
