defmodule ParserCombinatorTest do
  use ExUnit.Case
  doctest ParserCombinator
  alias ParserCombinator, as: PS

  describe "operator" do
    test ">=" do
      input = ">="
      parser = PS.operator()
      assert parser.(input) == {:ok, :>=, ""}
    end

    test "<=" do
      input = "<="
      parser = PS.operator()
      assert parser.(input) == {:ok, :<=, ""}
    end

    test ">" do
      input = ">"
      parser = PS.operator()
      assert parser.(input) == {:ok, :>, ""}
    end

    test "<" do
      input = "<"
      parser = PS.operator()
      assert parser.(input) == {:ok, :<, ""}
    end

    test "=" do
      input = "="
      parser = PS.operator()
      assert parser.(input) == {:ok, :=, ""}
    end

    test "!=" do
      input = "!="
      parser = PS.operator()
      assert parser.(input) == {:ok, :!=, ""}
    end
  end

  describe "number" do
    test "integer" do
      parser = PS.number()
      assert parser.("2") == {:ok, 2, ""}
      assert parser.("20") == {:ok, 20, ""}
      assert parser.("200") == {:ok, 200, ""}
      assert parser.("2000") == {:ok, 2000, ""}
    end

    test "float" do
      parser = PS.number()
      assert parser.("3.1") == {:ok, 3.1, ""}
      assert parser.("3.14") == {:ok, 3.14, ""}
      assert parser.("3.141") == {:ok, 3.141, ""}
      assert parser.("3.1415") == {:ok, 3.1415, ""}
    end
  end

  describe "string" do
    test "simple string" do
      input = "'hooman'"
      parser = PS.string()
      assert parser.(input) == {:ok, "hooman", ""}
    end

    test "string with empty space" do
      input = "'hoo man'"
      parser = PS.string()
      assert parser.(input) == {:ok, "hoo man", ""}
    end

    test "string with digits" do
      input = "'1hoo man'"
      parser = PS.string()
      assert parser.(input) == {:ok, "1hoo man", ""}
    end
  end

  describe "empty separated" do
    test "word" do
      input = " (  "
      parser = PS.token(PS.char(?()) |> PS.map(&<<&1>>)
      assert parser.(input) == {:ok, "(", ""}
    end
  end

  describe "identifier" do
    test "only chars" do
      parser = PS.identifier()
      assert {:ok, "onlychars", ""} == parser.("onlychars")
    end

    test "with chars and underscore" do
      parser = PS.identifier()
      assert {:ok, "value_with_underscore", ""} == parser.("value_with_underscore")
    end

    test "with chars and digits" do
      parser = PS.identifier()
      assert {:ok, "value1", ""} == parser.("value1")
    end

    test "with chars and digits and underscore" do
      parser = PS.identifier()
      assert {:ok, "value_1", ""} == parser.("value_1")
    end

    test "can start with an underscore" do
      parser = PS.identifier()
      assert {:ok, "_value_1", ""} == parser.("_value_1")
    end

    test "cannot start with a digit" do
      parser = PS.identifier()
      assert match?({:error, _}, parser.("1_value_1"))
    end
  end

  describe "token" do
    test "single value" do
      parser = PS.token()
      assert {:ok, "value", ""} == parser.("value")
    end

    test "multiple values" do
      parser = PS.token()
      {:ok, term, _} = parser.("  \t\n value value2")
      assert term == "value"
    end
  end

  describe "keyword" do
    test "single value" do
      parser = PS.keyword(:value)
      assert {:ok, "value", ""} == parser.("value")
    end

    test "multiple values" do
      parser = PS.keyword(:value)
      {:ok, term, _} = parser.("  \t\n value value2")
      assert term == "value"
    end
  end

  describe "separated list" do
    test "single value" do
      parser = PS.separated_list(PS.token(), PS.char(?,))

      assert {:ok, ["value"], ""} == parser.("value")
    end

    test "multiple values no whitespace" do
      parser = PS.separated_list(PS.token(), PS.char(?,))

      assert {:ok, ["value1", "value2", "value3"], ""} == parser.("value1,value2,value3")
    end

    test "multiple values with whitespace" do
      parser = PS.separated_list(PS.token(), PS.char(?,))

      assert {:ok, ["value1", "value2", "value3"], ""} ==
               parser.(" value1  ,\n\n value2,\t  value3 ")
    end
  end
end
