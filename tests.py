import sys
import subprocess
from pathlib import Path
import shutil

class IntegrationTests:
    DEFAULT_PATH = "./zig-out"
    GREEN = "\033[92m"
    RED = "\033[91m"
    RESET = "\033[0m"

    def __init__(self, cases, delete_bin_dir):
        self.__cases = cases
        self.__delete_bin_dir = delete_bin_dir
        self.__binary = self.DEFAULT_PATH + "/bin/cli_calculator"

    def run(self):
        self.__pre_run()

        for case, expected in self.__cases:
            print(f"testing {case} ...", end="")
            output = self.__run_calculator(case)
            if output == expected:
                print(f"{self.GREEN}✓ ok {self.RESET}")
            else:
                print(f"{self.RED}ko. expected: {expected} - actual: {output}{self.RESET}")

    def __pre_run(self):
        if self.__delete_bin_dir:
            shutil.rmtree(self.DEFAULT_PATH)
        
        if not self.__bin_exists():
            self.__compile()

    def __bin_exists(self):
        fd = Path(self.__binary)
        return fd.exists() and fd.is_file()

    def __compile(self):
        result = subprocess.run(["zig", "build"])
        return result.returncode == 0

    def __run_calculator(self, input):
        output = subprocess.run([self.__binary, input], capture_output=True).stderr.decode("utf8").strip()
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
    ("(10+10)*100", 2000),
    ("(5+5)*10", 100),
    ("((10+5)*2)-5", 25),
    ("100/(5+5)", 10),
    ("(100+50)/25", 6),
    ("3*(4+5)-10", 17),
    ("(10-5)*(10+5)", 75),
    ("1000/(10*10)", 10),
    ("(1+2)*(3+4)", 21),
    ("10-(5-3)", 8),
    ("100-50*2", 0),
    ("(100-50)*2", 100),
    ("2*2*2*2", 16),
    ("100/10/2", 5),
    ("(10+20)/(3+2)", 6),
    ("  10   +   5  ", 15),
    ("(  10  +  5  )  *  2", 30),
    ("0/1", 0),
    ("1/1", 1),
    ("0*999999999", 0),
    ("10 + (5", "SyntaxError"),
    ("10 + 5)", "SyntaxError"),
    ("10 / (5-5)", "ZeroDivisionError"),
    ("10 + * 5", "SyntaxError"),
    ("10 + 5 *", "SyntaxError"),
    ("*10 + 5", "SyntaxError"),
    ("10 & 2", "IllegalCharacter"),
    ("10.5 + 2", "IllegalCharacter"),
    ("1a + 2", "IllegalCharacter"),
    ("(10 + 2))", "SyntaxError"),
    ("5 + 3 * (2 + 1", "SyntaxError"),
    ("2++2", "SyntaxError"),
    ("10**2", "SyntaxError"),
    ("a", "IllegalCharacter"),
    ("-", "SyntaxError"),
    ("1/", "SyntaxError"),
    ("/1", "SyntaxError"),
    ("10//2", "SyntaxError"),
    ("10/0", "ZeroDivisionError"),
]
    

if __name__ == '__main__':
    args = sys.argv[-1]
    tests = IntegrationTests(cases, args == '-d')
    tests.run()
