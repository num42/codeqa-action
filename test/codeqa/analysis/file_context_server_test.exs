defmodule CodeQA.Analysis.FileContextServerTest do
  use ExUnit.Case, async: true

  alias CodeQA.Analysis.FileContextServer
  alias CodeQA.Engine.{FileContext, Pipeline}

  setup do
    {:ok, pid} = FileContextServer.start_link()
    {:ok, pid: pid}
  end

  test "get/2 returns a Pipeline.FileContext", %{pid: pid} do
    content = "defmodule Foo do\n  def bar, do: :ok\nend\n"
    ctx = FileContextServer.get(pid, content)
    assert %FileContext{} = ctx
    assert is_binary(ctx.content)
  end

  test "get/2 returns identical struct on second call without rebuilding", %{pid: pid} do
    content = "defmodule Foo do\n  def bar, do: :ok\nend\n"
    ctx1 = FileContextServer.get(pid, content)
    ctx2 = FileContextServer.get(pid, content)
    assert ctx1 == ctx2
  end

  test "get/2 with different content returns different results", %{pid: pid} do
    ctx_a = FileContextServer.get(pid, "defmodule A do\nend\n")
    ctx_b = FileContextServer.get(pid, "defmodule B do\n  def foo, do: 1\nend\n")
    assert ctx_a != ctx_b
  end

  test "get/2 matches Pipeline.build_file_context/1 directly", %{pid: pid} do
    content = "x = 1\ny = 2\n"
    expected = Pipeline.build_file_context(content)
    result = FileContextServer.get(pid, content)
    assert result == expected
  end
end
