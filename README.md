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
  only the large calibrated **natural-image** set (~19 GB) is **too large for GitHub** and must be obtained
  separately (`setup.m` warns if the store is missing; edit `cfg.paths.data_root` if it's elsewhere). The
  shipped model + the in-repo texture sheets cover the demo; the natural images are only needed to retrain
  (s1–s5) from scratch.
- MATLAB with the Image Processing and Statistics & Machine Learning toolboxes.

## Setup

```matlab
setup            % adds this repo + vislab to the path; checks the toolboxes
cfg = config;    % paths + parameters; edit cfg.paths.data_root if vislab-common/data isn't a sibling
```

## The pipeline

Run the stages in order (each is a function taking `cfg`). Stages 1–5 learn the model from natural
images and write artifacts to `data/models/`; stages 6–7 apply/evaluate it on GTR images.

| Stage | Function (`pipeline/`) | Produces |
|---|---|---|
| 1 | `s1_learn_color_transform(cfg)` | `vislab-common/data/cps_lms2abr_otf.mat` — LMS→ABR colour rotation (lab-shared) |
| 2 | `s2_learn_feature_cdfs(cfg)` | `cdfs_abr_mo13_mo23_cs33_otf.mat` — task-independent feature CDFs |
| 3 | `s3_make_nearfar_pairs(cfg, ecc)` | `patch_pairs_<ecc>.mat` — near/far training pairs |
| 4 | `s4_optimize_bins(cfg, dim, ecc)` | `AHEO<btype><dim><ecc>.mat` — adaptive histogram bins |
| 5 | `s5_train_decision_vars(cfg, ecc)` | `dbnd{h,e,c,b,bc}NO<ecc>.mat` — trained decision-variable bounds |
| 6 | `s6_selfsup_discrimination(cfg, method, itype, ecc, ntrl)` | per-image self-supervised discrimination accuracy surfaces (runs on Brodatz/Fabric — see Quick demo) |
| 7 | `s7_segment_gtr(cfg, method, itype, ecc, n_images)` | GTR segmentation: correct-region counts over the merge x grouping-offset grid |

Example (regenerate the eccentricity 1 (=fovea) model):
```matlab
setup; cfg = config;
s1_learn_color_transform(cfg);
s2_learn_feature_cdfs(cfg);
s3_make_nearfar_pairs(cfg, 1);
for dim = [1 5 6 7 9 10 11 13 14], s4_optimize_bins(cfg, dim, 1); end
s5_train_decision_vars(cfg, 1);
```

## Quick demo

To see the trained model produce results without re-running the (expensive) training, run the demo. It
uses the shipped model in `data/models` to run self-supervised discrimination (stage s6) on Brodatz GTR
images and plots the near-far accuracy surface (cf. the paper's Fig. 4):

```matlab
run('examples/demo.m')      % sets up the path, runs s6 on Brodatz, prints + plots the result
```

It reports the peak accuracy and shows the accuracy surface over the grouping-criterion x
mutual-similarity-weight grid. Expect a few minutes (it builds GTR images and computes all pairwise
patch similarities). The Brodatz sheets (and every other texture dataset) ship in the `vislab-common` repo
under `vislab-common/data/textures/`, so no extra download is needed for the demo.

## Repository layout

```
texture-learning/
├── setup.m, config.m         path bootstrap + central configuration
├── pipeline/                 numbered pipeline stages s1..s7 (+ list_natural_images helper)
├── +segmentation/            grouping algorithm (content-similarity, grouping, region scoring)
├── +gtr/                     GTR stimulus generation (texture-region masks, texture assignment)
├── data/models/              shipped trained artifacts (PCA, CDFs, AHEO bins, dbnd bounds)
├── data/derived/             generated data (patch pairs, results) — git-ignored
└── docs/                     papers, GLOSSARY.md, DATA_DICTIONARY.md
```

Shared low-level code lives in `vislab` (not here), so it isn't duplicated across the lab's repos.

## Status & caveats

- Pipeline **stages 1–7 are all implemented**. Stages 6–7 run end-to-end on all six texture
  datasets (Pertex, Fabric, Brodatz, Brodatz+Fabric, VisTex, McGill). Pertex source PNGs are
  1024×1024 and are resized to 640 on load, reproducing exactly the sheets used originally.
- During the reorganization several bugs were fixed (e.g. an optics double-mean, a center-surround CDF
  mix-up); re-running therefore differs slightly from the original preprint artifacts, which should be
  regenerated. Details in `../REORGANIZATION_PLAN.md` and (once verified) `CHANGELOG.md`.

## Documentation

- `docs/GLOSSARY.md` — code names ↔ paper symbols ↔ meanings.
- `docs/DATA_DICTIONARY.md` — contents of every `.mat` artifact and the filename codes.
- `../vislab-common/ARCHITECTURE.md` — how this repo, vislab, the toolboxes, and vislab-common/data fit together.

## License & citation

Code released under the MIT License (see `LICENSE`). If you use it, please cite the paper above.
