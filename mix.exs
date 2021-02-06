defmodule Lfs.MixProject do
  use Mix.Project

  def project do
    [
      app: :lfs,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Lfs.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:redis, "~> 0.1"},
      {:ex_aws, "~> 2.0"},
      {:ex_aws_dynamo, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.9"},
      {:configparser_ex, "~> 4.0"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.2"},
      {:poison, "~> 4.0"},
      {:joken, "~> 2.2"},
      {:distillery, "~> 2.1"},
      {:redix, ">= 0.0.0"},
      {:fast64, "~> 0.1.3"},
      {:sweet_xml, "~> 0.6"},
      {:minne, "~> 0.1.0", git: "https://github.com/harmon25/minne.git"},
      {:mock, "~> 0.3.0", only: :test}
    ]
  end
end
