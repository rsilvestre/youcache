defmodule YouCacheTest do
  use ExUnit.Case, async: false
  
  # Define a test cache module that uses YouCache
  defmodule TestCache do
    use YouCache,
      registries: ["test_items", "test_users"]
    
    # Domain-specific helper for the items registry
    def get_item(item_id) do
      get("test_items", item_id)
    end
    
    def put_item(item_id, item) do
      put("test_items", item_id, item)
    end
    
    def put_item(item_id, item, ttl) do
      put("test_items", item_id, item, ttl)
    end
    
    # Domain-specific helper for the users registry
    def get_user(user_id) do
      get("test_users", user_id)
    end
    
    def put_user(user_id, user) do
      put("test_users", user_id, user)
    end
  end
  
  setup do
    # Configure cache backends
    Application.put_env(:youcache, :test_backends, %{
      "test_items" => [
        backend: YouCache.Backend.Memory,
        backend_options: []
      ],
      "test_users" => [
        backend: YouCache.Backend.Memory,
        backend_options: []
      ]
    })
    
    # Start the cache
    start_supervised!({TestCache, [
      app_name: :youcache,
      backends_config: Application.get_env(:youcache, :test_backends),
      ttl: 5000,  # 5 seconds
      cleanup_interval: 1000  # 1 second
    ]})
    
    :ok
  end
  
  test "basic get and put operations" do
    # Test the get and put operations
    assert {:miss, nil} = TestCache.get_item("item1")
    
    # Put an item
    assert {:ok, %{name: "Item 1"}} = TestCache.put_item("item1", %{name: "Item 1"})
    
    # Get the item
    assert {:ok, %{name: "Item 1"}} = TestCache.get_item("item1")
  end
  
  test "multiple registries" do
    # Put items in different registries
    assert {:ok, %{name: "Item 2"}} = TestCache.put_item("item2", %{name: "Item 2"})
    assert {:ok, %{name: "User 1"}} = TestCache.put_user("user1", %{name: "User 1"})
    
    # Get items from different registries
    assert {:ok, %{name: "Item 2"}} = TestCache.get_item("item2")
    assert {:ok, %{name: "User 1"}} = TestCache.get_user("user1")
    
    # Items should be isolated by registry
    assert {:miss, nil} = TestCache.get_user("item2")
    assert {:miss, nil} = TestCache.get_item("user1")
  end
  
  test "TTL expiration" do
    # Put an item with short TTL (1 second)
    assert {:ok, %{name: "Item 3"}} = TestCache.put_item("item3", %{name: "Item 3"}, 1000)
    
    # Item should be available immediately
    assert {:ok, %{name: "Item 3"}} = TestCache.get_item("item3")
    
    # Wait for expiration
    :timer.sleep(1500)
    
    # Item should be expired
    assert {:miss, nil} = TestCache.get_item("item3")
  end
  
  test "delete operation" do
    # Put an item
    TestCache.put_item("item4", %{name: "Item 4"})
    
    # Delete the item
    assert {:ok, nil} = TestCache.delete("test_items", "item4")
    
    # Item should be gone
    assert {:miss, nil} = TestCache.get_item("item4")
  end
  
  test "clear operation" do
    # Put some items
    TestCache.put_item("item5", %{name: "Item 5"})
    TestCache.put_user("user2", %{name: "User 2"})
    
    # Clear all caches
    assert {:ok, nil} = TestCache.clear()
    
    # Items should be gone
    assert {:miss, nil} = TestCache.get_item("item5")
    assert {:miss, nil} = TestCache.get_user("user2")
  end
  
  test "default values" do
    # Get with default value
    assert {:miss, %{default: true}} = TestCache.get("test_items", "non_existent", %{default: true})
  end
  
  test "error handling for non-existent registry" do
    # Try to get from a non-existent registry
    assert {:error, :registry_not_found} = TestCache.get("non_existent_registry", "key")
  end
end