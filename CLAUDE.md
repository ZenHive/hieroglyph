@~/.claude/includes/across-instances.md
@~/.claude/includes/critical-rules.md
@~/.claude/includes/task-prioritization.md
@~/.claude/includes/task-writing.md
@~/.claude/includes/workflow-philosophy.md
@~/.claude/includes/web-command.md
@~/.claude/includes/elixir-setup.md
@~/.claude/includes/ex-unit-json.md
@~/.claude/includes/dialyzer-json.md
@~/.claude/includes/code-style.md
@~/.claude/includes/development-commands.md
@~/.claude/includes/development-philosophy.md
@~/.claude/includes/upstream-pr-workflow.md


# ABI

Pure Elixir library for encoding/decoding the Solidity ABI. No runtime processes — `ABI.encode/2`, `ABI.decode/2`, and the `TypeEncoder`/`TypeDecoder`/`FunctionSelector`/`Event` modules under `lib/abi/` are all stateless functions.

## Layout

- `lib/abi.ex` — public surface (`encode`, `decode`, `parse_specification`)
- `lib/abi/type_encoder.ex` / `type_decoder.ex` — head/tail packing for static and dynamic Solidity types
- `lib/abi/function_selector.ex` — parses `"foo(uint256,address)"` strings; uses generated yecc/leex parsers in `src/`
- `lib/abi/event.ex` — log decoding (indexed vs non-indexed args, topic hashing)
- `src/*.xrl` / `src/*.yrl` — leex/yecc grammar; compiled by the `:yecc, :leex` Mix compilers (see `mix.exs:18`). Edit the `.xrl`/`.yrl`, never the generated `.erl`.

## Gotchas

- `parse_specification/2` accepts `:string_keys` to keep ABI JSON keys as strings rather than atoms — preserve this when touching selector parsing.
- `TypeEncoder` recently grew integer- and string-key support (commits `a43e9d5`, `46accc8`); when adding new type paths, mirror both keyed-map and tuple input shapes.
- This library is consumed downstream by transaction builders. Breaking the public encode/decode shape is a major-version event — bump `version` in `mix.exs` accordingly.

## Open Work

See [ROADMAP.md](ROADMAP.md) for the current punch list (bugs, test debt, feature gaps).

## Package Identity

Published on hex.pm as [`hieroglyph`](https://hex.pm/packages/hieroglyph) (fork-of `exthereum/abi`); repo lives at `github.com/ZenHive/hieroglyph`. The module namespace is unchanged — consumers still call `ABI.encode/2`, `ABI.decode/2`, etc. Only the hex dep name differs (`{:hieroglyph, "~> 1.0"}`). Name chosen to mirror the `signet → cartouche` Egyptian-naming pattern (a cartouche literally contains hieroglyphs); the `ABI` module name was kept deliberately because Solidity's own term is the correct one — renaming it would hurt callsite discoverability. See CHANGELOG entry for 1.0.0 (2026-04-24) for the version-reset rationale.

## Upstream Issue Monitoring

**No upstream gating.** This fork lives in a dependency chain — our own libraries (signet, internal transaction builders) depend on it and can't wait for `exthereum/abi` maintainers to respond. Policy: file issues and PRs upstream (we *want* to contribute back to the originals), then ship the fix here immediately. Upstream acceptance is a bonus, not a prerequisite. If maintainers land a different fix later, we reconcile on their merge — not before.

Open issues/PRs filed on `exthereum/abi` that affect this fork's direction — check status at session start for awareness (not to block on):

- [exthereum/abi#53](https://github.com/exthereum/abi/issues/53) — indexed reference-type event params decoded wrong (bug). Filed 2026-04-24. Fork fix shipped on `zenhive`: `{:indexed_hash, <<32 bytes>>}` for all reference types (all arrays — fixed-size or dynamic — plus tuples, `string`, `bytes`) via a local `reference_type?/1`-gated branch in `ABI.Event`. Broader than the ABI head/tail "dynamic" rule by design — matches the spec's "all complex types" event-indexing rule. Awaiting upstream response.
- [exthereum/abi#54](https://github.com/exthereum/abi/issues/54) — `fixed`/`ufixed`/`function` parse-but-don't-encode + `@type type` gaps. Filed 2026-04-24. Fork fix shipped on `zenhive` (parse-time rejection in `ABI.Parser` + `{:bytes, N}` added to `@type type`); awaiting upstream response. A related `fixed<M>x<N>` lexer sub-bug (single `x` shadowed by LETTERS rule) was discovered during test-writing and is tracked as a separate ROADMAP task — not yet filed upstream.
- PR #52 (Elixir 1.19 compat + typespec widening) — currently open.

Check with `gh issue view 53 --repo exthereum/abi` / `gh issue view 54 --repo exthereum/abi` / `gh pr view 52 --repo exthereum/abi`.

Second-round candidates (held, not filed): `abi.encodePacked` scope check, `ABI.decode_error/2` helper, `decode_event/4` error contract. File when convenient; don't wait on earlier issue responses.
