# Data dictionary — texture-learning

Contents of every `.mat` artifact and the filename codes. Shipped artifacts live in `data/models/`;
generated data in `data/derived/` (git-ignored). Large inputs (natural images, texture sheets) live in
the external `vislab_data/` store (see `config.m`).

## Filename codes

- **`AHEO<btype><dim><ecc>.mat`** — adaptive-histogram bin bounds for one feature. `AHE`=adaptive
  histogram equalization, trailing **O**=OTF applied (no `O` = no optics). Then three numbers:
  `btype` (bound type; 5 = natural images, 4 = Brodatz/Fabric), `dim` (feature 1–14), `ecc` (1/2/4/8).
  Example: `AHEO5131` = adaptive/OTF, natural-image btype 5, feature 13 (small linear center-surround), eccentricity 1.
- **`dbnd<type>NO<ecc>.mat`** — trained decision-variable bound. `<type>` ∈ {`h` spot, `e` edge,
  `c` content, `b` border, `bc` border+content}; **`NO`** = **N**atural-image-trained + **O**TF
  (vs `BF`/`BFO` = Brodatz/Fabric); `ecc` = 1/2/4/8. Example: `dbndbcNO4`.
- **`patch_pairs_<ecc>.mat`** — near/far training pairs at eccentricity `ecc` (produced by stage 3).
- **`cdfs_abr_mo13_mo23_cs33[_otf].mat`** — see below (`mo13`=1st-deriv
  magnitude/orientation, `mo23`=2nd-deriv magnitude/orientation, `cs33`=3×3 center-surround).
  (The LMS→ABR rotation is **not** shipped here — it is the lab-shared `cps_lms2abr_otf.mat` in
  `vislab_data/`; see below.)

## `cps_lms2abr_otf.mat`  (stage 1 output — **shared**, lives in `vislab_data/`)
The lab-global LMS→ABR colour transform, produced by stage 1 and consumed by all lab projects
(texture-learning, texture-segmentation, …). Was `PCA_matrix_3_OTF.mat` under `data/models`.
| var | type | meaning |
|---|---|---|
| `coeff` | 3×3 | LMS→ABR rotation (PCA components); apply as `abr = lms * coeff` |

## `cdfs_abr_mo13_mo23_cs33_otf.mat`  (stage 2 output)
Marginal cumulative distribution functions (the task-independent priors, paper Fig. 5). Each feature
has an edge vector `e*` and cumulative-probability vector `N*` (from `histcounts(...,'Normalization','cdf')`).
| vars | feature |
|---|---|
| `ea,Na` / `eb,Nb` / `er,Nr` | ABR colour channels a / b / r |
| `em,Nm` / `eo,No` / `emo,Nmo` | 1st-derivative (edge) magnitude / orientation / mag×ori |
| `em2,Nm2` / `eo2,No2` / `emo2,Nmo2` | 2nd-derivative (bar) magnitude / orientation / mag×ori |
| `ecs1,Ncs1` / `ecs2,Ncs2` / `ecs4,Ncs4` | center-surround: ratio / small linear / large linear |
| `coeff` | 3×3 LMS→ABR rotation (copied from stage 1) |

## `AHEO<btype><dim><ecc>.mat`  (stage 4 output)
| var | type | meaning |
|---|---|---|
| `bnds` | 1×nbnds | histogram bin edges for the feature (first/last are ±inf) |
| `nbnds` | scalar | number of bin edges |

## `dbnd{h,e,c,b,bc}NO<ecc>.mat`  (stage 5 output)
| var | type | meaning |
|---|---|---|
| `dbndh` / `dbnde` / `dbndc` / `dbndb` / `dbndbc` | struct | quadratic decision boundary from `classify_normals` (`.samp_opt_bd`); turned into a DV function via `quad2fun`. h=spot, e=edge, c=content, b=border, bc=border+content |

## `patch_pairs_<ecc>.mat`  (stage 3 output, in data/derived/)
| var | type | meaning |
|---|---|---|
| `ptchn` | psz×2·psz×3×N | **near** patch pairs (reference + adjacent), stored side-by-side (raw LMS) |
| `ptchf` | psz×2·psz×3×N | **far** patch pairs (reference + distant), aligned by index with `ptchn` |
| `pcnt` | scalar | number of pairs N (`= n_images × 10 refs × 2`) |

*(Note: the original saved three per-set files `patch_pairs_{9,10,12}<ecc>.mat`; the reorganized stage 3
writes one combined file, which also fixed a per-set index bug.)*

## `results{P,F,B,BF,V,M}.mat`  (stage 7 output — pending)
Segmentation results per texture type (P=Pertex, F=Fabric, B=Brodatz, BF=Brodatz+Fabric, V=VisTex,
M=McGill): region counts and accuracy surfaces over the grouping-criterion sweeps. Schema to be
finalized when stage 7 is implemented (blocked on the texture-dataset layout — see `../../USER_TODO.md`).

## External inputs (in `vislab_data/`, not in this repo)
- `CPS natural images/Set{9,10,12}_16_*.png` — 16-bit calibrated natural images (stages 1–3).
- `textures/{brodatz,fabric,pertex,…}/` — texture sheets for GTR images (stages 6–7).
- `cps_rgb2lms.mat` (var `lms`, 3×3) — shared camera-RGB→LMS calibration; auto-loaded by `vislab.lib.rgb2lms`.
- `cps_lms2abr_otf.mat` (var `coeff`, 3×3) — shared LMS→ABR rotation (stage-1 output); auto-loaded by
  `vislab.nat_stat_bayes.apply_color_rotation`.
