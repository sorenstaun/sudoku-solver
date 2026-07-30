defmodule SudokuTest do
  use ExUnit.Case

  test "setup_solution_space replaces zeros with full candidate sets, keeps given digits" do
    row = [0, 5, 0, 0, 0, 0, 0, 0, 0]
    [first | _] = Sudoku.Solver.setup_solution_space([row | List.duplicate(row, 8)])
    assert is_struct(hd(first), MapSet)
    assert MapSet.equal?(hd(first), MapSet.new(1..9))
    assert Enum.at(first, 1) == 5
  end

  test "solves the sample board — all rows contain exactly 1..9" do
    board = [
      [0, 0, 9, 8, 0, 5, 3, 0, 0],
      [0, 0, 1, 2, 0, 3, 6, 0, 0],
      [2, 6, 0, 0, 9, 0, 0, 5, 4],
      [8, 9, 0, 0, 0, 0, 0, 3, 6],
      [0, 0, 5, 0, 0, 0, 2, 0, 0],
      [6, 3, 0, 0, 0, 0, 0, 7, 1],
      [1, 2, 0, 0, 5, 0, 0, 4, 8],
      [0, 0, 6, 7, 0, 9, 1, 0, 0],
      [0, 0, 8, 4, 0, 2, 7, 0, 0]
    ]

    assert {:ok, solved} = Sudoku.Solver.solve(board)
    assert Enum.all?(solved, fn row -> Enum.sort(row) == Enum.to_list(1..9) end)
  end

  test "solves the hard board" do
    solution = [
      [8, 1, 2, 7, 5, 3, 6, 4, 9],
      [9, 4, 3, 6, 8, 2, 1, 7, 5],
      [6, 7, 5, 4, 9, 1, 2, 8, 3],
      [1, 5, 4, 2, 3, 7, 8, 9, 6],
      [3, 6, 9, 8, 4, 5, 7, 2, 1],
      [2, 8, 7, 1, 6, 9, 5, 3, 4],
      [5, 2, 1, 9, 7, 4, 3, 6, 8],
      [4, 3, 8, 5, 2, 6, 9, 1, 7],
      [7, 9, 6, 3, 1, 8, 4, 5, 2]
    ]

    board = [
      [8, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 3, 6, 0, 0, 0, 0, 0],
      [0, 7, 0, 0, 9, 0, 2, 0, 0],
      [0, 5, 0, 0, 0, 7, 0, 0, 0],
      [0, 0, 0, 0, 4, 5, 7, 0, 0],
      [0, 0, 0, 1, 0, 0, 0, 3, 0],
      [0, 0, 1, 0, 0, 0, 0, 6, 8],
      [0, 0, 8, 5, 0, 0, 0, 1, 0],
      [0, 9, 0, 0, 0, 0, 4, 0, 0]
    ]

    assert {:ok, solved} = Sudoku.Solver.solve(board)
    assert solved == solution
  end

  test "returns error for an unsolvable (contradictory) board" do
    # (0,8) must be 9 (only digit missing from row 0), but col 8 already has 9 at row 1
    # → propagation empties its candidate set immediately
    invalid = [
      [1, 2, 3, 4, 5, 6, 7, 8, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 9],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0, 0, 0, 0]
    ]

    assert {:error, :unsolved, _} = Sudoku.Solver.solve(invalid)
  end
end
