defmodule CodeQA.Analysis.BehaviorConfigServerTest do
  use ExUnit.Case, async: true

  alias CodeQA.Analysis.BehaviorConfigServer

  setup do
    {:ok, pid} = BehaviorConfigServer.start_link()
    {:ok, pid: pid}
  end

  test "get_all_behaviors/1 returns a non-empty map of categories", %{pid: pid} do
    behaviors = BehaviorConfigServer.get_all_behaviors(pid)
    assert is_map(behaviors)
    assert map_size(behaviors) > 0

    Enum.each(behaviors, fn {category, list} ->
      assert is_binary(category)
      assert is_list(list)
      assert list != []

      Enum.each(list, fn {behavior, data} ->
        assert is_binary(behavior)
        assert is_map(data)
      end)
    end)
  end

  test "get_all_behaviors/1 matches YamlElixir direct reads", %{pid: pid} do
    behaviors = BehaviorConfigServer.get_all_behaviors(pid)
    yaml_dir = "priv/combined_metrics"

    {:ok, files} = File.ls(yaml_dir)

    Enum.each(files |> Enum.filter(&String.ends_with?(&1, ".yml")), fn yml_file ->
      category = String.trim_trailing(yml_file, ".yml")
      {:ok, data} = YamlElixir.read_from_file(Path.join(yaml_dir, yml_file))

      expected_behaviors =
        data |> Enum.filter(fn {_k, v} -> is_map(v) end) |> Enum.map(&elem(&1, 0))

      server_behaviors = Map.get(behaviors, category, []) |> Enum.map(&elem(&1, 0))
      assert Enum.sort(expected_behaviors) == Enum.sort(server_behaviors)
    end)
  end

  test "get_scalars/3 returns a map of {group, key} => scalar", %{pid: pid} do
    behaviors = BehaviorConfigServer.get_all_behaviors(pid)
    {category, [{behavior, _data} | _]} = Enum.at(behaviors, 0)

    scalars = BehaviorConfigServer.get_scalars(pid, category, behavior)
    assert is_map(scalars)

    Enum.each(scalars, fn {{group, key}, scalar} ->
      assert is_binary(group)
      assert is_binary(key)
      assert is_float(scalar)
    end)
  end

  test "get_scalars/3 returns empty map for unknown behavior", %{pid: pid} do
    assert BehaviorConfigServer.get_scalars(pid, "nonexistent", "also_nonexistent") == %{}
  end

  test "get_log_baseline/3 returns a float", %{pid: pid} do
    behaviors = BehaviorConfigServer.get_all_behaviors(pid)
    {category, [{behavior, _data} | _]} = Enum.at(behaviors, 0)

    baseline = BehaviorConfigServer.get_log_baseline(pid, category, behavior)
    assert is_float(baseline)
  end

  test "get_log_baseline/3 returns 0.0 for unknown behavior", %{pid: pid} do
    assert BehaviorConfigServer.get_log_baseline(pid, "nonexistent", "also_nonexistent") == 0.0
  end
end
