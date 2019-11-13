defmodule ParserCombinator do
  def run do
    input = input()

    parser = identifier()
    parser.(input)
  end

  defp char() do
    fn input ->
      case input do
        "" -> {:error, "cannot parse a char"}
        <<char::utf8, rest::binary>> -> {:ok, char, rest}
      end
    end
  end

  defp many(parser) do
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

  defp digit() do
    char()
    |> satisfy(fn term -> term in ?0..?9 end)
  end

  def identifier() do
    many(identifier_char())
  end

  defp identifier_char() do
    char()
    |> satisfy(fn term ->
      term in ?A..?Z or term in ?a..?z or term == ?_
    end)
  end

  defp satisfy(parser, acceptor) do
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

  defp input do
    "select column from table"
  end
end
