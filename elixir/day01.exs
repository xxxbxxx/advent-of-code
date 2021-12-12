# IO.puts("Hello world from Elixir")

{:ok, input} = File.read("2021/day01.txt")

input =
  input
  |> String.trim()
  |> String.split("\n")
  |> Enum.map(&String.to_integer/1)

defmodule AOC do
  def count_biggers(x) do
    case x do
      [a, b | tail] when a < b -> count_biggers([b | tail]) + 1
      [_, b | tail] -> count_biggers([b | tail])
      _ -> 0
    end
  end

  def count_biggers_3(x) do
    case x do
      [a, b, c, d | tail] when a + b + c < b + c + d -> count_biggers_3([b, c, d | tail]) + 1
      [_, b, c, d | tail] -> count_biggers_3([b, c, d | tail])
      _ -> 0
    end
  end
end

IO.puts("part1=#{AOC.count_biggers(input)}")
IO.puts("part2=#{AOC.count_biggers_3(input)}")

# bonus:

bigger = fn
  {a, b} when a < b -> 1
  _ -> 0
end

alt =
  (Enum.zip([0] ++ input, input)
   |> Enum.reduce(0, fn pair, a -> a + bigger.(pair) end)) - 1

IO.puts("part1=#{alt}")

alt2 =
  (Enum.zip([[0, 0, 0] ++ input, [0, 0] ++ input, [0] ++ input, input])
   |> Enum.reduce(0, fn {a, _, _, d}, accu ->
     accu +
       if a < d do
         1
       else
         0
       end
   end)) - 3

IO.puts("part1=#{alt2}")
