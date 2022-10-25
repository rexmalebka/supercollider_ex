defmodule Supercollider.MixProject do
  use Mix.Project

  def project do
    [
      app: :supercollider,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: "Elixir implementation of Supercollider client.",
      source_url: "https://github.com/rexmalebka/supercollider_ex",
      docs: [
        authors: ["rexmalebka"],
        deps: [OSC: "https://hexdocs.pm/osc/api-reference.html"],
        main: "/readme",
        api_reference: false,
        extras: [
          "README.md"
        ],
        groups_for_modules: [
          "Supercollider": [
            Supercollider
          ],
          structs: [
            ~r"SC*"
          ]
        ],
        nest_modules_by_prefix: [
          Supercollider,
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:osc, "~> 0.1.2"},
      # {:osc, git: "https://github.com/erlsci/osc", tag: "2.1.0"}
      {:earmark, "~> 1.2", only: :dev},
      {:ex_doc, "~> 0.19", only: :dev}
    ]
  end

  defp package() do
    [
      name: "supercollider",

    ]
  end
end
