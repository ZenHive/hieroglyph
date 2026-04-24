# ABI Roadmap

**Vision:** Production-grade Solidity ABI encoder/decoder for Elixir, matching feature parity with `eth-abi` (Python), `ethers`/`viem` (JS), and `alloy` (Rust).

**Completed work:** see [CHANGELOG.md](CHANGELOG.md). Recent releases added struct/map input, integer encoding, string-key map support, and Elixir 1.19 compat (through 1.3.0 + PR #52).

**Scope of this roadmap:** findings from the 2026-04-24 review of v1.3.0 (post-#52). Some items will land as upstream PRs to `exthereum/abi`, some are fork-only polish.

---

## 🎯 Current Focus

Upstream PRs for correctness bugs + test gaps in recently-added features. No architectural changes.

---

## 🐛 Bugs

| Task | Status | Location | Notes |
|---|---|---|---|
| **Indexed dynamic event parameters decoded wrong** | ⬜ [upstream #53](https://github.com/exthereum/abi/issues/53) | `lib/abi/event.ex:111-118` | `decode_raw` called on topic bytes regardless of type. Per ABI spec, indexed `string`/`bytes`/`T[]`/tuple params are stored as `keccak256(value)` in topics, not the raw encoding. Silent misdecode for any event using indexed dynamic types. Filed upstream 2026-04-24. |
| **`fixed`/`ufixed`/`function` types parse but can't encode + typespec gaps** | ⬜ [upstream #54](https://github.com/exthereum/abi/issues/54) | `lib/abi/function_selector.ex:7-16, 435-438` | `get_type/1` handles these in stringification; `TypeEncoder`/`TypeDecoder` don't. Also `@type type` omits `{:bytes, N}` plus the same missing entries. Filed upstream 2026-04-24. |
| **`encode_bytes/1` accidentally public** | ⬜ (no issue) | `lib/abi/type_encoder.ex:353` | No `@doc`, no `@spec`, no internal callers outside module. Changing `def` → `defp` is technically a breaking API change for downstream consumers we can't see — Codex review flagged this. Skip the issue; fold into a future PR or leave alone. |
| **`decode_event/4` mixed raise + tagged-tuple contract** | ⬜ (hold) | `lib/abi/event.ex:93-148` | Returns `{:error, _}` for topic/length mismatches but calls `decode_raw` internally, which raises on malformed data. Scope of change = arguable 2.0 breaking API — discuss before PR, not yet filed upstream. |

---

## 📋 Test & Quality Debt

### Tests for recently-added features

- [ ] Map-input encoder tests [D:2/B:7/U:7 → Eff:3.5] 🎯
      `type_encoder.ex:441-460` (`data_to_list/2` map branch) is entirely uncovered by the doctest suite. Covers string-key + atom-key map input paths added in commits `a43e9d5` and `46accc8`. Regression risk is live — these are the two most recent features.

- [ ] Round-trip test suite [D:3/B:7/U:7 → Eff:2.33] 🎯
      No systematic `decode(encode(x)) == x` coverage. Add property-based (StreamData) round-trip tests for core types: uint/int/bool/address/bytes/string/bytesN, fixed + dynamic arrays, nested tuples. Catches encoder/decoder symmetry drift.

- [ ] Error-path tests [D:3/B:5/U:4 → Eff:1.5] 📋
      Overflow guards, size mismatches, trailing-data errors, unsupported-type raises — none covered. Elevates `ABI.TypeEncoder` above the 80% floor (currently 76%).

### Typespecs + docs

- [ ] Fill `@spec` gaps [D:2/B:5/U:3 → Eff:2.0] 🎯
      Missing specs on: `ABI.event_signature/1`, `ABI.parse_specification/1`, `ABI.TypeDecoder.decode/3`, `ABI.TypeEncoder.encode_raw/2`, all public functions in `ABI.Event`, `ABI.FunctionSelector.encode/3`. Same PR shape as `bef2ff9` (merged in #52).

- [ ] Refresh README [D:2/B:6/U:6 → Eff:3.0] 🎯
      Stale tuple caveat ("currently ABI parsing doesn't parse tuples with multiple elements" — no longer true via JSON ABI), no example for `decode_event/4` or `parse_specification/1`, no mention of custom errors or that `abi.encodePacked` is unsupported. New users hit these gaps.

- [ ] Extract padding helpers into `ABI.Math` [D:3/B:4/U:3 → Eff:1.17] 📋
      Three stale TODOs (`type_encoder.ex:399`, `type_decoder.ex:324`, `type_decoder.ex:342`) point at this. Padding logic duplicated between encoder and decoder. Mechanical refactor, zero behavior change.

---

## 🚀 Feature Gaps vs. Peer Libraries

- [ ] `ABI.encode_packed/2` support [D:7/B:8/U:6 → Eff:1.0] 📋
      Non-standard packed encoding — used for Merkle airdrop leaves and `keccak256(abi.encodePacked(...))` signature schemes. (Note: EIP-712 itself uses structured hashing, not packed — avoid that framing in any upstream pitch.) Present in `eth-abi`, `ethers`/`viem`, `alloy`. Biggest ecosystem gap. Hold for round-two upstream scope-check after #53/#54 responses land.

- [ ] `ABI.decode_error/2` helper [D:4/B:6/U:7 → Eff:1.63] 🚀
      `function_type: :error` is parsed correctly but there's no convenience API for matching revert data against a list of known errors. Workflow is common in Solidity 0.8.4+. Design: `decode_error(revert_data, known_errors)` → `{:ok, %{error: selector, args: [...]}} | :no_match`. Hold for round-two upstream issue after #53/#54 responses land.

- [ ] Implement `function` type encode/decode [D:4/B:3/U:2 → Eff:0.63] ⚠️
      24-byte address+selector type, rarely used in practice. Listed in ABI spec for completeness. Closes the `get_type/1` / encoder asymmetry.

- [ ] Implement `fixed<M>x<N>` / `ufixed<M>x<N>` [D:8/B:3/U:2 → Eff:0.31] ⚠️
      Decimal fixed-point types. Rarely seen in real contracts. High cost (both encoder and decoder, plus range validation), low payoff. **Defer unless user demand surfaces.** Alternative: reject at parse time for clarity.

---

## Upstream / Fork Split

| Item | Upstream PR candidate? |
|---|---|
| Indexed dynamic event bug | ✅ Bug — file issue, then PR |
| `fixed`/`ufixed`/`function` parse-but-don't-encode | ✅ Bug — file issue |
| `encode_bytes/1` → `defp` | ✅ Hygiene — one-line PR |
| Map-input tests | ✅ Tests for recently-merged feature |
| Round-trip tests | ✅ Pure addition |
| Typespec gaps | ✅ Same shape as #52 |
| README refresh | ✅ Docs-only |
| Padding dedup into `ABI.Math` | ✅ Mechanical refactor |
| `decode_event/4` error contract | ⚠️ Arguable breaking change — discuss first |
| `encode_packed` | ⚠️ Feature — issue first |
| `decode_error/2` | ⚠️ Feature — issue first |
| `fixed`/`ufixed` / `function` implementations | ⚠️ Feature — confirm interest first |

Stale upstream issues worth courtesy-triaging (not opening, just noting): #17, #25, #32 all look fixed on current `main`.
