defmodule YouCache.ServerCallbacks do
  @moduledoc """
  Server callback functions for the YouCache module.
  """
  
  # This module contains callbacks that will be imported in modules
  # that use YouCache
  
  @doc false
  defmacro __using__(_opts) do
    quote do
      import YouCache.ServerCallbacks.Impl
      
      # Server Callbacks
      @impl true
      def init(opts), do: do_init(opts, @ttl, @cleanup_interval, @registries)
      
      @impl true
      def handle_call({:get, registry, key, default}, from, state), 
        do: do_handle_get(registry, key, default, from, state)
      
      @impl true
      def handle_call({:put, registry, key, value, ttl}, from, state),
        do: do_handle_put(registry, key, value, ttl, from, state)
      
      @impl true
      def handle_call({:delete, registry, key}, from, state),
        do: do_handle_delete(registry, key, from, state)
      
      @impl true
      def handle_call(:clear, from, state),
        do: do_handle_clear(from, state)
      
      @impl true
      def handle_info(:cleanup, state),
        do: do_handle_cleanup(state)
    end
  end
end

defmodule YouCache.ServerCallbacks.Impl do
  @moduledoc false
  
  # Implementation of the server callbacks
  
  def do_init(opts, default_ttl, default_cleanup_interval, registries) do
    # Get TTL and cleanup interval from options (in milliseconds)
    ttl = Keyword.get(opts, :ttl, default_ttl)
    cleanup_interval = Keyword.get(opts, :cleanup_interval, default_cleanup_interval)

    # Get backend configurations from application environment
    app_name = Keyword.get(opts, :app_name)
    backends_config = get_backends_config(app_name, opts)

    # Initialize backends for each registry
    backends = init_backends(registries, backends_config)

    # Schedule cleanup
    schedule_cleanup(cleanup_interval)

    {:ok, %{backends: backends, ttl: ttl, cleanup_interval: cleanup_interval}}
  end
  
  def do_handle_get(registry, key, default, _from, state) do
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
        other -> YouCache.Response.normalize(other, default)
      end
      
    {:reply, response, state}
  end
  
  def do_handle_put(registry, key, value, ttl, _from, state) do
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
  
  def do_handle_delete(registry, key, _from, state) do
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
  
  def do_handle_clear(_from, state) do
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
  
  def do_handle_cleanup(state) do
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
  def init_backends(registries, backends_config) do
    Enum.reduce(registries, %{}, fn registry, acc ->
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
  end
  
  # Helper functions that need to be imported
  def get_backends_config(nil, opts) do
    # Get from module options if app_name not provided
    Keyword.get(opts, :backends_config, %{})
  end

  def get_backends_config(app_name, _opts) do
    # Get from application environment
    Application.get_env(app_name, :cache_backends, %{})
  end

  def schedule_cleanup(interval_ms) do
    # Schedule cleanup after the interval
    Process.send_after(self(), :cleanup, interval_ms)
  end
end