# ABI Roadmap

**Vision:** Production-grade Solidity ABI encoder/decoder for Elixir, matching feature parity with `eth-abi` (Python), `ethers`/`viem` (JS), and `alloy` (Rust).

**Completed work:** see [CHANGELOG.md](CHANGELOG.md). Recent releases added struct/map input, integer encoding, string-key map support, Elixir 1.19 compat (through 1.3.0 + PR #52), and — in the Unreleased entries — map-input encoder tests, error-path tests, typespec/doc gap closure, and a README refresh.

**Scope of this roadmap:** findings from the 2026-04-24 review of v1.3.0 (post-#52). Some items will land as upstream PRs to `exthereum/abi`, some are fork-only polish.

**Task completion rule:** every task below names the docs it must update on completion (**Docs:** line). A task is not done until those doc updates land. At minimum, every task produces a CHANGELOG entry under `## [Unreleased]`; user-facing surface changes also update README; architectural or convention changes also update CLAUDE.md.

---

## 🎯 Current Focus

Upstream bugs #53 and #54 shipped locally on `zenhive` (see [CHANGELOG.md](CHANGELOG.md#unreleased)); still awaiting maintainer response on the upstream issues. Other fork-only polish (padding-helper extraction, `is_dynamic?` → `dynamic?` rename, `mix credo --strict` cleanup) landed alongside. Remaining fork-only items: the round-trip property test suite and the newly-discovered lexer rule-ordering bug (see below).

---

## 🐛 Bugs

| Task | Status | Location | Notes |
|---|---|---|---|
| **Indexed reference-type event parameters decoded wrong** | ✅ `zenhive` [upstream #53](https://github.com/exthereum/abi/issues/53) | `lib/abi/event.ex:146-172` | Fix shipped: indexed reference-type params (all arrays — fixed-size or dynamic — plus tuples, `string`, `bytes`) now return `{:indexed_hash, <<32 bytes>>}` via a local `reference_type?/1` predicate (matches the Solidity spec's "all complex types" event-indexing rule, which is broader than `FunctionSelector.dynamic?/1`'s head/tail-layout rule — `uint256[2]` and static-only tuples are static for regular encoding but still hashed in topics). Static value-type indexed params unchanged. See [CHANGELOG.md](CHANGELOG.md#unreleased). |
| **`fixed`/`ufixed`/`function` types parse but can't encode + typespec gaps** | ✅ `zenhive` [upstream #54](https://github.com/exthereum/abi/issues/54) | `lib/abi/parser.ex`, `lib/abi/function_selector.ex:9-19` | Fix shipped: parse-time rejection of `:function`, `{:fixed, M, N}`, `{:ufixed, M, N}` (including nested in arrays/tuples) in `ABI.Parser.parse!/2` with an `ArgumentError` linking to the upstream issue; `{:bytes, pos_integer()}` added to `@type type`. See [CHANGELOG.md](CHANGELOG.md#unreleased). |
| **Lexer `x` terminal shadowed by LETTERS rule** | ⬜ (no issue yet) [D:3/B:4/U:4 → Eff:1.33] 📋 | `src/ethereum_abi_lexer.xrl:13,19` | Discovered while writing tests for #54. `fixed128x18` / `ufixed128x18` tokenize the single `x` as `letters` (LETTERS rule appears before the `x` terminal; leex picks the earlier rule on equal-length matches), so grammar rule `type -> typename digits 'x' digits` never fires. Parser reduces `typename digits` → `juxt_type(fixed, 128)` → `FunctionClauseError` instead of a clean parse-time error. Scope: fix options are (a) reorder lexer rules so `x` outranks LETTERS, making sure identifiers like `foo_x_bar` still tokenize correctly (needs testing — LETTERS is currently the only rule producing `letters` tokens for identifier parts); (b) extend grammar's `identifier_part` to also accept the `x` terminal so identifiers still work; (c) wrap `:ethereum_abi_parser.parse/1` in a `try/rescue` inside `ABI.Parser.parse!/2` and convert the FunctionClauseError to an ArgumentError with an upstream-#54 link. File an upstream issue before picking an approach. **Docs:** CHANGELOG entry; if the fix ends up surfacing the same rejection as #54, may update the README lexer caveat. |
| **`encode_bytes/1` accidentally public** | ⬜ (no issue) | `lib/abi/type_encoder.ex:353` | No `@doc`, no `@spec`, no internal callers outside module. Changing `def` → `defp` is technically a breaking API change for downstream consumers we can't see — Codex review flagged this. Skip the issue; fold into a future PR or leave alone. **Docs:** CHANGELOG entry (breaking, if changed). |
| **`decode_event/4` mixed raise + tagged-tuple contract** | ⬜ (hold) | `lib/abi/event.ex:93-148` | Returns `{:error, _}` for topic/length mismatches but calls `decode_raw` internally, which raises on malformed data. Scope of change = arguable 2.0 breaking API — discuss before PR, not yet filed upstream. **Docs:** CHANGELOG entry (breaking); possibly README note on the unified return contract. |
| **`dynamic?/1` crashes on zero-length fixed array** | ⬜ (no issue yet) [D:1/B:2/U:2 → Eff:2.0] 🚀 | `lib/abi/function_selector.ex:474` | `{:array, _, 0}` matches no clause (guard is `len > 0`) → FunctionClauseError. Pre-existing; grammar line 80 of `ethereum_abi_parser.yrl` allows `N >= 0` (so `T[0]` parses). The event-indexing path is safe after the #53 fix (reference types short-circuit before `dynamic?/1` is called), but encoder/decoder paths still crash on a parseable-but-useless type. One-line fix: add `def dynamic?({:array, _, 0}), do: false` (zero-length fixed array is empty → static by any definition). **Docs:** CHANGELOG entry. |

---

## 📋 Test & Quality Debt

### Tests for recently-added features

- [x] ✅ Map-input encoder tests [D:2/B:7/U:7 → Eff:3.5]
      `type_encoder.ex` `data_to_list/2` map branch now has explicit coverage (7 test cases) plus a demonstrative doctest. Tests live in `test/abi/type_encoder_test.exs` — covers atom keys, string keys, camelCase→snake_case resolution, string-over-atom priority, integer values in nested named-struct maps, and the two raise paths. See [CHANGELOG.md](CHANGELOG.md#unreleased).

- [ ] Round-trip test suite [D:3/B:7/U:7 → Eff:2.33] 🎯
      No systematic `decode(encode(x)) == x` coverage. Add property-based (StreamData) round-trip tests for core types: uint/int/bool/address/bytes/string/bytesN, fixed + dynamic arrays, nested tuples. Catches encoder/decoder symmetry drift.
      **Docs:** CHANGELOG entry.

- [x] ✅ Error-path tests [D:3/B:5/U:4 → Eff:1.5]
      Added regression coverage for 11 previously-untested error branches: bool/bytes type mismatches, int/uint overflow, trailing decode data, unsupported type atoms across encoder/decoder/function-selector, and event-signature / topics-length mismatches in `decode_event/4`. See [CHANGELOG.md](CHANGELOG.md#unreleased).

### Typespecs + docs

- [x] ✅ Fill `@spec` and `@doc` gaps [D:2/B:5/U:3 → Eff:2.0]
      Added specs for every previously-undeclared public function across `ABI`, `ABI.Event`, `ABI.TypeDecoder`, `ABI.TypeEncoder`, and `ABI.FunctionSelector`; added docs for `TypeDecoder.tuple_value/3` and `TypeDecoder.decode_bytes/3`. Doctor spec coverage 42% → 88%, doc coverage 88% → 96%. See [CHANGELOG.md](CHANGELOG.md#unreleased).

- [x] ✅ Refresh README [D:2/B:6/U:6 → Eff:3.0]
      Dropped stale tuple caveat, corrected `ABI.encode/2` arity and `bytes<M>` support marker, migrated `solidity.readthedocs.io` links to `docs.soliditylang.org`, and added runnable examples for `ABI.parse_specification/1`, `ABI.Event.decode_event/4`, and map/struct input to `encode/2`. See [CHANGELOG.md](CHANGELOG.md#unreleased).

- [x] ✅ Extract padding helpers into `ABI.Math` [D:3/B:4/U:3 → Eff:1.17]
      Added `ABI.Math.pad/4` and `ABI.Math.unpad/3`; `ABI.TypeEncoder` and `ABI.TypeDecoder` now delegate instead of duplicating the 32-byte byte-domain padding formula. Resolved the three `TODO: add to ABI.Math` comments. Zero behavior change. See [CHANGELOG.md](CHANGELOG.md#unreleased).

- [x] ✅ Credo strict cleanup (AliasUsage + MaxLineLength + ParameterPatternMatching + Nesting) [D:2/B:3/U:3 → Eff:1.5]
      `mix credo --strict` drove from 51 → 0. Added top-of-module aliases across `ABI`, `ABI.Event`, `ABI.FunctionSelector`, `ABI.Parser`, `ABI.TypeDecoder`, `ABI.TypeEncoder`, and `ABI.Hex`; wrapped long specs and refactored the `Enum.reduce` tuple-encoder into an `encode_tuple_element/2` helper; flipped three `record = %{…}` heads; extracted `ABI.Event.verify_event_signature/2` and `ABI.TypeEncoder.fetch_named_field/2` + `fetch_by_name/2` to drop nesting. See [CHANGELOG.md](CHANGELOG.md#unreleased).

- [x] ✅ Rename `ABI.FunctionSelector.is_dynamic?/1` → `dynamic?/1` [D:2/B:3/U:2 → Eff:1.25]
      Renamed all 9 clause heads, the `@spec`, and the 2 recursive self-calls, plus the 3 private call-sites in `ABI.TypeDecoder` / `ABI.TypeEncoder`. No deprecation shim — `@doc false` since 2017, zero in-repo external callers, and a `defdelegate` shim would recreate the exact `PredicateFunctionNames` violation we were eliminating. See [CHANGELOG.md](CHANGELOG.md#unreleased).

- [ ] `address payable` vs `address` doc note [D:1/B:2/U:2 → Eff:2.0] 🚀
      Solidity's ABI JSON distinguishes `address` from `address payable`, but on-the-wire encoding is identical, so `FunctionSelector.parse_specification_type_type/1` collapses both to `:address` silently. Not mentioned in the public `@type type` or module docs. Add a short note to `ABI.FunctionSelector`'s `@moduledoc` (and/or the `@type type` docstring) so consumers don't expect a separate atom. Upstream-friendly.
      **Docs:** CHANGELOG entry (docs-only).

### Hardening

- [ ] Bound atom creation in `decode_structs: true` path [D:3/B:4/U:3 → Eff:1.17] 📋
      `ABI.TypeDecoder.tuple_value/3` and `ABI.TypeEncoder.data_to_list/2` call `String.to_atom` on contract-supplied field names. Already `sobelow_skip ["DOS.StringToAtom"]`-annotated because the path is gated behind opt-in `decode_structs: true` and field names normally come from trusted ABI metadata. "Trusted" breaks if a consumer ingests ABIs from arbitrary sources (block explorers, contract registries, user-submitted JSON) — the atom table is a non-reclaimable VM resource. Pick one: (a) switch to `String.to_existing_atom/1` with a documented "caller must pre-intern field atoms" contract, (b) add a per-selector atom budget, or (c) cap total unique fields per process. Benchmark either way — the call sites are hot on large ABIs. Upstream PR worth discussing first (behavior change on an opt-in path).
      **Docs:** CHANGELOG entry (security hardening); update `decode_structs: true` docstring with whichever contract lands.

---

## 🚀 Feature Gaps vs. Peer Libraries

- [ ] `ABI.encode_packed/2` support [D:7/B:8/U:6 → Eff:1.0] 📋
      Non-standard packed encoding — used for Merkle airdrop leaves and `keccak256(abi.encodePacked(...))` signature schemes. (Note: EIP-712 itself uses structured hashing, not packed — avoid that framing in any upstream pitch.) Present in `eth-abi`, `ethers`/`viem`, `alloy`. Biggest ecosystem gap. Hold for round-two upstream scope-check after #53/#54 responses land.
      **Docs:** CHANGELOG entry; add to README (mention packed encoding in Usage, note the difference from standard ABI encoding); update Support section if a checkbox category is added.

- [ ] `ABI.decode_error/2` helper [D:4/B:6/U:7 → Eff:1.63] 🚀
      `function_type: :error` is parsed correctly but there's no convenience API for matching revert data against a list of known errors. Workflow is common in Solidity 0.8.4+. Design: `decode_error(revert_data, known_errors)` → `{:ok, %{error: selector, args: [...]}} | :no_match`. Hold for round-two upstream issue after #53/#54 responses land.
      **Docs:** CHANGELOG entry; add a "Decoding custom errors" usage section to README.

- [ ] Implement `function` type encode/decode [D:4/B:3/U:2 → Eff:0.63] ⚠️
      24-byte address+selector type, rarely used in practice. Listed in ABI spec for completeness. Closes the `get_type/1` / encoder asymmetry.
      **Docs:** CHANGELOG entry; flip README Support checkbox for `function` to `[X]`.

- [ ] Implement `fixed<M>x<N>` / `ufixed<M>x<N>` [D:8/B:3/U:2 → Eff:0.31] ⚠️
      Decimal fixed-point types. Rarely seen in real contracts. High cost (both encoder and decoder, plus range validation), low payoff. **Defer unless user demand surfaces.** Alternative: reject at parse time for clarity.
      **Docs:** CHANGELOG entry; update README Support checkboxes (either flip to `[X]` if implemented, or mark as explicitly rejected-at-parse-time if that path is chosen).

---

## Upstream / Fork Split

| Item | Upstream PR candidate? |
|---|---|
| Indexed dynamic event bug | ✅ Bug — file issue, then PR |
| `fixed`/`ufixed`/`function` parse-but-don't-encode | ✅ Bug — file issue |
| `encode_bytes/1` → `defp` | ✅ Hygiene — one-line PR |
| Map-input tests | ✅ Tests for recently-merged feature |
| Round-trip tests | ✅ Pure addition |
| Typespec + doc gaps | ✅ Same shape as #52 |
| README refresh | ✅ Docs-only |
| Padding dedup into `ABI.Math` | ✅ Shipped locally on `zenhive`, ready for upstream PR |
| Credo strict style cleanup | ✅ Shipped locally on `zenhive`, ready for upstream PR |
| `is_dynamic?` → `dynamic?` rename | ✅ Shipped locally on `zenhive`, ready for upstream PR (optional deprecation shim can be added during review) |
| `decode_event/4` error contract | ⚠️ Arguable breaking change — discuss first |
| `encode_packed` | ⚠️ Feature — issue first |
| `decode_error/2` | ⚠️ Feature — issue first |
| `fixed`/`ufixed` / `function` implementations | ⚠️ Feature — confirm interest first |
| `address payable` vs `address` doc note | ✅ Docs — one-line PR |
| `decode_structs: true` atom bound | ⚠️ Hardening — discuss approach first (behavior change on opt-in path) |

Stale upstream issues worth courtesy-triaging (not opening, just noting): #17, #25, #32 all look fixed on current `main`.
