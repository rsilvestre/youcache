defmodule YouCache.Examples.SampleCache do
  @moduledoc """
  A sample implementation of YouCache for demonstration purposes.
  
  This shows how to use YouCache in your own applications.
  """
  
  use YouCache,
    registries: ["items", "users"]
  
  # Domain-specific helper for the items registry
  def get_item(item_id) do
    get("items", item_id)
  end
  
  def put_item(item_id, item) do
    put("items", item_id, item)
  end
  
  # Domain-specific helper for the users registry
  def get_user(user_id) do
    get("users", user_id)
  end
  
  def put_user(user_id, user) do
    put("users", user_id, user)
  end
end