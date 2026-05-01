# ABI Roadmap

**Vision:** Production-grade Solidity ABI encoder/decoder for Elixir, matching feature parity with `eth-abi` (Python), `ethers`/`viem` (JS), and `alloy` (Rust).

**Completed work:** see [CHANGELOG.md](CHANGELOG.md). Recent releases added struct/map input, integer encoding, string-key map support, Elixir 1.19 compat (through 1.3.0 + PR #52), and — in the Unreleased entries — map-input encoder tests, error-path tests, typespec/doc gap closure, and a README refresh.

**Scope of this roadmap:** findings from the 2026-04-24 review of v1.3.0 (post-#52). Some items will land as upstream PRs to `exthereum/abi`, some are fork-only polish.

**Task completion rule:** every task below names the docs it must update on completion (**Docs:** line). A task is not done until those doc updates land. At minimum, every task produces a CHANGELOG entry under `## [Unreleased]`; user-facing surface changes also update README; architectural or convention changes also update CLAUDE.md.

---

## 🎯 Current Focus

Upstream bugs #53, #54, and #55 shipped locally (see [CHANGELOG.md](CHANGELOG.md#unreleased)); still awaiting maintainer response on the upstream issues. Other fork-only polish (padding-helper extraction, `is_dynamic?` → `dynamic?` rename, `mix credo --strict` cleanup) landed alongside. The round-trip property suite landed on `main` and surfaced #55 (`encode_int` overflow-guard bug) on first run; fixed in the same task and filed upstream 2026-05-01. The pre-existing `dynamic?/1` zero-length-fixed-array crash, `address payable` typedoc gap, and empty-args calldata coverage all landed in the same batch. The 2026-04-30 `defi-skills` mining discovery task completed — 7 candidate test/coverage entries staged in "Proposed additions from defi-skills mining" below for triage into existing sections (one — empty-args calldata — landed in this batch). Remaining fork-only items: the lexer rule-ordering bug (tracked in Bugs below).

---

## 🐛 Bugs

| Task | Status | Location | Notes |
|---|---|---|---|
| **Indexed reference-type event parameters decoded wrong** | ✅ `zenhive` [upstream #53](https://github.com/exthereum/abi/issues/53) | `lib/abi/event.ex:146-172` | Fix shipped: indexed reference-type params (all arrays — fixed-size or dynamic — plus tuples, `string`, `bytes`) now return `{:indexed_hash, <<32 bytes>>}` via a local `reference_type?/1` predicate (matches the Solidity spec's "all complex types" event-indexing rule, which is broader than `FunctionSelector.dynamic?/1`'s head/tail-layout rule — `uint256[2]` and static-only tuples are static for regular encoding but still hashed in topics). Static value-type indexed params unchanged. See [CHANGELOG.md](CHANGELOG.md#unreleased). |
| **`fixed`/`ufixed`/`function` types parse but can't encode + typespec gaps** | ✅ `zenhive` [upstream #54](https://github.com/exthereum/abi/issues/54) | `lib/abi/parser.ex`, `lib/abi/function_selector.ex:9-19` | Fix shipped: parse-time rejection of `:function`, `{:fixed, M, N}`, `{:ufixed, M, N}` (including nested in arrays/tuples) in `ABI.Parser.parse!/2` with an `ArgumentError` linking to the upstream issue; `{:bytes, pos_integer()}` added to `@type type`. See [CHANGELOG.md](CHANGELOG.md#unreleased). |
| **Lexer `x` terminal shadowed by LETTERS rule** | ⬜ (no issue yet) [D:3/B:4/U:4 → Eff:1.33] 📋 | `src/ethereum_abi_lexer.xrl:13,19` | Discovered while writing tests for #54. `fixed128x18` / `ufixed128x18` tokenize the single `x` as `letters` (LETTERS rule appears before the `x` terminal; leex picks the earlier rule on equal-length matches), so grammar rule `type -> typename digits 'x' digits` never fires. Parser reduces `typename digits` → `juxt_type(fixed, 128)` → `FunctionClauseError` instead of a clean parse-time error. Scope: fix options are (a) reorder lexer rules so `x` outranks LETTERS, making sure identifiers like `foo_x_bar` still tokenize correctly (needs testing — LETTERS is currently the only rule producing `letters` tokens for identifier parts); (b) extend grammar's `identifier_part` to also accept the `x` terminal so identifiers still work; (c) wrap `:ethereum_abi_parser.parse/1` in a `try/rescue` inside `ABI.Parser.parse!/2` and convert the FunctionClauseError to an ArgumentError with an upstream-#54 link. File an upstream issue before picking an approach. **Docs:** CHANGELOG entry; if the fix ends up surfacing the same rejection as #54, may update the README lexer caveat. |
| **`encode_bytes/1` accidentally public** | ⬜ (no issue) | `lib/abi/type_encoder.ex:353` | No `@doc`, no `@spec`, no internal callers outside module. Changing `def` → `defp` is technically a breaking API change for downstream consumers we can't see — Codex review flagged this. Skip the issue; fold into a future PR or leave alone. **Docs:** CHANGELOG entry (breaking, if changed). |
| **`decode_event/4` mixed raise + tagged-tuple contract** | ⬜ (hold) | `lib/abi/event.ex:93-148` | Returns `{:error, _}` for topic/length mismatches but calls `decode_raw` internally, which raises on malformed data. Scope of change = arguable 2.0 breaking API — discuss before PR, not yet filed upstream. **Docs:** CHANGELOG entry (breaking); possibly README note on the unified return contract. |
| **`dynamic?/1` crashes on zero-length fixed array** | ✅ `main` (no upstream issue yet) | `lib/abi/function_selector.ex:484` | One-line fix shipped: `def dynamic?({:array, _type, 0}), do: false`. Encoder/decoder paths already handle zero-length arrays correctly — verified by extending `roundtrip_property_test.exs`'s fixed-array length domain to `0..3`. Pre-existing in upstream `exthereum/abi`; not yet filed (consider folding with the lexer-rule-ordering fix into a single PR). See [CHANGELOG.md](CHANGELOG.md#unreleased). |
| **`encode_int/2` byte-vs-bit overflow guard rejected ALL `int<N>`** | ✅ `main` [upstream #55](https://github.com/exthereum/abi/issues/55) | `lib/abi/type_encoder.ex:382-401` | Surfaced by the round-trip property suite on first run. The overflow guard compared `byte_size(significant_bytes)` against `desired_size_bytes - 1`, which is `0` for `int8` — so even encoding `0` raised. Replaced with a numeric range check against `2^(N-1)` performed up-front, so the encoder accepts the full signed range `-2^(N-1)..2^(N-1)-1` for every `int<N>`. The pre-existing `"int overflow raises data overflow"` test passed only because the encoder was broken for any value; tightened to assert specific in-range values encode AND specific boundary cases (`128`, `-129`) raise. Filed upstream 2026-05-01 — awaiting maintainer response. See [CHANGELOG.md](CHANGELOG.md#unreleased). |

---

## 📋 Test & Quality Debt

### Tests for recently-added features

- [x] ✅ Map-input encoder tests [D:2/B:7/U:7 → Eff:3.5]
      `type_encoder.ex` `data_to_list/2` map branch now has explicit coverage (7 test cases) plus a demonstrative doctest. Tests live in `test/abi/type_encoder_test.exs` — covers atom keys, string keys, camelCase→snake_case resolution, string-over-atom priority, integer values in nested named-struct maps, and the two raise paths. See [CHANGELOG.md](CHANGELOG.md#unreleased).

- [x] ✅ Round-trip test suite [D:3/B:7/U:7 → Eff:2.33]
      Added `test/abi/roundtrip_property_test.exs` — property-based `decode(encode(x)) == x` coverage using `stream_data` for every type in `ABI.FunctionSelector.@type type/0`: per-type properties for `uint`/`int`/`address`/`bool`/`string`/`bytes`/`bytesN`, fixed and dynamic arrays, mixed static+dynamic tuples, plus a recursive composite property (depth ≤ 3) for nested `{:tuple, [{:array, ...}]}` shapes. The composite property surfaced a real `encode_int` bug on its first run (see #encode_int entry under Bugs). See [CHANGELOG.md](CHANGELOG.md#unreleased).

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

- [x] ✅ `address payable` vs `address` doc note [D:1/B:2/U:2 → Eff:2.0]
      Added a `@typedoc` to `ABI.FunctionSelector.@type type/0` clarifying that `address payable` collapses to `:address` (Solidity ABI JSON only emits `"address"`; on-the-wire encoding identical; payability is a `state_mutability` property, not a type variant). See [CHANGELOG.md](CHANGELOG.md#unreleased).

### Hardening

- [ ] Bound atom creation in `decode_structs: true` path [D:3/B:4/U:3 → Eff:1.17] 📋
      `ABI.TypeDecoder.tuple_value/3` and `ABI.TypeEncoder.data_to_list/2` call `String.to_atom` on contract-supplied field names. Already `sobelow_skip ["DOS.StringToAtom"]`-annotated because the path is gated behind opt-in `decode_structs: true` and field names normally come from trusted ABI metadata. "Trusted" breaks if a consumer ingests ABIs from arbitrary sources (block explorers, contract registries, user-submitted JSON) — the atom table is a non-reclaimable VM resource. Pick one: (a) switch to `String.to_existing_atom/1` with a documented "caller must pre-intern field atoms" contract, (b) add a per-selector atom budget, or (c) cap total unique fields per process. Benchmark either way — the call sites are hot on large ABIs. Upstream PR worth discussing first (behavior change on an opt-in path).
      **Docs:** CHANGELOG entry (security hardening); update `decode_structs: true` docstring with whichever contract lands.

### Discovery / Research

- [x] ✅ Mine `defi-skills:intent-to-transaction` action surface for `hieroglyph` ABI coverage gaps [D:3/B:8/U:7 → Eff:2.50] 🎯 — completed 2026-04-30 (`pipx install defi-skills` 0.3.0; output landed in "Proposed additions from defi-skills mining" below)
      Planted 2026-04-30 from a cartouche session that surveyed cross-repo applicability of the `defi-skills` skill. Self-contained discovery exercise — execute from a fresh `hieroglyph` Claude Code session so this repo's CLAUDE.md, hooks, and ABI fixtures are loaded.

      **Prompt for the executing session:** invoke `/defi-skills:intent-to-transaction` to load the skill, then run `defi-skills actions --json` to enumerate the supported action surface (~50 actions across Aave, Uniswap, Lido, Compound, Balancer, Pendle, EigenLayer, Curve, MakerDAO, Rocket Pool, Fibrous, WETH). Map relevant actions to **`hieroglyph`'s scope: ABI encoding patterns surfaced by the action calldata** — function selectors, struct encoding, dynamic types (`bytes`, `string`, `T[]`), nested tuples, edge cases (zero-length arrays, max uint, malformed selectors). The ~50 actions span enough Solidity patterns to be a real-world test surface for the ABI library. For each gap or coverage opportunity, propose a ROADMAP entry with D/B/U scoring per `~/.claude/includes/task-prioritization.md`. Output: a "Proposed additions from defi-skills mining" section the user reviews and merges into `Test & Quality Debt`, `Feature Gaps vs. Peer Libraries`, or a new section before any implementation begins.

      Read-only exercise — discovery + scoring only, no `ABI.*` code edits in this task itself. The skill is already installed (`pip install defi-skills`); no new deps. Companion tasks were planted in `onchain`, `onchain_aave`, and `onchain_evm` ROADMAPs the same day.

      **Acceptance:** a "Proposed additions from defi-skills mining" section lands in this ROADMAP listing each candidate task with D/B/U scores and which `defi-skills` action(s) motivated it. The user merges accepted entries into the existing sections.
      **Docs:** no CHANGELOG entry — discovery task; CHANGELOG entries follow when surfaced tasks are implemented.

---

## 📋 Proposed additions from defi-skills mining

Surfaced 2026-04-30 by mining the [`defi-skills`](https://pypi.org/project/defi-skills/) v0.3.0 action surface (53 actions across 13 protocols: Aave V3, Balancer V2, Compound V3, Curve 3pool + Gauges, EigenLayer, Lido, MakerDAO DSR, Pendle V2, Rocket Pool, transfers, Uniswap V3, WETH, Fibrous). For each action we extracted the function selector + ABI types from the playbooks at `~/.local/pipx/venvs/defi-skills/lib/python3.14/site-packages/defi_skills/data/playbooks/*.json` and Etherscan-cached ABIs at `…/data/abi_cache/*.json`, plus concrete `defi-skills build --json` calldata samples for the static-only actions.

**Patterns already covered by `roundtrip_property_test.exs`** (no new task needed): all-static args; uint/int multiples of 8 from 8…256 (so `uint24`, `uint160` are in range); `bytes1`…`bytes32`; dynamic `address[]` / `uint256[]` / `string[]` / `bytes[]`; fixed-size arrays length 1–4 with `uint256` (covers Curve 3pool's `uint256[3]`); `(uint256,string,bool,bytes)` and `(uint256,uint256[])` mixed static/dynamic tuples. Below are entries for **gaps** the mining surfaced.

Pattern-grouped, with the `defi-skills` action(s) that motivated each. Concrete sample calldata included so the implementing session has copy-pasteable fixtures.

- [ ] Real-world golden calldata fixtures from `defi-skills build` [D:3/B:6/U:6 → Eff:2.0] 🚀
      Add a fixture file (e.g. `test/fixtures/defi_calldata.exs`) of locked `{signature, args, expected_calldata_hex}` triples captured from `defi-skills build --action <name> --json`. Each fixture asserts both directions: `ABI.encode(selector, args) == expected_calldata` AND `ABI.decode(expected_calldata, types) == args`. Validates against `eth_abi` (the canonical reference) without taking a runtime dep. Today only one real-world fixture exists in the repo — the ERC-20 `Transfer` event doctest in `lib/abi.ex`. Coverage gap: every encoder/decoder change is verified only against synthetic shapes.

      Recommended starter set (10 captures, all built without RPC/TheGraph):
      - `aave_supply` `supply(address,uint256,address,uint16)` selector `0x617ba037`
      - `aave_borrow` `borrow(address,uint256,uint256,uint16,address)` selector `0xa415bcad`
      - `aave_set_collateral` `setUserUseReserveAsCollateral(address,bool)` selector `0x5a3b74b9`
      - `compound_supply` `supply(address,uint256)` selector `0xf2b9fdb8`
      - `compound_claim_rewards` `claim(address,address,bool)` selector `0xb7034f7e`
      - `lido_stake` `submit(address)` selector `0xa1903eab`
      - `lido_unstake` `requestWithdrawals(uint256[],address)` selector `0xd6681042`
      - `eigenlayer_deposit` `depositIntoStrategy(address,address,uint256)` selector `0xe7a050aa`
      - `transfer_erc20` `transfer(address,uint256)` selector `0xa9059cbb`
      - `weth_unwrap` `withdraw(uint256)` selector `0x2e1a7d4d`

      Sample (aave_supply with `{"asset":"USDC","amount":"500","onBehalfOf":"0x1111…1111"}`):
      ```
      0x617ba037
        000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
        000000000000000000000000000000000000000000000000000000001dcd6500
        0000000000000000000000001111111111111111111111111111111111111111
        0000000000000000000000000000000000000000000000000000000000000000
      ```
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

- [ ] Function selector golden vectors against `FunctionSelector.encode/1` [D:2/B:5/U:5 → Eff:2.5] 🎯
      Lock 10–15 known mainnet selectors against `ABI.FunctionSelector.encode/1` output. Cheapest entry to win — all selectors are already known from `defi-skills` playbooks. No fixture file needed; one focused test module `test/abi/function_selector_real_world_test.exs` mapping `signature_string → expected_4_bytes`. Today there's no test that proves the keccak-derived selector matches what real chains expect.

      Selectors with known signatures (subset across protocols, all from `defi-skills` playbooks):
      - `supply(address,uint256,address,uint16)` → `0x617ba037` (Aave)
      - `borrow(address,uint256,uint256,uint16,address)` → `0xa415bcad` (Aave)
      - `withdraw(uint256)` → `0x2e1a7d4d` (WETH unwrap, Curve gauge withdraw — duplicate selector by design)
      - `deposit()` → `0xd0e30db0` (WETH wrap, Rocket Pool stake — also duplicate)
      - `transfer(address,uint256)` → `0xa9059cbb` (ERC-20)
      - `transferFrom(address,address,uint256)` → `0x23b872dd` (ERC-20/ERC-721)
      - `requestWithdrawals(uint256[],address)` → `0xd6681042` (Lido)
      - `claim(address,address,bool)` → `0xb7034f7e` (Compound)
      - `add_liquidity(uint256[3],uint256)` → `0x4515cef3` (Curve 3pool — exercises the fixed-size-array selector path)
      - `exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))` → `0x414bf389` (Uniswap V3 — exercises tuple-in-signature)
      - `swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)` → `0x52bbbe29` (Balancer V2 — multiple top-level tuples)
      - `queueWithdrawals((address[],uint256[],address)[])` → `0x0dd8dd02` (EigenLayer — `tuple[]` in signature)

      The Curve `uint256[3]`, Uniswap tuple, Balancer multi-tuple, and EigenLayer `tuple[]` cases double as proof that the canonical-signature serialisation in `function_selector.ex` matches the spec.
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

- [x] ✅ Empty-args calldata path coverage [D:1/B:2/U:3 → Eff:2.5]
      Tests added in `test/abi_test.exs` covering the `f()` shape (`weth.deposit()` / `rocket_pool.deposit()`): `ABI.encode("deposit()", []) == <<0xD0, 0xE3, 0x0D, 0xB0>>`, `ABI.decode("deposit()", <<>>) == []`, plus the `function: nil`/`types: []` empty-bytes shape. See [CHANGELOG.md](CHANGELOG.md#unreleased).

- [ ] Deep struct nesting (depth ≥ 4) round-trip [D:2/B:4/U:4 → Eff:2.0] 🚀
      `roundtrip_property_test.exs` `composite/2` recursion is capped at depth 3 (line ~252 of the file). Pendle `swapExactTokenForPt` exercises depth 5: `args.input` (struct) contains `swapData` (struct) which contains `extCalldata` (bytes); the `limit` arg (struct) contains `normalFills` and `flashFills` (each `tuple[]`). Bumping `composite` depth to 5 is a one-line change; the failures (if any) it surfaces are real.

      Motivated by: `pendle_swap_token_for_pt` (`0xc81f847a`), `pendle_swap_token_for_yt` (`0xed48907e`), `pendle_add_liquidity` (`0x12599ac6`).
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

- [ ] Multiple top-level struct args [D:3/B:4/U:4 → Eff:1.33] 📋
      Roundtrip property test always wraps arguments as a single tuple or a single dynamic array. Real protocols often pass **multiple sibling structs** as separate top-level args (Balancer V2 `swap(SingleSwap, FundManagement, uint256, uint256)` is the canonical case — 4 top-level args of which 2 are structs). Add a generator that builds an arg list `[t1, t2, ...]` where 2+ entries are independently-generated structs. Catches head/tail offset arithmetic when sibling tuples are dynamic at different rates.

      Motivated by: `balancer_swap` (`0x52bbbe29`) — `swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)`.
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

- [ ] `tuple[]` (dynamic array of tuples) round-trip coverage [D:4/B:5/U:5 → Eff:1.25] 📋
      `roundtrip_property_test.exs` exercises dynamic arrays only with `uint256`/`address`/`string`/`bytes` element types (lines ~189–211). It never generates a `(T1, T2, …)[]` shape — but `tuple[]` is the canonical shape for batch-style DeFi calls. Real-world examples found:
      - EigenLayer `queueWithdrawals((address[],uint256[],address)[])` (`0x0dd8dd02`) — each element is itself dynamic (two array fields), so `head/tail` is computed per-element AND per-array.
      - Pendle `limit.normalFills` and `limit.flashFills` (both `(...)[]` fields nested inside a struct, typically empty `[]` in practice — see the empty-array edge case task below).

      Add a `value_for({:array, {:tuple, [...]}, :dynamic})` clause and a property that exercises `tuple_of(static_only)[]`, `tuple_of(mixed)[]`, and an empty `tuple[]`.
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

- [ ] Empty `bytes` and empty `tuple[]` inside struct fields [D:3/B:5/U:4 → Eff:1.5] 📋
      Several protocols pass empty dynamic fields (`0x` for `bytes`, `[]` for `tuple[]`) inside a tuple where adjacent fields are also dynamic. Head/tail offsets must still be exact. The roundtrip property generates random-length `bytes` (0..64) but doesn't pin the empty-bytes-in-tuple case explicitly, and never tests empty `tuple[]` at all (see task above). Examples:
      - `balancer_swap.singleSwap.userData = "0x"` (constant in the playbook)
      - `eigenlayer_delegate.approverSignatureAndExpiry.signature = "0x"` (constant)
      - `pendle_*.limit.normalFills = []` and `limit.optData = "0x"`

      Add explicit fixtures (not properties) that exercise:
      - struct with two adjacent dynamic fields, one empty
      - struct with `(bytes,bytes)` where both are empty
      - struct with `tuple[]` empty as the only dynamic field
      - struct with `tuple[]` empty followed by a non-empty `bytes`
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

**Out-of-scope findings (deliberately not proposed):**

- **`address payable` vs `address` collapse** — already tracked in `Test & Quality Debt` ("`address payable` vs `address` doc note"). `defi-skills` playbooks use `address` uniformly, so no new evidence to change the existing scoring.
- **`zero-length fixed array` — `T[0]` crash** — already tracked in `Bugs` (`dynamic?/1` crashes on zero-length fixed array). `defi-skills` uses `uint256[3]` not `uint256[0]`, so doesn't surface fresh evidence.
- **Pre-encoded `raw` bytes in `defi-skills`** (Fibrous, `eigenlayer_complete_withdrawal`) — bypass path, the playbook hands ABI-encoded blobs through `bytes` rather than re-encoding. Not an ABI pattern this library needs to handle.
- **Multi-tx sequences (approval + action)** — each tx is independently ABI-encoded; nothing for `hieroglyph` to do at the encoding layer.

---

## 🚀 Feature Gaps vs. Peer Libraries

- [x] ✅ `ABI.decode_call/3` + `ABI.method_id/1` [D:2/B:5/U:6 → Eff:2.75]
      Symmetric counterpart to `ABI.encode/2` for selector-prefixed calldata: `decode_call` strips and verifies the 4-byte selector, then routes the payload through the existing `decode/3` machinery; returns `{:ok, _}` or `{:error, :calldata_too_short | :selector_mismatch | :no_function_name}`. `decode/3` semantics unchanged (still payload-only, matches `eth-abi`/`ethers`/`viem`/`alloy`). `method_id/1` exposes the selector-derivation primitive (`keccak256(canonical_signature)[0..3]`). See [CHANGELOG.md](CHANGELOG.md#unreleased).

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
| `decode_call/3` + `method_id/1` | ✅ Pure addition — file as upstream feature PR |
| `encode_packed` | ⚠️ Feature — issue first |
| `decode_error/2` | ⚠️ Feature — issue first |
| `fixed`/`ufixed` / `function` implementations | ⚠️ Feature — confirm interest first |
| `address payable` vs `address` doc note | ✅ Docs — one-line PR |
| `decode_structs: true` atom bound | ⚠️ Hardening — discuss approach first (behavior change on opt-in path) |

Stale upstream issues worth courtesy-triaging (not opening, just noting): #17, #25, #32 all look fixed on current `main`.
