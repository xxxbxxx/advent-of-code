# advent-of-code
https://adventofcode.com/ solutions in zig for fun.

needs latest zig master.

* `zig build run`  runs all days from 2018, 2019, 2020, 2021\
older years not included in the build script.  (and may not even compile with latest zig version)

* `zib build run2020` for a specific year

* manually run a single day:
   - for 2021:\
	`zig run 2021/day03.zig  --pkg-begin "tools" "common/tools_v2.zig" --pkg-end`
   - older years:\
	 `zig run 2018/day10.zig  --pkg-begin "tools" "common/tools.zig" --pkg-end`

* make an exe with all days and input embeded:\
  - `zig build-exe 2021/alldays.zig  --pkg-begin "tools" "common/tools_v2.zig" --pkg-end -OReleaseFast` (runtime ~750ms)
  - `zig build-exe 2020/alldays.zig  --pkg-begin "tools" "common/tools.zig" --pkg-end -OReleaseFast`  (runtime < 1 second)
  - `zig build-exe 2019/alldays.zig  --pkg-begin "tools" "common/tools.zig" --pkg-end -OReleaseFast`  (runtime < 5 second)

* 2019 intcode bench: (best year by far! )\
   `zig run 2019/intcode_bench.zig  --pkg-begin "tools" "common/tools.zig" --pkg-end -OReleaseFast`

```
benching 'sum-of-primes'...
...ok. 15ms
benching 'ackermann'...
...ok. 9ms
benching 'isqrt'...
...ok. 36µs
benching 'divmod'...
...ok. 39µs
benching 'factor1'...
...ok. 36ms
benching 'factor2'...
...ok. 94ms
```
