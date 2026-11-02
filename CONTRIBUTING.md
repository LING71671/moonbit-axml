# Contributing

[中文](CONTRIBUTING_zh.md) | [Project](README.md)

## Set up a checkout

Clone this repository and install the MoonBit version pinned in `README.md`.
Node.js 22+ runs the JavaScript CLI; Python 3.12+ runs the independent fixture
verifier. Android SDK tools and androguard are needed only when regenerating
fixtures. Building or testing requires no Mooncakes account or registry token.

## Make one reviewable change

Use a branch describing the change. Keep binary parsing separate from host I/O,
preserve raw resource IDs, and give malformed input a structured byte-offset
diagnostic. Add public-behavior tests in `*_test.mbt` and internal regressions in
`*_wbtest.mbt`. Update English documentation and its `_zh.md` counterpart.

Run these checks from the root:

```sh
moon fmt
moon info
moon check --target all --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
python scripts/verify_cli.py
```

Commit generated `.mbti` updates with API changes. Regenerate owned fixture tests
through `scripts/generate_fixtures.py`; preserve source/reference hashes and
provenance. Fixture generation instructions are in [fixtures/README.md](fixtures/README.md).

## Submit a pull request

Use a Conventional Commit title, explain the observed problem and resulting
behavior, and include the commands and platforms actually tested. Link relevant
issues or acceptance items. Describe observable limits and unresolved resource
references. The Linux and Windows CI jobs must pass before a change is accepted.

Contributions are distributed under this repository's [Apache-2.0 license](LICENSE).
Include origin and redistribution permission for any externally sourced fixture.
Use small authored or synthetic samples instead of arbitrary APKs.

## Report a bug

Include `moon version --all`, the backend and operating system, a minimal command,
expected versus actual behavior, and the complete offset diagnostic. Share a
sanitized minimal fixture or reproduction script; remove credentials and private
application metadata before attaching material to a public issue.
