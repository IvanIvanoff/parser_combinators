defmodule SignalParser do
  import ParserCombinator

  @open_paren ?(
  @close_paren ?)
  @coma ?,
  @single_quote ?'

  def signal_definition() do
    sequence([
      many(select_statement())
    ])
  end

  def fire_if() do
    sequence([
      keyword(:fire),
      keyword(:if),
      separated_list(expression(), choice([keyword(:and), keyword(:or), keyword(:not)]),
        preserve_separator: true
      )
    ])
    |> map(fn [_fire, _if, list] ->
      %{
        type: :fire_if,
        args: list,
        meta: []
      }
    end)
  end

  def expression() do
    sequence([
      choice([function_call(), token(number())]),
      operator(),
      choice([function_call(), token(number())])
    ])
    |> map(fn [first, op, second] ->
      %{
        type: {:operator, op},
        arguments: [first, second],
        meta: []
      }
    end)
  end

  def argument_list() do
    separated_list(
      choice([token(string()), token(number()), token()]),
      char(@coma)
    )
  end

  def function_call() do
    sequence([
      token(),
      token(char(@open_paren)),
      choice([
        argument_list(),
        many(empty())
      ]),
      token(char(@close_paren))
    ])
    |> map(fn
      [fun_name, _open_paren, args, _close_paren] when is_list(args) ->
        %{
          type: :function,
          name: fun_name,
          arguments: args
        }

      [fun_name, _open_paren, _args, _close_paren] ->
        %{
          type: :function,
          name: fun_name,
          arguments: []
        }
    end)
  end

  def subquery() do
    sequence([
      token(char(@open_paren)),
      lazy(fn -> select_statement() end),
      token(char(@close_paren))
    ])
    |> map(fn [_open_paren, subquery, _closing_paren] -> subquery end)
  end

  def select_statement() do
    sequence([
      keyword(:select),
      separated_list(choice([range(), token()]), char(@coma)),
      keyword(:from),
      choice([subquery(), token()])
    ])
    |> map(fn [_select_kw, columns, _from_kw, from] ->
      %{
        type: :sql_statement,
        statement: :select,
        columns: columns,
        from: from
      }
    end)
  end

  @range_err """
  Range has invalid number of arguments or missing parts.
  The proper format of a range is:
  RANGE('<identifier>', '<datetime>', '<datetime>', '<interval>') AS <alias>
  """

  def range() do
    sequence([
      keyword(:range),
      token(char(@open_paren)),
      separated_list(token(string()), char(@coma)),
      token(char(@close_paren)),
      keyword(:as),
      token()
    ])
    |> map(fn
      [_range_kw, _open_paren, list, _close_paren, _as_kw, as] ->
        case list do
          [identifier, from, to, interval] ->
            %{
              type: :range,
              identifier: identifier,
              from: from,
              to: to,
              interval: interval,
              as: as
            }

          _ ->
            {:error, @range_err}
        end

      _ ->
        {:error, @range_err}
    end)
  end
end
