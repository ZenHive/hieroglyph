defmodule ABI.TypeDecoderTest do
  use ExUnit.Case, async: true

  alias ABI.TypeDecoder
  alias ABI.TypeEncoder

  doctest TypeDecoder

  describe "error paths" do
    test "raises when encoded data has bytes left over after consuming all types" do
      one_uint256_worth = 32
      trailing = 32
      padded = :binary.copy(<<0>>, one_uint256_worth + trailing)

      assert_raise RuntimeError, ~r/Found extra binary data/, fn ->
        TypeDecoder.decode_raw(padded, [%{type: {:uint, 256}}])
      end
    end

    test "raises when asked to decode an unrecognized type atom" do
      assert_raise RuntimeError, ~r/Unsupported decoding type/, fn ->
        TypeDecoder.decode_raw(<<0::256>>, [%{type: :banana}])
      end
    end
  end

  describe "function type decoding" do
    # `function` is the 24-byte external function pointer (20-byte address
    # ++ 4-byte selector). On the wire it occupies a 32-byte slot with the
    # 24 payload bytes left-aligned and the trailing 8 bytes zero (right-pad).

    @addr :binary.copy(<<0xAB>>, 20)
    @sel <<0xCA, 0xFE, 0xBA, 0xBE>>
    @ptr @addr <> @sel

    test "decode_raw returns the 24-byte payload, dropping the right-padding" do
      slot = @ptr <> <<0::8*8>>
      assert [@ptr] = TypeDecoder.decode_raw(slot, [%{type: :function}])
    end

    test "round-trips inside (uint256, function, bool)" do
      types = [%{type: {:uint, 256}}, %{type: :function}, %{type: :bool}]
      values = [42, @ptr, true]
      encoded = TypeEncoder.encode_raw(values, types)
      assert TypeDecoder.decode_raw(encoded, types) == values
    end

    test "round-trips inside function[3] fixed-size array" do
      ptrs = [@ptr, :binary.copy(<<0x11>>, 24), :binary.copy(<<0xFF>>, 24)]
      types = [%{type: {:array, :function, 3}}]
      encoded = TypeEncoder.encode_raw([ptrs], types)
      assert [^ptrs] = TypeDecoder.decode_raw(encoded, types)
    end

    test "round-trips inside function[] dynamic array" do
      ptrs = [@ptr, :binary.copy(<<0x22>>, 24)]
      types = [%{type: {:array, :function}}]
      encoded = TypeEncoder.encode_raw([ptrs], types)
      assert [^ptrs] = TypeDecoder.decode_raw(encoded, types)
    end
  end
end
