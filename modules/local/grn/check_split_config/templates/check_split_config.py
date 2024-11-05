#!/usr/bin/env python3

import os
import platform
import json
import base64

# os.environ['MPLCONFIGDIR'] = os.getcwd() + "/configs/"
# os.environ[ 'NUMBA_CACHE_DIR' ] = '/tmp/'

import scanpy as sc

from threadpoolctl import threadpool_limits
threadpool_limits(int("${task.cpus}"))
sc.settings.n_jobs = int("${task.cpus}")

def format_yaml_like(data: dict, indent: int = 0) -> str:
    """Formats a dictionary to a YAML-like string.

    Args:
        data (dict): The dictionary to format.
        indent (int): The current indentation level.

    Returns:
        str: A string formatted as YAML.
    """
    yaml_str = ""
    for key, value in data.items():
        spaces = "  " * indent
        if isinstance(value, dict):
            yaml_str += f"{spaces}{key}:\\n{format_yaml_like(value, indent + 1)}"
        else:
            yaml_str += f"{spaces}{key}: {value}\\n"
    return yaml_str

adata = sc.read_h5ad("${h5ad}", backed='r')
prefix = "${prefix}"

# Load json file
with open('${split_config}', 'r') as file:
    data = json.load(file)

# Non unique IDs
if len(data.keys()) > len(set(data.keys())):
    raise Exception("Split IDs are not unique")
     
# Looping over all splits
for _, split_val in data.items():
    # Looping over all groups in each split
    if len(split_val.items()) > 2:
        raise Exception("More than two groups in a split! The differential test only supports the comparison of two grups.")

    for group_key, _ in split_val.items():
        if not set(split_val[group_key].keys()).issubset(adata.obs.columns):
            raise Exception(f"Group keys {set(split_val[group_key].keys()).difference(set(adata.obs.columns))} are not subset of adata.obs.columns") 


with open('${split_config}', 'w') as f:
    json.dump(data, f)
    
versions = {
    "${task.process}": {
        "python": platform.python_version(),
        "scanpy": sc.__version__
    }
}

with open("versions.yml", "w") as f:
    f.write(format_yaml_like(versions))