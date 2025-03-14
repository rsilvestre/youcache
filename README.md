# YouCache

[![Elixir CI](https://github.com/rsilvestre/youcache/actions/workflows/elixir.yml/badge.svg)](https://github.com/rsilvestre/youcache/actions/workflows/elixir.yml)
[![Coverage Status](https://coveralls.io/repos/github/rsilvestre/youcache/badge.svg?branch=main)](https://coveralls.io/github/rsilvestre/youcache?branch=main)

A flexible caching library for Elixir applications with multiple backend options:

- Memory (ETS)
- Disk (DETS)
- S3
- Cachex (for distributed caching)

## Features

- Pluggable backend architecture
- Simple API for get/put/delete operations
- TTL and automatic cleanup support
- Fallback mechanisms for backend failures
- Consistent response format

## Installation

```elixir
def deps do
  [
    {:youcache, "~> 0.1.0"},
    # Optional dependencies for S3 backend
    {:ex_aws, "~> 2.5", optional: true},
    {:ex_aws_s3, "~> 2.4", optional: true},
    {:sweet_xml, "~> 0.7", optional: true},
    {:configparser_ex, "~> 4.0", optional: true},
    # Optional dependency for distributed caching
    {:cachex, "~> 3.6", optional: true}
  ]
end
```

## Configuration

```elixir
config :my_app, :cache,
  ttl: 86400,                 # Time to live in seconds (default: 1 day)
  cleanup_interval: 3600      # Cleanup interval in seconds (default: 1 hour)

config :my_app, :cache_backends, %{
  "my_registry" => [
    backend: YouCache.Backend.Memory,
    backend_options: [
      cache_dir: "priv/my_app_cache"
    ]
  ]
}
```

## Usage

```elixir
# Configure in your application startup
children = [
  {YouCache, 
    module: MyApp.Cache,
    config: Application.get_env(:my_app, :cache, [])
  }
]

# Define your cache module
defmodule MyApp.Cache do
  use YouCache,
    registries: ["my_registry"]
  
  # Define domain-specific helper functions
  def get_item(item_id) do
    get("my_registry", item_id)
  end
  
  def put_item(item_id, item) do
    put("my_registry", item_id, item)
  end
end
```