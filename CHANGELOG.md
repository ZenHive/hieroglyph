# [Unreleased]

# 1.1.0 - 2026-05-01

* **Bug fix (upstream [#55](https://github.com/exthereum/abi/issues/55)):** `ABI.TypeEncoder.encode_int/2` rejected ALL `int<N>` values (including `0`) for small bit widths, because the overflow guard mixed up bytes and bits — it compared `byte_size(significant_bytes)` against `desired_size_bytes - 1`, which evaluates to `0` for `int8`, raising on every input. Replaced with a numeric range check against `2^(N-1)` performed up-front, so the encoder accepts the full signed range `-2^(N-1)..2^(N-1)-1` for every `int<N>`. The pre-existing `"int overflow raises data overflow"` test passed only because the encoder was broken for any value; tightened the test to assert specific in-range values encode AND specific boundary cases (`128`, `-129`) raise.
* **Bug fix:** `ABI.FunctionSelector.dynamic?/1` raised `FunctionClauseError` on `{:array, T, 0}` (zero-length fixed array). The grammar accepts `T[0]` (yrl rule allows `N >= 0`), so the type is parseable, but the existing clauses required `len > 0` and no clause matched the zero case. Added `def dynamic?({:array, _type, 0}), do: false` — a zero-length fixed array has no head/tail layout and no payload, so it is static by any sensible definition. Encoder and decoder paths already handle zero-length arrays (`encode_type({:array, _, 0})` produces an empty repeated-type tuple; `decode_type({:array, _, 0}, data, _opts) -> {[], data}`); verified by extending `roundtrip_property_test.exs`'s fixed-array length domain from `1..3` to `0..3`. Pre-existing in upstream `exthereum/abi`; not yet filed.
* `ABI.FunctionSelector.@type type` now carries a `@typedoc` clarifying that `address payable` collapses to `:address`. Solidity's ABI JSON only emits `"address"` for both forms, the on-the-wire encoding is identical (20-byte left-padded), and payability is a property of `state_mutability` rather than a separate type variant — so consumers shouldn't expect a distinct atom.
* Added `test/abi/roundtrip_property_test.exs` — property-based `decode(encode(x)) == x` coverage using `stream_data` for every type in `ABI.FunctionSelector.@type type/0`: `uint`, `int`, `address`, `bool`, `string`, `bytes`, `bytesN`, fixed and dynamic arrays, and recursively nested tuples (depth ≤ 3). Per-type properties localize failures to a single clause; the recursive composite property exercises nested `{:tuple, [{:array, ...}]}` shapes where head/tail offsets matter. Surfaced the `encode_int` bug above on its first run. Test-only dep `{:stream_data, "~> 1.1"}` added.
* Test coverage for the empty-args calldata path (`f()` shape — 4-byte selector with zero ABI-encoded args). `weth.deposit()` (selector `0xd0e30db0`), `rocket_pool.deposit()`, and similar zero-arg calls were untested by the round-trip property suite (every generator produced at least one value). Pinned both directions: `ABI.encode("deposit()", []) == <<0xD0, 0xE3, 0x0D, 0xB0>>` and `ABI.decode("deposit()", <<>>) == []`, plus the `function: nil`/`types: []` empty-bytes shape.
* Test coverage for `FunctionSelector` selector-rendering and parser edge cases: `encode/1` canonical-signature rendering of `{:int, N}`, `{:struct, _, _, _}`, dead-via-parse types (`:function`, `{:fixed, M, N}`, `{:ufixed, M, N}`) and `nil`-typed slots (defensive against partially-built typeinfo maps); plus `parse_specification/1`'s `%{"indexed" => _}`-without-`"name"` branch (older Solidity versions and hand-written ABIs may omit names on indexed event params).
* **New API:** `ABI.method_id/1` returns the 4-byte function selector (`keccak256(canonical_signature)[0..3]`) for a signature string or `FunctionSelector` struct. Returns `<<>>` for selectors with `function: nil`. Previously the same logic was private to `ABI.TypeEncoder`; exposing it is a useful primitive for callers that need to compute selectors without encoding args (selector-table routing, log-topic matching, calldata pre-validation).
* **New API:** `ABI.decode_call/3` is the symmetric counterpart to `ABI.encode/2` for selector-prefixed calldata. Splits the 4-byte prefix, verifies it matches the expected selector, and decodes the payload via the existing `decode/3` machinery. Returns `{:ok, decoded}` on match or `{:error, reason}` for `:calldata_too_short` (< 4 bytes), `:selector_mismatch` (prefix wrong), or `:no_function_name` (selector has `function: nil`, so there's nothing to verify against — caller should use `decode/3` with the payload). `ABI.decode/3` semantics are unchanged: it remains payload-only, matching `eth-abi` / `ethers` / `viem` / `alloy` conventions.

# 1.0.0 - 2026-04-24

First hex.pm release as `hieroglyph`. This is a maintained fork of [exthereum/abi](https://github.com/exthereum/abi); the module namespace is unchanged (`ABI.encode/2`, `ABI.decode/2`, etc. — consumers just swap the hex dep name). Version resets to `1.0.0` under the new package name; the `1.0.0-alpha*` / `1.0.0-bravo1` lines below this entry are the upstream's pre-release history, carried forward for context but never published to hex under `hieroglyph`.

* **Published as `hieroglyph`** — hex package renamed from the internal `abi` app name. Top-level module `ABI` preserved (the Solidity term is the correct module name). Repo renamed to `ZenHive/hieroglyph`; upstream `exthereum/abi` tracked in the package's "Upstream (fork-of)" link.
* **Bug fix (upstream [#53](https://github.com/exthereum/abi/issues/53)):** `ABI.Event.decode_event/4` now returns `{:indexed_hash, <<32 bytes>>}` for indexed parameters of *reference* type (`string`, `bytes`, all arrays — fixed-size or dynamic — and tuples/structs) instead of silently misdecoding the keccak topic as if it were a raw ABI-encoded value. Per the Solidity ABI spec, indexed reference-type values are stored in topics as `keccak256(value)` and the original is unrecoverable — the tagged tuple preserves the hash (useful for log filtering and equality checks) and makes the "unrecoverable" signal pattern-matchable. This is broader than the ABI head/tail "dynamic" rule: `uint256[2]` and tuples of all-static members are *static* for regular ABI encoding but are still hashed in event topics, and this fix handles both. Breaking for callers that consumed the previous garbage bytes directly; static value-type indexed params (`uint`/`int`/`address`/`bool`/`bytesN`/`function`/`fixed`/`ufixed`) are unchanged. Regression tests added for indexed `string`, indexed `bytes`, indexed dynamic array, indexed fixed-size static array (`uint256[2]`), indexed tuple of static members, and mixed static+dynamic+non-indexed cases.
* **Bug fix (upstream [#54](https://github.com/exthereum/abi/issues/54)):** `fixed`, `ufixed`, and `function` types now raise `ArgumentError` at parse time (in `ABI.Parser.parse!/2`, walking nested arrays and tuples) with a link to the tracking issue, instead of parsing silently into unsupported internal terms and later raising the cryptic `"Unsupported encoding type"` inside `TypeEncoder` / `TypeDecoder`. Also filled the `{:bytes, pos_integer()}` gap in `ABI.FunctionSelector.@type type` — previously omitted even though fully supported by the encoder and decoder. Note: the explicit `fixed<M>x<N>` / `ufixed<M>x<N>` forms still raise a `FunctionClauseError` upstream of this walker due to a separate pre-existing lexer-rule-ordering bug (single `x` tokenizes as `letters` instead of the `'x'` terminal) — tracked as a follow-up task. Also aligned the grammar's bare-`fixed` / bare-`ufixed` canonical expansion to the Solidity spec (`fixed128x18` / `ufixed128x18`; previously `x19`) so the rejection error message reports the correct form.
* Simplified `ABI.Parser.parse!/2`'s unsupported-type walker to drop a dead `is_list(returns)` branch — the yecc grammar only emits `nil` or a single bare type for `returns`, never a list. No behavior change.
* Extracted the 32-byte padding logic into `ABI.Math.pad/4` and `ABI.Math.unpad/3`. `ABI.TypeEncoder.encode_bytes/1`, `encode_int/2`, and `encode_uint/2` now delegate to `ABI.Math.pad/4`; `ABI.TypeDecoder.decode_bytes/3` is a thin wrapper around `ABI.Math.unpad/3`. No behavior change; resolves the long-standing `TODO: add to ABI.Math` comments in both modules.
* Renamed `ABI.FunctionSelector.is_dynamic?/1` to `ABI.FunctionSelector.dynamic?/1` to satisfy `Credo.Check.Readability.PredicateFunctionNames`. The function remains `@doc false` (internal). No deprecation shim — the old name had `@doc false` since 2017 and zero in-repo references outside three private call-sites, which were updated.
* Drove `mix credo --strict` to zero violations (was 51). Covers `Design.AliasUsage` (top-of-module aliases added across `ABI`, `ABI.Event`, `ABI.FunctionSelector`, `ABI.Parser`, `ABI.TypeDecoder`, `ABI.TypeEncoder`, and `ABI.Hex`), `Readability.MaxLineLength` (spec / docstring wraps + the big `Enum.reduce` tuple-encoder broken into an `encode_tuple_element/2` helper), `Consistency.ParameterPatternMatching` (flipped three `record = %{…}` heads to `%{…} = record`), and `Refactor.Nesting` (extracted `ABI.Event.verify_event_signature/2` and `ABI.TypeEncoder.fetch_named_field/2` + `fetch_by_name/2` helpers to drop nesting below 3).
* Added regression tests for the map-input encoder path (`ABI.TypeEncoder.data_to_list/2`): atom-keyed maps, string-keyed maps, camelCase→snake_case name resolution, string-over-atom key priority, integer values inside nested named-struct maps, and the missing-field / unnamed-type error raises. The map branch previously had zero test coverage; the string-key path was added in commit `46accc8`, and this suite also exercises integer encoding (`a43e9d5`) through the map branch.
* Added `@spec` typespecs and `@doc` strings for every previously-undeclared public function across `ABI`, `ABI.Event`, `ABI.TypeDecoder`, `ABI.TypeEncoder`, and `ABI.FunctionSelector`: `ABI.event_signature/1`, `ABI.parse_specification/1`, `ABI.TypeDecoder.decode/3`, `ABI.TypeDecoder.tuple_value/3`, `ABI.TypeEncoder.encode_raw/2`, `ABI.Event.decode_event/4` / `event_signature/1` / `canonical/2`, and `ABI.FunctionSelector.decode/1` / `decode_raw/1` / `parse_specification_item/1` / `decode_type/1` / `encode/3`; also added docs for `TypeDecoder.tuple_value/3` and `TypeDecoder.decode_bytes/3`. Matches the style widened in PR #52. Doctor spec coverage 42% → 88%, doc coverage 88% → 96%.
* Added regression tests for eleven previously-uncovered error paths: `bool` with non-boolean values, `bytes<N>` size mismatches and wrong-datatype values, unsupported type atoms across encoder / decoder / function-selector, int/uint overflow, trailing decode data, and `decode_event/4` returns for mismatched event signatures and invalid topic counts.
* README refreshed: dropped the stale "tuples with multiple elements don't parse" caveat (false since JSON-ABI support), corrected `ABI.encode/2` arity and flipped `bytes<M>` to supported in the Support checklist, migrated dead `solidity.readthedocs.io` links to `docs.soliditylang.org`, and added runnable examples for `ABI.parse_specification/1`, `ABI.Event.decode_event/4`, and map/struct input to `encode/2`.

# 1.0.0-bravo1
* Fix ABI tuple encoding for nested inlined tuples
# 1.0.0-alpha9
* Add Names to Event Signatures
# 1.0.0-alpha8
* Add Event Signature check to ABI.Event.decode_event
* Change `decode_event` to return an {:ok, event_name, event_params} tuple.
* Add ability to add `"indexed"` keyword to ABI canonicals
# 1.0.0-alpha7
* Bugfix for event decoding with dynamic parameters
# 1.0.0-alpha6
* Bugfix for is_dynamic
# 0.1.15
* Properly treat all function encodes as tuple encodings
# 0.1.14
* Fix 0-length `type[]` encoding
# 0.1.13
* Drop dependency on exth crypto and move in functionality
# 0.1.12
* Fix `string` decoding to truncate on encountering NUL
* Fix some edge-cases in `tuple` encoding/decoding
# 0.1.11
* Add support for method ID calculation of all standard types
# 0.1.10
* Fix parsing of function names containing uppercase letters/digits/underscores
* Add support for `bytes<M>`
# 0.1.9
* Add support for parsing ABI specification documents (`.abi.json` files)
* Reimplement function signature parsing using a BNF grammar
* Fix potential stack overflow during encoding/decoding
# 0.1.8
* Fix ordering of elements in tuples
# 0.1.7
* Fix support for arrays of uint types
# 0.1.6
* Add public interface to raw function versions.
# 0.1.5
* Bugfix so that addresses are still left padded.
# 0.1.4
* Bugfix for tuples to properly handle tail pointer poisition.
# 0.1.3
* Bugfix for tuples to properly handle head/tail encoding
# 0.1.2
* Add support for tuples, fixed-length and variable length arrays
