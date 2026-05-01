# Hieroglyph — Ethereum ABI for Elixir

[![Hex.pm](https://img.shields.io/hexpm/v/hieroglyph.svg)](https://hex.pm/packages/hieroglyph)
[![HexDocs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/hieroglyph)

The [Application Binary Interface](https://docs.soliditylang.org/en/latest/abi-spec.html) (ABI) of Solidity describes how to transform binary data to types which the Solidity programming language understands. For instance, if we want to call a function `bark(uint32,bool)` on a Solidity-created contract `contract Dog`, what `data` parameter do we pass into our Ethereum transaction? This project allows us to encode such function calls.

## About this package

`hieroglyph` is a maintained fork of [exthereum/abi](https://github.com/exthereum/abi) that ships bugfixes and Elixir 1.19+ compatibility ahead of upstream. **The module namespace is unchanged:** consumers still call `ABI.encode/2`, `ABI.decode/2`, `ABI.parse_specification/1`, etc. Only the hex package name differs. See [exthereum/abi#53](https://github.com/exthereum/abi/issues/53), [#54](https://github.com/exthereum/abi/issues/54), and [#55](https://github.com/exthereum/abi/issues/55) for the fork-motivating bug reports filed upstream.

## Installation

The package can be installed by adding `hieroglyph` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:hieroglyph, "~> 1.0"}
  ]
end
```

Docs are published on [HexDocs](https://hexdocs.pm/hieroglyph).

## Usage

### Encoding

To encode a function call, pass the ABI spec and the data to pass in to `ABI.encode/2`.

```elixir
iex> ABI.encode("baz(uint,address)", [50, <<1::160>> |> :binary.decode_unsigned])
<<162, 145, 173, 214, 0, 0, 0, 0, 0, 0, 0, 0, ...>
```

Then, you can construct an Ethereum transaction with that data, e.g.

```elixir
# Blockchain comes from `Exthereum.Blockchain`, see below.
iex> %Blockchain.Transaction{
...> # ...
...> data: <<162, 145, 173, 214, 0, 0, 0, 0, 0, 0, 0, 0, ...>
...> }
```

That transaction can then be sent via JSON-RPC or DevP2P to execute the given function.

### Decoding

Decode is generally the opposite of encoding, though we generally leave off the function signature from the start of the data. E.g. from above:

```elixir
iex> ABI.decode("baz(uint,address)", "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
[50, <<1::160>> |> :binary.decode_unsigned]
```

### Computing method IDs and decoding selector-prefixed calldata

`ABI.method_id/1` returns the 4-byte function selector (`keccak256(canonical_signature)[0..3]`) — useful for selector-table routing, log-topic matching, or pre-validating calldata without decoding args. Accepts a signature string or a `FunctionSelector` struct.

```elixir
iex> ABI.method_id("transfer(address,uint256)") |> Base.encode16(case: :lower)
"a9059cbb"

iex> ABI.method_id("deposit()") |> Base.encode16(case: :lower)
"d0e30db0"
```

`ABI.decode_call/3` is the symmetric counterpart to `ABI.encode/2` for selector-prefixed calldata: it strips and verifies the 4-byte prefix, then decodes the payload. `ABI.decode/3` remains payload-only — use `decode_call/3` when the input still has its method-ID prefix (raw transaction `data` from a node), and `decode/3` for return values or selector-routed payloads.

```elixir
iex> calldata = ABI.encode("transfer(address,uint256)", [<<1::160>>, 100])
iex> ABI.decode_call("transfer(address,uint256)", calldata)
{:ok, [<<1::160>>, 100]}

iex> ABI.decode_call("transfer(address,uint256)", <<0xde, 0xad, 0xbe, 0xef>>)
{:error, :selector_mismatch}

iex> ABI.decode_call("transfer(address,uint256)", <<0xa9, 0x05>>)
{:error, :calldata_too_short}
```

Returns `{:ok, decoded}` on selector match, or `{:error, :calldata_too_short | :selector_mismatch | :no_function_name}`. A malformed payload after a valid selector still raises — same contract as `decode/3`.

### Parsing a JSON ABI file

Full contract ABIs from `solc` / Foundry / Hardhat can be fed straight into `ABI.parse_specification/1` after decoding the JSON. Non-function entries (constructors) are skipped; function, fallback, receive, event, and custom-error entries are all returned as `ABI.FunctionSelector` structs.

```elixir
iex> File.read!("priv/dog.abi.json")
...> |> Jason.decode!()
...> |> ABI.parse_specification()
...> |> Enum.find(&(&1.function == "bark"))
%ABI.FunctionSelector{function: "bark", function_type: :function, ...}
```

Each returned selector carries its `function_type` (`:function`, `:constructor`, `:fallback`, `:receive`, `:event`, or `:error`), so you can filter the parsed list by shape when a single ABI mixes all of them.

### Decoding event logs

Event logs arrive as `{data, topics}` pairs from the JSON-RPC node. `ABI.decode_event/4` (or the lower-level `ABI.Event.decode_event/4`) splits indexed parameters out of the topics and decodes non-indexed parameters from the data blob. By default it verifies that `topics[0]` matches the keccak256 of the event signature; pass `check_event_signature: false` to skip that check when decoding anonymous events or when `topics` intentionally omits the signature slot.

```elixir
iex> hex = &Base.decode16!(&1, case: :lower)
iex> ABI.decode_event(
...>   "Transfer(address indexed from, address indexed to, uint256 amount)",
...>   hex.("00000000000000000000000000000000000000000000000000000004a817c800"),
...>   [
...>     hex.("ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"),
...>     hex.("000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8"),
...>     hex.("0000000000000000000000007795126b3ae468f44c901287de98594198ce38ea")
...>   ]
...> )
{:ok, "Transfer",
 %{
   "amount" => 20_000_000_000,
   "from" => <<0xb2, 0xb7, 0xc1, 0x79, 0x5f, 0x19, 0xfb, 0xc2, 0x8f, 0xda, 0x77, 0xa9, 0x5e, 0x59, 0xed, 0xbb, 0x8b, 0x37, 0x09, 0xc8>>,
   "to"   => <<0x77, 0x95, 0x12, 0x6b, 0x3a, 0xe4, 0x68, 0xf4, 0x4c, 0x90, 0x12, 0x87, 0xde, 0x98, 0x59, 0x41, 0x98, 0xce, 0x38, 0xea>>
 }}
```

### Map and struct input to `encode/2`

For tuple/struct parameters whose `:name` is known (i.e. parsed from a JSON ABI, or declared in a `FunctionSelector` literal), `ABI.encode/2` accepts a plain `Map` in place of the raw tuple. Both atom keys and string keys are resolved, with camelCase ABI names auto-mapped to their snake_case atom form. The output is identical to the tuple-shaped input — useful when the encoded parameters originated from a prior `ABI.decode/3` call with `decode_structs: true`, or from Jason-decoded request payloads.

```elixir
iex> selector = %ABI.FunctionSelector{
...>   function: nil,
...>   types: [%{type: {:tuple, [
...>     %{name: "recipient", type: :address},
...>     %{name: "amount",    type: {:uint, 256}}
...>   ]}}]
...> }
iex> ABI.encode(selector, [%{recipient: <<1::160>>, amount: 1_000}])
...> ==
...>   ABI.encode(selector, [{<<1::160>>, 1_000}])
true
```

## Agent Integration

`hieroglyph` is annotated with [`descripex`](https://hex.pm/packages/descripex) so its public surface is discoverable at runtime and emittable as a static manifest. The intended consumer is downstream codegen / agent tooling — `cartouche`-generated contract bindings, `onchain*` packages, and any catalog that needs to verify or list ABI primitives — not human readers (use the regular hexdocs for that).

Progressive discovery via `ABI.describe/0..2`:

```elixir
ABI.describe()                 # Level 1: all annotated modules with namespaces
ABI.describe(:abi)             # Level 2: function list for the top-level ABI module
ABI.describe(:abi, :encode)    # Level 3: full hints — params, returns, errors, spec
```

Direct module introspection:

```elixir
ABI.__api__()                  # list of %{name, arity, hints, spec, ...} entries
ABI.__api__(:encode)           # one entry by name
```

Static manifest emission (JSON-serializable representation of every annotated function — params, returns, errors, specs, descriptions):

```bash
mix descripex.manifest --app hieroglyph --pretty --output api_manifest.json
```

The manifest is suitable for downstream CI to diff across `hieroglyph` version bumps as a contract-stability check — silent contract drift in this library propagates as compile errors through cartouche-generated bindings into every onchain consumer. A dedicated `mix hieroglyph.manifest` task ships in 1.2.0 alongside this section (see CHANGELOG).

## Support

Currently supports:

  * [X] `uint<M>`
  * [X] `int<M>`
  * [X] `address`
  * [X] `uint`
  * [X] `bool`
  * [ ] `fixed<M>x<N>`
  * [ ] `ufixed<M>x<N>`
  * [ ] `fixed`
  * [X] `bytes<M>`
  * [ ] `function`
  * [X] `<type>[M]`
  * [X] `bytes`
  * [X] `string`
  * [X] `<type>[]`
  * [X] `(T1,T2,...,Tn)`

Round-trip safety — `decode(encode(x)) == x` — is property-tested with `stream_data` across every supported type above, including recursively nested tuples and fixed/dynamic arrays.

Types marked `[ ]` above are recognized by the ABI grammar but not implemented by this library. `ABI.FunctionSelector.decode/1`, `ABI.FunctionSelector.decode_type/1`, and `ABI.parse_specification/1` raise `ArgumentError` at parse time when a signature contains them (including nested in arrays or tuples, and the explicit `fixed<M>x<N>` / `ufixed<M>x<N>` forms), pointing at [exthereum/abi#54](https://github.com/exthereum/abi/issues/54) for tracking.

# Docs

* [Solidity ABI](https://docs.soliditylang.org/en/latest/abi-spec.html)
* [Solidity Docs](https://docs.soliditylang.org/)
* [Solidity Grammar](https://github.com/ethereum/solidity/blob/develop/docs/grammar.txt)
* [Exthereum Blockchain](https://github.com/exthereum/blockchain)

# Collaboration

MIT-licensed. Issues and PRs welcome at [ZenHive/hieroglyph](https://github.com/ZenHive/hieroglyph/issues). Upstream bugs affecting Solidity ABI semantics are also filed at [exthereum/abi](https://github.com/exthereum/abi/issues) — see `CHANGELOG.md` for cross-references.
