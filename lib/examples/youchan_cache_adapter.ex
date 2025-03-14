defmodule YouCache.Examples.YouchanCacheAdapter do
  @moduledoc """
  An example adapter for Youchan.Cache that uses YouCache internally
  while maintaining the original API.
  
  This shows how to migrate from an existing cache implementation to YouCache
  without breaking existing code.
  """
  
  use YouCache,
    registries: ["channel_details"]
  
  # Original API methods
  
  @doc """
  Gets channel details from the cache.
  """
  def get_channel_details(channel_id) do
    case get("channel_details", channel_id) do
      {:ok, details} -> {:ok, details}
      {:miss, _} -> {:miss, nil}
      {:error, reason} -> {:error, reason}
    end
  end
  
  @doc """
  Puts channel details in the cache.
  
  Returns the channel details for API compatibility.
  """
  def put_channel_details(channel_id, details) do
    case put("channel_details", channel_id, details) do
      {:ok, _} -> {:ok, details}
      error -> error
    end
  end
  
  @doc """
  Gets channel details from the cache, or raises an error if not found.
  """
  def get_channel_details!(channel_id) do
    case get_channel_details(channel_id) do
      {:ok, details} -> details
      {:miss, _} -> raise "Channel details not found for channel_id: #{channel_id}"
      {:error, reason} -> raise "Error fetching channel details: #{inspect(reason)}"
    end
  end
end