defmodule Raga.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RagaWeb.Telemetry,
      Raga.Repo,
      {DNSCluster, query: Application.get_env(:raga, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Raga.PubSub},
      # Start the Finch HTTP client for sending emails and API requests
      {Finch, name: Raga.Finch},
      # Start Groq client
      Raga.Groq.Client,
      # Start to serve requests, typically the last entry
      RagaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Raga.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RagaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
