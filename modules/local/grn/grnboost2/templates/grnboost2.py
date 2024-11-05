#!/usr/bin/env python3

import os
import platform
import json
import base64

os.environ[ 'NUMBA_CACHE_DIR' ] = '/tmp/'
# os.environ['MPLCONFIGDIR'] = "/tmp/"

import scanpy as sc
import resource
from importlib.metadata import version
from arboreto.algo import grnboost2
from arboreto.utils import load_tf_names

from threadpoolctl import threadpool_limits
threadpool_limits(int("${task.cpus}"))
sc.settings.n_jobs = int("${task.cpus}")

from distributed import Client, LocalCluster

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


sample_id = "${sample_h5ad}"[:-5]
adata = sc.read_h5ad("${sample_h5ad}")
use_gpu = "${task.ext.use_gpu}" == "true"
prefix = "${prefix}"

if adata.n_vars > 15000:
    adata.layers["raw"] = adata.X.copy()
    sc.pp.normalize_total(adata)
    sc.pp.log1p(adata)
    sc.pp.highly_variable_genes(adata, n_top_genes=15000)
    expr_matrix = adata[:, adata.var.highly_variable].to_df(layer="${layer}")

if "${params.grn_tflist}" != 'all':
    tf_names = load_tf_names("${params.grn_tflist}")
else:
    tf_names = 'all'

def main(expr_matrix, tf_names, prefix):
    client = Client(LocalCluster())
    network = grnboost2(
        expression_data=expr_matrix.to_numpy(), 
        gene_names=expr_matrix.columns, 
        tf_names=tf_names, 
        verbose=False,
        client_or_address=client
    )  

    network.to_csv(f"{sample_id}_grnboost2.csv", sep='\t', index=False)

    versions = {
        "${task.process}": {
            "python": platform.python_version(),
            "scanpy": sc.__version__,
            "arboreto": version('arboreto')
        }
    }

    with open("versions.yml", "w") as f:
        f.write(format_yaml_like(versions))

if __name__ == '__main__':
    main(expr_matrix, tf_names, prefix)