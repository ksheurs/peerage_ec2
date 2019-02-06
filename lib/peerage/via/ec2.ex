defmodule Peerage.Via.Ec2 do
  @moduledoc """
  A Peerage provider for easy clustering on AWS EC2 and Elastic Beanstalk.
  """
  @behaviour Peerage.Provider

  alias Peerage.Via.Ec2.Xml
  require Logger

  @doc """
  Periodically polls the metadata and EC2 API's for other nodes in the same "cluster."
  """
  def poll() do
    fetch_instance_id()
    |> fetch_cluster_name()
    |> fetch_running_services()
    |> format_services_list()
  end

  defp fetch_instance_id() do
    # EC2 provides an instance metadata API endpoint. We'll perform
    # a request to determine the ID of the running instance.
    #
    # AWS Documentation: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html
    metadata_api = 'http://169.254.169.254/latest/meta-data/instance-id'

    case request(metadata_api) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        to_string(body)

      error ->
        Logger.error("Peerage.Via.Ec2 hit error in fetch_instance_id: #{inspect(error)}")
        :error
    end
  end

  defp fetch_cluster_name(:error), do: :error

  defp fetch_cluster_name(instance_id) do
    # Having retrieved the instance_id of the current EC2 instance,
    # we'll peform a signed/authenticated request to Amazon's EC2
    # DescribeInstances API to retrieve the name of the `cluster`
    # of instances we've tagged.
    query = ExAws.EC2.describe_instances(filters: ["instance-id": [instance_id]])
    response = ExAws.request(query)

    case response do
      {:ok, %{status_code: 200, body: body}} ->
        body
        |> to_charlist
        |> Xml.parse()
        |> Xml.first("//tagSet/item[key='#{tag_name(:cluster)}']/value")
        |> Xml.text()

      error ->
        Logger.error("Peerage.Via.Ec2 hit error in fetch_cluster_name: #{inspect(error)}")
        :error
    end
  end

  defp fetch_running_services(:error), do: :error

  defp fetch_running_services(cluster_name) do
    # Having retrieved the cluster_name, we'll peform a
    # signed/authenticated request to Amazon's EC2
    # DescribeInstances API to retrieve all of the
    # running services in that cluster.
    #
    # Note that, an InstanceState code of 16 represents
    # a running EC2 service.
    #
    # AWS Documentation: http://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_InstanceState.html
    query =
      ExAws.EC2.describe_instances(
        filters: ["instance-state-code": ["16"], "tag:#{tag_name(:cluster)}": [cluster_name]]
      )

    response = ExAws.request(query)

    case response do
      {:ok, %{status_code: 200, body: body}} ->
        instances = body |> to_charlist |> Xml.parse()

        Enum.map(Xml.all(instances, "//instancesSet/item"), fn node ->
          host = Xml.first(node, "//privateIpAddress") |> Xml.text()
          service = Xml.first(node, "//tagSet/item[key='service']/value") |> Xml.text()
          %{host: host, name: service}
        end)

      error ->
        Logger.error("Peerage.Via.Ec2 hit error in fetch_running_services: #{inspect(error)}")
        :error
    end
  end

  defp format_services_list(:error), do: []

  defp format_services_list(services) do
    Enum.map(services, fn service ->
      String.to_atom("#{service.name}@" <> to_string(service.host))
    end)
  end

  defp describe_endpoint(filters) do
    query_string =
      filters
      |> Map.put("Action", "DescribeInstances")
      |> Map.put("Version", "2016-11-15")
      |> URI.encode_query()

    "https://ec2.amazonaws.com/?" <> query_string
  end

  defp request(uri), do: :httpc.request(:get, {uri, []}, [timeout: timeout()], [])
  defp tag_name(key), do: Application.fetch_env!(:peerage_ec2, :tags)[key]
  defp timeout(), do: Application.get_env(:peerage_ec2, :timeout, 1000)
end
