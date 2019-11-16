defmodule ParserCombinator do
  @open_paren ?(
  @close_paren ?)
  @coma ?,

  def input do
    "SELECT range('bitcoin', '2019-01-01 00:00:00', '2019-01-10 00:00:00', '1d') AS btc_price
    FROM prices"
  end

  def run do
    input = input()

    parser = select_statement()
    parser.(input)
  end

  def fire_if() do
    sequence([
      keyword(:fire),
      keyword(:if),
      separated_list(expression(), choice([keyword(:and), keyword(:or), keyword(:not)]))
    ])
  end

  def expression() do
    sequence([
      operator()
    ])
  end

  def function_call() do
    sequence([
      token(),
      char(@open_paren),
      choice([
        token(char(@close_paren)),
        sequence([separated_list(token(), char(@coma)), char(@close_paren)])
      ])
    ])
    |> map(fn
      [fun_name, _open_paren, [args, _close_paren]] ->
        %{
          type: :function,
          name: fun_name,
          arguments: args
        }

      [fun_name, _open_paren, _close_paren] = list ->
        %{
          type: :function,
          name: fun_name,
          arguments: []
        }
    end)
  end

  def operator() do
    choice([keyword(:>), keyword(:<), keyword(:>=), keyword(:<=), keyword(:=), keyword(:!=)])
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
      token(char(?()),
      separated_list(token(string()), char(@coma)),
      token(char(?))),
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

  def string() do
    sequence([
      char(?'),
      many(char_except(?')),
      char(?')
    ])
    |> map(fn [_open_quote, string, _close_quote] ->
      string |> to_string()
    end)
  end

  def lazy(fun) do
    fn input ->
      fun.().(input)
    end
  end

  def subquery() do
    sequence([
      token(char(?()),
      lazy(fn -> select_statement() end),
      token(char(?)))
    ])
    |> map(fn [_open_paren, subquery, _closing_paren] -> subquery end)
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

  def token(parser \\ identifier()) do
    sequence([many(empty()), parser, many(empty())])
    |> map(fn [_ls, term, _ts] -> term end)
  end

  def empty() do
    choice([char(?\s), char(?\t), char(?\n), char(?\r)])
  end

  def char() do
    fn input ->
      case input do
        "" -> {:error, "cannot parse a char with input '#{input}'"}
        <<char::utf8, rest::binary>> -> {:ok, char, rest}
      end
    end
  end

  def char(a..b), do: char() |> satisfy(fn term -> term in a..b end)
  def char(chars) when is_list(chars), do: char() |> satisfy(fn term -> term in chars end)
  def char(char), do: char() |> satisfy(fn term -> term == char end)

  def char_except(char) do
    char() |> satisfy(fn term -> term != char end)
  end

  def digit(), do: char() |> satisfy(fn term -> term in ?0..?9 end)

  def number() do
    choice([
      sequence([many(digit()), char(?.), many(digit())]),
      many(digit())
    ])
    |> map(fn
      [_first_part, _dot, _second_part] = list -> list |> List.flatten() |> List.to_float()
      number -> number |> List.to_integer()
    end)
  end

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
          {:error, "None of the parsers suceeded on input '#{input}'"}

        [parser | rest_parsers] ->
          with {:error, _} <- parser.(input),
               do: choice(rest_parsers).(input)
      end
    end
  end

  def identifier() do
    non_digit = identifier_char() |> satisfy(fn term -> term not in ?0..?9 end)

    sequence([non_digit, many(identifier_char())])
    |> map(fn term -> term |> to_string end)
  end

  def identifier_char() do
    choice([digit(), char(?_), char(?a..?z), char(?A..?Z)])
  end

  def parens() do
    choice([char([?), ?(, ?{, ?}, ?[, ?]])])
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
