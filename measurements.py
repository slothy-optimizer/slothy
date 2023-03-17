from example import *
import os
import re
import time

from statistics import median, mean, variance, StatisticsError
from dataclasses import dataclass, fields, asdict
from datetime import datetime
import json

@dataclass
class Measurement:
    """Class for storing measurement data"""
    name: str
    target: str
    # wall times
    times_slothy: list
    mean_time_slothy: float
    median_time_slothy: float
    var_time_slothy: float
    # solver times
    times_solver: list
    mean_time_solver_total_infeasible: float
    median_time_solver_total_infeasible: float
    var_time_solver_total_infeasible: float
    mean_time_solver_total_feasible: float
    median_time_solver_total_feasible: float
    var_time_solver_total_feasible: float
    # output file size
    size: int
    # collected over all iterations, then processed
    variables: list
    max_variables: int
    mean_variables: float
    median_variables: float
    var_variables: float
    # should remain constant without heuristics
    instrs: int
    variable_size: bool

    def latex_vars(self):
        vars = []
        for field in fields(Measurement):
            value = getattr(self, field.name)
            if type(value) == str:
                continue  # don't print Latex variable for the name
            elif type(value) == float:
                value = round(value, 2)
            vars.append(f"\\DefineVar{{{self.name}_{field.name}}}{{{value}}}\n")
        return vars

    def print_vars(self):
        vars = []
        for field in fields(Measurement):
            value = getattr(self, field.name)
            vars.append(f"{field.name}: {value}\n")
        return vars

    def write_measurement(self, iterations, name, latex=False, write_json=False):
        import platform
        with open(f"examples/{name}.txt", "a+") as m_file:
            m_file.write(f"\n# Measurement on {datetime.now()} (iterations: {iterations}, CPU: {platform.machine()})\n")
            m_file.write(f"## {self.name}\n")
            for line in self.print_vars():
                m_file.write(line)

            if latex:
                m_file.write("Latex:\n")
                for line in self.latex_vars():
                    m_file.write(line)


# Log parsing

def parse_log_vars(log):
    vars = re.findall(f"Booleans in result:\s*(?P<vars>.*)", log)
    return [int(x) for x in vars]


def parse_log_instrs(log):
    instrs = re.findall(r"Instructions in body:\s*(?P<instrs>.*)", log)
    return int(instrs[0])


def parse_log_variable_size(log):
    variable_size = re.findall(r"variable_size", log)
    return len(variable_size) != 0


def parse_log_solver_time(log):
    times = re.findall(r"(?P<result>\w+), wall time:\s*(?P<time>.*)s", log)
    infeasible_times = []
    feasible_times = []
    for t in times:
        if t[0] == "INFEASIBLE":
            infeasible_times.append(float(t[1]))
        else:
            feasible_times.append(float(t[1]))
    return (infeasible_times, feasible_times)


