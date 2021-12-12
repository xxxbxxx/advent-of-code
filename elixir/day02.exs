# IO.puts("Hello world from Elixir")

{:ok, input} = File.read("2021/day02.txt")

input =
  input
  |> String.trim()
  |> String.split("\n")

# |> Enum.map(&String.to_integer/1)

defmodule AOC do
  def parse_line(line) do
    case line do
      "down " <> int -> {0, String.to_integer(int)}
      "up " <> int -> {0, -String.to_integer(int)}
      "forward " <> int -> {String.to_integer(int), 0}
    end
  end

  def part1(input) do
    add = fn {x0, y0}, {x1, y1} -> {x0 + x1, y0 + y1} end

    case input do
      [line | tail] -> add.(parse_line(line), part1(tail))
      _ -> {0, 0}
    end
  end

  def part2(input, state) do
    advance = fn
      {forward, delta_aim}, {x, depth, aim} ->
        {x + forward, depth + forward * aim, aim + delta_aim}
    end

    case input do
      [line | tail] -> part2(tail, advance.(parse_line(line), state))
      _ -> state
    end
  end
end

{x1, y1} = AOC.part1(input)
IO.puts("part1=#{x1 * y1}")
{x2, y2, _} = AOC.part2(input, {0, 0, 0})
IO.puts("part2=#{x2 * y2}")
