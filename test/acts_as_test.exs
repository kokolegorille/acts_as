defmodule ActsAsTest do
  use ExUnit.Case
  doctest ActsAs

  test "greets the world" do
    assert ActsAs.hello() == :world
  end
end
