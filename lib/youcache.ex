defmodule YouCache do
  @moduledoc """
  A flexible caching library for Elixir applications with multiple backend options.

  YouCache provides a consistent API for caching operations with
  support for various backends (Memory, Disk, S3, Cachex).
  """
  
  @doc """
  Use this macro to create a cache module with the specified registries.

  ## Example

      defmodule MyApp.Cache do
        use YouCache,
          registries: ["my_registry"]
        
        # Define domain-specific helper functions
        def get_item(item_id) do
          get("my_registry", item_id)
        end
      end
  """
  defmacro __using__(opts) do
    quote do
      use GenServer
      alias YouCache.Backend
      alias YouCache.Response
      
      # Define module attributes
      @registries unquote(opts)[:registries] || []
      
      # Time units in milliseconds for compatibility with existing implementations
      @ttl 86_400_000  # 1 day in milliseconds
      @cleanup_interval 3_600_000  # 1 hour in milliseconds
      
      # Import functionality from supporting modules
      use YouCache.ClientAPI
      use YouCache.ServerCallbacks
      use YouCache.Helpers
    end
  end
end