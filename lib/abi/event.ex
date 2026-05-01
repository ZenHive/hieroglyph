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
        "{:ok, function_name, %{name => value}} on success, or {:error, message} on signature mismatch or topic-count mismatch"
    },
    composes_with: [:event_signature]
  )

  @doc ~S"""
  Decodes an event, including handling parsing out data from topics.

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
      {:error, "Mismatched event signature topic[0], expected=DDF252AD1BE2C89B69C2B068FC378DAA952BA7F163C4A11628F55A4DF523B3EF, got=0000000000000000000000000000000000000000000000000000000000000001"}

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
      {:error, "Invalid topics length (got=2, expected=3), consider toggling `check_event_signature`"}

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
  """
  @spec decode_event(binary(), [binary()], FunctionSelector.t(), keyword()) ::
          {:ok, String.t() | nil, map()} | {:error, String.t()}
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

    if Enum.count(indexed_types_full) == Enum.count(topics) do
      indexed_data =
        indexed_types_full
        |> Enum.zip(topics)
        |> Map.new(fn {type, topic} ->
          {type.name, decode_indexed(type, topic)}
        end)

      [non_indexed_data] =
        TypeDecoder.decode_raw(data, [%{type: {:tuple, non_indexed_types}}])

      non_indexed_data_map =
        non_indexed_data
        |> Tuple.to_list()
        |> Enum.zip(non_indexed_types)
        |> Map.new(fn {res, %{name: name}} -> {name, res} end)

      indexed_data_res =
        if check_event_signature do
          verify_event_signature(indexed_data, function_selector)
        else
          {:ok, indexed_data}
        end

      with {:ok, indexed_data_full} <- indexed_data_res do
        {:ok, function_selector.function, Map.merge(indexed_data_full, non_indexed_data_map)}
      end
    else
      {:error,
       "Invalid topics length (got=#{Enum.count(topics)}, expected=#{Enum.count(indexed_types_full)}), consider toggling `check_event_signature`"}
    end
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
    {event_signature, res} = Map.pop(indexed_data, "__abi__topic")
    expected = event_signature(function_selector)

    if event_signature == expected do
      {:ok, res}
    else
      {:error,
       "Mismatched event signature topic[0], expected=#{Base.encode16(expected)}, got=#{Base.encode16(event_signature)}"}
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
