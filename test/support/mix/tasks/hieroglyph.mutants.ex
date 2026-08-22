defmodule Mix.Tasks.Hieroglyph.Mutants do
  @shortdoc "Runs the planted-mutant corpus against the task-44 verification vectors"

  @moduledoc """
  Applies each planted mutant in `test/support/mutants/mutants.exs` to `lib/`,
  runs the suite, and reverts the file byte-exactly.

  A mutant is **killed** when the assertions added by roadmap task 44 — the
  independent ethers.js vector corpus and the spec-anchored assertions — fail
  on it. A mutant that only the pre-existing suite catches is a **survivor**,
  because the pre-existing suite is largely self-consistency (`decode(encode(x))`)
  and cannot detect a wire-format drift that both directions share.

  Two runs are recorded per mutant and kept apart:

    * `vectors` — `test/abi/ethers_corpus_test.exs` and
      `test/abi/abi_spec_test.exs` only. This is the number that matters.
    * `suite` — the whole `mix test` run, i.e. the "caught by something else"
      column. A `suite` failure alone never counts as a kill.

  Compilation is not an oracle: a mutant that fails to compile is reported as
  `invalid`, not as a kill.

  ## Usage

  The task lives under `test/support/` — it mutates `lib/` and is never
  shipped — so it is only on the code path in the test environment:

      MIX_ENV=test mix hieroglyph.mutants              # both runs, table + exit status
      MIX_ENV=test mix hieroglyph.mutants --vectors    # skip the whole-suite column
      MIX_ENV=test mix hieroglyph.mutants --only id    # one mutant by id (repeatable)

  The task exits non-zero when a mutant whose recorded expectation is
  `:killed` is not killed, when a mutant recorded as `:survivor` unexpectedly
  dies, when an anchor no longer matches its file exactly once, or when a
  mutated file is not restored byte-exactly.
  """

  use Mix.Task

  @vector_files ["test/abi/ethers_corpus_test.exs", "test/abi/abi_spec_test.exs"]
  @corpus_path "test/support/mutants/mutants.exs"

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(argv) do
    {opts, _rest} =
      OptionParser.parse!(argv, strict: [vectors: :boolean, only: :keep], aliases: [])

    mutants = select(load_corpus(), Keyword.get_values(opts, :only))
    run_suite? = not Keyword.get(opts, :vectors, false)

    results = Enum.map(mutants, &evaluate(&1, run_suite?))

    report(results, run_suite?)

    if Enum.all?(results, & &1.ok?) do
      :ok
    else
      Mix.raise("planted-mutant corpus failed — see the table above")
    end
  end

  @spec load_corpus() :: [map()]
  defp load_corpus do
    {mutants, _bindings} = Code.eval_file(@corpus_path)

    mutants
  end

  @spec select([map()], [String.t()]) :: [map()]
  defp select(mutants, []), do: mutants

  defp select(mutants, ids) do
    case Enum.filter(mutants, &(&1.id in ids)) do
      [] -> Mix.raise("no mutant matches --only #{Enum.join(ids, ",")}")
      selected -> selected
    end
  end

  # One mutant: snapshot, mutate, run, restore, verify the restore.
  @spec evaluate(map(), boolean()) :: map()
  defp evaluate(mutant, run_suite?) do
    original = File.read!(mutant.file)
    before_digest = :crypto.hash(:sha256, original)

    assert_single_anchor!(mutant, original)

    File.write!(mutant.file, replace_once(original, mutant.find, mutant.replace))

    outcome =
      try do
        vectors = run_tests(@vector_files)
        suite = if run_suite?, do: run_tests([]), else: :skipped

        %{vectors: vectors, suite: suite}
      after
        File.write!(mutant.file, original)
      end

    restored? = :crypto.hash(:sha256, File.read!(mutant.file)) == before_digest

    verdict = verdict(outcome.vectors)

    Map.merge(mutant, %{
      vectors: outcome.vectors,
      suite: outcome.suite,
      verdict: verdict,
      restored?: restored?,
      ok?: restored? and verdict == mutant.expect
    })
  end

  @spec assert_single_anchor!(map(), String.t()) :: :ok
  defp assert_single_anchor!(mutant, source) do
    case source |> String.split(mutant.find) |> length() do
      2 ->
        :ok

      count ->
        Mix.raise(
          "mutant #{mutant.id}: anchor matched #{count - 1} times in #{mutant.file} (expected exactly 1) — " <>
            "the site moved; update test/support/mutants/mutants.exs instead of guessing"
        )
    end
  end

  @spec replace_once(String.t(), String.t(), String.t()) :: String.t()
  defp replace_once(source, find, replace) do
    String.replace(source, find, replace, global: false)
  end

  # `:failed` is the only kill signal. `:invalid` means the mutant did not
  # compile, which is a static-analysis result, not a wire-format oracle.
  @spec run_tests([String.t()]) :: :passed | :failed | :invalid
  defp run_tests(files) do
    {output, status} =
      System.cmd("mix", ["test" | files],
        env: [{"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    cond do
      status == 0 -> :passed
      String.contains?(output, ["(CompileError)", "(SyntaxError)", "Compilation error"]) -> :invalid
      true -> :failed
    end
  end

  @spec verdict(:passed | :failed | :invalid) :: :killed | :survivor | :invalid
  defp verdict(:failed), do: :killed
  defp verdict(:passed), do: :survivor
  defp verdict(:invalid), do: :invalid

  @spec report([map()], boolean()) :: :ok
  defp report(results, run_suite?) do
    Mix.shell().info("\nplanted-mutant corpus (#{length(results)} mutants)\n")

    Enum.each(results, fn result ->
      suite = if run_suite?, do: " | suite: #{result.suite}", else: ""

      Mix.shell().info(
        "#{status_glyph(result)} #{String.pad_trailing(result.id, 34)} " <>
          "vectors: #{String.pad_trailing(to_string(result.vectors), 8)}" <>
          "-> #{String.pad_trailing(to_string(result.verdict), 10)}" <>
          "expected: #{String.pad_trailing(to_string(result.expect), 10)}#{suite}"
      )

      if !result.restored?, do: Mix.shell().error("   !! #{result.file} was not restored byte-exactly")
    end)

    Mix.shell().info("")

    :ok
  end

  @spec status_glyph(map()) :: String.t()
  defp status_glyph(%{ok?: true}), do: "ok  "
  defp status_glyph(_result), do: "FAIL"
end
