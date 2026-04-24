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
end
