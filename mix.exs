defmodule ABI.Mixfile do
  use Mix.Project

  @spec project() :: keyword()
  def project do
    [
      app: :hieroglyph,
      version: "1.4.0",
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
      # OOM mitigation: :apps_direct skips transitive dep recursion (default
      # :app_tree). Tidewave/bandit's HTTP stack (plug, finch, mint, gun,
      # cowlib, etc.) is not in lib/'s call graph. priv/plts/ survives `mix
      # clean` / _build wipes.
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [:mix, :descripex],
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts"
      ],
      deps: deps()
    ]
  end

  @spec package() :: keyword()
  defp package do
    [
      name: "hieroglyph",
      maintainers: ["ZenHive"],
      licenses: ["MIT"],
      files: ~w(lib src skills mix.exs README.md CHANGELOG.md LICENSE.md .formatter.exs),
      links: %{
        "GitHub" => "https://github.com/ZenHive/hieroglyph",
        "Changelog" => "https://github.com/ZenHive/hieroglyph/blob/main/CHANGELOG.md",
        "Upstream (fork-of)" => "https://github.com/exthereum/abi"
      }
    ]
  end

  @spec cli() :: keyword()
  def cli do
    [preferred_envs: ["test.json": :test, "dialyzer.json": :dev]]
  end

  # Run "mix help compile.app" to learn about applications.
  @spec application() :: keyword()
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  @spec elixirc_paths(atom()) :: [String.t()]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  @spec aliases() :: keyword()
  defp aliases do
    [
      tidewave: [
        "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4006) end)'"
      ],
      # TagTODO/TagFIXME stay on in .credo.exs for visibility; the gate excludes
      # them so it fails only on real regressions, not tracked debt.
      "check.fast": [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict --ignore TagTODO,TagFIXME"
      ],
      # Manual / CI gate (NOT run by the commit hook). Drops dialyzer; keeps
      # tests + sobelow + doctor. 95% coverage — this is a wire-format/crypto
      # encoder (critical business logic).
      precommit: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "credo --strict --ignore TagTODO,TagFIXME",
        "doctor --raise",
        # `preferred_envs` (cli/0) is ignored for alias steps, and `mix cmd`
        # runs args via `System.cmd` with no shell (so a `MIX_ENV=test` prefix
        # is treated as the binary name). Spawn a fresh `mix` in :test instead.
        &cover_gate/1,
        "sobelow --skip"
      ],
      # CI mirror — adds dialyzer. Matches `elixir-ci-harness` `harness.yml`.
      "precommit.full": ["precommit", "dialyzer.json --quiet"]
    ]
  end

  # 95% coverage gate. Spawns a child `mix` in :test (alias steps ignore
  # `cli/0` preferred_envs); a non-zero exit — test failure or sub-threshold
  # coverage — aborts the precommit run.
  @spec cover_gate([String.t()]) :: nil
  defp cover_gate(_args) do
    args =
      ~w(test.json --quiet --cover --cover-threshold 95 --summary-only --exclude integration)

    {_out, status} =
      System.cmd("mix", args, env: [{"MIX_ENV", "test"}], into: IO.stream())

    if status != 0, do: Mix.raise("coverage gate failed (mix test exit #{status})")
  end

  # Run "mix help deps" to learn about dependencies.
  @spec deps() :: [{atom(), String.t()} | {atom(), String.t(), keyword()}]
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
      {:doctor, "~> 0.23", only: [:dev, :test], runtime: false},
      {:tidewave, "~> 0.5", only: :dev},
      {:bandit, "~> 1.10", only: :dev},
      {:ex_dna, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_ast, "~> 0.12", only: [:dev, :test], runtime: false},
      {:stream_data, "~> 1.1", only: :test}
    ]
  end
end
