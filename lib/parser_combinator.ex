defmodule ParserCombinator do
  def input do
    " select  column
      from ( select v2 from table ) "
  end

  def run do
    input = input()

    parser = select_statement()
    parser.(input)
  end

  defp select_statement() do
    sequence([
      keyword(:select),
      separated_list(token(), char(?,)),
      keyword(:from),
      # token(),
      choice([token(), subquery()])
    ])
    |> map(fn [_select_kw, columns, _from_kw, from] ->
      %{
        statement: :select,
        columns: columns,
        from: from
      }
    end)
  end

  defp lazy(fun) do
    fn input ->
      fun.().(input)
    end
  end

  defp subquery() do
    sequence([
      char(?(),
      lazy(fn -> select_statement() end),
      char(?))
    ])
    |> map(fn [_open_paren, subquery, _closing_paren] -> subquery end)
  end

  def char() do
    fn input ->
      case input do
        "" -> {:error, "cannot parse a char"}
        <<char::utf8, rest::binary>> -> {:ok, char, rest}
      end
    end
  end

  def separated_list(element_parser, separator_parser) do
    sequence([
      element_parser,
      sequence([separator_parser, element_parser]) |> many()
    ])
    |> map(fn [term, list] ->
      [term | Enum.map(list, fn [_, t] -> t end)]
    end)
  end

  def keyword(word) do
    token() |> satisfy(fn term -> String.downcase(term) == String.downcase(to_string(word)) end)
  end

  def token() do
    sequence([many(empty()), identifier(), many(empty())])
    |> map(fn [_ls, term, _ts] -> term end)
  end

  def empty() do
    choice([char(?\s), char(?\t), char(?\n), char(?\r)])
  end

  def char(a..b), do: char() |> satisfy(fn term -> term in a..b end)
  def char(char), do: char() |> satisfy(fn term -> term == char end)
  def digit(), do: char() |> satisfy(fn term -> term in ?0..?9 end)
  def letter(), do: char() |> satisfy(fn term -> term in ?A..?Z or term in ?a..?z end)

  def map(parser, function) do
    fn input ->
      with {:ok, term, rest} <- parser.(input), do: {:ok, function.(term), rest}
    end
  end

  def many(parser) do
    fn input ->
      case parser.(input) do
        {:error, _} ->
          {:ok, [], input}

        {:ok, term, rest} ->
          {:ok, other_terms, rest} = many(parser).(rest)
          {:ok, [term | other_terms], rest}
      end
    end
  end

  def sequence(parsers) do
    fn input ->
      case parsers do
        [] ->
          {:ok, [], input}

        [parser | rest_parsers] ->
          with {:ok, term, rest} <- parser.(input),
               {:ok, other_terms, rest} <- sequence(rest_parsers).(rest),
               do: {:ok, [term | other_terms], rest}
      end
    end
  end

  def choice(parsers) do
    fn input ->
      case parsers do
        [] ->
          {:error, "None of the parsers suceeded"}

        [parser | rest_parsers] ->
          with {:error, _} <- parser.(input),
               do: choice(rest_parsers).(input)
      end
    end
  end

  def identifier() do
    non_digit = choice([letter(), char(?_)])

    sequence([non_digit, many(identifier_char())])
    |> map(fn term -> term |> to_string end)
  end

  def identifier_char() do
    choice([digit(), char(?_), char(?a..?z), char(?A..?Z)])
  end

  def satisfy(parser, acceptor) do
    fn input ->
      with {:ok, term, rest} <- parser.(input) do
        if(acceptor.(term)) do
          {:ok, term, rest}
        else
          {:error, "acceptor not satisfied"}
        end
      end
    end
  end
end
