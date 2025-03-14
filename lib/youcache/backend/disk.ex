defmodule YouCache.Backend.Disk do
  @moduledoc """
  Disk backend implementation using DETS.
  
  This backend stores cache entries in a DETS table on disk.
  """
  
  @behaviour YouCache.Backend
  
  @default_cache_dir "priv/youcache"
  
  @impl true
  def init(registry, options) do
    # Get cache directory from options or use default
    cache_dir = Keyword.get(options, :cache_dir, @default_cache_dir)
    
    # Create cache directory if it doesn't exist
    with :ok <- create_cache_dir(cache_dir) do
      # Table file path
      table_file = Path.join(cache_dir, "#{registry}_cache.dets")
      
      # Create DETS table
      case :dets.open_file(String.to_atom("#{registry}_cache"), [
        file: String.to_charlist(table_file),
        type: :set
      ]) do
        {:ok, table} ->
          {:ok, %{table: table, table_file: table_file}}
          
        {:error, reason} ->
          {:error, {:dets_error, reason}}
      end
    else
      {:error, reason} -> {:error, {:directory_error, reason}}
    end
  end
  
  @impl true
  def get(state, key) do
    table = state.table
    
    case :dets.lookup(table, key) do
      [{^key, value, expires_at}] ->
        # Check if the value has expired
        now = System.system_time(:millisecond)
        
        if expires_at > 0 and expires_at < now do
          # Value has expired
          {:expired, value}
        else
          # Value is valid
          {:ok, value}
        end
        
      [] ->
        # Value does not exist
        nil
    end
  end
  
  @impl true
  def put(state, key, value, ttl) do
    table = state.table
    
    # Calculate expiration time
    expires_at =
      if ttl do
        System.system_time(:millisecond) + ttl
      else
        0  # 0 means no expiration
      end
    
    # Store the value
    :dets.insert(table, {key, value, expires_at})
    
    :ok
  end
  
  @impl true
  def delete(state, key) do
    table = state.table
    
    # Delete the value
    :dets.delete(table, key)
    
    :ok
  end
  
  @impl true
  def clear(state) do
    table = state.table
    
    # Clear the table
    :dets.delete_all_objects(table)
    
    :ok
  end
  
  @impl true
  def cleanup(state) do
    table = state.table
    now = System.system_time(:millisecond)
    
    # Find and delete expired entries
    # This is not the most efficient way to do this, but it works for demonstration
    keys_to_delete =
      :dets.match_object(table, {:_, :_, :_})
      |> Enum.filter(fn {_key, _value, expires_at} -> 
        expires_at > 0 and expires_at < now
      end)
      |> Enum.map(fn {key, _value, _expires_at} -> key end)
    
    # Delete expired entries
    Enum.each(keys_to_delete, fn key ->
      :dets.delete(table, key)
    end)
    
    :ok
  end
  
  # Helper function to create cache directory
  defp create_cache_dir(cache_dir) do
    case File.mkdir_p(cache_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end