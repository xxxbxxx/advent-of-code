# IO.puts("Hello world from Elixir")

{:ok, input} = File.read("2021/day07.txt")

input =
  input
  |> String.trim()
  |> String.split(",")
  |> Enum.map(&String.to_integer/1)

# IO.inspect(input)

defmodule AOC do
  def computeTotalFuel(list, t, fuelcostFn) do
    # je pense que ça marche parceque c'est la mediane en fait https://math.stackexchange.com/questions/113270/the-median-minimizes-the-sum-of-absolute-deviations-the-ell-1-norm
    Enum.reduce(list, 0, fn p, total -> total + fuelcostFn.(t - p) end)
  end

  def best(list, fuelcostFn) do
    min = Enum.min(list)
    max = Enum.max(list)
    Enum.min(Stream.map(min..max, fn x -> computeTotalFuel(list, x, fuelcostFn) end))
  end
end

part1 = AOC.best(input, fn x -> abs(x) end)
part2 = AOC.best(input, fn x -> div(abs(x) * (abs(x) + 1), 2) end)
IO.puts("part1=#{part1}")
IO.puts("part2=#{part2}")
