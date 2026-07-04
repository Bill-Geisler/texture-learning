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

- **[vision-commons](https://github.com/abhranildas/vision-commons)** — the lab's shared MATLAB library (git submodule, or a sibling
  folder during local dev). Provides `vislib.*` (optics, filters, normalization, …) and
  `nat_stat_bayes.*` (the decision-variable / natural-scene-statistics toolkit).
- **[IntClassNorm](https://github.com/abhranildas/IntClassNorm)** and
  **[gx2](https://github.com/abhranildas/gx2)** — installed MATLAB **add-on toolboxes** (Add-On Explorer /
  File Exchange). `setup.m` verifies they're installed; they are *not* bundled or fetched as source.
- **global_data** — the shared data store (natural images, texture sheets). Point `config.m` at it.
- MATLAB with the Image Processing and Statistics & Machine Learning toolboxes.

## Setup

```matlab
setup            % adds this repo + vision-commons to the path; checks the toolboxes
cfg = config;    % paths + parameters; edit cfg.paths.data_root if global_data isn't a sibling
```

## The pipeline

Run the stages in order (each is a function taking `cfg`). Stages 1–5 learn the model from natural
images and write artifacts to `data/models/`; stages 6–7 apply/evaluate it on GTR images.

| Stage | Function (`pipeline/`) | Produces |
|---|---|---|
| 1 | `s1_learn_color_transform(cfg)` | `PCA_matrix_3_OTF.mat` — LMS→ABR colour rotation |
| 2 | `s2_learn_feature_cdfs(cfg)` | `cdfs_abr_mo13_mo23_cs33_otf.mat` — task-independent feature CDFs |
| 3 | `s3_make_nearfar_pairs(cfg, lev)` | `patch_pairs_<lev>.mat` — near/far training pairs |
| 4 | `s4_optimize_bins(cfg, dim, lev)` | `AHEO<btype><dim><lev>.mat` — adaptive histogram bins |
| 5 | `s5_train_decision_vars(cfg, lev)` | `dbnd{h,e,c,b,bc}NO<lev>.mat` — trained decision-variable bounds |
| 6 | `s6_selfsup_discrimination(cfg, method, itype, lev, ntrl)` | per-image self-supervised discrimination accuracy surfaces (runs on Brodatz/Fabric — see Quick demo) |
| 7 | `s7_segment_gtr(cfg, method, itype, lev, n_images)` | GTR segmentation: correct-region counts over the merge x grouping-offset grid |

Example (regenerate the level-1 model):
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
patch similarities). Requires the Brodatz sheets in `global_data/textures/brodatz/`; other texture
datasets need additional data (see `../USER_TODO.md`).

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

Shared low-level code lives in `vision-commons` (not here), so it isn't duplicated across the lab's repos.

## Status & caveats

- Pipeline **stages 1–7 are all implemented**. Stages 6–7 run on Brodatz/Fabric now (verified
  end-to-end); loading Pertex/VisTex/McGill needs additional data — see `../USER_TODO.md` and
  `../QUESTIONS_FOR_GEISLER.md`.
- During the reorganization several bugs were fixed (e.g. an optics double-mean, a center-surround CDF
  mix-up); re-running therefore differs slightly from the original preprint artifacts, which should be
  regenerated. Details in `../REORGANIZATION_PLAN.md` and (once verified) `CHANGELOG.md`.

## Documentation

- `docs/GLOSSARY.md` — code names ↔ paper symbols ↔ meanings.
- `docs/DATA_DICTIONARY.md` — contents of every `.mat` artifact and the filename codes.
- `../vision-commons/ARCHITECTURE.md` — how this repo, vision-commons, the toolboxes, and global_data fit together.

## License & citation

Code released under the MIT License (see `LICENSE`). If you use it, please cite the paper above.
