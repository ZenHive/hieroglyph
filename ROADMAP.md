# ABI Roadmap

**Vision:** Production-grade Solidity ABI encoder/decoder for Elixir, matching feature parity with `eth-abi` (Python), `ethers`/`viem` (JS), and `alloy` (Rust).

**Completed work:** see [CHANGELOG.md](CHANGELOG.md). Recent releases added struct/map input, integer encoding, string-key map support, Elixir 1.19 compat (through 1.3.0 + PR #52), and — in the Unreleased entries — map-input encoder tests, error-path tests, typespec/doc gap closure, and a README refresh.

**Scope of this roadmap:** findings from the 2026-04-24 review of v1.3.0 (post-#52). Some items will land as upstream PRs to `exthereum/abi`, some are fork-only polish.

**Task completion rule:** every task below names the docs it must update on completion (**Docs:** line). A task is not done until those doc updates land. At minimum, every task produces a CHANGELOG entry under `## [Unreleased]`; user-facing surface changes also update README; architectural or convention changes also update CLAUDE.md.

---

## 🎯 Current Focus

Upstream bugs (#53, #54) pending maintainer response. Fork-only polish: padding-helper extraction, `is_dynamic?` → `dynamic?` rename, and `mix credo --strict` cleanup all landed together on `zenhive` (see [CHANGELOG.md](CHANGELOG.md#unreleased)). Remaining fork-only item: the round-trip property test suite.

---

## 🐛 Bugs

| Task | Status | Location | Notes |
|---|---|---|---|
| **Indexed dynamic event parameters decoded wrong** | ⬜ [upstream #53](https://github.com/exthereum/abi/issues/53) | `lib/abi/event.ex:111-118` | `decode_raw` called on topic bytes regardless of type. Per ABI spec, indexed `string`/`bytes`/`T[]`/tuple params are stored as `keccak256(value)` in topics, not the raw encoding. Silent misdecode for any event using indexed dynamic types. Filed upstream 2026-04-24. **Docs:** CHANGELOG entry (bugfix). |
| **`fixed`/`ufixed`/`function` types parse but can't encode + typespec gaps** | ⬜ [upstream #54](https://github.com/exthereum/abi/issues/54) | `lib/abi/function_selector.ex:7-16, 435-438` | `get_type/1` handles these in stringification; `TypeEncoder`/`TypeDecoder` don't. Also `@type type` omits `{:bytes, N}` plus the same missing entries. Filed upstream 2026-04-24. **Docs:** CHANGELOG entry; if the fix implements `function` (or flips `fixed`/`ufixed` to reject-at-parse-time), also update README Support checkboxes. |
| **`encode_bytes/1` accidentally public** | ⬜ (no issue) | `lib/abi/type_encoder.ex:353` | No `@doc`, no `@spec`, no internal callers outside module. Changing `def` → `defp` is technically a breaking API change for downstream consumers we can't see — Codex review flagged this. Skip the issue; fold into a future PR or leave alone. **Docs:** CHANGELOG entry (breaking, if changed). |
| **`decode_event/4` mixed raise + tagged-tuple contract** | ⬜ (hold) | `lib/abi/event.ex:93-148` | Returns `{:error, _}` for topic/length mismatches but calls `decode_raw` internally, which raises on malformed data. Scope of change = arguable 2.0 breaking API — discuss before PR, not yet filed upstream. **Docs:** CHANGELOG entry (breaking); possibly README note on the unified return contract. |

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

Stale upstream issues worth courtesy-triaging (not opening, just noting): #17, #25, #32 all look fixed on current `main`.
