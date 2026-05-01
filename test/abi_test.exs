defmodule ABITest do
  use ExUnit.Case, async: true
  use ABI.Hex

  doctest ABI

  describe "empty argument list" do
    # `weth.deposit()`, `rocket_pool.deposit()`, and similar `f()` calls produce
    # calldata that's literally just the 4-byte selector — zero ABI-encoded
    # args. The roundtrip property suite never generates an empty arg list, so
    # this path was untested.

    test "encode/2 with `f()` signature produces only the 4-byte selector" do
      encoded = ABI.encode("deposit()", [])
      # keccak("deposit()")[0..3] — the selector used by WETH9 deposit and
      # Rocket Pool deposit.
      assert encoded == <<0xD0, 0xE3, 0x0D, 0xB0>>
      assert byte_size(encoded) == 4
    end

    test "encode/2 with FunctionSelector struct produces only the selector" do
      selector = %ABI.FunctionSelector{function: "deposit", types: []}
      encoded = ABI.encode(selector, [])
      assert encoded == <<0xD0, 0xE3, 0x0D, 0xB0>>
      assert byte_size(encoded) == 4
    end

    test "encode/2 with nil-function selector and empty types produces empty bytes" do
      selector = %ABI.FunctionSelector{function: nil, types: []}
      assert ABI.encode(selector, []) == <<>>
    end

    test "decode/3 of empty payload against `f()` returns []" do
      assert ABI.decode("deposit()", <<>>) == []
    end

    test "decode/3 of empty payload against FunctionSelector with no types returns []" do
      assert ABI.decode(%ABI.FunctionSelector{types: []}, <<>>) == []
    end
  end

  describe "method_id/1" do
    test "produces the canonical 4-byte selector for known mainnet signatures" do
      assert ABI.method_id("transfer(address,uint256)") == <<0xA9, 0x05, 0x9C, 0xBB>>

      assert ABI.method_id("transferFrom(address,address,uint256)") ==
               <<0x23, 0xB8, 0x72, 0xDD>>

      assert ABI.method_id("deposit()") == <<0xD0, 0xE3, 0x0D, 0xB0>>
      assert ABI.method_id("withdraw(uint256)") == <<0x2E, 0x1A, 0x7D, 0x4D>>
    end

    test "accepts a FunctionSelector struct and a signature string equivalently" do
      [selector] =
        ABI.parse_specification([%{"type" => "function", "name" => "deposit", "inputs" => []}])

      assert ABI.method_id(selector) == ABI.method_id("deposit()")
    end

    test "returns empty binary for selectors with function: nil" do
      selector = %ABI.FunctionSelector{
        function: nil,
        types: [%{type: :address}]
      }

      assert ABI.method_id(selector) == <<>>
    end
  end

  describe "decode_call/3" do
    test "round-trips through encode/2 for mixed static+dynamic args" do
      sig = "swap(address,uint256,bytes)"
      args = [<<1::160>>, 999, "payload"]
      calldata = ABI.encode(sig, args)

      assert {:ok, ^args} = ABI.decode_call(sig, calldata)
    end

    test "round-trips for empty-args calls" do
      calldata = ABI.encode("deposit()", [])
      assert {:ok, []} = ABI.decode_call("deposit()", calldata)
    end

    test "accepts a FunctionSelector struct" do
      [selector] =
        ABI.parse_specification([
          %{
            "type" => "function",
            "name" => "transfer",
            "inputs" => [
              %{"type" => "address", "name" => "to"},
              %{"type" => "uint256", "name" => "amount"}
            ]
          }
        ])

      calldata = ABI.encode(selector, [<<1::160>>, 100])
      assert {:ok, [<<1::160>>, 100]} = ABI.decode_call(selector, calldata)
    end

    test "returns :selector_mismatch when prefix doesn't match the signature" do
      # `transfer` calldata decoded against `withdraw(uint256)`.
      calldata = ABI.encode("transfer(address,uint256)", [<<1::160>>, 100])

      assert {:error, :selector_mismatch} =
               ABI.decode_call("withdraw(uint256)", calldata)
    end

    test "returns :calldata_too_short for fewer than 4 bytes" do
      sig = "deposit()"
      three_bytes = <<0xD0, 0xE3, 0x0D>>
      assert {:error, :calldata_too_short} = ABI.decode_call(sig, <<>>)
      assert {:error, :calldata_too_short} = ABI.decode_call(sig, <<0xD0>>)
      assert {:error, :calldata_too_short} = ABI.decode_call(sig, three_bytes)
    end

    test "returns :no_function_name when the selector has no function name" do
      selector = %ABI.FunctionSelector{
        function: nil,
        types: [%{type: {:uint, 256}}]
      }

      # Anything ≥ 4 bytes; precedence is checked before length.
      assert {:error, :no_function_name} =
               ABI.decode_call(selector, <<0::8*32>>)
    end

    test "passes opts through to decode/3 (decode_structs: true)" do
      [selector] =
        ABI.parse_specification([
          %{
            "type" => "function",
            "name" => "set",
            "inputs" => [
              %{"type" => "uint256", "name" => "first_field"},
              %{"type" => "bool", "name" => "second_field"}
            ]
          }
        ])

      calldata = ABI.encode(selector, [42, true])

      assert {:ok, %{first_field: 42, second_field: true}} =
               ABI.decode_call(selector, calldata, decode_structs: true)
    end
  end
end
