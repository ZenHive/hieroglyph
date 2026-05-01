# ABI Roadmap

**Vision:** Production-grade Solidity ABI encoder/decoder for Elixir, matching feature parity with `eth-abi` (Python), `ethers`/`viem` (JS), and `alloy` (Rust).

**Completed work:** see [CHANGELOG.md](CHANGELOG.md). Recent releases added struct/map input, integer encoding, string-key map support, Elixir 1.19 compat (through 1.3.0 + PR #52), and — in the Unreleased entries — map-input encoder tests, error-path tests, typespec/doc gap closure, and a README refresh.

**Scope of this roadmap:** findings from the 2026-04-24 review of v1.3.0 (post-#52). Some items will land as upstream PRs to `exthereum/abi`, some are fork-only polish.

**Task completion rule:** every task below names the docs it must update on completion (**Docs:** line). A task is not done until those doc updates land. At minimum, every task produces a CHANGELOG entry under `## [Unreleased]`; user-facing surface changes also update README; architectural or convention changes also update CLAUDE.md.

---

## 🎯 Current Focus

**1.2.0 shipped 2026-05-01** — bundled Agent Economy release. All three phases landed: top-level `ABI` plus the five remaining public modules annotated with `api()` declarations, `Descripex.Discoverable` wired across the full surface, dedicated `mix hieroglyph.manifest [path]` task, and a hint-rot validation test (`test/abi/agent_economy_test.exs`) whose load-bearing cross-check asserts every non-framework export is declared with `api()`. Manifest now emits 25 user-declared entries plus 4 framework `Discoverable` exports — suitable for downstream cartouche/onchain CI to diff across version bumps as a contract-stability artifact. Added runtime dep `{:descripex, "~> 0.6"}` (transitively pulls `:json_spec`). See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

**1.1.0 shipped 2026-05-01** — patch-bumped from `1.0.0` to a minor release because two new public APIs were added (`ABI.method_id/1`, `ABI.decode_call/3`) alongside the bug fixes. See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01) for the full entry list.

Upstream bugs #53, #54, and #55 shipped locally; still awaiting maintainer response on the upstream issues. The lexer `x`-terminal-shadow bug (sub-bug of upstream #54, filing deferred to a future batched issue) also shipped in 1.2.0.

**DeFi Real-World Fixtures bundle shipped 2026-05-01 (Unreleased)** — both members landed: real-world calldata round-trips (`test/abi/defi_calldata_test.exs`) and selector golden vectors (`test/abi/function_selector_real_world_test.exs`). Tests-only PR, no production code touched. See [CHANGELOG.md](CHANGELOG.md#unreleased).

**Next direction:** the remaining Property Suite Expansion bundle (`tuple[]` round-trip, empty-collection fixtures, multiple top-level struct args, deeper nesting) plus the standalone open tasks in subsequent sections.

**Shipping units:** see `📦 Bundles` below for the remaining release-bundle. The other open tasks ship standalone.

---

## 📦 Bundles

Tasks grouped by shipping unit. A bundle ships as one PR / one release; member tasks share scope, files, or sourcing. Standalone tasks (no `**Bundle:**` annotation on the task itself) ship independently. Each member task keeps its own D/B/U score — the per-bundle "Avg Eff" below is a planning convenience, not a substitute.

### Bundle: DeFi Real-World Fixtures ✅ shipped 2026-05-01 (Unreleased)
Both members landed in a single tests-only commit. Inline `@fixtures` format chosen over the originally-proposed `test/fixtures/defi_calldata.exs` because no `.exs` data-loading idiom exists in the repo. See [CHANGELOG.md](CHANGELOG.md#unreleased).

### Bundle: Property Suite Expansion
**Members:** `tuple[]` round-trip coverage, Empty `bytes` / empty `tuple[]` inside struct fields, Multiple top-level struct args, Deep struct nesting (depth ≥ 4)
**Avg Eff:** 1.52 — (1.25 + 1.5 + 1.33 + 2.0) / 4
**Ships:** single PR expanding `test/abi/roundtrip_property_test.exs`
**Why bundle:** every member edits the same property test file and the same generator helpers (`composite/2`, `value_for/1`, the arg-list builder). They're sequential, not parallel — bumping `composite` depth interacts with the new `{:array, {:tuple, _}, :dynamic}` clause; the empty-`tuple[]` fixtures depend on the `tuple[]` generator landing first. Integrating in one PR avoids merge friction inside the generator and runs the (slow) property suite once instead of four times in CI.
**Sequencing:** `tuple[]` round-trip → empty `tuple[]` fixtures → multiple top-level struct args → deep nesting bump. Depth bump lands last so it stresses the most generator surface.

---

## 🐛 Bugs

| Task | Status | Location | Notes |
|---|---|---|---|
| **Indexed reference-type event parameters decoded wrong** | ✅ shipped 1.0.0 [upstream #53](https://github.com/exthereum/abi/issues/53) | `lib/abi/event.ex:146-172` | Fix shipped: indexed reference-type params (all arrays — fixed-size or dynamic — plus tuples, `string`, `bytes`) now return `{:indexed_hash, <<32 bytes>>}` via a local `reference_type?/1` predicate (matches the Solidity spec's "all complex types" event-indexing rule, which is broader than `FunctionSelector.dynamic?/1`'s head/tail-layout rule — `uint256[2]` and static-only tuples are static for regular encoding but still hashed in topics). Static value-type indexed params unchanged. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24). |
| **`fixed`/`ufixed`/`function` types parse but can't encode + typespec gaps** | ✅ shipped 1.0.0 [upstream #54](https://github.com/exthereum/abi/issues/54) | `lib/abi/parser.ex`, `lib/abi/function_selector.ex:9-19` | Fix shipped: parse-time rejection of `:function`, `{:fixed, M, N}`, `{:ufixed, M, N}` (including nested in arrays/tuples) in `ABI.Parser.parse!/2` with an `ArgumentError` linking to the upstream issue; `{:bytes, pos_integer()}` added to `@type type`. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24). |
| **Lexer `x` terminal shadowed by LETTERS rule** | ✅ shipped 1.2.0 (upstream filing deferred — batched into a future combined-bugs issue) | `src/ethereum_abi_lexer.xrl`, `src/ethereum_abi_parser.yrl` | Fix shipped: dedicated `fixed_typename` / `ufixed_typename` terminals in the lexer so the `'x'` separator only appears in `fixed`/`ufixed` contexts; `'x'` rule moved before `{LETTERS}` so single `x` lexes as the terminal; parser gains `identifier_part -> 'x' \| fixed_typename \| ufixed_typename` so single-char `x` and the keyword forms still work as function/argument names. The explicit-M/N forms now route through `ABI.Parser.reject_unsupported!/1` and raise the same friendly `ArgumentError` (with upstream-#54 link) that bare `fixed`/`ufixed` already do. New shift/reduce count is 3 (was 1) — the 2 new conflicts resolve as shift, which is the desired behavior; documented inline in the `.yrl`. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01). |
| **`encode_bytes/1` accidentally public** | ⬜ (no issue) | `lib/abi/type_encoder.ex:353` | No `@doc`, no `@spec`, no internal callers outside module. Changing `def` → `defp` is technically a breaking API change for downstream consumers we can't see — Codex review flagged this. Skip the issue; fold into a future PR or leave alone. **Docs:** CHANGELOG entry (breaking, if changed). |
| **`decode_event/4` mixed raise + tagged-tuple contract** | ⬜ (hold) | `lib/abi/event.ex:93-148` | Returns `{:error, _}` for topic/length mismatches but calls `decode_raw` internally, which raises on malformed data. Scope of change = arguable 2.0 breaking API — discuss before PR, not yet filed upstream. **Docs:** CHANGELOG entry (breaking); possibly README note on the unified return contract. |
| **`dynamic?/1` crashes on zero-length fixed array** | ✅ shipped 1.1.0 (no upstream issue yet) | `lib/abi/function_selector.ex:484` | One-line fix shipped: `def dynamic?({:array, _type, 0}), do: false`. Encoder/decoder paths already handle zero-length arrays correctly — verified by extending `roundtrip_property_test.exs`'s fixed-array length domain to `0..3`. Pre-existing in upstream `exthereum/abi`; not yet filed (consider folding with the lexer-rule-ordering fix into a single PR). See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01). |
| **`encode_int/2` byte-vs-bit overflow guard rejected ALL `int<N>`** | ✅ shipped 1.1.0 [upstream #55](https://github.com/exthereum/abi/issues/55) | `lib/abi/type_encoder.ex:382-401` | Surfaced by the round-trip property suite on first run. The overflow guard compared `byte_size(significant_bytes)` against `desired_size_bytes - 1`, which is `0` for `int8` — so even encoding `0` raised. Replaced with a numeric range check against `2^(N-1)` performed up-front, so the encoder accepts the full signed range `-2^(N-1)..2^(N-1)-1` for every `int<N>`. The pre-existing `"int overflow raises data overflow"` test passed only because the encoder was broken for any value; tightened to assert specific in-range values encode AND specific boundary cases (`128`, `-129`) raise. Filed upstream 2026-05-01 — awaiting maintainer response. See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01). |

---

## 🤖 Agent Economy

Per `~/.claude/includes/agent-economy.md` and `elixir-setup.md`'s "≥3 public modules" rule, `hieroglyph` should be Descripex-annotated so its public surface is discoverable via `__api__/0` introspection, `ABI.describe/0..2` progressive disclosure, and a static `api_manifest.json`. **25 public functions across 6 modules currently have zero `api()` annotations.**

**Downstream consumer chain (real, in this monorepo):**

```
hieroglyph ← cartouche ← onchain ← {onchain_aave, onchain_evm, onchain_js, onchain_tempo}
                                      ← [MPP-fronted API service at the edge]
```

- **`cartouche`** (`{:hieroglyph, "~> 1.0"}`) is a codegen heavyweight: `lib/mix/cartouche.gen.ex` emits `ABI.encode/2` / `ABI.decode/3` calls into generated contract-binding modules at compile time, plus `lib/cartouche/{transaction,erc_20,sleuth,open_chain,rpc}.ex` use ABI directly.
- **`onchain`** (`{:cartouche, "~> 0.1"}`) consumes ABI directly in `lib/onchain/{abi,log,sleuth}.ex` and inherits cartouche-generated bindings.
- The four **`onchain_<protocol>`** packages depend on `onchain` and consume hieroglyph through that path.
- An **MPP-fronted API service** (`~/_DATA/code/mpp`) sits at the edge — not a direct hieroglyph consumer.

**Layered value of Descripex on hieroglyph:**

1. **Contract-stability artifact (primary, immediate).** The manifest captures every public function's signature + hints. cartouche / onchain CI hash the pinned-version manifest and detect breaking-change drift before generated code breaks downstream.
2. **Hexdocs richness + EIP-8004 verification (universal, immediate).** `api()` declarations land in hexdocs as structured hints; the static manifest is what an EIP-8004 verifier reads to confirm the deployed library matches its declared interface. Pure-functional core ⇒ trivially trustless-verifiable (per `agent-economy.md`: "the more pure your core, the easier trustless verification") — don't muddy this with Rust NIFs.
3. **Paid-tool catalog (secondary, eventual).** If the MPP-fronted API surfaces any hieroglyph primitives as paid tools, the manifest IS the catalog. Hint quality determines whether agents make wasted (paid) calls. Whether MPP exposes raw ABI or higher-level action verbs is a design call at that layer — hieroglyph's job is just accurate `__api__/0`.

**Precedent:** `~/_DATA/code/mpp` (`lib/mpp.ex` for Discoverable setup, `lib/mpp/amount.ex` and `lib/mpp/mcp.ex` for `api()` shapes including the polymorphic-arg pattern, `lib/mix/tasks/mpp.manifest.ex` for the manifest task, `test/mpp/descripex_test.exs` for the hint-rot validation test). Match its conventions.

- [x] ✅ Phase 1: Descripex on `ABI` top-level [D:2/B:7/U:7 → Eff:3.50] — shipped in `1.2.0`
      Added `{:descripex, "~> 0.6"}` as a runtime dep, annotated the seven public functions in `lib/abi.ex` (`encode/2`, `method_id/1`, `decode/3`, `decode_call/3`, `decode_event/4`, `event_signature/1`, `parse_specification/1`) with `api()` declarations under namespace `/abi`, and wired `use Descripex.Discoverable, modules: [ABI]`. Acceptance verified via `mix run`: `ABI.describe/0..2` returns hints; `ABI.__api__()` lists all seven; `mix descripex.manifest --app hieroglyph` emits 11 entries (7 annotated + 4 Discoverable bookkeeping). Version bumped `1.1.0` → `1.2.0`. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

- [x] ✅ Phase 2: Descripex on remaining public modules [D:4/B:6/U:5 → Eff:1.375] — shipped in `1.2.0`
      Annotated all 18 documented public functions across `ABI.Event` (`/selector`), `ABI.FunctionSelector` (`/selector` — 3 `@doc false` internals excluded), `ABI.TypeEncoder` (`/codec` — `encode_bytes/1` `@doc false` excluded), `ABI.TypeDecoder` (`/codec`), and `ABI.Math` (`/math`). `composes_with:` links wired across the natural pairings. Extended `use Descripex.Discoverable, modules: [...]` to all six annotated modules. Manifest now emits 25 user-declared `api()` entries plus 4 framework `Discoverable` exports. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

- [x] ✅ Phase 3: Custom manifest task + hint-rot validation test [D:2/B:5/U:6 → Eff:2.75] — shipped in `1.2.0`
      Added `lib/mix/tasks/hieroglyph.manifest.ex` (`mix hieroglyph.manifest [path]`, defaults to `api_manifest.json`) and `test/abi/agent_economy_test.exs` (17 tests across `api() annotations`, `Discoverable (ABI.describe/0-2)`, and `namespace assignment` describe blocks, including the load-bearing cross-check that walks `module_info(:exports)` and asserts every non-framework export is declared with `api()`). Documented commands in README "Agent Integration"; CLAUDE.md "Layout" gets the manifest task row. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

---

## 📋 Test & Quality Debt

### Tests for recently-added features

- [x] ✅ Map-input encoder tests [D:2/B:7/U:7 → Eff:3.5]
      `type_encoder.ex` `data_to_list/2` map branch now has explicit coverage (7 test cases) plus a demonstrative doctest. Tests live in `test/abi/type_encoder_test.exs` — covers atom keys, string keys, camelCase→snake_case resolution, string-over-atom priority, integer values in nested named-struct maps, and the two raise paths. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24).

- [x] ✅ Round-trip test suite [D:3/B:7/U:7 → Eff:2.33]
      Added `test/abi/roundtrip_property_test.exs` — property-based `decode(encode(x)) == x` coverage using `stream_data` for every type in `ABI.FunctionSelector.@type type/0`: per-type properties for `uint`/`int`/`address`/`bool`/`string`/`bytes`/`bytesN`, fixed and dynamic arrays, mixed static+dynamic tuples, plus a recursive composite property (depth ≤ 3) for nested `{:tuple, [{:array, ...}]}` shapes. The composite property surfaced a real `encode_int` bug on its first run (see #encode_int entry under Bugs). See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01).

- [x] ✅ Error-path tests [D:3/B:5/U:4 → Eff:1.5]
      Added regression coverage for 11 previously-untested error branches: bool/bytes type mismatches, int/uint overflow, trailing decode data, unsupported type atoms across encoder/decoder/function-selector, and event-signature / topics-length mismatches in `decode_event/4`. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24).

### Typespecs + docs

- [x] ✅ Fill `@spec` and `@doc` gaps [D:2/B:5/U:3 → Eff:2.0]
      Added specs for every previously-undeclared public function across `ABI`, `ABI.Event`, `ABI.TypeDecoder`, `ABI.TypeEncoder`, and `ABI.FunctionSelector`; added docs for `TypeDecoder.tuple_value/3` and `TypeDecoder.decode_bytes/3`. Doctor spec coverage 42% → 88%, doc coverage 88% → 96%. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24).

- [x] ✅ Refresh README [D:2/B:6/U:6 → Eff:3.0]
      Dropped stale tuple caveat, corrected `ABI.encode/2` arity and `bytes<M>` support marker, migrated `solidity.readthedocs.io` links to `docs.soliditylang.org`, and added runnable examples for `ABI.parse_specification/1`, `ABI.Event.decode_event/4`, and map/struct input to `encode/2`. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24).

- [x] ✅ Extract padding helpers into `ABI.Math` [D:3/B:4/U:3 → Eff:1.17]
      Added `ABI.Math.pad/4` and `ABI.Math.unpad/3`; `ABI.TypeEncoder` and `ABI.TypeDecoder` now delegate instead of duplicating the 32-byte byte-domain padding formula. Resolved the three `TODO: add to ABI.Math` comments. Zero behavior change. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24).

- [x] ✅ Credo strict cleanup (AliasUsage + MaxLineLength + ParameterPatternMatching + Nesting) [D:2/B:3/U:3 → Eff:1.5]
      `mix credo --strict` drove from 51 → 0. Added top-of-module aliases across `ABI`, `ABI.Event`, `ABI.FunctionSelector`, `ABI.Parser`, `ABI.TypeDecoder`, `ABI.TypeEncoder`, and `ABI.Hex`; wrapped long specs and refactored the `Enum.reduce` tuple-encoder into an `encode_tuple_element/2` helper; flipped three `record = %{…}` heads; extracted `ABI.Event.verify_event_signature/2` and `ABI.TypeEncoder.fetch_named_field/2` + `fetch_by_name/2` to drop nesting. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24).

- [x] ✅ Rename `ABI.FunctionSelector.is_dynamic?/1` → `dynamic?/1` [D:2/B:3/U:2 → Eff:1.25]
      Renamed all 9 clause heads, the `@spec`, and the 2 recursive self-calls, plus the 3 private call-sites in `ABI.TypeDecoder` / `ABI.TypeEncoder`. No deprecation shim — `@doc false` since 2017, zero in-repo external callers, and a `defdelegate` shim would recreate the exact `PredicateFunctionNames` violation we were eliminating. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24).

