defmodule Mix.Tasks.Sudoku.Run do
  use Mix.Task

  @shortdoc "Solve a sudoku puzzle"

  @default_board [
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

  @hard_board [
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

  @impl Mix.Task
  def run(args) do
    board =
      case args do
        ["hard"] ->
          @hard_board

        _ ->
          IO.gets("Enter your own sudoku? (y/n): ")
          |> String.trim()
          |> then(fn
            "y" -> read_board()
            _ -> @default_board
          end)
      end

    Sudoku.Solver.print_board(board)

    {elapsed, result} = :timer.tc(fn -> Sudoku.Solver.solve(board) end)

    case result do
      {:ok, solved} ->
        Sudoku.Solver.print_board(solved)
        IO.puts("Solved in #{elapsed / 1000} ms")

      {:error, :unsolved, partial} ->
        Sudoku.Solver.print_board(partial)
        IO.puts("Could not fully solve in #{elapsed / 1000} ms (requires guessing)")
    end
  end

  defp read_board do
    IO.puts("Enter 9 rows of 9 numbers (0 = empty):")

    Enum.map(1..9, fn i ->
      IO.gets("Row #{i}: ")
      |> String.trim()
      |> String.graphemes()
      |> Enum.map(&parse_digit!/1)
    end)
  end

  defp parse_digit!(str) do
    case Integer.parse(str) do
      {n, ""} when n in 0..9 -> n
      _ -> raise ArgumentError, "expected a digit 0-9, got: #{inspect(str)}"
    end
  end
end
