defmodule Peerage.Via.Ec2Test do
  use ExUnit.Case, async: false

  import Mock
  alias Peerage.Via.Ec2
  # alias Peerage.Via.Ec2.SignedUrl.RequestTime

  @instance_id "my-instance-id"

  setup do
    metadata_api_url = 'http://169.254.169.254/latest/meta-data/instance-id'

    cluster_name_response = File.read!("./test/support/fixtures/fetch_cluster_name.xml")

    running_services_response = File.read!("./test/support/fixtures/fetch_running_services.xml")

    get_cluster_name_query = %ExAws.Operation.Query{
      action: :describe_instances,
      params: %{
        "Action" => "DescribeInstances",
        "Filter.1.Name" => "instance-id",
        "Filter.1.Value.1" => "my-instance-id",
        "Version" => "2016-11-15"
      },
      path: "/",
      parser: &ExAws.Utils.identity/2,
      service: :ec2
    }

    get_running_instances_query = %ExAws.Operation.Query{
      action: :describe_instances,
      params: %{
        "Action" => "DescribeInstances",
        "Filter.1.Name" => "instance-state-code",
        "Filter.1.Value.1" => "16",
        "Filter.2.Name" => "tag:cluster",
        "Filter.2.Value.1" => "staging",
        "Version" => "2016-11-15"
      },
      parser: &ExAws.Utils.identity/2,
      path: "/",
      service: :ec2
    }

    {:ok,
     get_cluster_name_query: get_cluster_name_query,
     get_running_instances_query: get_running_instances_query,
     metadata_api_url: metadata_api_url,
     cluster_name_response: cluster_name_response,
     running_services_response: running_services_response}
  end

  describe "poll/0" do
    test "returns a list of instances from EC2", %{
      get_cluster_name_query: get_cluster_name_query,
      get_running_instances_query: get_running_instances_query,
      metadata_api_url: metadata_api_url,
      cluster_name_response: cluster_name_response,
      running_services_response: running_services_response
    } do
      with_mocks([
        {ExAws, [],
         [
           request: fn
             ^get_cluster_name_query ->
               {:ok, %{status_code: 200, body: cluster_name_response}}

             ^get_running_instances_query ->
               {:ok, %{status_code: 200, body: running_services_response}}
           end
         ]},
        {:httpc, [],
         [
           request: fn :get, {url, _}, _, _ ->
             case url do
               ^metadata_api_url -> successful_response(@instance_id)
             end
           end
         ]}
      ]) do
        assert Ec2.poll() == [:"gardiner@172.21.22.53", :"falkner@170.31.21.52"]
      end
    end

    test "returns an empty list when metadata request fails", %{
      metadata_api_url: metadata_api_url
    } do
      with_mocks([
        {:httpc, [], [request: fn :get, {^metadata_api_url, _}, _, _ -> failed_response() end]}
      ]) do
        assert Ec2.poll() == []
      end
    end

    test "returns an empty list when cluster name request fails", %{
      metadata_api_url: metadata_api_url,
      get_cluster_name_query: get_cluster_name_query
    } do
      with_mocks([
        {ExAws, [],
         [request: fn ^get_cluster_name_query -> {:ok, %{status_code: 403, body: ""}} end]},
        {:httpc, [],
         [
           request: fn :get, {url, _}, _, _ ->
             case url do
               ^metadata_api_url -> successful_response(@instance_id)
             end
           end
         ]}
      ]) do
        assert Ec2.poll() == []
      end
    end

    test "returns an empty list when running services request fails", %{
      metadata_api_url: metadata_api_url,
      get_cluster_name_query: get_cluster_name_query,
      get_running_instances_query: get_running_instances_query,
      cluster_name_response: cluster_name_response
    } do
      with_mocks([
        {ExAws, [],
         [
           request: fn
             ^get_cluster_name_query -> {:ok, %{status_code: 200, body: cluster_name_response}}
             ^get_running_instances_query -> {:ok, %{status_code: 403, body: ""}}
           end
         ]},
        {:httpc, [],
         [
           request: fn :get, {url, _}, _, _ ->
             case url do
               ^metadata_api_url -> successful_response(@instance_id)
             end
           end
         ]}
      ]) do
        assert Ec2.poll() == []
      end
    end
  end

  defp successful_response(body), do: httpc_response(200, body)
  defp failed_response(), do: httpc_response(403)

  defp httpc_response(code, body \\ ""), do: {:ok, {{"", code, ""}, %{}, body}}
end
