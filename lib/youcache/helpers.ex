defmodule YouCache.Helpers do
  @moduledoc """
  Helper functions for the YouCache module.
  """
  
  # Import the implementation functions from the ServerCallbacks.Impl module
  @doc false
  defmacro __using__(_opts) do
    quote do
      import YouCache.ServerCallbacks.Impl, only: [
        get_backends_config: 2,
        schedule_cleanup: 1
      ]
    end
  end
end