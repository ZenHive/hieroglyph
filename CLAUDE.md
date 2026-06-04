@~/.claude/includes/critical-rules.md
@~/.claude/includes/upstream-pr-workflow.md

<!--
  Selective-load (Opus 4.8): eager floor is `critical-rules` only; `upstream-pr-workflow`
  stays eager because this fork actively files PRs upstream (see "Upstream Issue Monitoring").
  Everything else is skill-on-demand — task-prioritization → elixir:roadmap-planning,
  task-writing → task-driver:task-writing, workflow-philosophy → dev-lifecycle:workflow-philosophy,
  worktree-workflow → elixir:git-worktrees, web-command/ex-unit-json/dialyzer-json/code-style/
  development-commands/development-philosophy/elixir-setup/agent-economy → elixir:*.
  Delegation + across-instances intentionally omitted (work/library repo, no cloud-agent usage).
  Re-add an `@`-import only if Opus quality drops on that surface.
-->


# ABI

Pure Elixir library for encoding/decoding the Solidity ABI. No runtime processes — `ABI.encode/2`, `ABI.decode/2`, and the `TypeEncoder`/`TypeDecoder`/`FunctionSelector`/`Event` modules under `lib/abi/` are all stateless functions.

## Layout

- `lib/abi.ex` — public surface (`encode/2`, `decode/3`, `decode_call/3`, `decode_event/4`, `method_id/1`, `event_signature/1`, `parse_specification/1`). Also the `Descripex.Discoverable` module — wires `ABI.describe/0..2` and `ABI.__descripex_modules__/0` for agent-side introspection.
- `lib/abi/type_encoder.ex` / `type_decoder.ex` — head/tail packing for static and dynamic Solidity types
- `lib/abi/function_selector.ex` — parses `"foo(uint256,address)"` strings; uses generated yecc/leex parsers in `src/`
- `lib/abi/event.ex` — log decoding (indexed vs non-indexed args, topic hashing)
- `lib/abi/parser.ex` — `@moduledoc false` walker; wraps `:ethereum_abi_parser.parse/1`, normalizes the AST, and rejects unsupported types (`fixed`/`ufixed`) at parse time (`:function` rejection lifted in 1.3.0 — it now encodes/decodes as a 24-byte payload)
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
- [exthereum/abi#54](https://github.com/exthereum/abi/issues/54) — `fixed`/`ufixed`/`function` parse-but-don't-encode + `@type type` gaps. Filed 2026-04-24. Initial fork fix shipped 1.0.0 (parse-time rejection of all three in `ABI.Parser` + `{:bytes, N}` added to `@type type`). **`function` rejection lifted in 1.3.0** — full encode/decode/packed support (Solidity supports `function`: 24-byte external pointer = 20-byte address ++ 4-byte selector). `fixed`/`ufixed` stay rejected because Solidity itself does not fully support fixed-point types (see CHANGELOG 1.3.0 and README "Why `fixed<M>x<N>` / `ufixed<M>x<N>` are deferred"). Awaiting upstream response on the original issue. A related `fixed<M>x<N>` lexer sub-bug (single `x` shadowed by LETTERS rule) was discovered during test-writing — local fix shipped in 1.2.0 (dedicated `fixed_typename`/`ufixed_typename` terminals + `'x'`-rule reorder + `identifier_part` extension); upstream filing deferred — will be batched into a future combined-bugs issue with PR offer.
- [exthereum/abi#55](https://github.com/exthereum/abi/issues/55) — `TypeEncoder.encode_int/2` overflow guard mixes bytes and bits, rejecting **every** `int8` value (including `0`) and most non-trivial `int16`/`int32`/... values. Filed 2026-05-01. Fork fix shipped here in 68ab658 (replaced the `byte_size > bytes - 1` guard with an up-front numeric range check against `Bitwise.bsl(1, N - 1)`). Surfaced by the round-trip property suite on first run; the upstream `"int overflow raises data overflow"` test passed against the broken encoder for the wrong reason. Awaiting upstream response.
- **`:string` decode silently truncated at first NUL byte** (upstream filing deferred — batch with the lexer `x` sub-bug). Pre-existing in upstream since commit `bdceb719` (2018). `ABI.TypeDecoder.nul_terminate_string/1` split the decoded binary at the first `<<0>>`, treating Solidity strings as C strings — but Solidity strings are length-prefixed UTF-8 and may contain NUL codepoints. Surfaced 2026-05-01 by the new mixed-element `tuple[]` property in `roundtrip_property_test.exs`; fork fix shipped in 1.2.0 (helper removed; `:string` decode now delegates straight to `decode_bytes(rest, length, :right)`). Affects every `exthereum/abi` consumer that decodes user-supplied strings.
- **`decode_structs: true` `String.to_atom/1` DoS surface** (upstream filing pending — to be filed against `exthereum/abi` post-1.4.0 ship). `ABI.TypeDecoder.tuple_value/3` and `ABI.TypeEncoder.fetch_by_name/2` previously created atoms from contract-supplied field names (gated by `sobelow_skip` annotations on a "trusted ABI metadata" assumption). The assumption breaks the moment a consumer ingests ABIs from arbitrary sources — the atom table is non-reclaimable VM resource. Fork fix shipped in 1.4.0: both call sites route through `String.to_existing_atom/1`; decoder requires snake_case field atoms to be pre-interned (raises `ArgumentError` with a migration hint when not), encoder change is a silent safety upgrade. Picked option (a) from the planted scoring; rejected `:strict`/`:strings` knob alternatives as API-surface bloat. Upstream maintainers may prefer a `decode_structs: :existing_atoms` opt-in over the same `to_existing_atom` switch — issue body should propose both.
- PR #52 (Elixir 1.19 compat + typespec widening) — currently open.

Check with `gh issue view 53 --repo exthereum/abi` / `gh issue view 54 --repo exthereum/abi` / `gh issue view 55 --repo exthereum/abi` / `gh pr view 52 --repo exthereum/abi`.

**1.2.0 Public Surface Pass — upcoming combined upstream PRs (filing deferred until #53/#54/#55 maintainer responses land):** the four bundle members split naturally into two upstream PRs:
1. **Bug/hygiene PR** — `decode_event/4` error contract narrowed (typespec said `{:error, term()}` but the runtime raised on malformed payloads — fix wraps the payload-decode path in `try/rescue` and converts to `{:error, {:malformed_data, _}}`; tightens signature-mismatch errors to atom-tagged shape) + `encode_bytes/1` flipped to `defp` (already `@doc false`, zero callers outside the module). Pair upstream because both are pure cleanup of accidentally-public / contract-lying surface.
2. **Feature PR** — `ABI.decode_error/2` (Solidity 0.8.4+ custom errors; mirrors `decode_call/3`'s contract) + `ABI.encode_packed/2` (Solidity non-standard packed encoding for Merkle airdrop leaves and `keccak256(abi.encodePacked(...))` schemes; spec-citing tests including the canonical `int16/bytes1/uint16/string` golden vector). Pair upstream because both close ecosystem-parity gaps with `eth-abi` / `ethers` / `viem` / `alloy`.

Second-round candidates (held, not filed): **lexer `x`-terminal-shadow sub-bug of #54** (already fixed locally; include in the batched filing as a sub-bug with the dedicated-terminal fix as the suggested PR shape), **`:string` decode NUL-truncation bug** (already fixed locally; simplest fix is the cleanest — just delete the helper, no API change). File when convenient; don't wait on earlier issue responses.
