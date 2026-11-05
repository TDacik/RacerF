import os
import re
import sys
import yaml
import argparse

from pathlib import Path
from dataclasses import dataclass

from subprocess import run, PIPE, TimeoutExpired

BENCHMARKS = "benchmarks/data_races"

class colors:
    gray = "\033[90m"
    red = "\033[91m"
    green = "\033[92m"
    yellow = "\033[93m"
    cyan = "\033[96m"
    end = "\033[0m"
    bold = "\033[1m"
    white = "\033[m"

def print_ok(text):
    print(f"{colors.green}{text}{colors.white}")

def print_debug(text):
    print(f"{colors.gray}{text}{colors.white}")

def print_err(text):
    print(f"{colors.red}{text}{colors.white}")

def print_unknown(text):
    print(f"{colors.yellow}{text}{colors.white}")

def print_fixed(text):
    print(f"{colors.cyan}{text}{colors.white}")

@dataclass
class TestCase:
    path: Path
    ground_truth: bool
    expected_verdict: bool | None # None denotes unknown

    def __str__(self):
        return f"{self.name} (verdict: {self.ground_truth}, expected: {self.expected_verdict})"

    @property
    def name(self):
        return self.path.name

    @staticmethod
    def get_ground_truth(path):
        res = []
        with open(path, "r") as f:
            for number, line in enumerate(f, start=1):
                if re.search(r"//\s*race", line, re.IGNORECASE):
                    res.append(number)
        return not(res)
    
    @staticmethod
    def get_expected_verdict(path):
        with open(path, "r") as f:
            header = f.readlines()[0]
            # TODO: do this properly
            if header.startswith("//# expected: unknown"):
                return None
        return TestCase.get_ground_truth(path)

    @classmethod
    def from_path(cls, path):
        ground_truth = cls.get_ground_truth(path)
        expected_verdict = cls.get_expected_verdict(path)
        return cls(path, ground_truth, expected_verdict)

    def check_verdict(self, actual):
        prefix = self.name
        if self.expected_verdict is None and actual is None:
            print_ok(f"{prefix}: unknown")
            return True
        if self.expected_verdict == True and actual == False:
            print_err(f"{prefix}: false alarm")
            return False
        if self.expected_verdict == False and actual == True:
            print_err(f"{prefix}: missed data race")
            return False
        if self.expected_verdict is not None and actual is None:
            print_unknown(f"{prefix}: regression")
            return False
        if self.expected_verdict is None and actual == self.ground_truth:
            print_improvement(f"{prefix}: correct!!")
            return True
        if self.expected_verdict is None and actual != self.ground_truth:
            print_err(f"{prefix}: TODO: wrong")
            return False
        
        print_ok(f"{prefix}: OK")
        return True

class Runner:
    def __init__(self, debug=False, timeout=10):
        self.debug = debug
        self.timeout = timeout
        self.all_correct = True

    def read_verdict(self, res):
        stdout = res.stdout.decode().strip()
        if "The result may be imprecise" in stdout:
            return None
        if "Data race (must)" in stdout:
            return False
        if "No data races found" in stdout:
            return True
        # Some may data races found
        return None

    def check_verdict(self, test_case, res):
        if res.returncode != 0:
            print_err(f"{test_case.name}: error")
            self.all_correct = False
            return

        verdict = self.read_verdict(res)
        res = test_case.check_verdict(verdict)
        self.all_correct = self.all_correct and res
        return

    def run(self, test_case):
        if self.debug:
            print_debug(str(test_case))

        command = ["scripts/racerf.py", str(test_case.path)]

        if self.debug:
            print_debug(" ".join(command))

        try:
            res = run(command, timeout=self.timeout, stdout=PIPE, stderr=PIPE)
            return self.check_verdict(test_case, res)
        except TimeoutExpired:
            print_warning(f"{self.name}: timeout")

    def run_all(self):
        for root, _, files in sorted(os.walk(BENCHMARKS)):
            path = Path(root)
            if any([f.endswith(".c") for f in files]):
                print(f"{colors.bold}{path.name}{colors.end}")
            for f in sorted(files):
                if f.endswith(".c"):
                    test = TestCase.from_path(path / f)
                    self.run(test)

        if self.all_correct:
            return 0
        return 1


def main():
    runner = Runner()
    return runner.run_all()

if __name__ == "__main__":
    sys.exit(main())
