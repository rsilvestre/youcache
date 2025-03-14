ExUnit.start()

# Create a temporary directory for test cache files
test_cache_dir = Path.join(["test", "tmp", "cache"])
File.mkdir_p!(test_cache_dir)

# Ensure the temporary directory is removed after tests
ExUnit.after_suite(fn (_) ->
  File.rm_rf!(test_cache_dir)
end)