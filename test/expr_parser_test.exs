defmodule ExprTest do
  use ExUnit.Case

  doctest ParserCombinator

  describe "validation" do
    test "empty is valid" do
      assert Expr.expr_valid?("") == true
    end

    test "constant is valid" do
      assert Expr.expr_valid?("1") == true
      assert Expr.expr_valid?("100") == true
      assert Expr.expr_valid?("100.0") == true
      assert Expr.expr_valid?("31.405") == true
    end

    test "single operator is not valid" do
      assert Expr.expr_valid?("+") == false
      assert Expr.expr_valid?("-") == false
      assert Expr.expr_valid?("*") == false
      assert Expr.expr_valid?("/") == false
      assert Expr.expr_valid?("^") == false
    end

    test "not finished expression is not valid" do
      assert Expr.expr_valid?("2 +") == false
      assert Expr.expr_valid?("3 - 2 *") == false
      assert Expr.expr_valid?(" 3 ^2 ^") == false
      assert Expr.expr_valid?("3/3/3/3/3/") == false
      assert Expr.expr_valid?("2 ++ ") == false
    end

    test "correct expressions are valid" do
      assert Expr.expr_valid?("2 + 2") == true
      assert Expr.expr_valid?("2 + 2^ 2 ") == true
      assert Expr.expr_valid?("2 + 2^ 2  / 3") == true
      assert Expr.expr_valid?("2 + 2^ 2  / 3 + 4") == true
      assert Expr.expr_valid?("2 + 2^ 2  / 3 + 4 * 5 * 5 *5") == true
    end
  end

  describe "reverse polish notation" do
    Expr.expr_reverse_polish("10+20*30") == "+10,*20,30"
  end
end
