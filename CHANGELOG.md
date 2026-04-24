# [Unreleased]
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
