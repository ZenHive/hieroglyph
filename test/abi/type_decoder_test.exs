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

    test "raises when an array length prefix exceeds the remaining payload" do
      # A count claiming 2^32-1 elements with no element words behind it. The
      # bound has to fire before the element type list is materialized —
      # otherwise this allocates 4 billion maps first.
      data = <<0xFFFFFFFF::256>>

      assert_raise RuntimeError, ~r/exceeds the 0 remaining 32-byte words/, fn ->
        TypeDecoder.decode_raw(data, [%{type: {:array, {:uint, 256}}}])
      end
    end

    test "reports the oversized array length as a strict violation in strict mode" do
      data = <<0xFFFFFFFF::256>>
      types = [%{type: {:array, {:uint, 256}}}]

      assert_raise TypeDecoder.StrictViolation, ~r/length_out_of_bounds/, fn ->
        TypeDecoder.decode_raw(data, types, strict: true)
      end
    end

    test "arrays of zero-width elements are exempt from the element-count bound" do
      # `bool[0][]` — each element occupies no payload at all, so element count
      # admits no data-length bound. Must still round-trip rather than trip the
      # guard (surfaced by the depth-5 composite property).
      types = [%{type: {:array, {:array, :bool, 0}}}]
      encoded = TypeEncoder.encode_raw([[[]]], types)

      assert [[[]]] = TypeDecoder.decode_raw(encoded, types)
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

  describe "decode_structs: true atom safety" do
    # The decoder only materializes atoms that already exist in the VM atom
    # table. Tests in this block use field-name strings whose snake_case form
    # is intentionally non-existent ("neverInterned…") or referenced as a
    # literal atom in the assertion ("preInterned…"); literal atoms are
    # interned at module-load time regardless of source line order.

    test "raises ArgumentError naming both the atom and the ABI field" do
      types = [%{type: {:uint, 256}, name: "neverInternedFieldXyzZ47Q"}]
      tuple_type = [%{type: {:tuple, types}}]
      encoded = TypeEncoder.encode_raw([{42}], tuple_type)

      err =
        assert_raise ArgumentError, fn ->
          TypeDecoder.decode_raw(encoded, tuple_type, decode_structs: true)
        end

      assert err.message =~ "decode_structs: true requires the snake_case"
      assert err.message =~ ":never_interned_field_xyz_z47_q"
      assert err.message =~ "\"neverInternedFieldXyzZ47Q\""
    end

    test "decodes successfully when the snake_case field atom has been interned" do
      types = [
        %{type: {:uint, 256}, name: "preInternedFieldA"},
        %{type: :bool, name: "preInternedFieldB"}
      ]

      tuple_type = [%{type: {:tuple, types}}]
      encoded = TypeEncoder.encode_raw([{42, true}], tuple_type)
      opts = [decode_structs: true]

      [decoded] = TypeDecoder.decode_raw(encoded, tuple_type, opts)

      # The literal atoms `:pre_interned_field_a` / `:pre_interned_field_b`
      # in this assertion intern them at compile time, satisfying the
      # decoder's `String.to_existing_atom/1` lookup.
      assert decoded == %{pre_interned_field_a: 42, pre_interned_field_b: true}
    end

    test "falls through to a tuple when decode_structs is false (no atom lookup)" do
      types = [
        %{type: {:uint, 256}, name: "yetAnotherNeverInternedFieldZ47Q"},
        %{type: :bool, name: "stillNeverInternedFieldZ47Q"}
      ]

      tuple_type = [%{type: {:tuple, types}}]
      encoded = TypeEncoder.encode_raw([{42, true}], tuple_type)

      # Default behavior: returns a tuple, never touches the atom table.
      assert [{42, true}] = TypeDecoder.decode_raw(encoded, tuple_type)
    end

    test "falls through to a tuple when any field name is empty (no atom lookup)" do
      types = [
        %{type: {:uint, 256}, name: "namedFieldXyzZ47Q"},
        # Empty :name forces the tuple fallback even with decode_structs: true.
        %{type: :bool, name: ""}
      ]

      tuple_type = [%{type: {:tuple, types}}]
      encoded = TypeEncoder.encode_raw([{42, true}], tuple_type)
      opts = [decode_structs: true]

      assert [{42, true}] = TypeDecoder.decode_raw(encoded, tuple_type, opts)
    end
  end
end
