defmodule YouCache.Backend.Memory do
  @moduledoc """
  Memory backend implementation using ETS.
  
  This backend stores cache entries in an ETS table.
  """
  
  @behaviour YouCache.Backend
  
  @impl true
  def init(registry, _options) do
    # Create ETS table for this registry
    table_name = String.to_atom("#{registry}_cache")
    
    table = :ets.new(table_name, [:set, :public, :named_table, read_concurrency: true])
    
    {:ok, %{table: table}}
  end
  
  @impl true
  def get(state, key) do
    table = state.table
    
    case :ets.lookup(table, key) do
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
    :ets.insert(table, {key, value, expires_at})
    
    :ok
  end
  
  @impl true
  def delete(state, key) do
    table = state.table
    
    # Delete the value
    :ets.delete(table, key)
    
    :ok
  end
  
  @impl true
  def clear(state) do
    table = state.table
    
    # Clear the table
    :ets.delete_all_objects(table)
    
    :ok
  end
  
  @impl true
  def cleanup(state) do
    table = state.table
    now = System.system_time(:millisecond)
    
    # Find and delete expired entries
    # This is not the most efficient way to do this, but it works for demonstration
    keys_to_delete =
      :ets.tab2list(table)
      |> Enum.filter(fn {_key, _value, expires_at} -> 
        expires_at > 0 and expires_at < now
      end)
      |> Enum.map(fn {key, _value, _expires_at} -> key end)
    
    # Delete expired entries
    Enum.each(keys_to_delete, fn key ->
      :ets.delete(table, key)
    end)
    
    :ok
  end
end