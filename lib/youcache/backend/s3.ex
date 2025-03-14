defmodule YouCache.Backend.S3 do
  @moduledoc """
  S3 backend implementation for YouCache.
  
  This backend stores cache entries in an S3 bucket.
  Requires the optional ex_aws and ex_aws_s3 dependencies.
  """
  
  @behaviour YouCache.Backend
  
  @default_bucket "youcache"
  @default_region "eu-west-1"
  
  @impl true
  def init(registry, options) do
    # Verify that ex_aws and ex_aws_s3 are available
    with :ok <- check_dependencies() do
      # Get options
      bucket = Keyword.get(options, :bucket, @default_bucket)
      region = Keyword.get(options, :region, @default_region)
      prefix = Keyword.get(options, :prefix, registry)
      
      # Return state
      {:ok, %{
        bucket: bucket,
        region: region,
        prefix: prefix
      }}
    end
  end
  
  @impl true
  def get(state, key) do
    # Build S3 key
    s3_key = build_key(state.prefix, key)
    
    # Get from S3
    case ExAws.S3.get_object(state.bucket, s3_key)
         |> ExAws.request(region: state.region) do
      {:ok, %{body: body, headers: headers}} ->
        # Parse expiration from metadata
        expires_at =
          headers
          |> Enum.find(fn {k, _v} -> String.downcase(k) == "x-amz-meta-expires-at" end)
          |> case do
            {_, expires_str} -> String.to_integer(expires_str)
            nil -> 0  # No expiration
          end
          
        # Check if expired
        now = System.os_time(:second)
        
        if expires_at > 0 and expires_at < now do
          # Value has expired
          value = :erlang.binary_to_term(body)
          {:expired, value}
        else
          # Value is valid
          value = :erlang.binary_to_term(body)
          {:ok, value}
        end
        
      {:error, {:http_error, 404, _}} ->
        # Value does not exist
        nil
        
      {:error, error} ->
        # Other error
        {:error, error}
    end
  end
  
  @impl true
  def put(state, key, value, ttl) do
    # Build S3 key
    s3_key = build_key(state.prefix, key)
    
    # Calculate expiration time
    expires_at =
      if ttl do
        System.os_time(:second) + ttl
      else
        0  # 0 means no expiration
      end
    
    # Convert value to binary
    binary_value = :erlang.term_to_binary(value)
    
    # Store in S3 with expiration metadata
    ExAws.S3.put_object(state.bucket, s3_key, binary_value, 
      metadata: [
        {"expires-at", Integer.to_string(expires_at)}
      ]
    )
    |> ExAws.request(region: state.region)
    |> case do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end
  
  @impl true
  def delete(state, key) do
    # Build S3 key
    s3_key = build_key(state.prefix, key)
    
    # Delete from S3
    ExAws.S3.delete_object(state.bucket, s3_key)
    |> ExAws.request(region: state.region)
    |> case do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end
  
  @impl true
  def clear(state) do
    # List all objects with the prefix
    case list_objects(state) do
      {:ok, []} ->
        # No objects to delete
        :ok
        
      {:ok, objects} ->
        # Delete objects
        delete_objects(state, objects)
        
      {:error, error} ->
        {:error, error}
    end
  end
  
  # Helper to list objects with prefix
  defp list_objects(state) do
    case ExAws.S3.list_objects(state.bucket, prefix: state.prefix)
         |> ExAws.request(region: state.region) do
      {:ok, %{body: %{contents: contents}}} ->
        objects = Enum.map(contents, fn %{key: key} -> key end)
        {:ok, objects}
        
      {:error, error} ->
        {:error, error}
    end
  end
  
  # Helper to delete multiple objects
  defp delete_objects(_state, []), do: :ok
  defp delete_objects(state, objects) do
    ExAws.S3.delete_multiple_objects(state.bucket, objects)
    |> ExAws.request(region: state.region)
    |> case do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end
  
  @impl true
  def cleanup(state) do
    now = System.os_time(:second)
    
    # List all objects with the prefix
    case list_objects(state) do
      {:ok, objects} ->
        # Delete expired objects
        delete_expired_objects(state, objects, now)
        :ok
        
      {:error, error} ->
        {:error, error}
    end
  end
  
  # Helper to delete expired objects
  defp delete_expired_objects(state, objects, now) do
    Enum.each(objects, fn key -> 
      check_and_delete_if_expired(state, key, now)
    end)
  end
  
  # Check object expiration and delete if needed
  defp check_and_delete_if_expired(state, key, now) do
    case get_object_expiry(state, key) do
      {:ok, expires_at} when expires_at > 0 and expires_at < now ->
        delete_object(state, key)
      _ ->
        :ok
    end
  end
  
  # Get object expiration time
  defp get_object_expiry(state, key) do
    case ExAws.S3.head_object(state.bucket, key)
         |> ExAws.request(region: state.region) do
      {:ok, %{headers: headers}} ->
        expires_at =
          headers
          |> Enum.find(fn {k, _v} -> String.downcase(k) == "x-amz-meta-expires-at" end)
          |> case do
            {_, expires_str} -> String.to_integer(expires_str)
            nil -> 0  # No expiration
          end
        {:ok, expires_at}
        
      _ ->
        {:error, :not_found}
    end
  end
  
  # Delete a single object
  defp delete_object(state, key) do
    ExAws.S3.delete_object(state.bucket, key)
    |> ExAws.request(region: state.region)
    |> case do
      {:ok, _} -> :ok
      _ -> :error
    end
  end
  
  # Helper functions
  
  defp build_key(prefix, key) do
    "#{prefix}/#{:erlang.phash2(key)}"
  end
  
  defp check_dependencies do
    # Check if ex_aws and ex_aws_s3 are available
    cond do
      not Code.ensure_loaded?(ExAws) ->
        {:error, "ExAws dependency is not available. Add {:ex_aws, \"~> 2.5\"} to your dependencies."}
        
      not Code.ensure_loaded?(ExAws.S3) ->
        {:error, "ExAws.S3 dependency is not available. Add {:ex_aws_s3, \"~> 2.4\"} to your dependencies."}
        
      true ->
        :ok
    end
  end
end
