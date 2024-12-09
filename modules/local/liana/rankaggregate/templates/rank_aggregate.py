#!/usr/bin/env python3

import os
import platform

os.environ["NUMBA_CACHE_DIR"] = "./tmp/numba"
os.environ["MPLCONFIGDIR"] = "./tmp/matplotlib"

import pandas as pd
import scanpy as sc
import liana as li

from threadpoolctl import threadpool_limits
threadpool_limits(int("${task.cpus}"))

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

adata = sc.read_h5ad("${h5ad}")
prefix = "${prefix}"
obs_key = "${obs_key}"

if adata.obs[obs_key].nunique() > 1:
    if (adata.X < 0).nnz == 0:
        sc.pp.log1p(adata)
    li.mt.rank_aggregate(adata, obs_key, use_raw=False, verbose=True, n_jobs=int("${task.cpus}"))
    df: pd.DataFrame = adata.uns["liana_res"]

    df.to_pickle(f"{prefix}.pkl")
    adata.write_h5ad(f"{prefix}.h5ad")
else:
    print(f"Skipping rank aggregation because the column {obs_key} has only one unique value.")

# Versions

versions = {
    "python": platform.python_version(),
    "scanpy": sc.__version__,
    "liana": li.__version__,
}

with open("versions.yml", "w") as f:
    f.write(format_yaml_like(versions))
