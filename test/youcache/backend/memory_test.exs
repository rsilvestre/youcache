defmodule YouCache.Backend.MemoryTest do
  use ExUnit.Case, async: true
  alias YouCache.Backend.Memory

  setup do
    registry = "test_memory_#{:erlang.unique_integer([:positive])}"
    {:ok, backend} = Memory.init(registry, [])
    %{backend: backend, registry: registry}
  end

  test "init/2 creates an ETS table", %{registry: registry} do
    table_name = String.to_atom("#{registry}_cache")
    assert :ets.info(table_name) != :undefined
    assert :ets.info(table_name, :type) == :set
  end

  test "put/4 and get/2", %{backend: backend} do
    # Put a value
    assert :ok = Memory.put(backend, "key1", "value1", nil)
    
    # Get the value
    assert {:ok, "value1"} = Memory.get(backend, "key1")
    
    # Get a non-existent value
    assert nil == Memory.get(backend, "non_existent")
  end

  test "put/4 with TTL", %{backend: backend} do
    # Put a value with TTL of 1 second
    assert :ok = Memory.put(backend, "key2", "value2", 1)
    
    # Value should exist before expiry
    assert {:ok, "value2"} = Memory.get(backend, "key2")
    
    # Wait for expiry
    :timer.sleep(1500)
    
    # Value should be expired
    assert {:expired, "value2"} = Memory.get(backend, "key2")
  end

  test "delete/2", %{backend: backend} do
    # Put a value
    Memory.put(backend, "key3", "value3", nil)
    
    # Delete the value
    assert :ok = Memory.delete(backend, "key3")
    
    # Value should be gone
    assert nil == Memory.get(backend, "key3")
  end

  test "clear/1", %{backend: backend} do
    # Put some values
    Memory.put(backend, "key4", "value4", nil)
    Memory.put(backend, "key5", "value5", nil)
    
    # Clear all values
    assert :ok = Memory.clear(backend)
    
    # Values should be gone
    assert nil == Memory.get(backend, "key4")
    assert nil == Memory.get(backend, "key5")
  end

  test "cleanup/1", %{backend: backend} do
    # Put a non-expired value
    Memory.put(backend, "key6", "value6", 3600)
    
    # Put an expired value
    Memory.put(backend, "key7", "value7", 1)
    
    # Wait for expiry
    :timer.sleep(1500)
    
    # Run cleanup
    assert :ok = Memory.cleanup(backend)
    
    # Non-expired value should exist
    assert {:ok, "value6"} = Memory.get(backend, "key6")
    
    # Expired value should be removed
    assert nil == Memory.get(backend, "key7")
  end
end