def main():
    examples = [# a55
                 ntt_kyber_123(),
                 ntt_kyber_4567(),
                 ntt_kyber_123(var="scalar_load"),
                 ntt_kyber_4567(var="scalar_load"),
                 ntt_kyber_4567(var="scalar_store"),
                 ntt_kyber_4567(var="scalar_load_store"),
                 ntt_kyber_4567(var="manual_st4"),
                 ntt_kyber_1234(target=Target_CortexA55),
                 ntt_kyber_567(target=Target_CortexA55),
                 # a72
                 ntt_kyber_123(target=Target_CortexA72),
                 ntt_kyber_4567(target=Target_CortexA72),
                 ntt_kyber_123(var="scalar_load", target=Target_CortexA72),
                 ntt_kyber_4567(var="scalar_load", target=Target_CortexA72),
                 ntt_kyber_4567(var="scalar_store", target=Target_CortexA72),
                 ntt_kyber_4567(var="scalar_load_store", target=Target_CortexA72),
                 ntt_kyber_4567(var="manual_st4", target=Target_CortexA72),
                 ntt_kyber_1234(),
                 ntt_kyber_567(),
                 # a55
                 ntt_dilithium_123(),
                 ntt_dilithium_45678(),
                 ntt_dilithium_123(var="w_scalar"),
                 ntt_dilithium_45678(var="w_scalar"),
                 ntt_dilithium_45678(var="manual_st4"),
                 ntt_dilithium_1234(target=Target_CortexA55),
                 ntt_dilithium_5678(target=Target_CortexA55),
                 # a72
                 ntt_dilithium_123(target=Target_CortexA72),
                 ntt_dilithium_45678(target=Target_CortexA72),
                 ntt_dilithium_123(var="w_scalar", target=Target_CortexA72),
                 ntt_dilithium_45678(var="w_scalar", target=Target_CortexA72),
                 ntt_dilithium_45678(var="manual_st4", target=Target_CortexA72),
                 ntt_dilithium_1234(),
                 ntt_dilithium_5678(),
                 # m55
                 ntt_kyber_1(), ntt_kyber_12(), ntt_kyber_23(), ntt_kyber_45(), ntt_kyber_67(),
                 ntt_dilithium_12(), ntt_dilithium_34(), ntt_dilithium_56(), ntt_dilithium_78(),
                 # m85
                 ntt_kyber_1(Target=Target_CortexM85r1), ntt_kyber_12(Target=Target_CortexM85r1),
                 ntt_kyber_23(Target=Target_CortexM85r1), ntt_kyber_45(Target=Target_CortexM85r1),
                 ntt_kyber_67(Target=Target_CortexM85r1),
                 ntt_dilithium_12(Target=Target_CortexM85r1), ntt_dilithium_34(Target=Target_CortexM85r1),
                 ntt_dilithium_56(Target=Target_CortexM85r1), ntt_dilithium_78(Target=Target_CortexM85r1),
                 ]
    all_example_names = [ e.name for e in examples ]

    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("--examples", type=str, default="all",
                        help=f"The list of examples to be run, comma-separated list from {all_example_names}")
    parser.add_argument("--debug", default=False, action="store_true")
    parser.add_argument("--latex", default=False, action="store_true")
    parser.add_argument("--json", default=False, action="store_true")
    parser.add_argument("--iterations", type=int, default=1)

    args = parser.parse_args()
    if args.examples != "all":
        todo = args.examples.split(",")
    else:
        todo = all_example_names
    iterations = args.iterations

    def run_example(ex, debug=False):
        start_time = time.time()
        output_path, log = ex.run(debug=debug)
        end_time = time.time()
        return end_time-start_time, output_path, log

    name = f"measurement_{datetime.now()}"
    measurements = []
    for e in todo:
        ex = None
        for e_try in examples:
            if e_try.name == e:
                ex = e_try
                break
        if ex is None:
            raise Exception(f"Could not find example {name}")
        time_measurements_slothy = []
        time_measurements_solver = []
        log_vars = []
        output_path = ""
        log = ""
        for _ in range(iterations):
            t, output_path, log = run_example(ex, debug=args.debug)
            time_measurements_slothy.append(t)
            time_measurements_solver.append(parse_log_solver_time(log))
            log_vars += (parse_log_vars(log))

        # analyze run
        file_size = 0
        log_instrs = []
        if output_path is not None:
            file_size = os.path.getsize(output_path)
        log_instrs = parse_log_instrs(log)  # extract number of instructions

        def variance_safe(data):
            try:
                v = variance(data)
            except StatisticsError:
                v = 0
            return v

        new_measurement = Measurement(ex.name,
                                      target_label_dict[ex.target],
                                      time_measurements_slothy,
                                      mean(time_measurements_slothy),
                                      median(time_measurements_slothy),
                                      variance_safe(time_measurements_slothy),
                                      # sum() to accumulate times for each run
                                      time_measurements_slothy,
                                      mean([sum(x[0]) for x in time_measurements_solver]),
                                      median([sum(x[0]) for x in time_measurements_solver]),
                                      variance_safe([sum(x[0]) for x in time_measurements_solver]),
                                      mean([sum(x[1]) for x in time_measurements_solver]),
                                      median([sum(x[1]) for x in time_measurements_solver]),
                                      variance_safe([sum(x[1]) for x in time_measurements_solver]),
                                      file_size,
                                      log_vars,
                                      max(log_vars),
                                      mean(log_vars),
                                      median(log_vars),
                                      variance_safe(log_vars),
                                      log_instrs,
                                      parse_log_variable_size(log))
        measurements.append(new_measurement)
        new_measurement.write_measurement(iterations, name, latex=args.latex, write_json=args.json)
    measurements_dicts = [asdict(m) for m in measurements]
    if args.json:
        with open(f"examples/{name}.json", "w") as m_file:
            m_file.write(json.dumps(measurements_dicts))


if __name__ == "__main__":
    main()
