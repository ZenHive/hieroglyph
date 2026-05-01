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
@~/.claude/includes/agent-economy.md


# ABI

Pure Elixir library for encoding/decoding the Solidity ABI. No runtime processes — `ABI.encode/2`, `ABI.decode/2`, and the `TypeEncoder`/`TypeDecoder`/`FunctionSelector`/`Event` modules under `lib/abi/` are all stateless functions.

## Layout

- `lib/abi.ex` — public surface (`encode/2`, `decode/3`, `decode_call/3`, `decode_event/4`, `method_id/1`, `event_signature/1`, `parse_specification/1`). Also the `Descripex.Discoverable` module — wires `ABI.describe/0..2` and `ABI.__descripex_modules__/0` for agent-side introspection.
- `lib/abi/type_encoder.ex` / `type_decoder.ex` — head/tail packing for static and dynamic Solidity types
- `lib/abi/function_selector.ex` — parses `"foo(uint256,address)"` strings; uses generated yecc/leex parsers in `src/`
- `lib/abi/event.ex` — log decoding (indexed vs non-indexed args, topic hashing)
- `lib/abi/parser.ex` — `@moduledoc false` walker; wraps `:ethereum_abi_parser.parse/1`, normalizes the AST, and rejects unsupported types (`fixed`/`ufixed`/`function`) at parse time
- `lib/abi/math.ex` — shared 32-byte padding helpers (`pad/4`, `unpad/3`) plus `mod/2` and `kec/1` (keccak256). Encoder/decoder delegate here instead of duplicating the byte-domain padding formula.
- `src/*.xrl` / `src/*.yrl` — leex/yecc grammar; compiled by the `:yecc, :leex` Mix compilers (see `mix.exs:18`). Edit the `.xrl`/`.yrl`, never the generated `.erl`.
- `lib/mix/tasks/hieroglyph.manifest.ex` — `mix hieroglyph.manifest [path]` task that emits `api_manifest.json` from `ABI.__descripex_modules__/0`; consumed by downstream cartouche/onchain CI as a contract-stability artifact.

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
- [exthereum/abi#54](https://github.com/exthereum/abi/issues/54) — `fixed`/`ufixed`/`function` parse-but-don't-encode + `@type type` gaps. Filed 2026-04-24. Fork fix shipped on `zenhive` (parse-time rejection in `ABI.Parser` + `{:bytes, N}` added to `@type type`); awaiting upstream response. A related `fixed<M>x<N>` lexer sub-bug (single `x` shadowed by LETTERS rule) was discovered during test-writing — local fix shipped under `## [Unreleased]` (dedicated `fixed_typename`/`ufixed_typename` terminals + `'x'`-rule reorder + `identifier_part` extension); upstream filing deferred — will be batched into a future combined-bugs issue with PR offer.
- [exthereum/abi#55](https://github.com/exthereum/abi/issues/55) — `TypeEncoder.encode_int/2` overflow guard mixes bytes and bits, rejecting **every** `int8` value (including `0`) and most non-trivial `int16`/`int32`/... values. Filed 2026-05-01. Fork fix shipped here in 68ab658 (replaced the `byte_size > bytes - 1` guard with an up-front numeric range check against `Bitwise.bsl(1, N - 1)`). Surfaced by the round-trip property suite on first run; the upstream `"int overflow raises data overflow"` test passed against the broken encoder for the wrong reason. Awaiting upstream response.
- **`:string` decode silently truncated at first NUL byte** (upstream filing deferred — batch with the lexer `x` sub-bug). Pre-existing in upstream since commit `bdceb719` (2018). `ABI.TypeDecoder.nul_terminate_string/1` split the decoded binary at the first `<<0>>`, treating Solidity strings as C strings — but Solidity strings are length-prefixed UTF-8 and may contain NUL codepoints. Surfaced 2026-05-01 by the new mixed-element `tuple[]` property in `roundtrip_property_test.exs`; fork fix shipped under `## [Unreleased]` (helper removed; `:string` decode now delegates straight to `decode_bytes(rest, length, :right)`). Affects every `exthereum/abi` consumer that decodes user-supplied strings.
- PR #52 (Elixir 1.19 compat + typespec widening) — currently open.

Check with `gh issue view 53 --repo exthereum/abi` / `gh issue view 54 --repo exthereum/abi` / `gh issue view 55 --repo exthereum/abi` / `gh pr view 52 --repo exthereum/abi`.

Second-round candidates (held, not filed): `abi.encodePacked` scope check, `ABI.decode_error/2` helper, `decode_event/4` error contract, **lexer `x`-terminal-shadow sub-bug of #54** (already fixed locally — see `## [Unreleased]`; include in the batched filing as a sub-bug with the dedicated-terminal fix as the suggested PR shape), **`:string` decode NUL-truncation bug** (already fixed locally — see `## [Unreleased]`; the simplest fix is the cleanest: just delete the helper, no API change). File when convenient; don't wait on earlier issue responses.
