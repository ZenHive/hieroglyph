defmodule Mix.Tasks.Hieroglyph.Preflight do
  @shortdoc "Verify version, CHANGELOG and git state agree before publishing"

  @moduledoc """
  Release preflight: fails when `mix.exs`, `CHANGELOG.md` and git disagree.

      mix hieroglyph.preflight              # full publish gate
      mix hieroglyph.preflight --ci         # only the always-true invariants
      mix hieroglyph.preflight --root DIR   # check another checkout

  `--root` points the file and git reads at another working tree, so a
  release worktree can be checked without leaving the current one. The
  `mix.exs` version always comes from the running project.

  Wired two ways. `--ci` runs as a `mix ci` step and asserts the single
  invariant that holds *between* releases: the `mix.exs` version has a
  matching released `CHANGELOG.md` section. The full gate shadows
  `mix hex.publish`, so a release cannot go out with entries still parked
  under `[Unreleased]`, a dirty tree, a HEAD no remote has, or a missing
  `v<version>` tag.

  It deliberately does **not** run the test suite. `mix ci` is that gate;
  this task only checks that the release metadata tells the truth about
  the code being published.
  """

  use Mix.Task

  alias Mix.Project

  @typedoc "A `CHANGELOG.md` section title paired with its body lines."
  @type section :: {String.t(), [String.t()]}

  @typedoc "Repository state the checks are decided from."
  @type facts :: %{
          version: String.t(),
          changelog: String.t(),
          head_tags: [String.t()],
          dirty?: boolean(),
          head_on_remote?: boolean()
        }

  @header ~r/^# (?<title>.+)$/
  @release ~r/^(?<version>\d+\.\d+\.\d+)\b/
  @unreleased "[Unreleased]"

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {opts, _positional} =
      OptionParser.parse!(args, strict: [ci: :boolean, root: :string])

    mode = if opts[:ci], do: :ci, else: :publish
    root = opts[:root] || File.cwd!()

    case problems(gather(root), mode) do
      [] ->
        Mix.shell().info("preflight ok (#{mode})")

      problems ->
        listed = Enum.map_join(problems, "\n", &("  * " <> &1))
        Mix.raise("release preflight failed:\n\n" <> listed)
    end
  end

  @doc """
  Returns a list of human-readable problems with `facts`, empty when the
  release metadata is consistent.

  `:ci` checks only the version/CHANGELOG agreement, which must hold on
  every commit. `:publish` adds the checks that are meaningful only at
  the moment of a release.
  """
  @spec problems(facts(), :ci | :publish) :: [String.t()]
  def problems(facts, mode) do
    sections = sections(facts.changelog)
    problems = version_problems(facts.version, sections)

    case mode do
      :ci -> problems
      :publish -> problems ++ publish_problems(facts, sections)
    end
  end

  @spec version_problems(String.t(), [section()]) :: [String.t()]
  defp version_problems(version, sections) do
    case latest_release(sections) do
      nil -> ["CHANGELOG.md has no released `# X.Y.Z` section"]
      ^version -> []
      other -> [version_mismatch(version, other)]
    end
  end

  @spec version_mismatch(String.t(), String.t()) :: String.t()
  defp version_mismatch(version, newest) do
    "mix.exs version #{version} does not match the newest " <>
      "CHANGELOG.md section #{newest}"
  end

  @spec publish_problems(facts(), [section()]) :: [String.t()]
  defp publish_problems(facts, sections) do
    tag = "v" <> facts.version

    [
      {unreleased_entries(sections) != [], unreleased_problem(facts.version)},
      {facts.dirty?, "working tree is dirty — commit or stash first"},
      {not facts.head_on_remote?, "HEAD is on no remote branch — push first"},
      {tag not in facts.head_tags, tag_problem(tag)}
    ]
    |> Enum.filter(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  @spec unreleased_problem(String.t()) :: String.t()
  defp unreleased_problem(version) do
    "CHANGELOG.md still has entries under #{@unreleased} — fold them " <>
      "into #{version} or cut a higher version"
  end

  @spec tag_problem(String.t()) :: String.t()
  defp tag_problem(tag) do
    "tag #{tag} does not point at HEAD — tag the release commit first"
  end

  @spec latest_release([section()]) :: String.t() | nil
  defp latest_release(sections) do
    Enum.find_value(sections, fn {title, _body} ->
      case Regex.named_captures(@release, title) do
        %{"version" => version} -> version
        nil -> nil
      end
    end)
  end

  @spec unreleased_entries([section()]) :: [String.t()]
  defp unreleased_entries(sections) do
    case List.keyfind(sections, @unreleased, 0) do
      {_title, body} -> Enum.filter(body, &entry?/1)
      nil -> []
    end
  end

  @spec entry?(String.t()) :: boolean()
  defp entry?(line) do
    trimmed = String.trim_leading(line)
    String.starts_with?(trimmed, "* ") or String.starts_with?(trimmed, "- ")
  end

  @spec sections(String.t()) :: [section()]
  defp sections(changelog) do
    changelog
    |> String.split("\n")
    |> Enum.reduce([], &collect_line/2)
    |> Enum.map(fn {title, body} -> {title, Enum.reverse(body)} end)
    |> Enum.reverse()
  end

  @spec collect_line(String.t(), [section()]) :: [section()]
  defp collect_line(line, acc) do
    case {Regex.named_captures(@header, line), acc} do
      {%{"title" => title}, _} -> [{String.trim(title), []} | acc]
      {nil, [{title, body} | rest]} -> [{title, [line | body]} | rest]
      {nil, []} -> []
    end
  end

  @spec gather(Path.t()) :: facts()
  defp gather(root) do
    tags = git(root, ["tag", "--points-at", "HEAD"])
    remotes = git(root, ["branch", "--remotes", "--contains", "HEAD"])

    %{
      version: Project.config()[:version],
      changelog: File.read!(Path.join(root, "CHANGELOG.md")),
      head_tags: String.split(tags, "\n", trim: true),
      dirty?: git(root, ["status", "--porcelain"]) != "",
      head_on_remote?: remotes != ""
    }
  end

  @spec git(Path.t(), [String.t()]) :: String.t()
  defp git(root, args) do
    case System.cmd("git", args, cd: root, stderr_to_stdout: true) do
      {out, 0} ->
        String.trim(out)

      {out, status} ->
        Mix.raise("`git #{Enum.join(args, " ")}` exited #{status}:\n#{out}")
    end
  end
end
