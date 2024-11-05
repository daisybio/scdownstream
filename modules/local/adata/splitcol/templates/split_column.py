#!/usr/bin/env python3

import platform

import pandas as pd
import anndata as ad

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

adata = ad.read_h5ad("${h5ad}")
column = "${column}"

assert column in adata.obs.columns, f"Column {column} not found in adata."

for value in adata.obs[column].unique():
    adata_subset = adata[adata.obs[column] == value]
    value = value.replace(" ", "_")
    adata_subset.write_h5ad(f"{value}.h5ad")

# Versions

versions = {
    "${task.process}": {
        "python": platform.python_version(),
        "anndata": ad.__version__
    }
}

with open("versions.yml", "w") as f:
    f.write(format_yaml_like(versions))
