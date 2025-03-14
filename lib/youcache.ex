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

      @registries unquote(opts)[:registries] || []
      # Time units in milliseconds for compatibility with existing implementations
      @ttl 86_400_000  # 1 day in milliseconds
      @cleanup_interval 3_600_000  # 1 hour in milliseconds

      # Client API

      @doc """
      Starts the cache server with the given options.
      """
      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      @doc """
      Gets a value from the cache.

      ## Examples

          iex> get("registry", "key")
          {:ok, "value"}

          iex> get("registry", "missing_key")
          {:miss, nil}
      """
      def get(registry, key, default \\ nil) do
        GenServer.call(__MODULE__, {:get, registry, key, default})
      end

      @doc """
      Puts a value in the cache.

      ## Examples

          iex> put("registry", "key", "value")
          :ok
      """
      def put(registry, key, value, ttl \\ nil) do
        GenServer.call(__MODULE__, {:put, registry, key, value, ttl})
      end

      @doc """
      Deletes a value from the cache.

      ## Examples

          iex> delete("registry", "key")
          :ok
      """
      def delete(registry, key) do
        GenServer.call(__MODULE__, {:delete, registry, key})
      end

      @doc """
      Clears all values from the cache.

      ## Examples

          iex> clear()
          :ok
      """
      def clear do
        GenServer.call(__MODULE__, :clear)
      end

      # Server Callbacks

      @impl true
      def init(opts) do
        # Get TTL and cleanup interval from options (in milliseconds)
        ttl = Keyword.get(opts, :ttl, @ttl)
        cleanup_interval = Keyword.get(opts, :cleanup_interval, @cleanup_interval)

        # Get backend configurations from application environment
        app_name = Keyword.get(opts, :app_name)
        backends_config = get_backends_config(app_name, opts)

        # Initialize backends for each registry
        backends =
          Enum.reduce(@registries, %{}, fn registry, acc ->
            # Get backend configuration for this registry
            config = Map.get(backends_config, registry, [])
            
            # Initialize backend
            backend_module = Keyword.get(config, :backend, YouCache.Backend.Memory)
            backend_options = Keyword.get(config, :backend_options, [])
            
            backend = 
              case backend_module.init(registry, backend_options) do
                {:ok, backend_state} ->
                  %{
                    module: backend_module,
                    state: backend_state
                  }
                
                {:error, reason} ->
                  # Log error and fall back to memory backend
                  IO.warn("Failed to initialize backend for #{registry}: #{inspect(reason)}")
                  IO.warn("Falling back to memory backend")
                  
                  # Initialize memory backend as fallback
                  {:ok, fallback_state} = YouCache.Backend.Memory.init(registry, [])
                  
                  %{
                    module: YouCache.Backend.Memory,
                    state: fallback_state
                  }
              end
              
            Map.put(acc, registry, backend)
          end)

        # Schedule cleanup
        schedule_cleanup(cleanup_interval)

        {:ok, %{backends: backends, ttl: ttl, cleanup_interval: cleanup_interval}}
      end

      @impl true
      def handle_call({:get, registry, key, default}, _from, state) do
        backends = state.backends
        
        result =
          case Map.get(backends, registry) do
            nil ->
              # Registry not found
              {:error, :registry_not_found}
              
            backend ->
              # Call backend get
              backend.module.get(backend.state, key)
          end
          
        # Special case for nil results from the backend to match expectations in tests
        response = 
          case result do
            nil -> {:miss, default}
            other -> Response.normalize(other, default)
          end
          
        {:reply, response, state}
      end

      @impl true
      def handle_call({:put, registry, key, value, ttl}, _from, state) do
        backends = state.backends
        ttl = ttl || state.ttl
        
        # Backends now expect milliseconds directly - no conversion needed
        
        result = 
          case Map.get(backends, registry) do
            nil ->
              # Registry not found
              {:error, :registry_not_found}
              
            backend ->
              # Call backend put
              case backend.module.put(backend.state, key, value, ttl) do
                :ok -> 
                  # Return the value for compatibility with existing cache implementations
                  {:ok, value}
                error -> 
                  error
              end
          end
        
        {:reply, result, state}
      end

      @impl true
      def handle_call({:delete, registry, key}, _from, state) do
        backends = state.backends
        
        result = 
          case Map.get(backends, registry) do
            nil ->
              # Registry not found, do nothing
              {:error, :registry_not_found}
              
            backend ->
              # Call backend delete
              case backend.module.delete(backend.state, key) do
                :ok -> {:ok, nil}
                error -> error
              end
          end
        
        {:reply, result, state}
      end

      @impl true
      def handle_call(:clear, _from, state) do
        backends = state.backends
        
        # Clear all backends
        results = 
          Enum.map(backends, fn {_registry, backend} ->
            backend.module.clear(backend.state)
          end)
        
        # If any errors, return the first error
        result = 
          case Enum.find(results, fn
            :ok -> false
            {:error, _} -> true
          end) do
            nil -> {:ok, nil}
            error -> error
          end
          
        {:reply, result, state}
      end

      @impl true
      def handle_info(:cleanup, state) do
        backends = state.backends
        
        # Cleanup all backends
        Enum.each(backends, fn {_registry, backend} ->
          backend.module.cleanup(backend.state)
        end)
        
        # Reschedule cleanup
        schedule_cleanup(state.cleanup_interval)
        
        {:noreply, state}
      end

      # Helper functions

      defp get_backends_config(nil, opts) do
        # Get from module options if app_name not provided
        Keyword.get(opts, :backends_config, %{})
      end

      defp get_backends_config(app_name, _opts) do
        # Get from application environment
        Application.get_env(app_name, :cache_backends, %{})
      end

      defp schedule_cleanup(interval_ms) do
        # Schedule cleanup after the interval
        Process.send_after(self(), :cleanup, interval_ms)
      end
    end
  end
end