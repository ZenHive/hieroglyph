defmodule ABI.TypeEncoderTest do
  use ExUnit.Case, async: true

  alias ABI.FunctionSelector
  alias ABI.TypeEncoder

  doctest TypeEncoder

  describe "map-input encoding (data_to_list/2 map branch)" do
    @named_selector %FunctionSelector{
      function: nil,
      types: [
        %{
          type:
            {:tuple,
             [
               %{name: "x", type: {:uint, 32}},
               %{name: "flag", type: :bool}
             ]}
        }
      ]
    }

    test "atom-keyed map encodes identically to the tuple form" do
      assert TypeEncoder.encode([%{x: 42, flag: true}], @named_selector) ==
               TypeEncoder.encode([{42, true}], @named_selector)
    end

    test "string-keyed map encodes identically to the tuple form" do
      assert TypeEncoder.encode([%{"x" => 42, "flag" => true}], @named_selector) ==
               TypeEncoder.encode([{42, true}], @named_selector)
    end

    test "camelCase name resolves to the snake_case atom key" do
      selector = %FunctionSelector{
        function: nil,
        types: [%{type: {:tuple, [%{name: "myField", type: :string}]}}]
      }

      assert TypeEncoder.encode([%{my_field: "hello"}], selector) ==
               TypeEncoder.encode([{"hello"}], selector)
    end

    test "string key takes priority over atom key when both are present" do
      selector = %FunctionSelector{
        function: nil,
        types: [%{type: {:tuple, [%{name: "x", type: {:uint, 32}}]}}]
      }

      assert TypeEncoder.encode([%{"x" => 1, x: 2}], selector) ==
               TypeEncoder.encode([{1}], selector)
    end

    test "integer values inside a nested named-struct map round-trip through both map branches" do
      selector = %FunctionSelector{
        function: nil,
        types: [
          %{
            type:
              {:tuple,
               [
                 %{name: "amount", type: {:int, 32}},
                 %{
                   name: "inner",
                   type:
                     {:tuple,
                      [
                        %{name: "x", type: {:uint, 8}},
                        %{name: "y", type: {:uint, 8}}
                      ]}
                 }
               ]}
          }
        ]
      }

      map_input = [%{amount: -5, inner: %{x: 1, y: 2}}]
      tuple_input = [{-5, {1, 2}}]

      assert TypeEncoder.encode(map_input, selector) ==
               TypeEncoder.encode(tuple_input, selector)
    end

    test "raises a descriptive error when a required field is missing from the map" do
      selector = %FunctionSelector{
        function: nil,
        types: [%{type: {:tuple, [%{name: "required", type: :bool}]}}]
      }

      assert_raise RuntimeError, ~r/Cannot find key/, fn ->
        TypeEncoder.encode([%{other: true}], selector)
      end
    end

    test "raises when a map value targets types without :name" do
      selector = %FunctionSelector{
        function: nil,
        types: [%{type: {:tuple, [%{type: :bool}]}}]
      }

      assert_raise RuntimeError, ~r/no name given/, fn ->
        TypeEncoder.encode([%{anything: true}], selector)
      end
    end

    # String keys are looked up verbatim (no underscore normalization), so a
    # caller passing the snake_case form of a camelCase ABI name must convert
    # it themselves or switch to an atom key. Documented so the asymmetry with
    # atom-key lookup stays inspectable.
    test "raises when string key is the snake_case form of a camelCase field name" do
      selector = %FunctionSelector{
        function: nil,
        types: [%{type: {:tuple, [%{name: "myField", type: {:uint, 8}}]}}]
      }

      assert_raise RuntimeError, ~r/Cannot find key/, fn ->
        TypeEncoder.encode([%{"my_field" => 9}], selector)
      end
    end
  end

  describe "type-error paths" do
    test "bool with non-boolean value raises" do
      selector = %FunctionSelector{function: nil, types: [%{type: :bool}]}

      assert_raise RuntimeError, ~r/Invalid data for bool/, fn ->
        TypeEncoder.encode([42], selector)
      end
    end

    test "bytes<N> with a binary longer than N raises size mismatch" do
      selector = %FunctionSelector{function: nil, types: [%{type: {:bytes, 4}}]}

      assert_raise RuntimeError, ~r/size mismatch for bytes4/, fn ->
        TypeEncoder.encode([<<1, 2, 3, 4, 5>>], selector)
      end
    end

    test "bytes<N> with a non-binary value raises wrong datatype" do
      selector = %FunctionSelector{function: nil, types: [%{type: {:bytes, 4}}]}

      assert_raise RuntimeError, ~r/wrong datatype for bytes4/, fn ->
        TypeEncoder.encode([42], selector)
      end
    end

    test "unrecognized type atom raises unsupported encoding type" do
      selector = %FunctionSelector{function: nil, types: [%{type: :banana}]}

      assert_raise RuntimeError, ~r/Unsupported encoding type/, fn ->
        TypeEncoder.encode([:anything], selector)
      end
    end

    test "int overflow raises at the signed-range boundary" do
      selector = %FunctionSelector{function: nil, types: [%{type: {:int, 8}}]}

      # int8 range is -128..127; the boundary cases must raise.
      for value <- [128, -129, -200, 1_000] do
        assert_raise RuntimeError, ~r/Data overflow encoding int/, fn ->
          TypeEncoder.encode([value], selector)
        end
      end

      # In-range values must NOT raise (regression guard against the
      # byte-vs-bit overflow check that previously rejected ALL int8 input,
      # including 0).
      for value <- [-128, -1, 0, 1, 127] do
        assert is_binary(TypeEncoder.encode([value], selector))
      end
    end

    test "uint overflow raises data overflow" do
      selector = %FunctionSelector{function: nil, types: [%{type: {:uint, 8}}]}

      assert_raise RuntimeError, ~r/Data overflow encoding uint/, fn ->
        TypeEncoder.encode([256], selector)
      end
    end
  end
end
