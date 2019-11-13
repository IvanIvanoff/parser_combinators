defmodule ParserCombinatorTest do
  use ExUnit.Case
  doctest ParserCombinator

  test "greets the world" do
    assert ParserCombinator.hello() == :world
  end
end
