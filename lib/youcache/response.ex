defprotocol YouCache.Response do
  @moduledoc """
  Protocol for normalizing cache responses.
  
  This protocol is used to normalize the various response formats from cache backends
  into a consistent format:
  
  - `{:ok, value}` for successful cache hits
  - `{:miss, default}` for cache misses
  - `{:error, reason}` for errors
  """
  
  @doc """
  Normalizes a cache response.
  
  ## Examples
  
      iex> Response.normalize({:ok, "value"}, nil)
      {:ok, "value"}
      
      iex> Response.normalize(nil, "default")
      {:miss, "default"}
      
      iex> Response.normalize({:error, :connection_error}, nil)
      {:error, :connection_error}
  """
  def normalize(response, default)
end

# Implementation for successful responses
defimpl YouCache.Response, for: Tuple do
  def normalize({:ok, value}, _default) do
    {:ok, value}
  end
  
  def normalize({:expired, _value}, default) do
    {:miss, default}
  end
  
  def normalize({:error, reason}, _default) do
    {:error, reason}
  end
  
  # Handle other tuples as errors
  def normalize(tuple, _default) do
    {:error, {:unexpected_response, tuple}}
  end
end

# Implementation for nil responses (cache miss)
defimpl YouCache.Response, for: Nil do
  def normalize(nil, default) do
    {:miss, default}
  end
end

# Implementation for atom responses
defimpl YouCache.Response, for: Atom do
  def normalize(:not_found, default) do
    {:miss, default}
  end
  
  def normalize(atom, _default) do
    {:error, {:unexpected_response, atom}}
  end
end

# Implementation for integer responses
defimpl YouCache.Response, for: Integer do
  def normalize(value, _default) do
    {:ok, value}
  end
end

# Implementation for BitString (string) responses
defimpl YouCache.Response, for: BitString do
  def normalize(value, _default) do
    {:ok, value}
  end
end

# Implementation for List responses
defimpl YouCache.Response, for: List do
  def normalize(value, _default) do
    {:ok, value}
  end
end

# Implementation for Map responses
defimpl YouCache.Response, for: Map do
  def normalize(value, _default) do
    {:ok, value}
  end
end

# Implementation for other types
defimpl YouCache.Response, for: Any do
  def normalize(value, _default) do
    {:ok, value}
  end
end