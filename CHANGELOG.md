# Changelog

## Shipped artifacts vs. the corrected pipeline (verification, 2026-07-05)

The trained artifacts in `data/models/` were produced by the **original** code and match
the preprint. During the reorganization, several genuine bugs in the original were fixed
(listed below). Those fixes are **behaviour-changing**: rerunning the pipeline with the
corrected code produces artifacts that differ from the shipped ones. This file records the
fixes and the differences measured by a **full s1–s5 verification run** (eccentricity 1,
391 natural images, ~92 min).

The verification regenerated everything into a temporary folder and compared it to the
shipped originals; **the shipped `data/models/` were left untouched.**

### Behaviour-changing fixes (the reason the artifacts differ)

1. **Optics / OTF.** The original `aply_otf` added the image mean back **twice** (doubled
   the DC term) and did not zero spatial frequencies beyond the diffraction cutoff. The
   corrected `vislab.lib.otf_filter` subtracts and re-adds the mean once, zeros the
   out-of-cutoff band, and handles multi-channel images. Stages s1, s2, and s3 all pass
   images through the OTF, so this shifts **every** downstream artifact slightly.
2. **Center-surround CDF (feature 14, `Ncs4`).** The original `cdfs_of_features` built
   `Ncs4` from the wrong variable (`csl2` instead of `csl4`). Corrected in
   `s2_learn_feature_cdfs`. This directly changes the `Ncs4` CDF.
3. **Natural-image sampling resolution.** The original `nat_near_far_patches` used
   `ppd = 60` for the same images that s1/s2 treated at `ppd = 64`. Unified to **64** in
   `s3_make_nearfar_pairs`. (Flagged for Geisler.)

Also fixed but **not** affecting this pipeline's artifacts: the `Re` bar-count map used
feature 8, which the proximity pipeline (features 5, 7, 9, 10) does not use; the `Rb`
off-border `/` (mrdivide) was **preserved** pending Geisler's confirmation.

### Measured differences — regenerated vs. shipped (eccentricity 1)

`max|d|` = maximum absolute element-wise difference between the regenerated and shipped array.

**s1 — LMS→ABR color rotation** (`PCA_matrix_3_OTF.mat`)
- `coeff`: `max|d| = 0.0695` — attributable to the OTF fix.

**s2 — feature CDFs** (`cdfs_abr_mo13_mo23_cs33_otf.mat`)
- `coeff` 0.0695 · `Na` 0.967 · `Nm` 0.099 · `No` 0.0076 · `Nm2` 0.032 · `Ncs2` 0.563 · `Ncs4` 0.982
- `Ncs4` shows the largest change — expected, since it is the directly-fixed feature; the
  rest follow from the optics change.

**s4 — adaptive-histogram bins** (`AHEO_bins.mat`) — the **number of bins changed** for
several features (so everything trained on top of them changes structure):
- feat 1: 9→5 · feat 5: 10→9 · feat 6: 11→10 · feat 9: 9→8 · feat 11: 12→9 · feat 13: 9→7 · feat 14: 9→7
- feat 7: same bin count, bound values differ (`max|d| = 6.4e4`, in feature-value units) · feat 10: same count, `max|d| = 6.5`

**s5 — trained decision boundaries** (`dbnd{h,e,c,b,bc}NO1.mat`)
- Shapes/types differ from shipped — i.e. different dimensions, a direct consequence of the
  changed s4 bin counts, not an independent change. (Trained on 7576 near / 7756 far pairs;
  s5 sample accuracies ~0.72–0.81, sensible.)

### Decision still open (not made by this run)

- The regenerated artifacts are the output of the **corrected** pipeline; the shipped ones
  match the **preprint** (original code).
- **To decide (user / Geisler):** either *replace* the shipped `data/models/` with the
  corrected artifacts (repo then reflects the corrected code but no longer reproduces the
  preprint numbers), or *keep* the shipped artifacts (paper-matching) and treat the
  corrected pipeline as the going-forward version. This verification changed nothing either
  way — the shipped files are as they were.
- Only **eccentricity 1** (fovea) was regenerated here; a full replacement would also regenerate
  eccentricities 2/4/8.
