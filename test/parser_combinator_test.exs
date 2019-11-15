defmodule ParserCombinatorTest do
  use ExUnit.Case
  doctest ParserCombinator

  describe "identifier" do
    test "only chars" do
      parser = ParserCombinator.identifier()
      assert {:ok, "onlychars", ""} == parser.("onlychars")
    end

    test "with chars and underscore" do
      parser = ParserCombinator.identifier()
      assert {:ok, "value_with_underscore", ""} == parser.("value_with_underscore")
    end

    test "with chars and digits" do
      parser = ParserCombinator.identifier()
      assert {:ok, "value1", ""} == parser.("value1")
    end

    test "with chars and digits and underscore" do
      parser = ParserCombinator.identifier()
      assert {:ok, "value_1", ""} == parser.("value_1")
    end

    test "can start with an underscore" do
      parser = ParserCombinator.identifier()
      assert {:ok, "_value_1", ""} == parser.("_value_1")
    end

    test "cannot start with a digit" do
      parser = ParserCombinator.identifier()
      assert match?({:error, _}, parser.("1_value_1"))
    end
  end

  describe "token" do
    test "single value" do
      parser = ParserCombinator.token()
      assert {:ok, "value", ""} == parser.("value")
    end

    test "multiple values" do
      parser = ParserCombinator.token()
      {:ok, term, _} = parser.("  \t\n value value2")
      assert term == "value"
    end
  end

  describe "keyword" do
    test "single value" do
      parser = ParserCombinator.keyword(:value)
      assert {:ok, "value", ""} == parser.("value")
    end

    test "multiple values" do
      parser = ParserCombinator.keyword(:value)
      {:ok, term, _} = parser.("  \t\n value value2")
      assert term == "value"
    end
  end

  describe "separated list" do
    test "single value" do
      parser =
        ParserCombinator.separated_list(ParserCombinator.token(), ParserCombinator.char(?,))

      assert {:ok, ["value"], ""} == parser.("value")
    end

    test "multiple values no whitespace" do
      parser =
        ParserCombinator.separated_list(ParserCombinator.token(), ParserCombinator.char(?,))

      assert {:ok, ["value1", "value2", "value3"], ""} == parser.("value1,value2,value3")
    end

    test "multiple values with whitespace" do
      parser =
        ParserCombinator.separated_list(ParserCombinator.token(), ParserCombinator.char(?,))

      assert {:ok, ["value1", "value2", "value3"], ""} ==
               parser.(" value1  ,\n\n value2,\t  value3 ")
    end
  end
end
