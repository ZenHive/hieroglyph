# ABI Roadmap

**Vision:** Production-grade Solidity ABI encoder/decoder for Elixir, matching feature parity with `eth-abi` (Python), `ethers`/`viem` (JS), and `alloy` (Rust).

**Completed work:** see [CHANGELOG.md](CHANGELOG.md). Recent releases added struct/map input, integer encoding, string-key map support, Elixir 1.19 compat (through 1.2.0 + PR #52), and — in the Unreleased entries — map-input encoder tests, error-path tests, typespec/doc gap closure, and a README refresh.

**Scope of this roadmap:** findings from the 2026-04-24 review of v1.2.0 (post-#52). Some items will land as upstream PRs to `exthereum/abi`, some are fork-only polish.

**Task completion rule:** every task below names the docs it must update on completion (**Docs:** line). A task is not done until those doc updates land. At minimum, every task produces a CHANGELOG entry under `## [Unreleased]`; user-facing surface changes also update README; architectural or convention changes also update CLAUDE.md.

---

## 🎯 Current Focus

**1.4.0 shipped 2026-05-01** — atom-creation hardening on the `decode_structs: true` path. Both call sites (`ABI.TypeDecoder.tuple_value/3`, `ABI.TypeEncoder.fetch_by_name/2`) routed through `String.to_existing_atom/1`; `sobelow_skip` annotations removed. Decoder requires pre-interned field atoms with a clear migration message; encoder change is a silent safety upgrade (no observable behavior change). README grew a "Pre-interning atoms for `decode_structs: true`" subsection. The DoS surface (atom-table exhaustion via attacker-controlled ABI field names) is now closed. See [CHANGELOG.md](CHANGELOG.md#140---2026-05-01).

**1.3.0 shipped 2026-05-01** — solo-feature release: lifted the parse-time rejection on the Solidity `function` ABI type (24-byte external function pointer = 20-byte address ++ 4-byte selector). `ABI.encode("foo(function)", [<<24-byte payload>>])` now succeeds; `ABI.decode("foo(function)", payload)` returns the 24-byte binary; `function[]`, `function[N]`, and `(uint256, function)` work via the existing recursion; `ABI.encode_packed/2` accepts `function` (24 bytes tight per spec). `fixed`/`ufixed` stay deferred — Solidity itself does not fully support fixed-point types ([language docs](https://docs.soliditylang.org/en/latest/types.html): *"Fixed point numbers are not fully supported by Solidity yet"*) — so there's nothing real-world to encode against; README "Support" section explains the deferral inline. See [CHANGELOG.md](CHANGELOG.md#130---2026-05-01).

**1.2.0 shipped 2026-05-01** — bundled release combining two batches of work. **Agent Economy:** top-level `ABI` plus the five remaining public modules annotated with `api()` declarations, `Descripex.Discoverable` wired across the full surface, dedicated `mix hieroglyph.manifest [path]` task, and a hint-rot validation test (`test/abi/agent_economy_test.exs`) whose load-bearing cross-check asserts every non-framework export is declared with `api()`. **Public Surface Pass:** new public APIs `ABI.decode_error/2` (Solidity 0.8.4+ custom errors) and `ABI.encode_packed/2` (Solidity non-standard packed encoding for Merkle airdrop leaves and `keccak256(abi.encodePacked(...))` schemes); `decode_event/4` error contract narrowed from `{:error, term()}` to a closed atom-tagged set (`{:event_signature_mismatch, _}`, `{:topics_length_mismatch, _}`, `{:malformed_data, _}`); `encode_bytes/1` flipped from `def` to `defp`. Folded in the previously-Unreleased Property Suite Expansion + DeFi Real-World Fixtures bundles. Manifest emits 28 user-declared entries (was 25; +3 for `decode_error/2` on `ABI`, `encode_packed/2` on `ABI`, and `encode_packed/2` on `ABI.TypeEncoder`). See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

**1.1.0 shipped 2026-05-01** — patch-bumped from `1.0.0` to a minor release because two new public APIs were added (`ABI.method_id/1`, `ABI.decode_call/3`) alongside the bug fixes. See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01) for the full entry list.

Upstream bugs #53, #54, and #55 shipped locally; still awaiting maintainer response on the upstream issues. The lexer `x`-terminal-shadow bug (sub-bug of upstream #54, filing deferred to a future batched issue) also shipped in 1.2.0.

**Next direction:** no live standalone open work in the table. `fixed<M>x<N>` / `ufixed<M>x<N>` stay deferred (Solidity language limitation — see CHANGELOG 1.3.0 and README "Support"). Public-surface feature parity with `eth-abi` / `ethers` / `viem` / `alloy` is now closed. Maintenance posture from here: respond to upstream maintainer feedback on #53/#54/#55 + the queued combined-bug filings (lexer `x` sub-bug, `:string` NUL truncation, `decode_structs: true` DoS hardening from 1.4.0), and watch for new gaps surfaced by downstream consumer activity (cartouche / onchain) or new EIPs.

**Shipping units:** all release-bundles closed. No remaining open tasks.

---

## 📦 Bundles

Tasks grouped by shipping unit. A bundle ships as one PR / one release; member tasks share scope, files, or sourcing. Standalone tasks (no `**Bundle:**` annotation on the task itself) ship independently. Each member task keeps its own D/B/U score — the per-bundle "Avg Eff" below is a planning convenience, not a substitute.

### Bundle: Public Surface Pass ✅ shipped 2026-05-01
Four members in a single release: `decode_event/4` error contract narrowed (bugfix-honoring-typespec, atom-tagged closed error set), `encode_bytes/1` flipped to `defp` (hygiene), `ABI.decode_error/2` (new — Solidity 0.8.4+ custom errors), `ABI.encode_packed/2` (new — non-standard packed encoding). Combined with the previously-Unreleased Property Suite Expansion + DeFi Real-World Fixtures bundles into the 1.2.0 release. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

### Bundle: DeFi Real-World Fixtures ✅ shipped 1.2.0
Both members landed in a single tests-only commit. Inline `@fixtures` format chosen over the originally-proposed `test/fixtures/defi_calldata.exs` because no `.exs` data-loading idiom exists in the repo. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

### Bundle: Property Suite Expansion ✅ shipped 1.2.0
All four planned members landed. Sequencing held: `tuple[]` (member 1a) → empty fixtures (1b) → multi-arg (1c) → depth bump (1d). The mixed-element `tuple[]` property in 1a surfaced an 8-year-old upstream bug in `ABI.TypeDecoder.nul_terminate_string/1` (Solidity strings are length-prefixed UTF-8, not C strings) — fixed in production code as a fifth bundle member, with regression tests for leading/embedded/all-NUL strings. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

---

## 🐛 Bugs

| Task | Status | Location | Notes |
|---|---|---|---|
| **Indexed reference-type event parameters decoded wrong** | ✅ shipped 1.0.0 [upstream #53](https://github.com/exthereum/abi/issues/53) | `lib/abi/event.ex:146-172` | Fix shipped: indexed reference-type params (all arrays — fixed-size or dynamic — plus tuples, `string`, `bytes`) now return `{:indexed_hash, <<32 bytes>>}` via a local `reference_type?/1` predicate (matches the Solidity spec's "all complex types" event-indexing rule, which is broader than `FunctionSelector.dynamic?/1`'s head/tail-layout rule — `uint256[2]` and static-only tuples are static for regular encoding but still hashed in topics). Static value-type indexed params unchanged. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24). |
| **`fixed`/`ufixed`/`function` types parse but can't encode + typespec gaps** | ✅ shipped 1.0.0 [upstream #54](https://github.com/exthereum/abi/issues/54); `function` extended to full encode/decode in 1.3.0 | `lib/abi/parser.ex`, `lib/abi/function_selector.ex:9-19` | Fix shipped: parse-time rejection of `:function`, `{:fixed, M, N}`, `{:ufixed, M, N}` (including nested in arrays/tuples) in `ABI.Parser.parse!/2` with an `ArgumentError` linking to the upstream issue; `{:bytes, pos_integer()}` added to `@type type`. **1.3.0 lifted the `:function` rejection** — full encode/decode/packed support shipped (Solidity supports `function`); `fixed`/`ufixed` stay rejected per Solidity's own incomplete support. See [CHANGELOG.md](CHANGELOG.md#100---2026-04-24) and [CHANGELOG.md](CHANGELOG.md#130---2026-05-01). |
| **Lexer `x` terminal shadowed by LETTERS rule** | ✅ shipped 1.2.0 (upstream filing deferred — batched into a future combined-bugs issue) | `src/ethereum_abi_lexer.xrl`, `src/ethereum_abi_parser.yrl` | Fix shipped: dedicated `fixed_typename` / `ufixed_typename` terminals in the lexer so the `'x'` separator only appears in `fixed`/`ufixed` contexts; `'x'` rule moved before `{LETTERS}` so single `x` lexes as the terminal; parser gains `identifier_part -> 'x' \| fixed_typename \| ufixed_typename` so single-char `x` and the keyword forms still work as function/argument names. The explicit-M/N forms now route through `ABI.Parser.reject_unsupported!/1` and raise the same friendly `ArgumentError` (with upstream-#54 link) that bare `fixed`/`ufixed` already do. New shift/reduce count is 3 (was 1) — the 2 new conflicts resolve as shift, which is the desired behavior; documented inline in the `.yrl`. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01). |
| **`encode_bytes/1` accidentally public** | ✅ shipped 1.2.0 (Public Surface Pass bundle) | `lib/abi/type_encoder.ex` | Flipped `def` → `defp` and dropped the now-redundant `@doc false`. Function was already `@doc false`, had zero callers outside the module across the local monorepo, and was already excluded from the hint-rot validation test — so the "(breaking, if changed)" framing was overcautious; manifest user-declared count unchanged. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01). |
| **`decode_event/4` mixed raise + tagged-tuple contract** | ✅ shipped 1.2.0 (Public Surface Pass bundle) | `lib/abi/event.ex` | Bugfix-honoring-typespec: the existing `@spec` already declared `{:error, term()}`, but the runtime path raised on malformed payloads. Wrapped the `decode_raw`-driven payload decode in a `try/rescue` and converted exceptions into `{:error, {:malformed_data, _}}`; tightened `verify_event_signature/2` from string-formatted errors to atom-tagged `{:error, {:event_signature_mismatch, %{expected: _, got: _}}}`. Added `@type ABI.Event.decode_error/0` and narrowed `decode_event/4`'s `@spec` from `{:error, term()}` to the closed set; `api()` declaration carries an `errors:` block exposing the closed set in the manifest. Not a breaking change in any meaningful sense (the prior contract was unreachable for malformed payloads). See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01). |
| **`dynamic?/1` crashes on zero-length fixed array** | ✅ shipped 1.1.0 (no upstream issue yet) | `lib/abi/function_selector.ex:484` | One-line fix shipped: `def dynamic?({:array, _type, 0}), do: false`. Encoder/decoder paths already handle zero-length arrays correctly — verified by extending `roundtrip_property_test.exs`'s fixed-array length domain to `0..3`. Pre-existing in upstream `exthereum/abi`; not yet filed (consider folding with the lexer-rule-ordering fix into a single PR). See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01). |
| **`encode_int/2` byte-vs-bit overflow guard rejected ALL `int<N>`** | ✅ shipped 1.1.0 [upstream #55](https://github.com/exthereum/abi/issues/55) | `lib/abi/type_encoder.ex:382-401` | Surfaced by the round-trip property suite on first run. The overflow guard compared `byte_size(significant_bytes)` against `desired_size_bytes - 1`, which is `0` for `int8` — so even encoding `0` raised. Replaced with a numeric range check against `2^(N-1)` performed up-front, so the encoder accepts the full signed range `-2^(N-1)..2^(N-1)-1` for every `int<N>`. The pre-existing `"int overflow raises data overflow"` test passed only because the encoder was broken for any value; tightened to assert specific in-range values encode AND specific boundary cases (`128`, `-129`) raise. Filed upstream 2026-05-01 — awaiting maintainer response. See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01). |
| **`:string` decode silently truncated at first NUL byte** | ✅ shipped 1.2.0 — upstream filing pending (batch with #53/#54/#55 follow-up) | `lib/abi/type_decoder.ex:295-298` | Surfaced by the new mixed-element `tuple[]` property in the Property Suite Expansion bundle. The `:string` decode clause called a `nul_terminate_string/1` helper that split the decoded binary at the first `<<0>>` byte and returned only the prefix — treating Solidity strings as C strings. Solidity strings are length-prefixed UTF-8 and may legally contain NUL codepoints (`U+0000`); `decode_bytes/3 → Math.unpad/3` already returns exactly the right length, so the post-strip was both wrong and unnecessary. Fix: removed the helper entirely; `:string` decode now delegates straight to `decode_bytes(rest, length, :right)`. Pre-existing in upstream `exthereum/abi` since 2018 (commit `bdceb719`); undetected because random `StreamData.string(:utf8, ...)` rarely starts with NUL and most real Solidity strings (function names, error messages) don't either. Production paths affected: `ABI.decode/3`, `ABI.decode_call/3`, `ABI.decode_event/4`, `ABI.TypeDecoder.decode/3`. Three regression unit tests added (leading-NUL, embedded-NUL, all-NULs strings). See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01). |

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

- [x] ✅ Bound atom creation in `decode_structs: true` path [D:3/B:4/U:3 → Eff:1.17] — shipped 1.4.0
      Both call sites (`ABI.TypeDecoder.tuple_value/3` and `ABI.TypeEncoder.fetch_by_name/2`) now route through `String.to_existing_atom/1` — `sobelow_skip ["DOS.StringToAtom"]` annotations removed. Decoder requires snake_case field atoms to already exist in the VM atom table; new private helper `atom_key_for!/1` re-raises `ArgumentError` with a migration hint naming both the underscored atom and the original ABI field name. Encoder change is silent safety upgrade (the atom is only used for `Map` lookup; consumer maps can only contain pre-existing atoms anyway). Picked option (a) from the planted scoring; rejected (b) per-selector atom budget and (c) per-process cap as API-surface bloat that preserves the footgun. No benchee dep added — same hash-table lookup as `String.to_atom` on the hit path; benchmarking deferred until a workload regression surfaces. Version bumped 1.3.0 → 1.4.0 (behavior change on an opt-in path; not breaking the wire format or default decoder). Upstream filing pending — describes the DoS surface and proposes either the same `to_existing_atom` switch or a `decode_structs: :existing_atoms` opt-in for back-compat. See [CHANGELOG.md](CHANGELOG.md#140---2026-05-01).

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

- [x] ✅ shipped 1.2.0 — Real-world golden calldata fixtures from `defi-skills build` [D:3/B:6/U:6 → Eff:2.0]
      Landed as `test/abi/defi_calldata_test.exs` — 10 round-trip golden vectors captured via `defi-skills build --action <name> --json` (defi-skills v0.3.0). Format chosen: inline `@fixtures` module attribute (the `test/fixtures/defi_calldata.exs` proposal was discarded — no `.exs` data-loading idiom exists in the repo and inline matches the existing convention). Each fixture asserts both directions: `ABI.encode(sig, args)` reproduces the locked calldata exactly, and `ABI.decode_call(sig, calldata)` round-trips back to the original args. Covers Aave V3 supply/borrow/setCollateral, Compound V3 supply/claim, Lido stake/unstake (exercising `uint256[]` head/tail layout), EigenLayer deposit, ERC-20 transfer, and WETH unwrap. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

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

- [x] ✅ shipped 1.2.0 — Function selector golden vectors against `FunctionSelector.encode/1` [D:2/B:5/U:5 → Eff:2.5]
      Landed as `test/abi/function_selector_real_world_test.exs`. 12 explicit `ABI.method_id/1` golden-vector tests cover Aave V3, Compound V3, Lido (`uint256[]`), Curve 3pool (`uint256[3]`), Uniswap V3 (single tuple arg), Balancer V2 (multiple top-level tuples), EigenLayer (`tuple[]`), ERC-20 (`transfer`, plus `transferFrom` whose 4-byte selector is shared with ERC-721), and WETH. A second `describe` block round-trips the four tuple/`tuple[]`/fixed-array signatures through `FunctionSelector.decode/1 ∘ encode/1` and re-asserts the resulting selector — proving the canonical-signature serialization matches the spec. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

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

- [x] ✅ shipped 1.2.0 — Deep struct nesting (depth ≥ 4) round-trip [D:2/B:4/U:4 → Eff:2.0]
      Bumped `composite` property's `type_and_value_gen(3)` cap to depth 5; raised the property's `@tag timeout` from 120s to 300s to absorb the larger generation surface; added `max_runs: 50` (down from default 100) so deep samples have higher information-density without ballooning CI time. Depth-5 trees passed cleanly — no production failures surfaced from this member alone (the string-NUL bug below was surfaced by member 1a's mixed-element `tuple[]` property, not by the depth bump). See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

- [x] ✅ shipped 1.2.0 — Multiple top-level struct args [D:3/B:4/U:4 → Eff:1.33]
      Added a `roundtrip_args/2` helper alongside the single-arg `roundtrip/2`. New property mirrors the Balancer V2 `swap(SingleSwap, FundManagement, uint256, uint256)` shape — two sibling structs of differing dynamic-rate (one mixed static+dynamic, one static-only) plus two scalar args at the ends. Exercises sibling-tuple offset arithmetic when adjacent top-level tuples are dynamic at different rates. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

- [x] ✅ shipped 1.2.0 — `tuple[]` (dynamic array of tuples) round-trip coverage [D:4/B:5/U:5 → Eff:1.25]
      The existing `value_for/1` dispatcher already composed `{:array, inner}` with `{:tuple, ...}`, so no new generator clause was needed (the roadmap planting note proposed a new `value_for({:array, {:tuple, [...]}, :dynamic})` clause but `:dynamic` is not how this codebase represents dynamic arrays — they're just `{:array, inner}` at depth-2). What was missing was explicit pin-down via three properties: a static-only-element `tuple[]`, a mixed-element `tuple[]` where each element is itself dynamic (the most stress-testing shape), and an empty `tuple[]` unit test. The mixed-element property surfaced the 8-year-old `nul_terminate_string/1` bug in `ABI.TypeDecoder` on its first run — see new entry in `🐛 Bugs` table. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

- [x] ✅ shipped 1.2.0 — Empty `bytes` and empty `tuple[]` inside struct fields [D:3/B:5/U:4 → Eff:1.5]
      Added explicit unit tests (not properties) for the four pinned shapes: `(bytes, string)` with empty bytes and non-empty string, `(bytes, bytes)` both empty, empty `tuple[]` as the only dynamic field in a struct, and empty `tuple[]` followed by non-empty bytes. Inline `test "..." do` blocks (not the `@fixtures` pattern from `defi_calldata_test.exs`) — round-trip equality is enough; locking against synthetic byte strings would be overkill given the property tests already exercise the layout invariants. See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

**Out-of-scope findings (deliberately not proposed):**

- **`address payable` vs `address` collapse** — already tracked in `Test & Quality Debt` ("`address payable` vs `address` doc note"). `defi-skills` playbooks use `address` uniformly, so no new evidence to change the existing scoring.
- **`zero-length fixed array` — `T[0]` crash** — already tracked in `Bugs` (`dynamic?/1` crashes on zero-length fixed array). `defi-skills` uses `uint256[3]` not `uint256[0]`, so doesn't surface fresh evidence.
- **Pre-encoded `raw` bytes in `defi-skills`** (Fibrous, `eigenlayer_complete_withdrawal`) — bypass path, the playbook hands ABI-encoded blobs through `bytes` rather than re-encoding. Not an ABI pattern this library needs to handle.
- **Multi-tx sequences (approval + action)** — each tx is independently ABI-encoded; nothing for `hieroglyph` to do at the encoding layer.

---

## 🚀 Feature Gaps vs. Peer Libraries

- [x] ✅ `ABI.decode_call/3` + `ABI.method_id/1` [D:2/B:5/U:6 → Eff:2.75]
      Symmetric counterpart to `ABI.encode/2` for selector-prefixed calldata: `decode_call` strips and verifies the 4-byte selector, then routes the payload through the existing `decode/3` machinery; returns `{:ok, _}` or `{:error, :calldata_too_short | :selector_mismatch | :no_function_name}`. `decode/3` semantics unchanged (still payload-only, matches `eth-abi`/`ethers`/`viem`/`alloy`). `method_id/1` exposes the selector-derivation primitive (`keccak256(canonical_signature)[0..3]`). See [CHANGELOG.md](CHANGELOG.md#110---2026-05-01).

- [x] ✅ `ABI.encode_packed/2` support [D:7/B:8/U:6 → Eff:1.0] — shipped 1.2.0 (Public Surface Pass bundle)
      Solidity's [non-standard packed encoding](https://docs.soliditylang.org/en/stable/abi-spec.html#non-standard-packed-mode). Implemented per spec: types <32 bytes concatenate tight (no padding); dynamic types (`bytes`, `string`) inline as raw payload (no length prefix); array elements pad to 32 bytes (or 32-byte multiples for `string`/`bytes`); tuples/structs and nested arrays raise `ArgumentError` with a spec link. Wrapper accepts the same polymorphic first arg as `encode/2`. Cross-checked against the canonical spec example and a Merkle-leaf golden vector (`address ++ uint256` → 52 bytes pre-hash). See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

- [x] ✅ `ABI.decode_error/2` helper [D:4/B:6/U:7 → Eff:1.63] — shipped 1.2.0 (Public Surface Pass bundle)
      Decodes Solidity 0.8.4+ custom-error revert data: matches first-4-byte selector against a list of known error definitions (signature strings or pre-parsed `FunctionSelector` structs, mixed accepted), decodes the payload of whichever matches first. Returns `{:ok, %{error: name, args: [...]}}` on match, `{:error, :no_match}` when no definition matches (or list empty), `{:error, :calldata_too_short}` on `<4` bytes. Mirrors `decode_call/3`'s contract; malformed payload after a selector match still raises (same as `decode/3`). See [CHANGELOG.md](CHANGELOG.md#120---2026-05-01).

- [x] ✅ Implement `function` type encode/decode [D:2/B:5/U:5 → Eff:2.5] — shipped 1.3.0
      24-byte address+selector type. Lifted upstream #54's parse-time rejection for `:function` (`fixed`/`ufixed` stay deferred per the Solidity-language reason — see README "Why `fixed<M>x<N>` / `ufixed<M>x<N>` are deferred"). One encoder clause, one decoder clause, one packed-encoder clause; reused `encode_bytes/1` (right-pad to 32) and `decode_bytes/3` (unpad via `Math.unpad`). `function[]`, `function[N]`, and `(uint256, function)` work via existing recursion. See [CHANGELOG.md](CHANGELOG.md#130---2026-05-01).

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
| `encode_bytes/1` → `defp` | ✅ Hygiene — shipped 1.2.0; one-line PR ready (combine with the `decode_event/4` contract narrow into a single bug/hygiene upstream PR) | 1.2.0 — Public Surface Pass (shipped) |
| Map-input tests | ✅ Tests for recently-merged feature | — |
| Round-trip tests | ✅ Pure addition | — |
| Typespec + doc gaps | ✅ Same shape as #52 | — |
| README refresh | ✅ Docs-only | — |
| Padding dedup into `ABI.Math` | ✅ Shipped locally on `zenhive`, ready for upstream PR | — |
| Credo strict style cleanup | ✅ Shipped locally on `zenhive`, ready for upstream PR | — |
| `is_dynamic?` → `dynamic?` rename | ✅ Shipped locally on `zenhive`, ready for upstream PR (optional deprecation shim can be added during review) | — |
| `decode_event/4` error contract | ✅ Bugfix-honoring-typespec — shipped 1.2.0; pair with `encode_bytes/1 → defp` in a single bug/hygiene upstream PR | 1.2.0 — Public Surface Pass (shipped) |
| `decode_call/3` + `method_id/1` | ✅ Pure addition — file as upstream feature PR | — |
| `encode_packed` | ✅ Feature — shipped 1.2.0; combine with `decode_error/2` in a single feature upstream PR (spec-citing test vectors included) | 1.2.0 — Public Surface Pass (shipped) |
| `decode_error/2` | ✅ Feature — shipped 1.2.0; combine with `encode_packed` in a single feature upstream PR | 1.2.0 — Public Surface Pass (shipped) |
| `function` implementation | ✅ Feature — shipped 1.3.0; standalone upstream PR (independent of #53/#54/#55 follow-ups) | 1.3.0 — `function` type (shipped) |
| `fixed`/`ufixed` implementations | ⚠️ Feature — deferred (Solidity itself does not fully support fixed-point types — no real-world contracts emit them); reconsider if upstream Solidity work or a downstream consumer surfaces a concrete need | — |
| `address payable` vs `address` doc note | ✅ Docs — one-line PR | — |
| `decode_structs: true` atom bound | ⚠️ Hardening — shipped 1.4.0; upstream issue pending. Discuss approach first (behavior change on opt-in path); maintainers may prefer a `decode_structs: :existing_atoms` opt-in over the same `to_existing_atom` switch. | — |
| Phase 1: Descripex on `ABI` top-level | ❌ Fork-only — adds a runtime `:descripex` dep upstream maintainers haven't opted into; pitch only if they signal interest in the agent-economy pattern | 1.2.0 — Agent Economy |
| Phase 2: Descripex on remaining public modules | ❌ Fork-only — same `:descripex` dep concern as Phase 1 | 1.2.0 — Agent Economy |
| Phase 3: `mix hieroglyph.manifest` + hint-rot validation test | ❌ Fork-only — task name is `hieroglyph.manifest`; if Phase 1+2 ever upstream, the task would land as `abi.manifest` instead | 1.2.0 — Agent Economy |
| Real-world golden calldata fixtures from `defi-skills build` | ✅ Pure tests — shipped locally; combine with selector vectors into the upstream PR after #53/#54 responses land | DeFi Real-World Fixtures (shipped) |
| Function selector golden vectors against `FunctionSelector.encode/1` | ✅ Pure tests — shipped locally; combine with calldata fixtures into one upstream PR matching the bundle | DeFi Real-World Fixtures (shipped) |
| `tuple[]` (dynamic array of tuples) round-trip coverage | ✅ Pure tests — file the whole bundle as one "round-trip property suite expansion" upstream PR | Property Suite Expansion (shipped) |
| Empty `bytes` / empty `tuple[]` inside struct fields | ✅ Pure tests — same upstream PR as the rest of the bundle | Property Suite Expansion (shipped) |
| Multiple top-level struct args | ✅ Pure tests — same upstream PR as the rest of the bundle | Property Suite Expansion (shipped) |
| Deep struct nesting (depth ≥ 4) round-trip | ✅ Pure tests — same upstream PR as the rest of the bundle | Property Suite Expansion (shipped) |
| `:string` decode silently truncated at first NUL byte | ✅ Bug — file as a fourth upstream issue alongside #53/#54/#55 (or batch with the lexer `x` sub-bug); affects every `exthereum/abi` consumer that decodes user-supplied strings | Property Suite Expansion (shipped) — surfaced by member 1a's mixed-element `tuple[]` property |

Stale upstream issues worth courtesy-triaging (not opening, just noting): #17, #25, #32 all look fixed on current `main`.
