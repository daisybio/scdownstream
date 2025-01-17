#!/usr/bin/env python3

import os
import platform
from collections import defaultdict

os.environ["NUMBA_CACHE_DIR"] = "./tmp/numba"
os.environ["MPLCONFIGDIR"] = "./tmp/matplotlib"

import numpy as np
import scipy
from scipy.sparse import csr_matrix
import anndata as ad
import scanpy as sc

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

adatas = [sc.read_h5ad(f) for f in "${h5ads}".split()]

base_path = "${base}"
if base_path:
    adata_base = sc.read_h5ad(base_path)
    adatas = [adata_base] + adatas

genes = [adata.var_names for adata in adatas]
obs_col_intersection = set(adatas[0].obs.columns).intersection(*[adata.obs.columns for adata in adatas[1:]])
force_obs_cols = "${force_obs_cols}"
obs_col_intersection = list(obs_col_intersection.union(force_obs_cols.split(",") if force_obs_cols else []))
sorted(obs_col_intersection)

def get_columns(adata):
    return {dtype: adata.obs.select_dtypes(include=dtype).columns for dtype in ["object", "category", "number"]}

column_dtypes = defaultdict(set)

for adata in adatas:
    for dtype, columns in get_columns(adata).items():
        for column in columns:
            column_dtypes[column].add(dtype)

column_defaults = {}

for column, dtypes in column_dtypes.items():
    if len(dtypes) > 1:
        for adata in adatas:
            if column in adata.obs.columns:
                adata.obs[column] = adata.obs[column].astype("object")
        column_defaults[column] = "unknown"
    else:
        column_defaults[column] = np.nan if dtypes.pop() == "number" else "unknown"

for adata in adatas:
    for col in set(obs_col_intersection).difference(adata.obs.columns):
        adata.obs[col] = column_defaults[col]
    adata.obs = adata.obs[obs_col_intersection]

    for col in obs_col_intersection:
        if column_dtypes[col] == {"number"}:
            continue
        adata.obs[col] = adata.obs[col].astype(str).astype("category")

adata_outer = ad.concat(adatas, join="outer")
adata_outer.X = csr_matrix(adata_outer.X)

gene_intersection = set(genes[0]).intersection(*genes[1:])
intersection_mask = adata_outer.var_names.to_series(name='intersection').map(lambda x: x in gene_intersection)
adata_inner = adata_outer[:, intersection_mask]

intersection_mask.to_pickle("gene_intersection.pkl")

adata_outer.write("${prefix}_outer.h5ad")
adata_inner.write("${prefix}_inner.h5ad")

if base_path:
    adata_integrate = adata_inner[~adata_inner.obs.index.isin(adata_base.obs.index)]

    known_labels = adata_base.obs["label"].unique()
    adata_integrate.obs["label"] = adata_integrate.obs["label"].map(
        lambda x: x if x in known_labels else "unknown"
    )
    adata_integrate.write("${prefix}_integrate.h5ad")
else:
    # Create symlink to the inner dataset
    os.symlink("${prefix}_inner.h5ad", "${prefix}_integrate.h5ad")


# Versions

versions = {
    "${task.process}": {
        "python": platform.python_version(),
        "scanpy": sc.__version__,
        "anndata": ad.__version__,
        "scipy": scipy.__version__,
    }
}

with open("versions.yml", "w") as f:
    f.write(format_yaml_like(versions))
