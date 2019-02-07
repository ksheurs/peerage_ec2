# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :peerage, via: Peerage.Via.Ec2

config :peerage_ec2,
  tags: [{:cluster, "cluster"}, {:service, "service"}],
  timeout: 1000
