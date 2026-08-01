defmodule Mix.Tasks.Hieroglyph.Manifest do
  @shortdoc "Generate api_manifest.json from descripex metadata"

  @moduledoc """
  Generates a static `api_manifest.json` from the library's descripex annotations.

  The manifest is a JSON-serializable representation of every public function
  in the library — params, return types, errors, specs, and descriptions.
  Suitable for downstream codegen (cartouche-generated contract bindings),
  agent discovery, validators, and CI contract-stability diffs across
  hieroglyph version bumps.

      mix hieroglyph.manifest
      mix hieroglyph.manifest path/to/output.json

  Uses `ABI.__descripex_modules__/0` as the single source of truth for which
  modules to include. Output defaults to `api_manifest.json` in the project root.
  """

  use Mix.Task

  alias Descripex.Manifest

  @default_output "api_manifest.json"

  @impl Mix.Task
  def run(args) do
    output_file = List.first(args) || @default_output
    modules = ABI.__descripex_modules__()
    manifest = Manifest.build(modules)
    json = Jason.encode!(manifest, pretty: true)
    File.write!(output_file, json)

    Mix.shell().info(
      "Generated #{output_file} (#{length(manifest.modules)} modules, #{Enum.sum_by(manifest.modules, &length(&1.functions))} entries)"
    )
  end
end
