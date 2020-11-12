defmodule SignalParserTest do
  use ExUnit.Case
  doctest ParserCombinator

  describe "argument list" do
    test "integer argument" do
      input = "10"
      parser = SignalParser.argument_list()
      assert parser.(input) == {:ok, [10], ""}
    end

    test "string argument" do
      input = "'str'"
      parser = SignalParser.argument_list()
      assert parser.(input) == {:ok, ["str"], ""}
    end

    test "float argument" do
      input = "2.55"
      parser = SignalParser.argument_list()
      assert parser.(input) == {:ok, [2.55], ""}
    end

    test "variable" do
      input = "btc"
      parser = SignalParser.argument_list()
      assert parser.(input) == {:ok, ["btc"], ""}
    end

    test "arguments" do
      input = "10,'bitcoin', 'asd', 12.5"
      parser = SignalParser.argument_list()
      assert parser.(input) == {:ok, [10, "bitcoin", "asd", 12.5], ""}
    end
  end

  describe "function call" do
    test "0 arity function" do
      input = "time()"
      parser = SignalParser.function_call()
      assert parser.(input) == {:ok, %{arguments: [], name: "time", type: :function}, ""}
    end

    test "1 arity function" do
      input = "last(btc_price)"
      parser = SignalParser.function_call()

      assert parser.(input) ==
               {:ok, %{arguments: ["btc_price"], name: "last", type: :function}, ""}
    end

    test "2 arity function" do
      input = "percent_change(10, 20)"
      parser = SignalParser.function_call()

      assert parser.(input) ==
               {:ok, %{arguments: [10, 20], name: "percent_change", type: :function}, ""}
    end
  end

  describe "fire if" do
    test "fire if" do
      input = "FIRE IF last(btc_price) > 10000 AND percent_change(btc_price) >= 10"
      parser = SignalParser.fire_if()

      assert parser.(input) ==
               {:ok,
                %{
                  meta: [],
                  type: :fire_if,
                  args: [
                    %{
                      type: {:operator, :>},
                      arguments: [
                        %{arguments: ["btc_price"], name: "last", type: :function},
                        10000
                      ],
                      meta: []
                    },
                    [
                      [
                        "AND",
                        %{
                          arguments: [
                            %{arguments: ["btc_price"], name: "percent_change", type: :function},
                            10
                          ],
                          meta: [],
                          type: {:operator, :>=}
                        }
                      ]
                    ]
                  ]
                }, ""}
    end
  end

  describe "range" do
    input = "range('bitcoin', '2019-01-01 00:00:00', '2019-01-10 00:00:00', '1d') AS btc_price"
    parser = SignalParser.range()

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

  describe "query" do
    test "missing columns" do
      input = "select from table"
      parser = SignalParser.select_statement()
      assert {:error, "Acceptor not satisfied on term '\"table\"'"} == parser.(input)
    end

    test "simple query" do
      input = " SELECT  column
      FROM table "
      parser = SignalParser.select_statement()

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
      parser = SignalParser.select_statement()

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
end
