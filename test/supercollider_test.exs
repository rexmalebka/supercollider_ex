defmodule SupercolliderTest do
  use ExUnit.Case
  doctest Supercollider

  test "greets the world" do
    assert Supercollider.hello() == :world
  end
end
