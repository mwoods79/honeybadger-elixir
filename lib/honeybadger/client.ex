defmodule Honeybadger.Client do
  alias Poison, as: JSON

  defstruct [:environment_name, :headers, :hostname, :origin, :proxy, :proxy_auth]

  @notices_endpoint "/v1/notices"
  @headers [
    {"Accept", "application/json"},
    {"Content-Type", "application/json"}
  ]

  def new do
    origin = Application.get_env(:honeybadger, :origin)
    api_key = Application.get_env(:honeybadger, :api_key)
    env_name = Application.get_env(:honeybadger, :environment_name)
    hostname = Application.get_env(:honeybadger, :hostname)
    proxy = Application.get_env(:honeybadger, :proxy)
    proxy_auth = Application.get_env(:honeybadger, :proxy_auth)
    %__MODULE__{origin: origin,
                headers: headers(api_key),
                environment_name: env_name,
                hostname: hostname,
                proxy: proxy,
                proxy_auth: proxy_auth}
  end

  def send_notice(%__MODULE__{} = client, notice, http_mod \\ HTTPoison) do
    encoded_notice = JSON.encode!(notice)
    do_send_notice(client, encoded_notice, http_mod, active_environment?())
  end

  defp do_send_notice(_client, _encoded_notice, _http_mod, false), do: {:ok, :unsent}
  defp do_send_notice(client, encoded_notice, http_mod, true) do
    case client.proxy do
      nil ->
        http_mod.post(
          client.origin <> @notices_endpoint, encoded_notice, client.headers
        )
      _ ->
        http_mod.post(
          client.origin <> @notices_endpoint, encoded_notice, client.headers,
          [proxy: client.proxy, proxy_auth: client.proxy_auth]
        )
    end
  end

  defp headers(api_key) do
    [{"X-API-Key", api_key}] ++ @headers
  end

  def active_environment? do
    env = Application.get_env(:honeybadger, :environment_name)
    exclude_envs = Application.get_env(:honeybadger, :exclude_envs, [:dev, :test])
    not env in exclude_envs
  end

end
