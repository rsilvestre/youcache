import Config

# Example configuration
config :youcache, :example,
  ttl: 86400,
  cleanup_interval: 3600

config :youcache, :example_backends, %{
  "example_registry" => [
    backend: YouCache.Backend.Memory,
    backend_options: []
  ],
  "example_disk_registry" => [
    backend: YouCache.Backend.Disk,
    backend_options: [
      cache_dir: "priv/youcache"
    ]
  ]
}