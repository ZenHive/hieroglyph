defmodule ABI.Event do
  @moduledoc """
  Decodes Ethereum event log data into Solidity-typed arguments.

  Splits the topic list (indexed parameters) from the data blob (non-indexed
  parameters) per the ABI specification, and optionally verifies that
  `topics[0]` matches the `keccak256` hash of the event signature.
  """

  use Descripex, namespace: "/selector"

  alias ABI.FunctionSelector
  alias ABI.Math
  alias ABI.TypeDecoder

  api(
    :decode_event,
    "Decode an Ethereum event log, splitting indexed parameters from topics and non-indexed parameters from the data blob, optionally verifying topics[0] against the event signature.",
    params: [
      data: [
        kind: :exchange_data,
        description: "Non-indexed event payload (binary); originates from the log's data field returned by eth_getLogs",
        source: "eth_getLogs"
      ],
      topics: [
        kind: :exchange_data,
        description:
          "List of topic binaries (each 32 bytes). topics[0] is the event signature hash unless check_event_signature is false",
        source: "eth_getLogs"
      ],
      function_selector: [
        kind: :value,
        description: "Pre-parsed FunctionSelector with type metadata including indexed flags"
      ],
      opts: [
        kind: :value,
        default: [],
        description:
          "Optional keyword list. Supports check_event_signature: false to skip topics[0] verification (anonymous events or pre-stripped topics)"
      ]
    ],
    returns: %{
      type: :tuple,
      description:
        "{:ok, function_name, %{name => value}} on success, or {:error, reason} where reason is a closed tagged-tuple set"
    },
    errors: [
      event_signature_mismatch:
        "topics[0] did not match keccak256(canonical_signature). Reason payload: %{expected: <<32 bytes>>, got: <<32 bytes>>}.",
      topics_length_mismatch:
        "Number of topics did not match the indexed-parameter count (plus topics[0] when check_event_signature is true). Reason payload: %{got: integer, expected: integer}.",
      malformed_data:
        "Non-indexed payload bytes failed to decode (truncated, wrong type, or otherwise inconsistent with the function_selector types). Reason payload: a human-readable string describing the underlying decode failure."
    ],
    composes_with: [:event_signature]
  )

  @typedoc """
  Closed error set returned by `decode_event/4`.

  * `:event_signature_mismatch` — `topics[0]` did not match `keccak256(canonical_signature)`.
  * `:topics_length_mismatch` — number of topics did not match the indexed-parameter count
    (plus the implicit `topics[0]` slot when `check_event_signature: true`).
  * `:malformed_data` — non-indexed payload failed to decode (truncated, wrong types, or
    otherwise inconsistent with `function_selector.types`).
  """
  @type decode_error ::
          {:event_signature_mismatch, %{expected: binary(), got: binary()}}
          | {:topics_length_mismatch, length_pair()}
          | {:malformed_data, String.t()}

  @typep length_pair :: %{got: non_neg_integer(), expected: non_neg_integer()}

  @doc ~S"""
  Decodes an event, including handling parsing out data from topics.

  Returns `{:ok, function_name, args_map}` on success, or `{:error, reason}` where
  `reason` is one of the variants in `t:decode_error/0`.

  ## Examples

      iex> ABI.Event.decode_event(
      ...>   ~h[0x00000000000000000000000000000000000000000000000000000004a817c800],
      ...>   [
      ...>     ~h[0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef],
      ...>     ~h[0x000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
      ...>     ~h[0x0000000000000000000000007795126b3ae468f44c901287de98594198ce38ea]
      ...>   ],
      ...>   %ABI.FunctionSelector{
      ...>     function: "Transfer",
      ...>     types: [
      ...>       %{type: :address, name: "from", indexed: true},
      ...>       %{type: :address, name: "to", indexed: true},
      ...>       %{type: {:uint, 256}, name: "amount"},
      ...>     ]
      ...>   })
      {:ok,
        "Transfer", %{
          "amount" => 20000000000,
          "from" => ~h[0xb2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
          "to" => ~h[0x7795126b3ae468f44c901287de98594198ce38ea]
      }}

      iex> ABI.Event.decode_event(
      ...>   ~h[0x00000000000000000000000000000000000000000000000000000004a817c800],
      ...>   [
      ...>     ~h[0x0000000000000000000000000000000000000000000000000000000000000001],
      ...>     ~h[0x000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
      ...>     ~h[0x0000000000000000000000007795126b3ae468f44c901287de98594198ce38ea]
      ...>   ],
      ...>   %ABI.FunctionSelector{
      ...>     function: "Transfer",
      ...>     types: [
      ...>       %{type: :address, name: "from", indexed: true},
      ...>       %{type: :address, name: "to", indexed: true},
      ...>       %{type: {:uint, 256}, name: "amount"},
      ...>     ]
      ...>   })
      {:error,
        {:event_signature_mismatch,
         %{
           expected: ~h[0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef],
           got: ~h[0x0000000000000000000000000000000000000000000000000000000000000001]
         }}}

      iex> ABI.Event.decode_event(
      ...>   ~h[0x00000000000000000000000000000000000000000000000000000004a817c800],
      ...>   [
      ...>     ~h[0x000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
      ...>     ~h[0x0000000000000000000000007795126b3ae468f44c901287de98594198ce38ea]
      ...>   ],
      ...>   %ABI.FunctionSelector{
      ...>     function: "Transfer",
      ...>     types: [
      ...>       %{type: :address, name: "from", indexed: true},
      ...>       %{type: :address, name: "to", indexed: true},
      ...>       %{type: {:uint, 256}, name: "amount"},
      ...>     ]
      ...>   })
      {:error, {:topics_length_mismatch, %{got: 2, expected: 3}}}

      iex> ABI.Event.decode_event(
      ...>   ~h[0x00000000000000000000000000000000000000000000000000000004a817c800],
      ...>   [
      ...>     ~h[0x000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
      ...>     ~h[0x0000000000000000000000007795126b3ae468f44c901287de98594198ce38ea]
      ...>   ],
      ...>   %ABI.FunctionSelector{
      ...>     function: "Transfer",
      ...>     types: [
      ...>       %{type: :address, name: "from", indexed: true},
      ...>       %{type: :address, name: "to", indexed: true},
      ...>       %{type: {:uint, 256}, name: "amount"},
      ...>     ]
      ...>   },
      ...>   check_event_signature: false
      ...> )
      {:ok,
        "Transfer", %{
          "amount" => 20000000000,
          "from" => ~h[0xb2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
          "to" => ~h[0x7795126b3ae468f44c901287de98594198ce38ea]
      }}

  When the non-indexed payload bytes are truncated or wrongly typed, the underlying
  decoder previously raised; the function now wraps that path and returns
  `{:error, {:malformed_data, msg}}` with a human-readable description.
  """
  @spec decode_event(binary(), [binary()], FunctionSelector.t(), keyword()) ::
          {:ok, String.t() | nil, map()} | {:error, decode_error()}
  def decode_event(data, topics, function_selector, opts \\ []) do
    check_event_signature = Keyword.get(opts, :check_event_signature, true)

    # First, split the types into indexed and not indexed
    {indexed_types, non_indexed_types} =
      Enum.split_with(function_selector.types, fn t -> Map.get(t, :indexed) end)

    indexed_types_full =
      if check_event_signature do
        [%{type: {:bytes, 32}, name: "__abi__topic"} | indexed_types]
      else
        indexed_types
      end

    expected_count = Enum.count(indexed_types_full)
    actual_count = Enum.count(topics)

    if expected_count == actual_count do
      indexed_data = decode_indexed_topics(indexed_types_full, topics)

      verified =
        maybe_verify(indexed_data, function_selector, check_event_signature)

      with {:ok, idx} <- verified,
           {:ok, non_idx} <- decode_non_indexed(data, non_indexed_types) do
        {:ok, function_selector.function, Map.merge(idx, non_idx)}
      end
    else
      lengths = %{got: actual_count, expected: expected_count}
      {:error, {:topics_length_mismatch, lengths}}
    end
  end

  defp decode_indexed_topics(indexed_types_full, topics) do
    indexed_types_full
    |> Enum.zip(topics)
    |> Map.new(fn {type, topic} -> {type.name, decode_indexed(type, topic)} end)
  end

  defp decode_non_indexed(data, non_indexed_types) do
    tuple_type = [%{type: {:tuple, non_indexed_types}}]
    [non_indexed_data] = TypeDecoder.decode_raw(data, tuple_type)

    map =
      non_indexed_data
      |> Tuple.to_list()
      |> Enum.zip(non_indexed_types)
      |> Map.new(fn {res, %{name: name}} -> {name, res} end)

    {:ok, map}
  rescue
    e -> {:error, {:malformed_data, Exception.message(e)}}
  end

  defp maybe_verify(indexed_data, function_selector, true) do
    verify_event_signature(indexed_data, function_selector)
  end

  defp maybe_verify(indexed_data, _function_selector, false) do
    {:ok, indexed_data}
  end

  defp decode_indexed(param, topic) do
    if reference_type?(param.type) do
      {:indexed_hash, topic}
    else
      [value] = TypeDecoder.decode_raw(topic, [param])
      value
    end
  end

  # Per the Solidity ABI spec, indexed parameters of reference types
  # (all arrays — fixed-size or dynamic — plus `string`, `bytes`, and
  # tuples/structs) are stored in topics as keccak256(value). The
  # original is unrecoverable, so we surface the hash as a tagged tuple
  # rather than decoding garbage bytes. This is broader than
  # `FunctionSelector.dynamic?/1` — that predicate answers the ABI
  # head/tail question and says `uint256[2]` is static, but the event
  # encoding rule hashes it all the same.
  defp reference_type?(:string), do: true
  defp reference_type?(:bytes), do: true
  defp reference_type?({:array, _}), do: true
  defp reference_type?({:array, _, _}), do: true
  defp reference_type?({:tuple, _}), do: true
  defp reference_type?(_), do: false

  defp verify_event_signature(indexed_data, function_selector) do
    {got, res} = Map.pop(indexed_data, "__abi__topic")
    expected = event_signature(function_selector)

    if got == expected do
      {:ok, res}
    else
      {:error, {:event_signature_mismatch, %{expected: expected, got: got}}}
    end
  end

  api(
    :event_signature,
    "Compute the keccak-256 hash of the event's canonical signature, used as topics[0] in event logs.",
    params: [
      function_selector: [kind: :value, description: "Event FunctionSelector with name and type metadata"]
    ],
    returns: %{type: :binary, description: "32-byte topic hash matching the first topic of an emitted log for this event"},
    composes_with: [:decode_event]
  )

  @doc ~S"""
  Returns the signature of an event, i.e. the first item that appears
  in an Ethereum log for this event.

  ## Examples

      iex> ABI.Event.event_signature(
      ...>   %ABI.FunctionSelector{
      ...>     function: "Transfer",
      ...>     types: [
      ...>       %{type: :address, name: "from", indexed: true},
      ...>       %{type: :address, name: "to", indexed: true},
      ...>       %{type: {:uint, 256}, name: "amount"},
      ...>     ]
      ...>   }
      ...> )
      ...> |> to_hex()
      "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
  """
  @spec event_signature(FunctionSelector.t()) :: binary()
  def event_signature(function_selector) do
    function_selector
    |> FunctionSelector.encode()
    |> Math.kec()
  end

  api(
    :canonical,
    "Render the canonical signature string of an event for hashing or display, optionally including indexed and parameter-name annotations.",
    params: [
      function_selector: [kind: :value, description: "Event FunctionSelector with name and type metadata"],
      opts: [
        kind: :value,
        default: [],
        description:
          "Optional keyword list. Supports indexed: true to include the indexed keyword on indexed parameters, and names: true to include parameter names"
      ]
    ],
    returns: %{
      type: :string,
      description:
        "Canonical signature string such as Transfer(address,address,uint256) or with indexed/names annotations applied"
    }
  )

  @doc ~S"""
  Returns the canonical form of this event topic. Pass in `indexed: true`
  to include "indexed" keywords.

  ## Examples

      iex> ABI.Event.canonical(
      ...>   %ABI.FunctionSelector{
      ...>     function: "Transfer",
      ...>     types: [
      ...>       %{type: :address, name: "from", indexed: true},
      ...>       %{type: :address, name: "to", indexed: true},
      ...>       %{type: {:uint, 256}, name: "amount"},
      ...>     ]
      ...>   }
      ...> )
      "Transfer(address,address,uint256)"

      iex> ABI.Event.canonical(
      ...>   %ABI.FunctionSelector{
      ...>     function: "Transfer",
      ...>     types: [
      ...>       %{type: :address, name: "from", indexed: true},
      ...>       %{type: :address, name: "to", indexed: true},
      ...>       %{type: {:uint, 256}, name: "amount"},
      ...>     ]
      ...>   },
      ...>   names: true
      ...> )
      "Transfer(address from,address to,uint256 amount)"

      iex> ABI.Event.canonical(
      ...>   %ABI.FunctionSelector{
      ...>     function: "Transfer",
      ...>     types: [
      ...>       %{type: :address, name: "from", indexed: true},
      ...>       %{type: :address, name: "to", indexed: true},
      ...>       %{type: {:uint, 256}, name: "amount"},
      ...>     ]
      ...>   },
      ...>   indexed: true
      ...> )
      "Transfer(address indexed,address indexed,uint256)"

      iex> ABI.Event.canonical(
      ...>   %ABI.FunctionSelector{
      ...>     function: "Transfer",
      ...>     types: [
      ...>       %{type: :address, name: "from", indexed: true},
      ...>       %{type: :address, name: "to", indexed: true},
      ...>       %{type: {:uint, 256}, name: "amount"},
      ...>     ]
      ...>   },
      ...>   indexed: true,
      ...>   names: true
      ...> )
      "Transfer(address indexed from,address indexed to,uint256 amount)"
  """
  @spec canonical(FunctionSelector.t(), keyword()) :: String.t()
  def canonical(function_selector, opts \\ []) do
    indexed = Keyword.get(opts, :indexed, false)
    names = Keyword.get(opts, :names, false)

    FunctionSelector.encode(function_selector, indexed, names)
  end
end
