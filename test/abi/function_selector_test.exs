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
end
