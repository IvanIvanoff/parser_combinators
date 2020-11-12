defmodule ParserCombinator do
  def input do
    ""
  end

  @open_paren ?(
  @close_paren ?)
  @coma ?,
  @single_quote ?'

  def operator() do
    choice([
      token(sequence([char('>'), char('=')])),
      token(sequence([char('<'), char('=')])),
      token(sequence([char('!'), char('=')])),
      token(char('>')),
      token(char('<')),
      token(char('='))
    ])
    |> map(fn
      [_ | _] = term -> term |> List.to_string() |> String.to_atom()
      term -> <<term>> |> String.to_atom()
    end)
  end

  def string() do
    sequence([
      char(@single_quote),
      many(char_except(@single_quote)),
      char(@single_quote)
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

  def separated_list(element_parser, separator_parser, opts \\ []) do
    sequence([
      element_parser,
      sequence([separator_parser, element_parser]) |> many()
    ])
    |> map(fn [term, list] ->
      case Keyword.get(opts, :preserve_separator) == true do
        true ->
          [term, list]

        _ ->
          [term | Enum.map(list, fn [_, t] -> t end)]
      end
    end)
  end

  def keyword(word) do
    token()
    |> satisfy(fn term ->
      String.downcase(term) == String.downcase(to_string(word))
    end)
  end

  def token(parser \\ identifier()) do
    sequence([many(empty()), parser, many(empty())])
    |> map(fn [_ls, term, _ts] -> term end)
  end

  def empty() do
    choice([
      char(?\s),
      char(?\t),
      char(?\n),
      char(?\r)
    ])
  end

  def char() do
    fn input ->
      case input do
        "" -> {:error, "Cannot parse a char with input '#{input}'"}
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
    |> satisfy(fn term -> length(term) > 0 end)
    |> map(fn
      [_first_part, ?., _second_part] = list ->
        list |> List.flatten() |> List.to_float()

      [_ | _] = number ->
        number |> List.to_integer()

      result ->
        {:error, "Cannot parse a number. Got '#{inspect(result)}'"}
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
        case acceptor.(term) do
          true ->
            {:ok, term, rest}

          false ->
            {:error, "Acceptor not satisfied on term '#{inspect(term)}'"}
        end
      end
    end
  end
end
