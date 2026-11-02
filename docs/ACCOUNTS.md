# Repository account isolation

[中文](ACCOUNTS_zh.md) | [Project](../README.md)

This checkout belongs to **LING71671**. Its GitHub remote is
`https://github.com/LING71671/moonbit-axml.git`; its Mooncakes module name is
`LING71671/axml`. Repository creation and package publication are separate actions.

## Windows command entry points

```powershell
pwsh -NoProfile -File scripts/setup-accounts.ps1
pwsh -NoProfile -File scripts/moon.ps1 whoami
pwsh -NoProfile -File scripts/github.ps1 api user --jq .login
```

Both identity commands must report `LING71671`. Use `scripts/moon.ps1` for
account-sensitive Mooncakes commands and `scripts/github.ps1` for GitHub commands.
Ordinary builds and tests do not require registry authentication.

The MoonBit entry point sets `MOON_HOME` to
`$env:USERPROFILE\.moon\profiles\LING71671` only for its child process and pins
`MOON_TOOLCHAIN_ROOT` to the shared `$env:USERPROFILE\.moon` toolchain. It reuses
the existing external `credentials.json`, checks its username, and restores its
environment afterward. Leading global options and account-changing commands are
disabled. It never calls a global account switcher. `moon whoami`
checks the local saved identity, not server-side token validity.

The GitHub entry point retrieves the named `LING71671` keyring entry, sets
`GH_TOKEN` only in its process, verifies the authenticated GitHub username through
the API, then runs the command. Ambient `GH_TOKEN`/`GITHUB_TOKEN` values are
temporarily removed for named-token lookup and restored afterward. `GH_HOST` and
`GH_REPO` are pinned to github.com and this repository for the operation, then
restored. Only explicit repository/API commands are accepted; leading global
options, aliases, login and global configuration commands are disabled.

## Git scope

`setup-accounts.ps1` writes only this checkout's `.git/config`: author identity,
path-scoped HTTPS credentials, and a credential helper limited to
`LING71671/moonbit-axml`. Git obtains the named account token from the existing
keyring through the helper; no token is stored in the repository or command line.
Run setup again after moving the checkout because the local helper path is
absolute. Other repositories and global Git configuration are unaffected.

Do not commit credentials, embed tokens in remotes, or copy a profile into the
checkout. Do not run `moon-switch` or `gh auth switch` as part of this project's
workflow. Publishing still requires a separately authorized release and a valid
Mooncakes token for the configured owner.
