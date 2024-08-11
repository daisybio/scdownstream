#!/usr/bin/env python3

import scanpy as sc
import scipy
import numpy as np
from scipy.sparse import csr_matrix
import platform

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

# Function borrowed from https://github.com/icbi-lab/luca/blob/5ffb0a4671e9c288b10e73de18d447ee176bef1d/lib/scanpy_helper_submodule/scanpy_helpers/util.py#L122C1-L135C21
def aggregate_duplicate_var(adata, aggr_fun=np.mean):
    retain_var = ~adata.var_names.duplicated(keep="first")
    duplicated_var = adata.var_names[adata.var_names.duplicated()].unique()
    if len(duplicated_var):
        for var in duplicated_var:
            mask = adata.var_names == var
            var_aggr = aggr_fun(adata.X[:, mask], axis=1)[:, np.newaxis]
            adata.X[:, mask] = np.repeat(var_aggr, np.sum(mask), axis=1)

        adata_dedup = adata[:, retain_var].copy()
        return adata_dedup
    else:
        return adata

adata = sc.read_h5ad("$h5ad")

# Aggregate duplicate genes
method = "${params.var_aggr_method}"
if not method in ["mean", "sum", "max"]:
    raise ValueError(f"Invalid aggregation method: {method}")

adata = aggregate_duplicate_var(adata, aggr_fun=getattr(np, method))

# Prevent duplicate cells
adata.obs_names_make_unique()
adata.obs_names = "${meta.id}_" + adata.obs_names

# Unify batches
batch_col = "${meta.batch_col}"
if batch_col not in adata.obs:
    adata.obs[batch_col] = "${meta.id}"

if batch_col != "batch":
    if "batch" in adata.obs:
        raise ValueError("The batch column already exists.")
    adata.obs["batch"] = adata.obs[batch_col]
    del adata.obs[batch_col]

# Unify labels
label_col = "${meta.label_col ?: ''}"
unknown_label = "${meta.unknown_label}"

if label_col:
    if label_col != "label":
        if "label" in adata.obs:
            raise ValueError("The label column already exists.")
        adata.obs["label"] = adata.obs[label_col]
        del adata.obs[label_col]

    if unknown_label != "unknown":
        if "unknown" in adata.obs["label"]:
            raise ValueError("The label column already contains 'unknown' values.")
        adata.obs["label"].replace({unknown_label: "unknown"}, inplace=True)
else:
    if "label" in adata.obs:
        raise ValueError("The label column already exists.")
    adata.obs["label"] = "unknown"

# Unify gene symbols
symbol_col = "${meta.symbol_col ?: 'index'}"

if symbol_col != "gene_symbol":
    if "gene_symbol" in adata.var:
        raise ValueError("The gene symbol column already exists.")
    if symbol_col == "index":
        adata.var["gene_symbol"] = adata.var_names
    elif symbol_col == "none":
        raise ValueError("Automatic gene symbol conversion is not supported yet.")
    else:
        adata.var["gene_symbol"] = adata.var[symbol_col]
        del adata.var[symbol_col]

# Add "sample" column
if "sample" in adata.obs and not adata.obs["sample"].equals("${meta.id}"):
    adata.obs["sample_original"] = adata.obs["sample"]
adata.obs["sample"] = "${meta.id}"

# Convert to CSR matrix
adata.X = csr_matrix(adata.X)
adata.layers["counts"] = adata.X

adata.write_h5ad("${prefix}.h5ad")

# Versions

versions = {
    "${task.process}": {
        "python": platform.python_version(),
        "scanpy": sc.__version__,
        "scipy": scipy.__version__,
        "numpy": np.__version__
    }
}

with open("versions.yml", "w") as f:
    f.write(format_yaml_like(versions))