- [x] ✅ `address payable` vs `address` doc note [D:1/B:2/U:2 → Eff:2.0]
      Added a `@typedoc` to `ABI.FunctionSelector.@type type/0` clarifying that `address payable` collapses to `:address` (Solidity ABI JSON only emits `"address"`; on-the-wire encoding identical; payability is a `state_mutability` property, not a type variant). See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01).

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

- [x] ✅ shipped 2026-05-01 (Unreleased) — Real-world golden calldata fixtures from `defi-skills build` [D:3/B:6/U:6 → Eff:2.0]
      Landed as `test/abi/defi_calldata_test.exs` — 10 round-trip golden vectors captured via `defi-skills build --action <name> --json` (defi-skills v0.3.0). Format chosen: inline `@fixtures` module attribute (the `test/fixtures/defi_calldata.exs` proposal was discarded — no `.exs` data-loading idiom exists in the repo and inline matches the existing convention). Each fixture asserts both directions: `ABI.encode(sig, args)` reproduces the locked calldata exactly, and `ABI.decode_call(sig, calldata)` round-trips back to the original args. Covers Aave V3 supply/borrow/setCollateral, Compound V3 supply/claim, Lido stake/unstake (exercising `uint256[]` head/tail layout), EigenLayer deposit, ERC-20 transfer, and WETH unwrap. See [CHANGELOG.md](CHANGELOG.md#unreleased).

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
      **Bundle:** DeFi Real-World Fixtures
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

- [x] ✅ shipped 2026-05-01 (Unreleased) — Function selector golden vectors against `FunctionSelector.encode/1` [D:2/B:5/U:5 → Eff:2.5]
      Landed as `test/abi/function_selector_real_world_test.exs`. 12 explicit `ABI.method_id/1` golden-vector tests cover Aave V3, Compound V3, Lido (`uint256[]`), Curve 3pool (`uint256[3]`), Uniswap V3 (single tuple arg), Balancer V2 (multiple top-level tuples), EigenLayer (`tuple[]`), ERC-20 (`transfer`, plus `transferFrom` whose 4-byte selector is shared with ERC-721), and WETH. A second `describe` block round-trips the four tuple/`tuple[]`/fixed-array signatures through `FunctionSelector.decode/1 ∘ encode/1` and re-asserts the resulting selector — proving the canonical-signature serialization matches the spec. See [CHANGELOG.md](CHANGELOG.md#unreleased).

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
      **Bundle:** DeFi Real-World Fixtures
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

- [x] ✅ Empty-args calldata path coverage [D:1/B:2/U:3 → Eff:2.5]
      Tests added in `test/abi_test.exs` covering the `f()` shape (`weth.deposit()` / `rocket_pool.deposit()`): `ABI.encode("deposit()", []) == <<0xD0, 0xE3, 0x0D, 0xB0>>`, `ABI.decode("deposit()", <<>>) == []`, plus the `function: nil`/`types: []` empty-bytes shape. See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01).

- [ ] Deep struct nesting (depth ≥ 4) round-trip [D:2/B:4/U:4 → Eff:2.0] 🚀
      `roundtrip_property_test.exs` `composite/2` recursion is capped at depth 3 (line ~252 of the file). Pendle `swapExactTokenForPt` exercises depth 5: `args.input` (struct) contains `swapData` (struct) which contains `extCalldata` (bytes); the `limit` arg (struct) contains `normalFills` and `flashFills` (each `tuple[]`). Bumping `composite` depth to 5 is a one-line change; the failures (if any) it surfaces are real.

      Motivated by: `pendle_swap_token_for_pt` (`0xc81f847a`), `pendle_swap_token_for_yt` (`0xed48907e`), `pendle_add_liquidity` (`0x12599ac6`).
      **Bundle:** Property Suite Expansion
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

- [ ] Multiple top-level struct args [D:3/B:4/U:4 → Eff:1.33] 📋
      Roundtrip property test always wraps arguments as a single tuple or a single dynamic array. Real protocols often pass **multiple sibling structs** as separate top-level args (Balancer V2 `swap(SingleSwap, FundManagement, uint256, uint256)` is the canonical case — 4 top-level args of which 2 are structs). Add a generator that builds an arg list `[t1, t2, ...]` where 2+ entries are independently-generated structs. Catches head/tail offset arithmetic when sibling tuples are dynamic at different rates.

      Motivated by: `balancer_swap` (`0x52bbbe29`) — `swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)`.
      **Bundle:** Property Suite Expansion
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

- [ ] `tuple[]` (dynamic array of tuples) round-trip coverage [D:4/B:5/U:5 → Eff:1.25] 📋
      `roundtrip_property_test.exs` exercises dynamic arrays only with `uint256`/`address`/`string`/`bytes` element types (lines ~189–211). It never generates a `(T1, T2, …)[]` shape — but `tuple[]` is the canonical shape for batch-style DeFi calls. Real-world examples found:
      - EigenLayer `queueWithdrawals((address[],uint256[],address)[])` (`0x0dd8dd02`) — each element is itself dynamic (two array fields), so `head/tail` is computed per-element AND per-array.
      - Pendle `limit.normalFills` and `limit.flashFills` (both `(...)[]` fields nested inside a struct, typically empty `[]` in practice — see the empty-array edge case task below).

      Add a `value_for({:array, {:tuple, [...]}, :dynamic})` clause and a property that exercises `tuple_of(static_only)[]`, `tuple_of(mixed)[]`, and an empty `tuple[]`.
      **Bundle:** Property Suite Expansion
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
      **Bundle:** Property Suite Expansion
      **Docs:** CHANGELOG entry under `## [Unreleased]`.

**Out-of-scope findings (deliberately not proposed):**

- **`address payable` vs `address` collapse** — already tracked in `Test & Quality Debt` ("`address payable` vs `address` doc note"). `defi-skills` playbooks use `address` uniformly, so no new evidence to change the existing scoring.
- **`zero-length fixed array` — `T[0]` crash** — already tracked in `Bugs` (`dynamic?/1` crashes on zero-length fixed array). `defi-skills` uses `uint256[3]` not `uint256[0]`, so doesn't surface fresh evidence.
- **Pre-encoded `raw` bytes in `defi-skills`** (Fibrous, `eigenlayer_complete_withdrawal`) — bypass path, the playbook hands ABI-encoded blobs through `bytes` rather than re-encoding. Not an ABI pattern this library needs to handle.
- **Multi-tx sequences (approval + action)** — each tx is independently ABI-encoded; nothing for `hieroglyph` to do at the encoding layer.

---

## 🚀 Feature Gaps vs. Peer Libraries

- [x] ✅ `ABI.decode_call/3` + `ABI.method_id/1` [D:2/B:5/U:6 → Eff:2.75]
      Symmetric counterpart to `ABI.encode/2` for selector-prefixed calldata: `decode_call` strips and verifies the 4-byte selector, then routes the payload through the existing `decode/3` machinery; returns `{:ok, _}` or `{:error, :calldata_too_short | :selector_mismatch | :no_function_name}`. `decode/3` semantics unchanged (still payload-only, matches `eth-abi`/`ethers`/`viem`/`alloy`). `method_id/1` exposes the selector-derivation primitive (`keccak256(canonical_signature)[0..3]`). See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01).

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

