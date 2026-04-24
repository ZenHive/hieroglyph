defmodule ABI.EventTest do
  use ExUnit.Case, async: true
  use ABI.Hex

  alias ABI.Event
  alias ABI.FunctionSelector

  doctest Event

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
