# cli-calculator
cli calculator in zig

# dependencies

* python3
* zig 0.15.X

# build and run
zig build
./zig-out/bin/cli_calculator 1+1

# run tests

### integration tests
python3 tests.py

### zig tests
zig build test --summary all
