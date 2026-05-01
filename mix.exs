defmodule ABI.Mixfile do
  use Mix.Project

  def project do
    [
      app: :hieroglyph,
      version: "1.2.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      description:
        "Solidity ABI encoder/decoder for Elixir. Maintained fork of exthereum/abi with bugfixes and Elixir 1.19+ support.",
      source_url: "https://github.com/ZenHive/hieroglyph",
      homepage_url: "https://github.com/ZenHive/hieroglyph",
      docs: [
        main: "ABI",
        extras: ["README.md", "CHANGELOG.md"],
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
      ],
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      compilers: [:yecc, :leex] ++ Mix.compilers(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  defp package do
    [
      name: "hieroglyph",
      maintainers: ["ZenHive"],
      licenses: ["MIT"],
      files: ~w(lib src mix.exs README.md CHANGELOG.md LICENSE.md .formatter.exs),
      links: %{
        "GitHub" => "https://github.com/ZenHive/hieroglyph",
        "Changelog" => "https://github.com/ZenHive/hieroglyph/blob/main/CHANGELOG.md",
        "Upstream (fork-of)" => "https://github.com/exthereum/abi"
      }
    ]
  end

  def cli do
    [preferred_envs: ["test.json": :test, "dialyzer.json": :dev]]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      tidewave: [
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4006) end)'"
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:ex_sha3, "~> 0.1.4"},
      {:descripex, "~> 0.6"},
      {:ex_unit_json, "~> 0.4", only: [:dev, :test], runtime: false},
      {:dialyzer_json, "~> 0.2", only: [:dev, :test], runtime: false},
      {:styler, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:doctor, "~> 0.22", only: [:dev, :test], runtime: false},
      {:tidewave, "~> 0.5", only: :dev},
      {:bandit, "~> 1.10", only: :dev},
      {:ex_dna, "~> 1.3", only: [:dev, :test], runtime: false},
      {:ex_ast, "~> 0.5", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.1", only: :test}
    ]
  end
end
