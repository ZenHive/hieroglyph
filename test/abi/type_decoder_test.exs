defmodule ABI.TypeDecoderTest do
  use ExUnit.Case, async: true

  alias ABI.TypeDecoder

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
end
