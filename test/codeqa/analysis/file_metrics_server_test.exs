defmodule CodeQA.Analysis.FileMetricsServerTest do
  use ExUnit.Case, async: true

  alias CodeQA.Analysis.FileMetricsServer

  defp build_registry do
    CodeQA.Engine.Analyzer.build_registry()
  end

  setup do
    {:ok, pid} = FileMetricsServer.start_link()
    {:ok, pid: pid}
  end

  describe "populate/3 and get_by_path/2" do
    test "returns pre-populated baseline metrics for a path", %{pid: pid} do
      content = "defmodule A do\n  def foo, do: 1\nend\n"

      pipeline_result = %{
        "files" => %{
          "lib/a.ex" => %{"metrics" => %{"halstead" => %{"tokens" => 5.0}}}
        }
      }

      files_map = %{"lib/a.ex" => content}
      :ok = FileMetricsServer.populate(pid, pipeline_result, files_map)

      metrics = FileMetricsServer.get_by_path(pid, "lib/a.ex")
      assert metrics == %{"halstead" => %{"tokens" => 5.0}}
    end

    test "returns nil for unknown path", %{pid: pid} do
      :ok = FileMetricsServer.populate(pid, %{"files" => %{}}, %{})
      assert FileMetricsServer.get_by_path(pid, "nonexistent.ex") == nil
    end
  end

  describe "get_for_content/3" do
    test "computes and caches metrics on first call", %{pid: pid} do
      registry = build_registry()
      content = "defmodule A do\n  def foo, do: 1\nend\n"

      metrics = FileMetricsServer.get_for_content(pid, registry, content)
      assert is_map(metrics)
      assert map_size(metrics) > 0
    end

    test "returns identical result on second call (cache hit)", %{pid: pid} do
      registry = build_registry()
      content = "defmodule A do\n  def foo, do: 1\nend\n"

      m1 = FileMetricsServer.get_for_content(pid, registry, content)
      m2 = FileMetricsServer.get_for_content(pid, registry, content)
      assert m1 == m2
    end

    test "different content returns different metrics", %{pid: pid} do
      registry = build_registry()
      ma = FileMetricsServer.get_for_content(pid, registry, "x = 1\n")

      mb =
        FileMetricsServer.get_for_content(
          pid,
          registry,
          String.duplicate("def foo(a, b), do: a + b\n", 20)
        )

      assert ma != mb
    end

    test "populate cross-indexes hash so get_for_content hits cache", %{pid: pid} do
      registry = build_registry()
      content = "defmodule A do\n  def foo, do: 1\nend\n"

      pipeline_result = %{
        "files" => %{
          "lib/a.ex" => %{
            "metrics" => %{"halstead" => %{"tokens" => 99.0}}
          }
        }
      }

      files_map = %{"lib/a.ex" => content}
      :ok = FileMetricsServer.populate(pid, pipeline_result, files_map)

      # Should hit the hash-keyed cache entry seeded from pipeline_result
      metrics = FileMetricsServer.get_for_content(pid, registry, content)
      assert metrics == %{"halstead" => %{"tokens" => 99.0}}
    end
  end
end
