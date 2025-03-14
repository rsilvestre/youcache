defmodule YouCache.ResponseTest do
  use ExUnit.Case, async: true
  alias YouCache.Response

  test "normalize/2 for successful responses" do
    assert {:ok, "value"} = Response.normalize({:ok, "value"}, nil)
  end

  test "normalize/2 for expired values" do
    assert {:miss, "default"} = Response.normalize({:expired, "old_value"}, "default")
  end

  test "normalize/2 for error responses" do
    assert {:error, :some_error} = Response.normalize({:error, :some_error}, nil)
  end

  test "normalize/2 for nil responses" do
    # Direct protocol test - this is now handled specially in the YouCache module
    assert {:error, {:unexpected_response, nil}} = Response.normalize(nil, nil)
    assert {:error, {:unexpected_response, nil}} = Response.normalize(nil, "default")
    
    # But in practice, we're handling nil from backends as a miss in the YouCache module
  end

  test "normalize/2 for atom responses" do
    assert {:miss, "default"} = Response.normalize(:not_found, "default")
    assert {:error, {:unexpected_response, :something_else}} = Response.normalize(:something_else, "default")
  end

  test "normalize/2 for unexpected tuples" do
    assert {:error, {:unexpected_response, {:weird, :tuple}}} = Response.normalize({:weird, :tuple}, nil)
  end

  test "normalize/2 for direct values (Any implementation)" do
    assert {:ok, 123} = Response.normalize(123, nil)
    assert {:ok, "direct"} = Response.normalize("direct", nil)
    assert {:ok, ["list"]} = Response.normalize(["list"], nil)
  end
end