# Migration Guide

This guide explains how to migrate from using project-specific cache implementations to using the YouCache library.

## Compatibility Notes

YouCache has been designed to be as compatible as possible with the existing cache implementations in youchan, youtex, and youvid. However, there are some differences that should be addressed during migration:

1. **Time Units**: YouCache expects TTL and cleanup intervals in milliseconds, matching the existing implementations.

2. **Return Values**: All YouCache operations return standardized formats:
   - `{:ok, value}` for successful operations
   - `{:miss, default}` for cache misses
   - `{:error, reason}` for errors

3. **API Differences**: YouCache uses registry-based API calls, while the existing implementations use domain-specific method names.

## Migration Approaches

There are two main approaches to migration:

### Option 1: Adapter Pattern (Recommended)

Create adapter modules that implement the original API but use YouCache internally. This approach:
- Maintains backward compatibility
- Allows for incremental migration
- Preserves domain-specific method names

See the [YouchanCacheAdapter example](lib/examples/youchan_cache_adapter.ex) for implementation details.

### Option 2: Direct Replacement

Replace all cache usage with direct calls to YouCache. This approach:
- Requires updating all call sites
- Provides a cleaner long-term solution
- Removes the need for adapter maintenance

## Step-by-Step Migration Guide

### Step 1: Add the dependency

Add YouCache to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:youcache, "~> 0.1.0", path: "../youcache"},
    # Keep the optional dependencies if you use S3 or Cachex backends
    {:ex_aws, "~> 2.5", optional: true},
    {:ex_aws_s3, "~> 2.4", optional: true},
    {:sweet_xml, "~> 0.7", optional: true},
    {:configparser_ex, "~> 4.0", optional: true},
    {:cachex, "~> 3.6", optional: true}
  ]
end
```

### Step 2: Create an adapter module

```elixir
defmodule Youchan.Cache do
  # Use YouCache with your registries
  use YouCache,
    registries: ["channel_details"]
    
  # Implement your original API, delegating to YouCache
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
  
  # Add any other methods from your original cache implementation
end
```

### Step 3: Update your configuration

Update your configuration to use the YouCache backends:

```elixir
# In config/config.exs
config :youchan, :cache,
  ttl: 86_400_000,  # 1 day in milliseconds
  cleanup_interval: 3_600_000  # 1 hour in milliseconds

config :youchan, :cache_backends, %{
  "channel_details" => [
    backend: YouCache.Backend.Disk,
    backend_options: [
      cache_dir: "priv/youchan_cache"
    ]
  ]
}
```

### Step 4: Update application startup

Update your application startup code:

```elixir
# In lib/youchan/application.ex
children = [
  {Youchan.Cache, [app_name: :youchan] ++ cache_config}
]
```

### Step 5: Remove unnecessary files

You can now remove the following files if you're using the adapter approach:
- `lib/youchan/cache/backend.ex`
- `lib/youchan/cache/backend/memory.ex`
- `lib/youchan/cache/backend/disk.ex`
- `lib/youchan/cache/backend/s3.ex`
- `lib/youchan/cache/backend/cachex.ex`
- `lib/youchan/cache/response.ex`

Keep your adapter module as it implements the original API.

### Step 6: Update tests

Update your cache tests to account for any behavioral differences. The existing tests should continue to pass with the adapter approach.