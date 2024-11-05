#!/usr/bin/env python3

import platform
import json
import base64
import pickle

import numpy as np
import pandas as pd
import scanpy as sc
import SEACells
import matplotlib
import matplotlib.pyplot as plt
import seaborn as sns
import json

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

def read_config(path):
    with open(path) as handle:
        config = json.load(handle)
    return config, path[:-5]

def experiment_id_and_subconfig(config):
    return config['key'], config['value']

def run_standard_pp(adata):
    # Copy the counts to ".raw" attribute of the anndata since it is necessary for downstream analysis
    # This step should be performed after filtering 
    raw_ad = sc.AnnData(adata.X)
    raw_ad.obs_names, raw_ad.var_names = adata.obs_names, adata.var_names
    adata.raw = raw_ad

    ## RUN standard embedding
    #sc.pp.filter_cells(adata, min_genes=200)
    #sc.pp.filter_genes(adata, min_cells=3)
    # Normalize cells, log transform and compute highly variable genes
    sc.pp.normalize_per_cell(adata)
    sc.pp.log1p(adata)
    sc.pp.highly_variable_genes(adata, n_top_genes=1500)
    # Compute principal components - 
    # Here we use 50 components. This number may also be selected by examining variance explaint
    sc.tl.pca(adata, n_comps=50, use_highly_variable=True)
    sc.pp.neighbors(adata)
    sc.tl.umap(adata)
    return adata

def return_raw_to_X(adata):
    adata.X = adata.raw.X
    return adata


def subset_adata(adata, dataset_config):
    sub = adata.copy()
    ds_varnames = list(dataset_config.keys())
    for var in ds_varnames:
        if isinstance(dataset_config[var], list):
            sub = sub[sub.obs[var].isin(dataset_config[var])]
        else:
             sub = sub[sub.obs[var] == dataset_config[var]]
    return sub

def create_all_adata_subsets(adata, subconfig):
    dict_of_datasets = {}
    for k in list(subconfig.keys()):
        dict_of_datasets[k] = subset_adata(adata, subconfig[k])
    return dict_of_datasets


def compute_seacells(adata, n_SEACells, build_kernel_on, **kwargs):

    print(n_SEACells)
    # Run standard preprocesseing
    adata = run_standard_pp(adata)
    model = SEACells.core.SEACells(
        adata, 
        n_SEACells=n_SEACells, 
        build_kernel_on=build_kernel_on, 
        n_waypoint_eigs=kwargs['n_waypoint_eigs'],
        convergence_epsilon=kwargs['convergence_epsilon']
    )
    
    model.construct_kernel_matrix()
    # M = model.kernel_matrix
    
    # Initialize archetypes
    model.initialize_archetypes()
    
    model.fit(min_iter=10, max_iter=kwargs['max_iterations'])
    converged = model.RSS_iters[-2]-model.RSS_iters[-1]<model.convergence_threshold
    SEACell_ad = SEACells.core.summarize_by_SEACell(adata, SEACells_label='SEACell', summarize_layer='raw')

    if not converged:
        print(f'Warning: SEACells did not converge after {kwargs['max_iterations']} iterations')
    
    return adata, SEACell_ad
    


def run_seacells_on_all(config_id, dict_of_adata, tracer, n_SEACells, build_kernel_on, **kwargs):
    
    print(n_SEACells)
    list_of_colnames = []
    for key in dict_of_adata:
        # Run seacells
        sub, SEACell_ad = compute_seacells(dict_of_adata[key], n_SEACells, build_kernel_on,  **kwargs)

        SEACell_ad.write_h5ad(f"{config_id}_{key}_seacell.h5ad")

        # Create object to trace back the origin of the metacell
        tracer = pd.merge(tracer, sub.obs.SEACell, left_index=True, right_index=True, how='left')
        # make list to ensure colums are named in the correct order
        list_of_colnames.append(f"seacells:{key}")

    tracer.columns = list_of_colnames

    return tracer

### PRPOCESS PARAMETERS ###
n_SEACells =  "${params.n_seacells_per_group}"
print(n_SEACells)
build_kernel_on = 'X_pca'

arg_dict = {'n_waypoint_eigs': int("${n_waypoint_eigs}"),
           'max_iterations': int("${max_iterations}"),
           'convergence_epsilon': float("${convergence_epsilon}")}

config, config_id = read_config("${json}")
key, subconfig = experiment_id_and_subconfig(config)

adata = sc.read_h5ad("${h5ad}")
prefix = "${prefix}"

## subset the data
dict_of_adata = create_all_adata_subsets(adata, subconfig)
## create the anndata subdata sets
## This saves the data

## create the anndata subdata sets
## This saves the data
tracer = pd.DataFrame(index = adata.obs.index)
print(tracer)
print(dict_of_adata)
tracer = run_seacells_on_all(config_id, dict_of_adata, tracer, n_SEACells=n_SEACells, build_kernel_on=build_kernel_on, **arg_dict)


# add the metacell information to the adata object
adata.obs = adata.obs.merge(tracer,  left_index=True, right_index=True, how='left')

# save the adata, save the metadata columns
tracer.to_pickle("${prefix}.pkl")
adata.write_h5ad("${prefix}.h5ad")



# # MultiQC
# with open(path, "rb") as f_plot, open("${prefix}_mqc.json", "w") as f_json:
#     image_string = base64.b64encode(f_plot.read()).decode("utf-8")
#     image_html = f'<div class="mqc-custom-content-image"><img src="data:image/png;base64,{image_string}" /></div>'

#     custom_json = {
#         "id": "${prefix}",
#         "parent_id": "${meta.integration}",
#         "parent_name": "${meta.integration}",
#         "parent_description": "Results of the ${meta.integration} integration.",

#         "section_name": "${meta.id} PAGA",
#         "plot_type": "image",
#         "data": image_html,
#     }

#     json.dump(custom_json, f_json)

# Versions

versions = {
    "${task.process}": {
        "python": platform.python_version(),
        "scanpy": sc.__version__,
        'seacells': SEACells.__version__
    }
}

with open("versions.yml", "w") as f:
    f.write(format_yaml_like(versions))
