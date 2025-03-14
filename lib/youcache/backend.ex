defmodule YouCache.Backend do
  @moduledoc """
  Behaviour for YouCache backends.

  This behaviour defines the interface that all cache backends must implement.
  """

  @doc """
  Initializes the backend with the given options.
  
  Returns `{:ok, state}` on success, or `{:error, reason}` on failure.
  """
  @callback init(registry :: String.t(), options :: Keyword.t()) ::
              {:ok, state :: term} | {:error, reason :: term}

  @doc """
  Gets a value from the cache.
  
  Returns various formats depending on result, which will be normalized by Response protocol:
  - `{:ok, value}` if the value exists and is not expired
  - `nil` or `:not_found` if the value does not exist
  - `{:expired, value}` if the value exists but is expired
  - `{:error, reason}` if an error occurred
  """
  @callback get(state :: term, key :: term) :: term

  @doc """
  Puts a value in the cache with an optional TTL (in seconds).
  
  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  @callback put(state :: term, key :: term, value :: term, ttl :: non_neg_integer | nil) ::
              :ok | {:error, reason :: term}

  @doc """
  Deletes a value from the cache.
  
  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  @callback delete(state :: term, key :: term) :: :ok | {:error, reason :: term}

  @doc """
  Clears all values from the cache.
  
  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  @callback clear(state :: term) :: :ok | {:error, reason :: term}

  @doc """
  Cleans up expired values from the cache.
  
  Returns `:ok` on success, or `{:error, reason}` on failure.
  """
  @callback cleanup(state :: term) :: :ok | {:error, reason :: term}
end