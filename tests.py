import subprocess
from pathlib import Path

class IntegrationTests:
    DEFAULT_BIN_PATH = "./zig-out/bin/cli_calculator"
    GREEN = "\033[92m"
    RED = "\033[91m"
    RESET = "\033[0m"

    def run(self, cases):
        self.__pre_run()

        for case, expected in cases:
            print(f"testing {case} ...", end="")
            output = self.__run_calculator(case)
            if output == expected:
                print(f"{self.GREEN}✓ ok {self.RESET}")
            else:
                print(f"{self.RED}ko. expected: {expected} - actual: {output}{self.RESET}")

    def __pre_run(self):
        if not self.__bin_exists():
            self.__compile()

    def __bin_exists(self):
        fd = Path(self.DEFAULT_BIN_PATH)
        return fd.exists() and fd.is_file()

    def __compile(self):
        result = subprocess.run(["zig", "build"])
        return result.returncode == 0

    def __run_calculator(self, input):
        output = subprocess.run([self.DEFAULT_BIN_PATH, input], capture_output=True).stderr.decode("utf8").strip()
        try:
            return int(output)
        except:
            return output
        

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
    

if __name__ == '__main__':
    tests = IntegrationTests()
    tests.run(cases)
