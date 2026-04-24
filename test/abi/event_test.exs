defmodule ABI.EventTest do
  use ExUnit.Case, async: true
  use ABI.Hex

  alias ABI.Event
  alias ABI.FunctionSelector
  alias ABI.Math

  doctest Event

  describe "indexed reference-type parameters (upstream #53)" do
    # Per the Solidity ABI spec, indexed parameters of reference type
    # (all arrays — fixed-size or dynamic — plus string, bytes, and
    # tuples/structs) are stored in topics as keccak256(value) — the
    # original value is unrecoverable. The decoder returns
    # {:indexed_hash, <<32 bytes>>} for these slots.

    test "indexed string is returned as a tagged hash of the keccak topic" do
      selector = %FunctionSelector{
        function: "Named",
        types: [%{type: :string, name: "who", indexed: true}]
      }

      hashed_name = Math.kec("alice")
      sig_topic = Event.event_signature(selector)

      assert {:ok, "Named", %{"who" => {:indexed_hash, ^hashed_name}}} =
               Event.decode_event(<<>>, [sig_topic, hashed_name], selector)
    end

    test "indexed bytes is returned as a tagged hash" do
      selector = %FunctionSelector{
        function: "Tagged",
        types: [%{type: :bytes, name: "payload", indexed: true}]
      }

      hashed = Math.kec(<<0xDE, 0xAD, 0xBE, 0xEF>>)
      sig_topic = Event.event_signature(selector)

      assert {:ok, "Tagged", %{"payload" => {:indexed_hash, ^hashed}}} =
               Event.decode_event(<<>>, [sig_topic, hashed], selector)
    end

    test "indexed dynamic array is returned as a tagged hash" do
      selector = %FunctionSelector{
        function: "Batch",
        types: [%{type: {:array, {:uint, 256}}, name: "ids", indexed: true}]
      }

      # Arbitrary 32-byte hash stand-in — chain emits keccak256 of the
      # packed array encoding; from the decoder's viewpoint the bytes are
      # opaque.
      hashed = Math.kec("ids-payload")
      sig_topic = Event.event_signature(selector)

      assert {:ok, "Batch", %{"ids" => {:indexed_hash, ^hashed}}} =
               Event.decode_event(<<>>, [sig_topic, hashed], selector)
    end

    test "indexed fixed-size static array is returned as a tagged hash" do
      # `uint256[2]` is static under the ABI head/tail rule but the event
      # encoding still hashes it — this is the regression the narrower
      # `dynamic?/1` predicate missed.
      selector = %FunctionSelector{
        function: "Pair",
        types: [%{type: {:array, {:uint, 256}, 2}, name: "pair", indexed: true}]
      }

      hashed = Math.kec("pair-payload")
      sig_topic = Event.event_signature(selector)

      assert {:ok, "Pair", %{"pair" => {:indexed_hash, ^hashed}}} =
               Event.decode_event(<<>>, [sig_topic, hashed], selector)
    end

    test "indexed tuple of static members is returned as a tagged hash" do
      # A struct/tuple with all-static members is still a reference type
      # for event-indexing purposes and must be hashed.
      selector = %FunctionSelector{
        function: "Point",
        types: [
          %{
            type: {:tuple, [%{type: {:uint, 256}}, %{type: {:uint, 256}}]},
            name: "p",
            indexed: true
          }
        ]
      }

      hashed = Math.kec("point-payload")
      sig_topic = Event.event_signature(selector)

      assert {:ok, "Point", %{"p" => {:indexed_hash, ^hashed}}} =
               Event.decode_event(<<>>, [sig_topic, hashed], selector)
    end

    test "mixed static + dynamic indexed params: each slot decoded per its type" do
      selector = %FunctionSelector{
        function: "Mixed",
        types: [
          %{type: :address, name: "who", indexed: true},
          %{type: :string, name: "label", indexed: true},
          %{type: {:uint, 256}, name: "amount"}
        ]
      }

      who_topic = ~h[0x000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8]
      label_hash = Math.kec("promo")
      sig_topic = Event.event_signature(selector)
      data = ~h[0x00000000000000000000000000000000000000000000000000000004a817c800]

      topics = [sig_topic, who_topic, label_hash]

      assert {:ok, "Mixed", result} =
               Event.decode_event(data, topics, selector)

      assert %{
               "who" => ~h[0xb2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
               "label" => {:indexed_hash, ^label_hash},
               "amount" => 20_000_000_000
             } = result
    end
  end

  describe "error paths" do
    @transfer_selector %FunctionSelector{
      function: "Transfer",
      types: [
        %{type: :address, name: "from", indexed: true},
        %{type: :address, name: "to", indexed: true},
        %{type: {:uint, 256}, name: "amount"}
      ]
    }

    test "returns :error when topic[0] does not match the event signature" do
      data = ~h[0x00000000000000000000000000000000000000000000000000000004a817c800]

      topics = [
        ~h[0x0000000000000000000000000000000000000000000000000000000000000001],
        ~h[0x000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
        ~h[0x0000000000000000000000007795126b3ae468f44c901287de98594198ce38ea]
      ]

      case Event.decode_event(data, topics, @transfer_selector) do
        {:error, msg} ->
          assert msg =~ "Mismatched event signature"

        other ->
          flunk("Expected {:error, _}, got #{inspect(other)}")
      end
    end

    test "returns :error when the topics count disagrees with the indexed-parameter count" do
      data = ~h[0x00000000000000000000000000000000000000000000000000000004a817c800]

      topics = [
        ~h[0x000000000000000000000000b2b7c1795f19fbc28fda77a95e59edbb8b3709c8],
        ~h[0x0000000000000000000000007795126b3ae468f44c901287de98594198ce38ea]
      ]

      case Event.decode_event(data, topics, @transfer_selector) do
        {:error, msg} ->
          assert msg =~ "Invalid topics length"

        other ->
          flunk("Expected {:error, _}, got #{inspect(other)}")
      end
    end
  end
end
