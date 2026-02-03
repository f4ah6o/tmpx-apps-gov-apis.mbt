///|
test "version benchmark" (b : @bench.T) {
  b.bench(fn() { ignore(version()) })
}
