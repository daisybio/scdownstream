#!/usr/bin/env python3

import scvi
import anndata as ad
import pandas as pd
from scvi.model import SCVI, SCANVI
import platform
import torch

torch.set_float32_matmul_precision('medium')

from threadpoolctl import threadpool_limits
threadpool_limits(int("${task.cpus}"))
scvi.settings.num_threads = int("${task.cpus}")

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
reference_model_path = "reference_model"
reference_model_type = "${meta2.id}"

if reference_model_type == "scanvi":
    SCANVI.prepare_query_anndata(adata, reference_model_path)
    model = SCANVI.load_query_data(adata, reference_model_path)
else:
    unique_labels = set(adata.obs["label"].unique())
    unique_labels.discard("unknown")

    if not len(unique_labels) > 1:
        raise ValueError("Not enough labels to run scANVI.")

    if reference_model_type == "scvi":
        SCVI.prepare_query_anndata(adata, reference_model_path)
        model = SCVI.load(reference_model_path, adata)
        model = SCANVI.from_scvi_model(
            scvi_model=model, labels_key="label", unlabeled_category="unknown"
        )
    else:
        SCANVI.setup_anndata(adata, batch_key="batch", labels_key="label", unlabeled_category="unknown")
        model = SCANVI(adata,
                        n_hidden=int("${n_hidden}"),
                        n_layers=int("${n_layers}"),
                        n_latent=int("${n_latent}"),
                        dispersion="${dispersion}",
                        gene_likelihood="${gene_likelihood}")

if "${task.ext.use_gpu}" == "true":
    model.to_device(0)

model.train(early_stopping=True)
adata.obsm["X_emb"] = model.get_latent_representation()
adata.obs["label:scANVI"] = model.predict()

adata.write_h5ad("${prefix}.h5ad")
adata.obs[["label:scANVI"]].to_pickle("${prefix}.pkl")
model.save("${prefix}_model")

df = pd.DataFrame(adata.obsm["X_emb"], index=adata.obs_names)
df.to_pickle("X_${prefix}.pkl")

# Versions

versions = {
    "${task.process}": {
        "python": platform.python_version(),
        "anndata": ad.__version__,
        "scvi": scvi.__version__,
    }
}

with open("versions.yml", "w") as f:
    f.write(format_yaml_like(versions))

