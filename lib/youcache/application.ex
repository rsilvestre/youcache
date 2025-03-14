defmodule YouCache.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # Define children and start the supervisor
    children = []
    
    opts = [strategy: :one_for_one, name: YouCache.Supervisor]
    Supervisor.start_link(children, opts)
  end
end