The Bundle column maps each open item to its `📦 Bundles` membership (or `—` for standalone / already-shipped items). For bundled items the upstream-pitch position is per-item; bundles only constrain how this fork ships, not how upstream PRs are split — though the DeFi Fixtures and Property Suite bundles each map naturally to a single upstream "test coverage expansion" PR matching the bundle's shape.

| Item | Upstream PR candidate? | Bundle |
|---|---|---|
| Indexed dynamic event bug | ✅ Bug — file issue, then PR | — |
| `fixed`/`ufixed`/`function` parse-but-don't-encode | ✅ Bug — file issue | — |
| Lexer `x`-terminal shadowed by LETTERS (sub-bug of #54) | ⚠️ Bug — defer to a future batched upstream issue with PR offer | — |
| `encode_bytes/1` → `defp` | ✅ Hygiene — one-line PR | — |
| Map-input tests | ✅ Tests for recently-merged feature | — |
| Round-trip tests | ✅ Pure addition | — |
| Typespec + doc gaps | ✅ Same shape as #52 | — |
| README refresh | ✅ Docs-only | — |
| Padding dedup into `ABI.Math` | ✅ Shipped locally on `zenhive`, ready for upstream PR | — |
| Credo strict style cleanup | ✅ Shipped locally on `zenhive`, ready for upstream PR | — |
| `is_dynamic?` → `dynamic?` rename | ✅ Shipped locally on `zenhive`, ready for upstream PR (optional deprecation shim can be added during review) | — |
| `decode_event/4` error contract | ⚠️ Arguable breaking change — discuss first | — |
| `decode_call/3` + `method_id/1` | ✅ Pure addition — file as upstream feature PR | — |
| `encode_packed` | ⚠️ Feature — issue first | — |
| `decode_error/2` | ⚠️ Feature — issue first | — |
| `fixed`/`ufixed` / `function` implementations | ⚠️ Feature — confirm interest first | — |
| `address payable` vs `address` doc note | ✅ Docs — one-line PR | — |
| `decode_structs: true` atom bound | ⚠️ Hardening — discuss approach first (behavior change on opt-in path) | — |
| Phase 1: Descripex on `ABI` top-level | ❌ Fork-only — adds a runtime `:descripex` dep upstream maintainers haven't opted into; pitch only if they signal interest in the agent-economy pattern | 1.2.0 — Agent Economy |
| Phase 2: Descripex on remaining public modules | ❌ Fork-only — same `:descripex` dep concern as Phase 1 | 1.2.0 — Agent Economy |
| Phase 3: `mix hieroglyph.manifest` + hint-rot validation test | ❌ Fork-only — task name is `hieroglyph.manifest`; if Phase 1+2 ever upstream, the task would land as `abi.manifest` instead | 1.2.0 — Agent Economy |
| Real-world golden calldata fixtures from `defi-skills build` | ✅ Pure tests — shipped locally; combine with selector vectors into the upstream PR after #53/#54 responses land | DeFi Real-World Fixtures (shipped) |
| Function selector golden vectors against `FunctionSelector.encode/1` | ✅ Pure tests — shipped locally; combine with calldata fixtures into one upstream PR matching the bundle | DeFi Real-World Fixtures (shipped) |
| `tuple[]` (dynamic array of tuples) round-trip coverage | ✅ Pure tests — file the whole bundle as one "round-trip property suite expansion" upstream PR | Property Suite Expansion |
| Empty `bytes` / empty `tuple[]` inside struct fields | ✅ Pure tests — same upstream PR as the rest of the bundle | Property Suite Expansion |
| Multiple top-level struct args | ✅ Pure tests — same upstream PR as the rest of the bundle | Property Suite Expansion |
| Deep struct nesting (depth ≥ 4) round-trip | ✅ Pure tests — same upstream PR as the rest of the bundle | Property Suite Expansion |

Stale upstream issues worth courtesy-triaging (not opening, just noting): #17, #25, #32 all look fixed on current `main`.
