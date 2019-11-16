defmodule ParserCombinatorTest do
  use ExUnit.Case
  doctest ParserCombinator
  alias ParserCombinator, as: PS

  describe "argument list" do
    test "integer argument" do
      input = "10"
      parser = PS.argument_list()
      assert parser.(input) == {:ok, [10], ""}
    end

    test "string argument" do
      input = "'str'"
      parser = PS.argument_list()
      assert parser.(input) == {:ok, ["str"], ""}
    end

    test "float argument" do
      input = "2.55"
      parser = PS.argument_list()
      assert parser.(input) == {:ok, [2.55], ""}
    end

    test "variable" do
      input = "btc"
      parser = PS.argument_list()
      assert parser.(input) == {:ok, ["btc"], ""}
    end

    test "arguments" do
      input = "10,'bitcoin', 'asd', 12.5"
      parser = PS.argument_list()
      assert parser.(input) == {:ok, [10, "bitcoin", "asd", 12.5], ""}
    end
  end

  describe "function call" do
    test "0 arity function" do
      input = "time()"
      parser = PS.function_call()
      assert parser.(input) == {:ok, %{arguments: [], name: "time", type: :function}, ""}
    end

    test "1 arity function" do
      input = "last(btc_price)"
      parser = PS.function_call()

      assert parser.(input) ==
               {:ok, %{arguments: ["btc_price"], name: "last", type: :function}, ""}
    end

    test "2 arity function" do
      input = "percent_change(10, 20)"
      parser = PS.function_call()

      assert parser.(input) ==
               {:ok, %{arguments: [10, 20], name: "percent_change", type: :function}, ""}
    end
  end

  describe "number" do
    test "integer" do
      input = "20"
      parser = PS.number()
      assert parser.(input) == {:ok, 20, ""}
    end

    test "float" do
      input = "3.1415"
      parser = PS.number()
      assert parser.(input) == {:ok, 3.1415, ""}
    end
  end

  # describe "fire if" do
  #   input = "FIRE IF last(btc_price) > 10000 AND percent_change(btc_price) >= 10"
  #   parser = PS.fire_if()

  #   assert parser.(input) ==
  #            {:ok,
  #             %{
  #               type: :fire_if,
  #               conditions: [
  #                 condition: :and,
  #                 left: %{
  #                   operator: :>,
  #                   left: %{operator: :last, argument: "btc_price"},
  #                   right: 10_000
  #                 },
  #                 right: %{
  #                   operator: :>=,
  #                   left: %{
  #                     operator: :>=,
  #                     left: %{operator: :percent_change, argument: "btc_price"},
  #                     right: 10
  #                   }
  #                 }
  #               ]
  #             }}
  # end

  describe "range" do
    input = "range('bitcoin', '2019-01-01 00:00:00', '2019-01-10 00:00:00', '1d') AS btc_price"
    parser = PS.range()

    assert parser.(input) ==
             {:ok,
              %{
                type: :range,
                identifier: "bitcoin",
                from: "2019-01-01 00:00:00",
                to: "2019-01-10 00:00:00",
                interval: "1d",
                as: "btc_price"
              }, ""}
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

  describe "query" do
    test "missing columns" do
      input = "select from table"
      parser = PS.select_statement()
      assert {:error, "acceptor not satisfied on term '\"table\"'"} == parser.(input)
    end

    test "simple query" do
      input = " SELECT  column
      FROM table "
      parser = PS.select_statement()

      assert {:ok,
              %{
                type: :sql_statement,
                statement: :select,
                columns: ["column"],
                from: "table"
              }, ""} == parser.(input)
    end

    test "subquery" do
      input = " select  \n column
      from   \n( \n select v2 from table
      )
      "
      parser = PS.select_statement()

      assert {:ok,
              %{
                type: :sql_statement,
                statement: :select,
                columns: ["column"],
                from: %{
                  type: :sql_statement,
                  statement: :select,
                  columns: ["v2"],
                  from: "table"
                }
              }, ""} == parser.(input)
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
