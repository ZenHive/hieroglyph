defmodule ABI.Parser do
  @moduledoc false

  alias ABI.FunctionSelector

  @doc false
  @spec parse!(String.t(), keyword()) :: FunctionSelector.type() | FunctionSelector.t()
  def parse!(str, opts \\ []) do
    {:ok, tokens, _} = str |> String.to_charlist() |> :ethereum_abi_lexer.string()

    tokens =
      case opts[:as] do
        nil -> tokens
        :type -> [{:"expecting type", 1} | tokens]
        :selector -> [{:"expecting selector", 1} | tokens]
      end

    {:ok, ast} = :ethereum_abi_parser.parse(tokens)

    case ast do
      {:type, type} -> type
      {:selector, selector_parts} -> struct!(FunctionSelector, selector_parts)
    end
  end
end
