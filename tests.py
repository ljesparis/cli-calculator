import subprocess
from pathlib import Path

DEFAULT_PATH = "./zig-out/bin/cli_calculator"

GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"

def bin_exists():
    fd = Path(DEFAULT_PATH)
    return fd.exists() and fd.is_file()

def compile():
    result = subprocess.run(["zig", "build"])
    return result.returncode == 0

def run_calculator(input):
    output = subprocess.run([DEFAULT_PATH, input], capture_output=True).stderr.decode("utf8").strip()
    try:
        return int(output)
    except:
        return output

def run_tests():
    cases = [
            ("0+0", 0),
            ("0-0", 0),
            ("0*0", 0),
            ("10/5", 2),
            ("5-10", -5),
            ("100-50+25", 75),
            ("10+10*10", 110),
            ("100/10*2+5", 25),
            ("10*10/5-5", 15),
            ("99999+1", 100000),
            ("12345*6789", 83810205),
            ("1000000/1", 1000000),
            ("1000000-999999", 1),
            ("7/2", 3),
            ("10/3", 3),
            ("9/4", 2),
            ("", "Syntax error"),
            ("2++2", "Syntax error"),
            ("10**2", "Syntax error"),
            ("a", "IllegalCharacter"),
            ("-", "Syntax error"),
            ("1/", "Syntax error"),
            ("/1", "Syntax error"),
            ("10//2", "Syntax error"),
    ]
    for case, expected in cases:
        print(f"testing {case} ...", end="")
        output = run_calculator(case)
        if output == expected:
              print(f"{GREEN}✓ ok {RESET}")
        else:
              print(f"{RED}ko. expected: {expected} - actual: {output}{RESET}")


if not bin_exists():
    compile()

run_tests()

