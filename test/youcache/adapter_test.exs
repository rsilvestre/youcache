defmodule YouCache.AdapterTest do
  use ExUnit.Case, async: false
  
  # Define a test adapter module that simulates the original Youchan.Cache API
  defmodule TestAdapter do
    use YouCache,
      registries: ["channel_details"]
    
    # Original API methods
    
    def get_channel_details(channel_id) do
      case get("channel_details", channel_id) do
        {:ok, details} -> {:ok, details}
        {:miss, _} -> {:miss, nil}
        {:error, reason} -> {:error, reason}
      end
    end
    
    def put_channel_details(channel_id, details) do
      case put("channel_details", channel_id, details) do
        {:ok, _} -> {:ok, details}
        error -> error
      end
    end
    
    def get_channel_details!(channel_id) do
      case get_channel_details(channel_id) do
        {:ok, details} -> details
        {:miss, _} -> raise "Channel details not found for channel_id: #{channel_id}"
        {:error, reason} -> raise "Error fetching channel details: #{inspect(reason)}"
      end
    end
    
    # Add some original error formatting functions to test compatibility
    
    def format_error({:error, reason}) do
      "Error: #{inspect(reason)}"
    end
    
    def format_error({:miss, _}) do
      "Not found"
    end
    
    def format_error(_) do
      "Unknown error"
    end
  end
  
  setup do
    # Configure cache backends
    Application.put_env(:youcache, :test_backends, %{
      "channel_details" => [
        backend: YouCache.Backend.Memory,
        backend_options: []
      ]
    })
    
    # Start the cache
    start_supervised!({TestAdapter, [
      app_name: :youcache,
      backends_config: Application.get_env(:youcache, :test_backends),
      ttl: 86_400_000,  # 1 day in milliseconds
      cleanup_interval: 3_600_000  # 1 hour in milliseconds
    ]})
    
    :ok
  end
  
  test "original API compatibility for get operations" do
    # Put a channel
    channel = %{id: "test1", name: "Test Channel"}
    assert {:ok, ^channel} = TestAdapter.put_channel_details("test1", channel)
    
    # Get the channel with standard function
    assert {:ok, ^channel} = TestAdapter.get_channel_details("test1")
    
    # Get a non-existent channel
    assert {:miss, nil} = TestAdapter.get_channel_details("non_existent")
  end
  
  test "original API compatibility for put operations" do
    # Put a channel and check return value format
    channel = %{id: "test2", name: "Test Channel 2"}
    assert {:ok, ^channel} = TestAdapter.put_channel_details("test2", channel)
  end
  
  test "bang function behavior" do
    # Put a channel
    channel = %{id: "test3", name: "Test Channel 3"}
    TestAdapter.put_channel_details("test3", channel)
    
    # Get with bang function should return the value directly
    assert ^channel = TestAdapter.get_channel_details!("test3")
    
    # Get non-existent with bang function should raise
    assert_raise RuntimeError, ~r/Channel details not found/, fn ->
      TestAdapter.get_channel_details!("non_existent")
    end
  end
  
  test "error formatting compatibility" do
    # Format a miss error
    assert "Not found" = TestAdapter.format_error({:miss, nil})
    
    # Format an error
    assert "Error: :some_reason" = TestAdapter.format_error({:error, :some_reason})
  end
  
  test "TTL compatibility (milliseconds)" do
    # Put with short TTL (500ms)
    channel = %{id: "test4", name: "Test Channel 4"}
    TestAdapter.put("channel_details", "test4", channel, 500)
    
    # Should be available immediately
    assert {:ok, ^channel} = TestAdapter.get_channel_details("test4")
    
    # Wait for expiration
    :timer.sleep(700)
    
    # Should be expired
    assert {:miss, nil} = TestAdapter.get_channel_details("test4")
  end
  
  test "domain-specific error handling" do
    # Try to get from non-existent registry
    result = TestAdapter.get("non_existent", "key")
    assert {:error, :registry_not_found} = result
    
    # The adapter should still be able to format this
    assert "Error: :registry_not_found" = TestAdapter.format_error(result)
  end
end