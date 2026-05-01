defmodule ABI.FunctionSelectorTest do
  use ExUnit.Case, async: true

  alias ABI.FunctionSelector

  doctest FunctionSelector

  describe "error paths" do
    test "encode/1 raises when the selector has an unrecognized type" do
      selector = %FunctionSelector{function: "foo", types: [%{type: :banana}]}

      assert_raise RuntimeError, ~r/Unsupported type/, fn ->
        FunctionSelector.encode(selector)
      end
    end
  end

  describe "parse-time rejection of unsupported grammar types (upstream #54)" do
    # `function`, `fixed` (bare → default `fixed128x18`), `ufixed` (bare →
    # default `ufixed128x18`) are accepted by the ABI grammar but not
    # implemented by this library. Rejecting at parse time surfaces the
    # error on the user's input instead of deep inside the encoder/decoder
    # catch-all.
    #
    # The explicit-M-and-N forms like `fixed128x18` / `ufixed128x18` do NOT
    # currently reach this walker: the lexer tokenizes single `x` as
    # `letters` (LETTERS rule wins over the `x` terminal), so the parser
    # reduces `typename digits` → `juxt_type(fixed, 128)` and raises
    # FunctionClauseError earlier. That's a separate pre-existing lexer bug,
    # tracked as a new ROADMAP task.

    test "decode_type/1 raises on bare `function`" do
      assert_raise ArgumentError, ~r/function/, fn ->
        FunctionSelector.decode_type("function")
      end
    end

    test "decode_type/1 raises on bare `fixed` (parser expands to fixed128x18)" do
      assert_raise ArgumentError, ~r/fixed/, fn ->
        FunctionSelector.decode_type("fixed")
      end
    end

    test "decode_type/1 raises on bare `ufixed`" do
      assert_raise ArgumentError, ~r/ufixed/, fn ->
        FunctionSelector.decode_type("ufixed")
      end
    end

    test "decode_type/1 raises on array of rejected type" do
      assert_raise ArgumentError, ~r/function/, fn ->
        FunctionSelector.decode_type("function[]")
      end
    end

    test "decode_type/1 raises on fixed-size array of rejected type" do
      assert_raise ArgumentError, ~r/fixed/, fn ->
        FunctionSelector.decode_type("fixed[5]")
      end
    end

    test "decode_type/1 raises on tuple containing rejected type" do
      assert_raise ArgumentError, ~r/function/, fn ->
        FunctionSelector.decode_type("(uint256,function)")
      end
    end

    test "decode/1 raises on selector argument with rejected type" do
      assert_raise ArgumentError, ~r/function/, fn ->
        FunctionSelector.decode("foo(function)")
      end
    end

    test "decode/1 raises on selector return with rejected type" do
      assert_raise ArgumentError, ~r/function/, fn ->
        FunctionSelector.decode("foo(uint256)->function")
      end
    end

    test "decode_type/1 still accepts supported types unchanged" do
      assert {:array, {:uint, 256}} = FunctionSelector.decode_type("uint256[]")
      assert {:bytes, 32} = FunctionSelector.decode_type("bytes32")
      assert :address = FunctionSelector.decode_type("address")
    end
  end

  describe "encode/3 canonical signature rendering" do
    # Pins the `get_type/1` clauses used to build canonical Solidity
    # signature strings (the basis for selector keccak hashing). Each
    # branch maps a parsed type back to its Solidity textual form.

    test "renders {:int, N} as `intN`" do
      selector = %FunctionSelector{
        function: "foo",
        types: [%{type: {:int, 256}}, %{type: {:int, 8}}]
      }

      assert FunctionSelector.encode(selector) == "foo(int256,int8)"
    end

    test "renders {:struct, _, types, _} as a tuple of its types" do
      # `:struct` is an internal shape used when `decode_structs: true` is
      # set on the decoder; documenting the rendering contract here pins
      # behavior for any caller that constructs selectors directly.
      selector = %FunctionSelector{
        function: "foo",
        types: [%{type: {:struct, "Pair", [:address, {:uint, 256}], ["addr", "amount"]}}]
      }

      assert FunctionSelector.encode(selector) == "foo((address,uint256))"
    end

    test "renders dead-via-parse types when constructed manually" do
      # `:function`, `{:fixed, _, _}`, `{:ufixed, _, _}` are rejected at
      # parse time per upstream #54, but the `get_type/1` clauses remain
      # for callers that build selectors directly. `nil` is the same
      # shape: defensive against partially-built typeinfo maps.
      assert FunctionSelector.encode(%FunctionSelector{
               function: "f",
               types: [%{type: :function}]
             }) == "f(function)"

      assert FunctionSelector.encode(%FunctionSelector{
               function: "f",
               types: [%{type: {:fixed, 128, 18}}]
             }) == "f(fixed128x18)"

      assert FunctionSelector.encode(%FunctionSelector{
               function: "f",
               types: [%{type: {:ufixed, 128, 18}}]
             }) == "f(ufixed128x18)"

      assert FunctionSelector.encode(%FunctionSelector{
               function: "f",
               types: [%{type: nil}]
             }) == "f()"
    end
  end

  describe "parse_specification — indexed event input without a name" do
    test "produces a typeinfo map with :type and :indexed but no :name" do
      # Older Solidity versions and hand-written ABIs may omit `name` on
      # indexed event params. Pins the `parse_specification_type/1` branch
      # that handles `%{"indexed" => _}` without a corresponding `"name"`.
      abi = [
        %{
          "type" => "event",
          "name" => "Transfer",
          "anonymous" => false,
          "inputs" => [
            %{"type" => "address", "indexed" => true},
            %{"type" => "uint256", "indexed" => false}
          ]
        }
      ]

      [%FunctionSelector{types: [first, second]}] = ABI.parse_specification(abi)

      refute Map.has_key?(first, :name)
      assert first.type == :address
      assert first.indexed == true
      assert second.type == {:uint, 256}
    end
  end

  describe "dynamic?/1 zero-length fixed array" do
    # The grammar allows `T[0]` (yrl rule permits N >= 0), so a parseable type
    # `{:array, T, 0}` reaches `dynamic?/1`. Before the fix, no clause matched
    # zero-length arrays — only `len > 0` — and any caller raised
    # FunctionClauseError. A zero-length fixed array has no head/tail layout
    # and no payload, so it's static by any sensible definition.
    test "returns false for zero-length fixed array of value type" do
      refute FunctionSelector.dynamic?({:array, :address, 0})
      refute FunctionSelector.dynamic?({:array, {:uint, 256}, 0})
      refute FunctionSelector.dynamic?({:array, :bool, 0})
    end

    test "returns false for zero-length fixed array of dynamic element type" do
      refute FunctionSelector.dynamic?({:array, :string, 0})
      refute FunctionSelector.dynamic?({:array, :bytes, 0})
    end

    test "non-zero fixed arrays still inherit dynamic? from element type" do
      refute FunctionSelector.dynamic?({:array, :address, 3})
      assert FunctionSelector.dynamic?({:array, :string, 3})
    end
  end
end
