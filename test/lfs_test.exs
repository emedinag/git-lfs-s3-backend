defmodule LfsTest do
  use ExUnit.Case
  doctest Lfs

  test "greets the world" do
    assert Lfs.hello() == :world
  end
end
