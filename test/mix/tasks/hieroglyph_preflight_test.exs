defmodule Mix.Tasks.Hieroglyph.PreflightTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias Mix.Tasks.Hieroglyph.Preflight

  @clean """
  # [Unreleased]

  # 1.6.2 - 2026-08-22

  * **Widened** — the descripex bound.

  # 1.6.1 - 2026-08-17

  * **Dependency refresh.**
  """

  describe "problems/2 in :ci mode" do
    test "is empty when mix.exs matches the newest released section" do
      assert Preflight.problems(facts(), :ci) == []
    end

    test "ignores entries parked under [Unreleased]" do
      assert Preflight.problems(facts(%{changelog: with_entry("*")}), :ci) == []
    end

    test "reports a version that has no CHANGELOG section" do
      assert [problem] = Preflight.problems(facts(%{version: "1.7.0"}), :ci)
      assert problem =~ "1.7.0 does not match"
      assert problem =~ "1.6.2"
    end

    test "reports a CHANGELOG with no released section at all" do
      only_unreleased = "# [Unreleased]\n\n* **Fixed** — a thing.\n"

      assert Preflight.problems(facts(%{changelog: only_unreleased}), :ci) ==
               ["CHANGELOG.md has no released `# X.Y.Z` section"]
    end

    test "does not apply the publish-only checks" do
      loose = %{dirty?: true, head_tags: [], head_on_remote?: false}

      assert Preflight.problems(facts(loose), :ci) == []
    end
  end

  describe "problems/2 in :publish mode" do
    test "is empty for a tagged, pushed, clean release commit" do
      assert Preflight.problems(facts(), :publish) == []
    end

    test "rejects entries still parked under [Unreleased]" do
      parked = facts(%{changelog: with_entry("*")})

      assert [problem] = Preflight.problems(parked, :publish)
      assert problem =~ "[Unreleased]"
    end

    test "counts a dash bullet as an [Unreleased] entry too" do
      parked = facts(%{changelog: with_entry("-")})

      assert [problem] = Preflight.problems(parked, :publish)
      assert problem =~ "[Unreleased]"
    end

    test "rejects a dirty working tree" do
      assert [problem] = Preflight.problems(facts(%{dirty?: true}), :publish)
      assert problem =~ "dirty"
    end

    test "rejects a HEAD no remote branch contains" do
      unpushed = facts(%{head_on_remote?: false})

      assert [problem] = Preflight.problems(unpushed, :publish)
      assert problem =~ "no remote branch"
    end

    test "rejects a HEAD that is not tagged for this version" do
      mistagged = facts(%{head_tags: ["v1.6.1"]})

      assert [problem] = Preflight.problems(mistagged, :publish)
      assert problem =~ "v1.6.2"
    end

    test "reports every failing check at once" do
      broken =
        facts(%{
          version: "9.9.9",
          dirty?: true,
          head_tags: [],
          head_on_remote?: false
        })

      assert length(Preflight.problems(broken, :publish)) == 4
    end
  end

  describe "mix hieroglyph.preflight" do
    test "--ci passes against this repository's own committed state" do
      # Assert the return value, not the printed line: under `--quiet` the
      # gate installs Mix.Shell.Quiet, which swallows `info/1`.
      capture_io(fn -> assert Preflight.run(["--ci"]) == :ok end)
    end

    test "raises listing the problems when the metadata disagrees" do
      root = temp_repo("# 9.9.9 - 2020-01-01\n\n* **Nothing.**\n")

      error =
        assert_raise Mix.Error, fn ->
          Preflight.run(["--ci", "--root", root])
        end

      assert error.message =~ "release preflight failed"
      assert error.message =~ "does not match"
    end

    test "--root checks another working tree" do
      root = temp_repo(File.read!("CHANGELOG.md"))

      capture_io(fn ->
        assert Preflight.run(["--ci", "--root", root]) == :ok
      end)
    end
  end

  @spec facts(map()) :: map()
  defp facts(overrides \\ %{}) do
    defaults = %{
      version: "1.6.2",
      changelog: @clean,
      head_tags: ["v1.6.2"],
      dirty?: false,
      head_on_remote?: true
    }

    Map.merge(defaults, overrides)
  end

  @spec with_entry(String.t()) :: String.t()
  defp with_entry(bullet) do
    String.replace(
      @clean,
      "# [Unreleased]\n",
      "# [Unreleased]\n\n#{bullet} **Fixed** — a thing.\n"
    )
  end

  @spec temp_repo(String.t()) :: Path.t()
  defp temp_repo(changelog) do
    name = "preflight_#{System.unique_integer([:positive])}"
    dir = Path.join(System.tmp_dir!(), name)
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "CHANGELOG.md"), changelog)
    on_exit(fn -> File.rm_rf!(dir) end)

    git = fn args ->
      System.cmd("git", args, cd: dir, stderr_to_stdout: true)
    end

    git.(["init", "--quiet"])

    git.([
      "-c",
      "user.email=t@t",
      "-c",
      "user.name=t",
      "commit",
      "--allow-empty",
      "--quiet",
      "-m",
      "root"
    ])

    dir
  end
end
