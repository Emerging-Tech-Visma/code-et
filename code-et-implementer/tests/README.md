# Hook script tests

Run all: `./run-tests.sh`
Run one: `bats resolve-prd.bats`

Requires: `bats-core` (`brew install bats-core` or `npm i -g bats`).

Fixtures live under `fixtures/`. Each test creates a temp repo via
`mktemp -d` and exports `CLAUDE_PLUGIN_ROOT` so scripts resolve correctly.
