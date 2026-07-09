# texture-learning

Code for **"Proximity as a Ground-Truth Proxy for Training Texture Discrimination and Segmentation"**
(W. S. Geisler, [bioRxiv 2026](https://www.biorxiv.org/content/10.64898/2026.05.12.724620v1.abstract)).

## What it does

Telling whether two image patches are the *same* or *different* texture normally needs labelled ground
truth. This project's idea is that **spatial proximity is a free proxy for that label** — nearby patches
are usually the same texture, distant patches usually different — and, under mild assumptions, the
optimal *near-vs-far* decision boundary is the same as the optimal *same-vs-different* boundary. So a
biologically-plausible **Hierarchical Bayesian Observer (HBO)** model of texture discrimination can be
trained directly from *unlabelled* natural images, and then used to segment "grown-texture-region"
(GTR) images. See the [foundational segmentation paper](https://www.biorxiv.org/content/10.64898/2026.05.06.723304v1.abstract)
for the HBO model this builds on.

## Dependencies

- **[vislab-common](https://github.com/abhranildas/vislab-common)** — the lab's shared MATLAB library
  (the `+vislab` package inside the sibling `vislab-common` folder; `setup.m` clones it automatically if
  it's missing). Provides `vislab.lib.*` (optics, filters, normalization, …) and
  `vislab.nat_stat_bayes.*` (the decision-variable / natural-scene-statistics toolkit).
- **[IntClassNorm](https://github.com/abhranildas/IntClassNorm)** and
  **[gx2](https://github.com/abhranildas/gx2)** — installed MATLAB **add-on toolboxes** (Add-On Explorer /
  File Exchange). `setup.m` verifies they're installed; they are *not* bundled or fetched as source.
- **vislab-common/data** — the shared data store, a sibling folder alongside this repo. Its texture sheets
  and colour transforms ship inside the `vislab-common` repo (so `setup.m`'s auto-clone brings them along);
  the large calibrated **natural-image** set (~19 GB) is **too large for GitHub** and must be obtained
  separately. However, a small **12-image demo subset** (4 images from 3 sets) is included directly in the repo to allow out-of-the-box training. The model uses a **constant-volume sampling algorithm**, which dynamically increases the per-image patch count when run on small datasets so that the total number of sampled patches (and patch-pairs) remains fixed at ~7,820 regardless of dataset size. This ensures the demo dataset provides the same statistical richness as the full dataset.
- MATLAB with the Image Processing and Statistics & Machine Learning toolboxes.

## Installation and Setup

First, download or clone this repository to your local machine:
```bash
git clone https://github.com/abhranildas/texture-learning.git
cd texture-learning
```

Then, from within MATLAB, run:
```matlab
setup            % adds this repo + vislab to the path; checks the toolboxes
cfg = config;    % paths + parameters; edit cfg.paths.data_root if vislab-common/data isn't a sibling
```

## Quick demo

The `quickstart_demo.m` script demonstrates the entire model lifecycle. By changing the `demo_type` variable at the top of the script, you can run it in two modes:

- **`quick` mode**: Skips the expensive training phase (Stages 1-5) and uses the pre-trained models shipped in `data/models/`. It plots the learned parameters, and then evaluates the model (Stages 6-7) on a small set of Grown-Texture-Region (GTR) images. The evaluation takes a few minutes to run.
- **`full` mode**: Re-trains the model from scratch (Stages 1-5) before evaluating. During training, the script will pause to ask if you want to save (and overwrite) the newly-learned parameters to disk.

```matlab
quickstart_demo      % runs the demo according to the selected demo_type
```

## Model pipeline

The demo runs these stages in order (each is a function taking `cfg`). Stages 1–5 learn the model from natural
images and write artifacts to `data/models/`; stages 6–7 apply/evaluate it on GTR images.

| Stage | Function (`pipeline/`) | Produces |
|---|---|---|
| 1 | `s1_learn_color_transform(cfg)` | `vislab-common/data/cps_lms2abr_otf.mat` — LMS→ABR colour rotation (lab-shared) |
| 2 | `s2_learn_feature_priors(cfg)` | `priors_abr_mo13_mo23_cs33_otf.mat` — task-independent feature priors |
| 3 | `s3_make_nearfar_pairs(cfg, ecc)` | `patch_pairs_<ecc>.mat` — near/far training pairs |
| 4 | `s4_optimize_bins(cfg, dim, ecc)` | `AHEO<btype><dim><ecc>.mat` — adaptive histogram bins |
| 5 | `s5_train_decision_vars(cfg, ecc)` | `dbnd{h,e,c,b,bc}NO<ecc>.mat` — trained decision-variable bounds |
| 6 | `s6_selfsup_discrimination(cfg, method, itype, ecc, ntrl)` | per-image self-supervised discrimination accuracy surfaces (runs on GTR images built from Brodatz/Fabric source textures — see Quick demo) |
| 7 | `s7_segment_gtr(cfg, method, itype, ecc, n_images)` | GTR segmentation: correct-region counts over the merge x grouping-offset grid |

## Repository layout

```
texture-learning/
├── setup.m, config.m         path bootstrap + central configuration
├── pipeline/                 numbered pipeline stages s1..s7 (+ list_natural_images helper)
├── +segmentation/            grouping algorithm (content-similarity, grouping, region scoring)
├── +gtr/                     GTR stimulus generation (texture-region masks, texture assignment)
├── data/models/              shipped trained artifacts (PCA, priors, AHEO bins, dbnd bounds)
├── data/derived/             generated data (patch pairs, results) — git-ignored
└── docs/                     papers, GLOSSARY.md, DATA_DICTIONARY.md
```

Shared low-level code lives in `vislab` (not here), so it isn't duplicated across the lab's repos.


## Documentation

- `docs/GLOSSARY.md` — code names ↔ paper symbols ↔ meanings.
- `docs/DATA_DICTIONARY.md` — contents of every `.mat` artifact and the filename codes.
- `../vislab-common/ARCHITECTURE.md` — how this repo, vislab, the toolboxes, and vislab-common/data fit together.

## License & citation

Code released under the MIT License (see `LICENSE`). If you use it, please cite the paper above.
