defmodule ABI.RoundtripPropertyTest do
  @moduledoc """
  Property-based `decode(encode(x)) == x` coverage for every type in
  `ABI.FunctionSelector.@type type/0`.

  Structure: per-type properties localize failures to a single clause; the
  recursive `composite` property exercises nested `{:tuple, [{:array, ...}]}`
  shapes where head/tail offsets matter.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias ABI.TypeDecoder
  alias ABI.TypeEncoder

  @uint_sizes Enum.map(1..32, &(&1 * 8))
  @int_sizes @uint_sizes
  @bytes_n_sizes 1..32

  # ── Per-type value generators ───────────────────────────────────────────

  defp uint_value(size) do
    StreamData.integer(0..(Bitwise.bsl(1, size) - 1))
  end

  defp int_value(size) do
    StreamData.integer(-Bitwise.bsl(1, size - 1)..(Bitwise.bsl(1, size - 1) - 1))
  end

  defp address_value, do: StreamData.binary(length: 20)
  defp bool_value, do: StreamData.boolean()
  defp bytes_n_value(n), do: StreamData.binary(length: n)
  defp bytes_value, do: StreamData.binary(max_length: 64)
  defp string_value, do: StreamData.string(:utf8, max_length: 64)

  # ── Dispatcher: return a generator for any valid type ───────────────────

  defp value_for({:uint, size}), do: uint_value(size)
  defp value_for({:int, size}), do: int_value(size)
  defp value_for(:address), do: address_value()
  defp value_for(:bool), do: bool_value()
  defp value_for({:bytes, n}), do: bytes_n_value(n)
  defp value_for(:bytes), do: bytes_value()
  defp value_for(:string), do: string_value()

  defp value_for({:array, inner, count}) do
    StreamData.list_of(value_for(inner), length: count)
  end

  defp value_for({:array, inner}) do
    StreamData.list_of(value_for(inner), max_length: 4)
  end

  defp value_for({:tuple, arg_types}) do
    arg_types
    |> Enum.map(fn %{type: t} -> value_for(t) end)
    |> StreamData.fixed_list()
    |> StreamData.map(&List.to_tuple/1)
  end

  # ── Recursive type generator ────────────────────────────────────────────
  #
  # Fixed-array count domain is 0..3. `{:array, T, 0}` is now handled
  # statically by `FunctionSelector.dynamic?/1`; if a downstream encoder or
  # decoder path crashes on an empty fixed array, that's a real bug — surface
  # it here, don't suppress it.

  @leaf_types [
    :bool,
    :address,
    :string,
    :bytes,
    {:uint, 8},
    {:uint, 256},
    {:int, 8},
    {:int, 256},
    {:bytes, 1},
    {:bytes, 32}
  ]

  defp leaf_type, do: StreamData.member_of(@leaf_types)

  defp type_gen(0), do: leaf_type()

  defp type_gen(depth) do
    StreamData.frequency([
      {4, leaf_type()},
      {1, StreamData.map(type_gen(depth - 1), &{:array, &1})},
      {1,
       StreamData.bind(type_gen(depth - 1), fn inner ->
         StreamData.map(StreamData.integer(0..3), &{:array, inner, &1})
       end)},
      {1,
       (depth - 1)
       |> type_gen()
       |> StreamData.list_of(min_length: 1, max_length: 3)
       |> StreamData.map(fn inners ->
         {:tuple, Enum.map(inners, &%{type: &1})}
       end)}
    ])
  end

  defp type_and_value_gen(depth) do
    StreamData.bind(type_gen(depth), fn t ->
      StreamData.map(value_for(t), &{t, &1})
    end)
  end

  # ── Round-trip helper ───────────────────────────────────────────────────

  defp roundtrip(type, value) do
    args = [%{type: type}]
    encoded = TypeEncoder.encode_raw([value], args)
    [decoded] = TypeDecoder.decode_raw(encoded, args)
    decoded
  end

  # ── Static value types ──────────────────────────────────────────────────

  describe "static value types" do
    property "uint round-trips across all valid sizes" do
      check all(
              size <- StreamData.member_of(@uint_sizes),
              value <- uint_value(size)
            ) do
        assert roundtrip({:uint, size}, value) == value
      end
    end

    property "int round-trips across all valid sizes" do
      check all(
              size <- StreamData.member_of(@int_sizes),
              value <- int_value(size)
            ) do
        assert roundtrip({:int, size}, value) == value
      end
    end

    property "bool round-trips" do
      check all(value <- bool_value()) do
        assert roundtrip(:bool, value) == value
      end
    end

    property "address round-trips (20-byte binary)" do
      check all(value <- address_value()) do
        assert roundtrip(:address, value) == value
      end
    end

    property "bytesN round-trips across all valid sizes" do
      check all(
              size <- StreamData.member_of(Enum.to_list(@bytes_n_sizes)),
              value <- bytes_n_value(size)
            ) do
        assert roundtrip({:bytes, size}, value) == value
      end
    end
  end

  # ── Dynamic value types ─────────────────────────────────────────────────

  describe "dynamic value types" do
    property "bytes (dynamic) round-trips" do
      check all(value <- bytes_value()) do
        assert roundtrip(:bytes, value) == value
      end
    end

    property "string round-trips" do
      check all(value <- string_value()) do
        assert roundtrip(:string, value) == value
      end
    end
  end

  # ── Arrays ──────────────────────────────────────────────────────────────

  describe "arrays" do
    property "fixed-size uint arrays round-trip (count 1..4)" do
      check all(
              size <- StreamData.integer(1..4),
              value <- StreamData.list_of(uint_value(256), length: size)
            ) do
        assert roundtrip({:array, {:uint, 256}, size}, value) == value
      end
    end

    property "dynamic uint arrays round-trip" do
      check all(value <- StreamData.list_of(uint_value(256), max_length: 4)) do
        assert roundtrip({:array, {:uint, 256}}, value) == value
      end
    end

    property "dynamic address arrays round-trip" do
      check all(value <- StreamData.list_of(address_value(), max_length: 4)) do
        assert roundtrip({:array, :address}, value) == value
      end
    end

    property "dynamic string arrays round-trip" do
      check all(value <- StreamData.list_of(string_value(), max_length: 4)) do
        assert roundtrip({:array, :string}, value) == value
      end
    end

    property "dynamic bytes arrays round-trip" do
      check all(value <- StreamData.list_of(bytes_value(), max_length: 4)) do
        assert roundtrip({:array, :bytes}, value) == value
      end
    end
  end

  # ── Tuples ──────────────────────────────────────────────────────────────

  describe "tuples" do
    property "mixed static+dynamic tuple round-trips" do
      check all(
              u <- uint_value(256),
              s <- string_value(),
              b <- bool_value(),
              bs <- bytes_value()
            ) do
        type =
          {:tuple,
           [
             %{type: {:uint, 256}},
             %{type: :string},
             %{type: :bool},
             %{type: :bytes}
           ]}

        assert roundtrip(type, {u, s, b, bs}) == {u, s, b, bs}
      end
    end

    property "tuple of (uint, dynamic uint[]) round-trips" do
      check all(
              u <- uint_value(256),
              xs <- StreamData.list_of(uint_value(256), max_length: 4)
            ) do
        type =
          {:tuple, [%{type: {:uint, 256}}, %{type: {:array, {:uint, 256}}}]}

        assert roundtrip(type, {u, xs}) == {u, xs}
      end
    end
  end

  # ── Composite (recursive) ───────────────────────────────────────────────

  describe "composite" do
    @tag timeout: 120_000
    property "arbitrary valid types and values round-trip (depth ≤ 3)" do
      check all({type, value} <- type_and_value_gen(3)) do
        assert roundtrip(type, value) == value
      end
    end
  end

  # ── decode_structs: true map round-trip ─────────────────────────────────
  #
  # The decoder applies `Macro.underscore/1` to field names when
  # `decode_structs: true`, so only already-snake_case names round-trip
  # losslessly.

  describe "decode_structs: true round-trip" do
    property "atom-keyed map with snake_case field names round-trips" do
      check all(
              a <- uint_value(256),
              b <- bool_value()
            ) do
        type =
          {:tuple,
           [
             %{type: {:uint, 256}, name: "first_field"},
             %{type: :bool, name: "second_field"}
           ]}

        args = [%{type: type}]
        input = %{first_field: a, second_field: b}

        encoded = TypeEncoder.encode_raw([input], args)
        [decoded] = TypeDecoder.decode_raw(encoded, args, decode_structs: true)

        assert decoded == %{first_field: a, second_field: b}
      end
    end
  end
end
