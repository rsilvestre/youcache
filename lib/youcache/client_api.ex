defmodule YouCache.ClientAPI do
  @moduledoc """
  Client API functions for the YouCache module.
  """
  
  # This module contains functions that will be imported in modules
  # that use YouCache
  
  @doc false
  defmacro __using__(_opts) do
    quote do
      # Client API
      @doc """
      Starts the cache server with the given options.
      """
      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      @doc """
      Gets a value from the cache.

      ## Examples

          iex> get("registry", "key")
          {:ok, "value"}

          iex> get("registry", "missing_key")
          {:miss, nil}
      """
      def get(registry, key, default \\ nil) do
        GenServer.call(__MODULE__, {:get, registry, key, default})
      end

      @doc """
      Puts a value in the cache.

      ## Examples

          iex> put("registry", "key", "value")
          :ok
      """
      def put(registry, key, value, ttl \\ nil) do
        GenServer.call(__MODULE__, {:put, registry, key, value, ttl})
      end

      @doc """
      Deletes a value from the cache.

      ## Examples

          iex> delete("registry", "key")
          :ok
      """
      def delete(registry, key) do
        GenServer.call(__MODULE__, {:delete, registry, key})
      end

      @doc """
      Clears all values from the cache.

      ## Examples

          iex> clear()
          :ok
      """
      def clear do
        GenServer.call(__MODULE__, :clear)
      end
    end
  end
end