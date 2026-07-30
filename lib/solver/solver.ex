defmodule Sudoku.Solver do
  @moduledoc """
  Documentation for `Sudoku.Solver`.
  """



  def setup_solution_space(board) do
    board
    |> Enum.map(fn row ->
      Enum.map(row, fn
        0 -> MapSet.new(1..9)
        n -> n
      end)
    end)
  end

  def print_board(board) do
    board
    |> Enum.with_index()
    |> Enum.each(fn {row, index} ->
      if rem(index, 3) == 0 do
        IO.puts("  +------+------+------+")
      end

      row
      |> Enum.map(fn
        cell when is_struct(cell, MapSet) -> "- "
        0 -> "  "
        number -> "#{number} "
      end)
      |> Enum.chunk_every(3)
      |> Enum.map(&Enum.join/1)
      |> Enum.join("|")
      |> then(&("  |" <> &1 <> "|"))
      |> IO.puts()
    end)

    IO.puts("  +------+------+------+")
  end

  defp solved?(solution_space) do
    Enum.all?(solution_space, fn row ->
      Enum.all?(row, &is_integer/1)
    end)
  end

  defp number_in_same_row_or_col(solspace) do
    solspace
    |> Enum.with_index()
    |> Enum.map(fn {row, _row_idx} ->
      solved_in_row = row |> Enum.filter(&is_integer/1) |> MapSet.new()

      row
      |> Enum.with_index()
      |> Enum.map(fn {cell, col_idx} ->
        case cell do
          _ when is_struct(cell, MapSet) ->
            solved_in_col =
              solspace
              |> Enum.map(&Enum.at(&1, col_idx))
              |> Enum.filter(&is_integer/1)
              |> MapSet.new()

            cell
            |> MapSet.difference(solved_in_row)
            |> MapSet.difference(solved_in_col)

          n ->
            n
        end
      end)
    end)
  end

  defp get_solved_in_box(solspace, box_row, box_col) do
    for row_idx <- (box_row * 3)..(box_row * 3 + 2),
        col_idx <- (box_col * 3)..(box_col * 3 + 2),
        cell = solspace |> Enum.at(row_idx) |> Enum.at(col_idx),
        is_integer(cell),
        into: MapSet.new() do
      cell
    end
  end

  defp number_in_same_square(solspace) do
    solspace
    |> Enum.with_index()
    |> Enum.map(fn {row, row_idx} ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {cell, col_idx} ->
        case cell do
          _ when is_struct(cell, MapSet) ->
            solved = get_solved_in_box(solspace, div(row_idx, 3), div(col_idx, 3))
            MapSet.difference(cell, solved)

          n ->
            n
        end
      end)
    end)
  end

  defp collapse_singles(solspace) do
    solspace
    |> Enum.map(fn row ->
      Enum.map(row, fn
        cell when is_struct(cell, MapSet) ->
          if MapSet.size(cell) == 1, do: cell |> MapSet.to_list() |> hd(), else: cell

        cell ->
          cell
      end)
    end)
  end

  defp eliminate_candidates(solspace) do
    solspace
    |> number_in_same_square()
    |> number_in_same_row_or_col()
    |> collapse_singles()
  end

  defp propagate_until_stable(solspace) do
    reduced = eliminate_candidates(solspace)
    if reduced == solspace, do: solspace, else: propagate_until_stable(reduced)
  end

  defp contradiction?(solspace) do
    has_empty_candidates =
      Enum.any?(solspace, fn row ->
        Enum.any?(row, fn
          cell when is_struct(cell, MapSet) -> MapSet.size(cell) == 0
          _ -> false
        end)
      end)

    has_empty_candidates or duplicate_integers?(solspace)
  end

  # Detects when collapse_singles places the same value twice in the same group.
  defp duplicate_integers?(solspace) do
    ints = fn cells -> Enum.filter(cells, &is_integer/1) end
    dup? = fn cells -> cells != Enum.uniq(cells) end

    Enum.any?(solspace, &(dup?.(ints.(&1)))) or
      Enum.any?(0..8, fn c ->
        dup?.(ints.(Enum.map(solspace, &Enum.at(&1, c))))
      end) or
      Enum.any?(
        for(r <- [0, 3, 6], c <- [0, 3, 6], do: {r, c}),
        fn {r, c} ->
          dup?.(ints.(for dr <- 0..2, dc <- 0..2, do: solspace |> Enum.at(r + dr) |> Enum.at(c + dc)))
        end
      )
  end

  # Returns {row_idx, col_idx, candidates} for the unsolved cell with fewest candidates.
  defp find_mrv_cell(solspace) do
    solspace
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, row_idx} ->
      row
      |> Enum.with_index()
      |> Enum.filter(fn {cell, _} -> is_struct(cell, MapSet) end)
      |> Enum.map(fn {cell, col_idx} -> {row_idx, col_idx, cell} end)
    end)
    |> Enum.min_by(fn {_, _, candidates} -> MapSet.size(candidates) end)
  end

  defp put_cell(solspace, row_idx, col_idx, value) do
    List.update_at(solspace, row_idx, &List.replace_at(&1, col_idx, value))
  end

  # Each task gets one candidate value and backtracks sequentially from there.
  defp backtrack(solspace) do
    stable = propagate_until_stable(solspace)

    cond do
      contradiction?(stable) ->
        :error

      solved?(stable) ->
        {:ok, stable}

      true ->
        {row_idx, col_idx, candidates} = find_mrv_cell(stable)

        candidates
        |> MapSet.to_list()
        |> Task.async_stream(
          fn val -> backtrack_sequential(put_cell(stable, row_idx, col_idx, val)) end,
          ordered: false,
          max_concurrency: System.schedulers_online()
        )
        |> Enum.find_value(:error, fn
          {:ok, {:ok, _} = result} -> result
          _ -> nil
        end)
    end
  end

  defp backtrack_sequential(solspace) do
    stable = propagate_until_stable(solspace)

    cond do
      contradiction?(stable) ->
        :error

      solved?(stable) ->
        {:ok, stable}

      true ->
        {row_idx, col_idx, candidates} = find_mrv_cell(stable)

        Enum.find_value(MapSet.to_list(candidates), :error, fn val ->
          case backtrack_sequential(put_cell(stable, row_idx, col_idx, val)) do
            {:ok, _} = result -> result
            :error -> nil
          end
        end)
    end
  end

  def solve(board) do
    solspace = setup_solution_space(board)
    stable = propagate_until_stable(solspace)

    cond do
      solved?(stable) -> {:ok, stable}
      contradiction?(stable) -> {:error, :unsolved, stable}
      true ->
        case backtrack(stable) do
          {:ok, _} = result -> result
          :error -> {:error, :unsolved, stable}
        end
    end
  end
end
