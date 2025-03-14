defmodule YouCache.Backend.Cachex do
  @moduledoc """
  Cachex backend implementation.
  
  This backend uses Cachex for caching, which provides an advanced
  distributed cache with many features. It requires the optional
  Cachex dependency to be installed.
  """
  
  @behaviour YouCache.Backend
  
  @impl true
  def init(registry, options) do
    # Verify that Cachex dependency is available
    with :ok <- check_dependencies() do
      # Build Cachex name
      cache_name = String.to_atom("#{registry}_cache")
      
      # Get fallback TTL
      fallback_ttl = Keyword.get(options, :fallback_ttl, nil)
      
      # Start Cachex
      case Cachex.start_link(cache_name, [
        fallback: fallback_handler(fallback_ttl)
      ]) do
        {:ok, _pid} ->
          {:ok, %{
            cache_name: cache_name,
            fallback_ttl: fallback_ttl
          }}
          
        {:error, {:already_started, _pid}} ->
          # Cache already exists, which is fine
          {:ok, %{
            cache_name: cache_name,
            fallback_ttl: fallback_ttl
          }}
          
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
  
  @impl true
  def get(state, key) do
    cache_name = state.cache_name
    
    # Get from Cachex
    case Cachex.get(cache_name, key) do
      {:ok, nil} ->
        # Value does not exist
        nil
        
      {:ok, value} ->
        # Value exists
        {:ok, value}
        
      {:error, error} ->
        # Error
        {:error, error}
    end
  end
  
  @impl true
  def put(state, key, value, ttl) do
    cache_name = state.cache_name
    
    # TTL already in milliseconds, no need to convert
    ttl_ms = ttl
    
    # Store in Cachex
    options = if ttl_ms, do: [ttl: ttl_ms], else: []
    
    case Cachex.put(cache_name, key, value, options) do
      {:ok, true} -> :ok
      {:ok, false} -> :ok  # Cachex returns false sometimes but it still succeeded
      {:error, error} -> {:error, error}
    end
  end
  
  @impl true
  def delete(state, key) do
    cache_name = state.cache_name
    
    # Delete from Cachex
    case Cachex.del(cache_name, key) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end
  
  @impl true
  def clear(state) do
    cache_name = state.cache_name
    
    # Clear Cachex cache
    case Cachex.clear(cache_name) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end
  
  @impl true
  def cleanup(state) do
    cache_name = state.cache_name
    
    # Use purge instead of expire to clean up expired entries
    case Cachex.purge(cache_name) do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end
  
  # Helper functions
  
  defp fallback_handler(nil), do: nil
  defp fallback_handler(ttl) do
    fn _key ->
      # This function is called by Cachex when a key is not found
      # You can customize this for your application to fetch data
      # from another source. For now, we'll just return nil.
      {:commit, nil, ttl: ttl}
    end
  end
  
  defp check_dependencies do
    # Check if Cachex is available
    if Code.ensure_loaded?(Cachex) do
      :ok
    else
      {:error, "Cachex dependency is not available. Add {:cachex, \"~> 3.6\"} to your dependencies."}
    end
  end
end