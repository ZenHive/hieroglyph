defmodule ABI do
  @moduledoc """
  Documentation for ABI, the function interface language for Solidity.
  Generally, the ABI describes how to take binary Ethereum and transform
  it to or from types that Solidity understands.
  """

  alias ABI.Event
  alias ABI.FunctionSelector
  alias ABI.Math
  alias ABI.Parser
  alias ABI.TypeDecoder
  alias ABI.TypeEncoder

  @doc """
  Encodes the given data into the function signature or tuple signature.

  In place of a signature, you can also pass one of the `ABI.FunctionSelector` structs returned from `parse_specification/1`.

  ## Examples

      iex> ABI.encode("(uint256)", [{10}])
      ...> |> Base.encode16(case: :lower)
      "000000000000000000000000000000000000000000000000000000000000000a"

      iex> ABI.encode("baz(uint,address)", [50, <<1::160>>])
      ...> |> Base.encode16(case: :lower)
      "a291add600000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> ABI.encode("price(string)", ["BAT"])
      ...> |> Base.encode16(case: :lower)
      "fe2c6198000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000034241540000000000000000000000000000000000000000000000000000000000"

      iex> ABI.encode("baz(uint8)", [9999])
      ** (RuntimeError) Data overflow encoding uint, data `9999` cannot fit in 8 bits

      iex> ABI.encode("(uint,address)", [{50, <<1::160>>}])
      ...> |> Base.encode16(case: :lower)
      "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001"

      iex> ABI.encode("(string)", [{"Ether Token"}])
      ...> |> Base.encode16(case: :lower)
      "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000"

      iex> ABI.encode("((uint256,uint256),string)", [{{0x11, 0x22}, "Ether Token"}])
      ...> |> Base.encode16(case: :lower)
      "000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000"

      iex> ABI.encode("((uint256,(uint256,uint256)),string)", [{{0x11, {0x22, 0x33}}, "Ether Token"}])
      ...> |> Base.encode16(case: :lower)
      "0000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000330000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000"

      iex> ABI.encode("(string)", [{String.duplicate("1234567890", 10)}])
      ...> |> Base.encode16(case: :lower)
      "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000643132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393000000000000000000000000000000000000000000000000000000000"

      iex> File.read!("priv/dog.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification
      ...> |> Enum.find(&(&1.function == "bark")) # bark(address,bool)
      ...> |> ABI.encode([<<1::160>>, true])
      ...> |> Base.encode16(case: :lower)
      "b85d0bd200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001"
  """
  @spec encode(binary() | FunctionSelector.t(), [any()]) :: binary()
  def encode(function_signature, data) when is_binary(function_signature) do
    encode(Parser.parse!(function_signature), data)
  end

  def encode(%FunctionSelector{} = function_selector, data) do
    TypeEncoder.encode(data, function_selector)
  end

  @doc """
  Returns the 4-byte function selector (method ID) for a function signature.

  The selector is `keccak256(canonical_signature)` truncated to its first 4
  bytes. Returns `<<>>` for selectors with no `function` name (anonymous /
  raw-tuple selectors used for return-value decoding).

  ## Examples

      iex> ABI.method_id("transfer(address,uint256)") |> Base.encode16(case: :lower)
      "a9059cbb"

      iex> ABI.method_id("deposit()") |> Base.encode16(case: :lower)
      "d0e30db0"

      iex> ABI.method_id(%ABI.FunctionSelector{function: "deposit", types: []}) |> Base.encode16(case: :lower)
      "d0e30db0"

      iex> ABI.method_id(%ABI.FunctionSelector{function: nil, types: [%{type: {:uint, 256}}]})
      ""
  """
  @spec method_id(binary() | FunctionSelector.t()) :: binary()
  def method_id(signature) when is_binary(signature) do
    method_id(Parser.parse!(signature))
  end

  def method_id(%FunctionSelector{function: nil}), do: <<>>

  def method_id(%FunctionSelector{} = function_selector) do
    <<id::binary-size(4), _::binary>> =
      function_selector
      |> FunctionSelector.encode()
      |> Math.kec()

    id
  end

  @doc """
  Decodes the given data based on the function or tuple
  signature.

  In place of a signature, you can also pass one of the `ABI.FunctionSelector` structs returned from `parse_specification/1`.

  ## Examples

      iex> ABI.decode("baz(uint,address)", "00000000000000000000000000000000000000000000000000000000000000320000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      [50, <<1::160>>]

      iex> ABI.decode("(address[])", "00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [[]]

      iex> ABI.decode("(uint256)", "000000000000000000000000000000000000000000000000000000000000000a" |> Base.decode16!(case: :lower))
      [10]

      iex> ABI.decode("(string)", "0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      ["Ether Token"]

      iex> ABI.decode("((uint256,uint256),string)", "000000000000000000000000000000000000000000000000000000000000001100000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [{0x11, 0x22}, "Ether Token"]

      iex> ABI.decode("((uint256,(uint256,uint256)),string)", "0000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000330000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000b457468657220546f6b656e000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [{0x11, {0x22, 0x33}}, "Ether Token"]

      iex> File.read!("priv/dog.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification
      ...> |> Enum.find(&(&1.function == "bark")) # bark(address,bool)
      ...> |> ABI.decode("00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower))
      [<<1::160>>, true]

      iex> ABI.decode("(uint256 a,bool b)", "000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000001" |> Base.decode16!(case: :lower), decode_structs: true)
      %{a: 10, b: true}
  """
  @spec decode(binary() | FunctionSelector.t(), binary(), keyword()) ::
          [any()] | map()
  def decode(function_signature, data, opts \\ [])

  def decode(function_signature, data, opts) when is_binary(function_signature) do
    decode(FunctionSelector.decode(function_signature), data, opts)
  end

  def decode(%FunctionSelector{} = function_selector, data, opts) do
    [res] = TypeDecoder.decode_raw(data, [%{type: {:tuple, function_selector.types}}], opts)

    if is_tuple(res) do
      Tuple.to_list(res)
    else
      res
    end
  end

  @doc """
  Decodes selector-prefixed calldata (4-byte method ID followed by ABI-encoded
  args) and verifies the prefix matches the expected selector.

  Symmetric counterpart to `encode/2`, which produces selector-prefixed
  output. Use `decode/2` for payload-only data (return values, or calldata
  that has already been routed by selector).

  Returns:

  * `{:ok, decoded}` — selector matched; `decoded` is the same shape `decode/3` returns
  * `{:error, :calldata_too_short}` — fewer than 4 bytes provided
  * `{:error, :selector_mismatch}` — first 4 bytes don't match the expected selector
  * `{:error, :no_function_name}` — the selector has `function: nil`, so there's no
    selector to verify against; use `decode/3` with the payload directly

  > #### Note {: .info}
  >
  > Only the *selector* check is wrapped in `{:error, _}`. When the selector
  > matches but the payload is malformed (truncated or wrongly-typed bytes),
  > the underlying `decode/3` still raises — same contract as calling
  > `decode/3` directly.

  ## Examples

      iex> calldata = ABI.encode("transfer(address,uint256)", [<<1::160>>, 100])
      iex> ABI.decode_call("transfer(address,uint256)", calldata)
      {:ok, [<<1::160>>, 100]}

      iex> ABI.decode_call("deposit()", <<0xd0, 0xe3, 0x0d, 0xb0>>)
      {:ok, []}

      iex> ABI.decode_call("transfer(address,uint256)", <<0xde, 0xad, 0xbe, 0xef>>)
      {:error, :selector_mismatch}

      iex> ABI.decode_call("transfer(address,uint256)", <<0xa9, 0x05>>)
      {:error, :calldata_too_short}

      iex> ABI.decode_call(%ABI.FunctionSelector{function: nil, types: []}, <<0::32>>)
      {:error, :no_function_name}
  """
  @typep decode_call_error ::
           :calldata_too_short | :selector_mismatch | :no_function_name

  @spec decode_call(binary() | FunctionSelector.t(), binary(), keyword()) ::
          {:ok, [any()] | map()} | {:error, decode_call_error()}
  def decode_call(signature_or_selector, calldata, opts \\ [])

  def decode_call(signature, calldata, opts) when is_binary(signature) do
    decode_call(FunctionSelector.decode(signature), calldata, opts)
  end

  def decode_call(%FunctionSelector{function: nil}, _calldata, _opts) do
    {:error, :no_function_name}
  end

  def decode_call(%FunctionSelector{}, calldata, _opts) when byte_size(calldata) < 4 do
    {:error, :calldata_too_short}
  end

  def decode_call(%FunctionSelector{} = function_selector, calldata, opts) do
    expected = method_id(function_selector)
    <<actual::binary-size(4), payload::binary>> = calldata

    if actual == expected do
      {:ok, decode(function_selector, payload, opts)}
    else
      {:error, :selector_mismatch}
    end
  end

  @doc """
  Decodes an event, including indexed and non-indexed data.

  ## Examples

      iex> ABI.decode_event(
      ...>   "Transfer(address indexed from, address indexed to, uint256 amount)",
      ...>   ~h[0x00000000000000000000000000000000000000000000000000000004a817c800],
      ...>   [
      ...>     ~h[0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef],
      ...>     ~h[0x000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
      ...>     ~h[0x0000000000000000000000007795126b3ae468f44c901287de98594198ce38ea]
      ...>   ]
      ...> )
      {:ok,
        "Transfer", %{
          "amount" => 20000000000,
          "from" => ~h[0xb2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
          "to" => ~h[0x7795126b3ae468f44c901287de98594198ce38ea]
      }}

      iex> ABI.decode_event(
      ...>   "Transfer(address indexed from, address indexed to, uint256 amount)",
      ...>   ~h[0x00000000000000000000000000000000000000000000000000000004a817c800],
      ...>   [
      ...>     ~h[0x000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
      ...>     ~h[0x0000000000000000000000007795126b3ae468f44c901287de98594198ce38ea]
      ...>   ],
      ...>   check_event_signature: false
      ...> )
      {:ok,
        "Transfer", %{
          "amount" => 20000000000,
          "from" => ~h[0xb2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
          "to" => ~h[0x7795126b3ae468f44c901287de98594198ce38ea]
      }}

      iex> ABI.decode_event(
      ...>   %ABI.FunctionSelector{
      ...>     function: "Transfer",
      ...>     types: [
      ...>       %{type: :address, name: "from", indexed: true},
      ...>       %{type: :address, name: "to", indexed: true},
      ...>       %{type: {:uint, 256}, name: "amount"},
      ...>     ]
      ...>   },
      ...>   ~h[0x00000000000000000000000000000000000000000000000000000004a817c800],
      ...>   [
      ...>     ~h[0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef],
      ...>     ~h[0x000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
      ...>     ~h[0x0000000000000000000000007795126b3ae468f44c901287de98594198ce38ea]
      ...>   ]
      ...> )
      {:ok,
        "Transfer", %{
          "amount" => 20000000000,
          "from" => ~h[0xb2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
          "to" => ~h[0x7795126b3ae468f44c901287de98594198ce38ea]
      }}
  """
  @spec decode_event(
          binary() | FunctionSelector.t(),
          binary(),
          [binary()],
          keyword()
        ) :: {:ok, String.t() | nil, map()} | {:error, term()}
  def decode_event(function_signature, data, topics, opts \\ [])

  def decode_event(function_signature, data, topics, opts) when is_binary(function_signature) do
    decode_event(FunctionSelector.decode(function_signature), data, topics, opts)
  end

  def decode_event(%FunctionSelector{} = function_selector, data, topics, opts) do
    Event.decode_event(data, topics, function_selector, opts)
  end

  @doc """
  Returns the signature for an event.

  ## Examples

      iex> ABI.event_signature("Transfer(address indexed from, address indexed to, uint256 amount)")
      ...> |> Base.encode16(case: :lower)
      "ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  """
  @spec event_signature(binary() | FunctionSelector.t()) :: binary()
  def event_signature(function_signature) when is_binary(function_signature) do
    event_signature(FunctionSelector.decode(function_signature))
  end

  def event_signature(%FunctionSelector{} = function_selector) do
    Event.event_signature(function_selector)
  end

  @doc """
  Parses the given ABI specification document into an array of `ABI.FunctionSelector`s.

  Non-function entries (e.g. constructors) in the ABI specification are skipped. Fallback function entries are accepted.

  This function can be used in combination with a JSON parser, e.g. [`Jason`](https://hex.pm/packages/jason), to parse ABI specification JSON files.

  ## Examples

      iex> File.read!("priv/dog.abi.json")
      ...> |> Jason.decode!
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{function: "bark", function_type: :function, state_mutability: :nonpayable, returns: [], types: [%{name: "at", type: :address}, %{name: "loudly", type: :bool}]},
       %ABI.FunctionSelector{function: "rollover", function_type: :function, state_mutability: :nonpayable, returns: [%{name: "is_a_good_boy", type: :bool}], types: []}]

      iex> [%{
      ...>   "constant" => true,
      ...>   "inputs" => [
      ...>     %{"name" => "at", "type" => "address"},
      ...>     %{"name" => "loudly", "type" => "bool"}
      ...>   ],
      ...>   "name" => "bark",
      ...>   "outputs" => [],
      ...>   "payable" => false,
      ...>   "stateMutability" => "pure",
      ...>   "type" => "function"
      ...> }]
      ...> |> ABI.parse_specification
      [
        %ABI.FunctionSelector{function: "bark", function_type: :function, state_mutability: :pure, returns: [], types: [
          %{type: :address, name: "at"},
          %{type: :bool, name: "loudly"}
        ]}
      ]

      iex> [%{
      ...>   "inputs" => [
      ...>      %{"name" => "_numProposals", "type" => "uint8"}
      ...>   ],
      ...>   "payable" => false,
      ...>   "stateMutability" => "nonpayable",
      ...>   "type" => "constructor"
      ...> }]
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{function: nil, function_type: :constructor, state_mutability: :nonpayable, types: [%{name: "_numProposals", type: {:uint, 8}}], returns: nil}]

      iex> ABI.decode("(string)", "000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000643132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393031323334353637383930313233343536373839303132333435363738393000000000000000000000000000000000000000000000000000000000" |> Base.decode16!(case: :lower))
      [String.duplicate("1234567890", 10)]

      iex> [%{
      ...>   "payable" => false,
      ...>   "stateMutability" => "nonpayable",
      ...>   "type" => "fallback"
      ...> }]
      ...> |> ABI.parse_specification
      [%ABI.FunctionSelector{function: nil, function_type: :fallback, state_mutability: :nonpayable, returns: nil, types: []}]
  """
  @spec parse_specification([map()]) :: [FunctionSelector.t()]
  def parse_specification(doc) do
    doc
    |> Enum.map(&FunctionSelector.parse_specification_item/1)
    |> Enum.filter(& &1)
  end
end
