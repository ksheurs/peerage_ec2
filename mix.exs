defmodule Peerage.Via.Ec2.Mixfile do
  use Mix.Project

  def project do
    [
      app: :peerage_ec2,
      version: "1.0.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      name: "Peerage EC2",
      description: description(),
      source_url: "https://github.com/BoweryFarming/peerage_ec2"
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
      {:ex_aws, "~> 1.1"},
      {:ex_doc, "~> 0.18.1", only: :dev, runtime: false},
      {:hackney, "~> 1.10"},
      {:sweet_xml, "~> 0.6.5"},
    ]
  end

  def package do
    [maintainers: ["Kevin Sheurs", "Dylan Fareed", "Henry Sztul"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/BoweryFarming/peerage_ec2",
              "Docs" => "https://hexdocs.pm/peerage_ec2/readme.html"}]
  end

  def description do
    """
    A Peerage provider for easy clustering on AWS EC2 and Elastic Beanstalk
    """
  end
end
