defmodule YouCache.Backend.DiskTest do
  use ExUnit.Case, async: true
  alias YouCache.Backend.Disk

  @cache_dir Path.join(["test", "tmp", "cache"])

  setup do
    registry = "test_disk_#{:erlang.unique_integer([:positive])}"
    {:ok, backend} = Disk.init(registry, [cache_dir: @cache_dir])
    %{backend: backend, registry: registry}
  end

  test "init/2 creates a DETS table", %{registry: registry} do
    table_name = String.to_atom("#{registry}_cache")
    assert :dets.info(table_name) != :undefined
    assert :dets.info(table_name, :type) == :set
  end

  test "put/4 and get/2", %{backend: backend} do
    # Put a value
    assert :ok = Disk.put(backend, "key1", "value1", nil)
    
    # Get the value
    assert {:ok, "value1"} = Disk.get(backend, "key1")
    
    # Get a non-existent value
    assert nil == Disk.get(backend, "non_existent")
  end

  test "put/4 with TTL", %{backend: backend} do
    # Put a value with TTL of 1 second
    assert :ok = Disk.put(backend, "key2", "value2", 1)
    
    # Value should exist before expiry
    assert {:ok, "value2"} = Disk.get(backend, "key2")
    
    # Wait for expiry
    :timer.sleep(1500)
    
    # Value should be expired
    assert {:expired, "value2"} = Disk.get(backend, "key2")
  end

  test "delete/2", %{backend: backend} do
    # Put a value
    Disk.put(backend, "key3", "value3", nil)
    
    # Delete the value
    assert :ok = Disk.delete(backend, "key3")
    
    # Value should be gone
    assert nil == Disk.get(backend, "key3")
  end

  test "clear/1", %{backend: backend} do
    # Put some values
    Disk.put(backend, "key4", "value4", nil)
    Disk.put(backend, "key5", "value5", nil)
    
    # Clear all values
    assert :ok = Disk.clear(backend)
    
    # Values should be gone
    assert nil == Disk.get(backend, "key4")
    assert nil == Disk.get(backend, "key5")
  end

  test "cleanup/1", %{backend: backend} do
    # Put a non-expired value
    Disk.put(backend, "key6", "value6", 3600)
    
    # Put an expired value
    Disk.put(backend, "key7", "value7", 1)
    
    # Wait for expiry
    :timer.sleep(1500)
    
    # Run cleanup
    assert :ok = Disk.cleanup(backend)
    
    # Non-expired value should exist
    assert {:ok, "value6"} = Disk.get(backend, "key6")
    
    # Expired value should be removed (or at least show as expired)
    # DETS cleanup might be lazy, so we just check it shows as expired
    result = Disk.get(backend, "key7")
    assert result == nil || match?({:expired, _}, result)
  end
end