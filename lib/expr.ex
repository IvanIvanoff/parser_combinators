defmodule Expr do
  import ParserCombinator

  def expr_valid?(expr_str) when is_binary(expr_str) do
    # Expression is valid if it is parsed correctly and there is nothing
    # left to be parsed. If an unknown symbol or a sequence of known symbols
    # (example: "+ + 2") is encountered, the string left to be parsed will
    # not be empty
    match?(
      {:ok, _, ""},
      expr_parser().(expr_str)
    )
  end

  def expr_reverse_polish(expr_str) when is_binary(expr_str) do
    case expr_parser().(expr_str) do
      {:ok, [num, []], ""} ->
        num

      {:ok, [num, rest], ""} ->
        output_queue = [num]
        operator_stack = []

        Enum.reduce(rest, {output_queue, operator_stack}, fn [op, num], {out_queue, op_stack} ->
          nil
        end)
    end
  end

  def eval_expr(expr_str) do
    case expr_parser().(expr_str) do
      {:ok, [], ""} -> 0
      _ -> :error
    end
  end

  def expr_parser() do
    non_empty =
      sequence([
        token(number()),
        sequence([expr_operator(), number()]) |> many(),
        empty() |> many()
      ])

    choice([
      non_empty,
      empty() |> many()
    ])
    |> ParserCombinator.map(fn
      [] -> []
      [x, y, _empty_tokens] -> [x, y]
    end)
  end

  def expr_operator() do
    choice([
      token(char('+')),
      token(char('-')),
      token(char('*')),
      token(char('/')),
      token(char('^'))
    ])
  end
end
