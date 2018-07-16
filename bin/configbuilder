#!/usr/bin/env python
import argparse
from string import Template

CONFIG_TEMPLATE = """
[mapping]

# Absolute path to RazerS3 binary, and number of threads to use for mapping

razers3=razers3
threads=$max_cpus

[ilp]

# A Pyomo-supported ILP solver. The solver must be globally accessible in the
# environment OptiType is run, so make sure to include it in PATH.
# Note: this is NOT a path to the solver binary, but a keyword argument for
# Pyomo. Examples: glpk, cplex, cbc.

solver=$solver
threads=$solver_threads

[behavior]

# tempdir=/path/to/tempdir  # we may enable this setting later. Not used now.

# Delete intermediate bam files produced by RazerS3 after OptiType finished
# loading them. If you plan to re-analyze your samples with different settings
# disabling this option can be a time-saver, as you'll be able to pass the bam
# files to OptiType directly as input and spare the expensive read mapping
# step.

deletebam=true

# In paired-end mode one might want to use reads with just one mapped end (e.g.,
# the other end falls outside the reference region). This setting allows the
# user to keep them with an optionally reduced weight. A value of 0 means they
# are discarded for typing, 0.2 means single reads are "worth" 20% of paired
# reads, and a value of 1 means they are treated as valuable as properly mapped
# read pairs. Note: unpaired reads will be reported on the result coverage plots
# for completeness, regardless of this setting.

unpaired_weight=0

# We call a read pair discordant if its two ends best-map to two disjoint sets
# of alleles. Such reads can be either omitted or either of their ends treated
# as unpaired hits. Note: discordant read pairs are reported on the coverage
# plots as unpaired reads, regardless of this setting.

use_discordant=false
"""

def generate_config_file(values):
    config_template = Template(CONFIG_TEMPLATE)
    return config_template.substitute(values)

def __main__():
    parser = argparse.ArgumentParser(description="""Generate config file for OptiType Nextflow workflow.""")
    parser.add_argument('-m', "--max-cpus", help='Specifies the maximum number of used cpus.', required=True)
    parser.add_argument('-s', "--solver", help="Specifies the solver used by OptiType.", required=True)

    args = parser.parse_args()
    
    """ Not all IP solvers are multi-threaded.

    So we have to tell the script, which solvers to restrict the number of threads.
    """
    solver_threads_config = {
        'glpk': 1 # The glpk solver is not multi-threaded, so we have to set it to one
    }

    max_solver_threads = solver_threads_config[args.solver] if solver_threads_config.get(args.solver) else args.max_cpus

    print(generate_config_file({'solver':args.solver, 'max_cpus':args.max_cpus, 'solver_threads':max_solver_threads}))

if __name__ == "__main__":
    __main__()
