defmodule CodeQA.MixProject do
  use Mix.Project

  def project do
    [
      app: :codeqa,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: CodeQA.CLI],
      elixirc_paths: elixirc_paths(Mix.env()),
      preferred_envs: [precommit: :test],
      aliases: aliases(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        plt_local_path: "priv/plts",
        plt_core_path: "priv/plts"
      ],
      consolidate_protocols: Mix.env() != :test
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format"
      ],
      health: [
        "run -e 'CodeQA.CLI.main([\"health-report\", \".\", \"--ignore-paths\", \"test/**\"])'"
      ],
      "health.progress": [
        "run -e 'CodeQA.CLI.main([\"health-report\", \".\", \"--ignore-paths\", \"test/**\", \"--progress\"])'"
      ]
    ]
  end

  defp deps do
    [
      {:nx, "~> 0.9"},
      {:jason, "~> 1.4"},
      {:flow, "~> 1.2"},
      {:yaml_elixir, "~> 2.11"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ]
  end
end
