# Twin CNN — plan and to-do

## Goal

Train the twin CNN to learn **texture statistics** from near/far natural-image labels,
so the rule transfers to Brodatz same/different discrimination. Target: mid-80s–90s.
This is the learned counterpart to the Bayesian model in this repo's `pipeline/`.

## Bayesian anchors

Near/far ≈ 73–80%. Texture same/different ≈ 92.7%. These share one decision bound, but
only for order-invariant features (position-agnostic histograms / power spectrum) — that's
why the clean task scores higher despite training on the noisier one.

## Reading the plots

- `test (nat)` plateauing ~0.78–0.80 is expected (near/far labels are noisy) — don't chase it.
- **Success = `test (Brodatz)` rises above `test (nat)`**, toward ~85–90%. Below or declining
  = the network is using non-texture, near/far-specific cues.
- Training accuracy → 100% = memorizing label noise.

## Design principles

1. **No early stopping.** Want a network that transfers well fully trained, not one
   cherry-picked at its Brodatz peak.
2. **No hand-defined Bayesian features.** The Bayesian model is already near-optimal on its
   own features, so feeding those in would teach the CNN nothing new. Constrain the *class*
   of features generically; let the CNN find its own.

## Current state

- **Data:** on-the-fly, non-repeating sampling — `load_nat_A_pool` (builds the image pool once,
  via the shared `source_to_lms`), `getTwinBatch_nat_live` (cuts fresh pairs each batch).
  `train_cnn.m` reads all shared params from `config()` and splits by **image**, not pair.
- **Test:** balanced same/different set across all texture databases + a Brodatz-only set
  (`texture_same_diff_patches_cnn`, also via `source_to_lms` + `cfg.textures`).
- **Monitoring:** `test (nat)` batch resampled fresh each check; training accuracy measured
  *before* the weight update (fresh-data, comparable to validation).
- **Architecture: C** (tiny pooling, ~9,600 params) active.

## To-do

Ordered roughly by expected impact on the Brodatz transfer gap.

### 1. Unify the data ingestion (Bayesian ↔ CNN)  — *A-storage done at ecc 1; ppd + ecc>1 pending*

Both models share one recipe, split into two steps:

**Per image** (the expensive part, run once per source image):

> read → (per-dataset: gray-replicate / gamma-linearize / pertex resize) → OTF →
> RGB→LMS (camera calibration) → `downsample(·, ecc)`  → **LMS image**

`gray`/`gamma` are per-dataset pre-steps to get each source file into common linear RGB
(grayscale sheets → replicate to 3 channels for the camera transform; gamma-compressed sheets →
linearize). Natural images skip both.

**Per patch** (cheap, run per cut patch) — `vislab.nat_stat_bayes.patch_to_a`:

> cut LMS patch → `ptch_norm`(mean 128, type 3, 3-channel) → LMS→ABR rotate → **keep A**

This is the order the Bayesian already used (normalize on the 3-channel LMS patch, *then* rotate),
so its numbers are preserved. It has to be per-patch because `ptch_norm` type 3 scales by a factor
computed from that patch's own 3 channel means — a factor you can't recover once you've dropped to A.

**Decisions:**
- **Keep only A** (done). The model's decision variables all read the A channel only (verified:
  `spot_dims = [1 13 14]`, `edge_dims = [5 7 9 10]`; the B/R pixel features 2/3 are computed but
  never fed to any DV). Storing 1 channel loses nothing the model uses.
- **Normalize then rotate then save A** (done). Safe for both:
  - *Bayesian:* baked into `s3` storage (each patch-half normalized + rotated, A stored). s4/s5 and
    `run_demo` now read A via `patch_to_a` (passthrough on A files, exact convert on old 3-channel
    files). Numerically identical, so the shipped priors / bins / bounds stay valid — no retraining.
  - *CNN:* its A is functionally unchanged — rotation is per-pixel (commutes with cutting) and the
    input layer divides each patch by its own mean (`img/mean(img(:))`), which cancels the per-patch
    scale factor, so the per-image A pool already gives the equivalent A. (No LMS pool / per-patch
    ptch_norm needed — that would only cost RAM for zero change.) The CNN now gets that A from the
    **shared** `source_to_lms` with params from `config()`, so it can't diverge from the Bayesian side.
  - This also resolves the old **scaling** question: the initial `255/max` (CNN) vs `255/maxval`
    (Bayesian) whole-image scalar is overridden by the per-patch `ptch_norm`, so it no longer matters.
- **ppd = 60 across all cases** — *code changed; retrain pending.* Collapsed `cfg.optics.ppd_natural`
  (64) into the single `cfg.optics.ppd = 60`, used by s1/s2/s3 (textures already ran at 60). This alters
  the natural-image OTF, so unlike the A-storage refactor it is **not** behavior-preserving: the shipped
  color transform (s1), priors (s2), bins (s4), and bounds (s5) were made at 64 and must be **regenerated
  by rerunning s1–s5** before the model is self-consistent again.

Hard limit: ingestion can only be identical *up to the fork* — Bayesian → hand features, CNN → learned.

**Done (this pass), all at ecc = 1:**
- `vislab-common/.../patch_to_a.m` — shared per-patch normalize→rotate→keep-A (A-aware).
- `vislab-common/.../source_to_lms.m` — **the single shared per-image ingestion** (read → gray/gamma/
  pertex-resize → OTF → RGB→LMS → downsample, plus optional A). Both models call it.
- `dv_spot_hist.m` — accepts 1-channel A input (`min(3, nch)` pixel loop); still handles 3-channel.
- `s3` stores A (1-channel, dropped `transpose_channels`); `s4`/`s5`/`run_demo` read A via `patch_to_a`.
- `s1`/`s2`/`s3` and `load_texture_images` now ingest via `source_to_lms`; texture flags moved to a
  single `cfg.textures` table (used by both `load_texture_images` and the CNN generator).
- **CNN reads `config()` for every shared param** (optics, patch size, image list, normalization); no
  hardcoded ppd / image dir / set counts. `load_nat_A_pool(cfg, down_level)` uses `list_natural_images`
  + `source_to_lms`; `texture_same_diff_patches_cnn` uses `cfg.textures` + `source_to_lms`. Deleted the
  CNN's `nat_image_to_A` / `texture_image_to_A` (subsumed by `source_to_lms`).
- Result: one parameter source (`config.m`) and one ingestion function feed both models — parameters
  and per-image processing can no longer diverge. Only the *sampling strategy* stays model-specific
  (Bayesian pre-generates near/far pairs offline; CNN samples on the fly). A-storage is
  behavior-preserving; old 3-channel `patch_pairs_*.mat` still load (auto-converted).

**Still to do:**
- **Retrain s1–s5 at ppd 60**, then regenerate `patch_pairs_ecc1.mat` via `s3` (now A-only) and the CNN
  texture test set via `texture_same_diff_patches_cnn`. The code is at ppd 60 but the shipped
  `data/models` artifacts are still the 64 versions, so the model is inconsistent until this rerun.
- **Dead B/R code** — s2 still builds unused dim-2/3 color priors (Nb/Nr); s4 still maps dims 2/3.
  Harmless (never used); prune or guard when convenient.

**At other eccentricities (ecc > 1):**
- The A-storage + shared ingestion already work at any ecc (regenerate the pairs via `s3`). Both models
  now shrink the image the same way (`source_to_lms` → `downsample(·, ecc)`).
- **Patch size still differs and must be reconciled:** the Bayesian uses `psz = cfg.patch.size/ecc`
  (a smaller patch), while the CNN's input layer is fixed at 64 px, so it cuts 64-px patches from the
  shrunk image (a larger visual angle). Decide the convention before comparing peripherally.
- **Bins/bounds are ecc-1 only** (`eccb = 1` default in s4/s5). Running at ecc > 1 needs
  same-eccentricity bins (regenerate s4/s5 for that ecc).

### 2. Remove the near/far shortcut from the labels

On-the-fly data ruled out memorization, yet Brodatz still peaks then declines — so the shortcut
is intrinsic to the near/far objective. Match near/far pairs on a suspected low-level statistic
at sampling time (`getTwinBatch_nat_live`) so that cue can't separate the labels.

### 3. Architecture experiments

- Does arch C stop the Brodatz decline? (in progress)
- A vs B at full training: A's FC embedding can read spatial layout; if its Brodatz gap is
  worse, that confirms layout was part of the shortcut.

### 4. Feature visualization during training

Refresh on the existing every-50-iterations schedule. Cheapest first:
1. **First-layer filter montage (recommended).** conv1 kernels are tiny images; show as a grid
   beside the accuracy plot. Near-zero cost. Only shows input-level features.
2. **Activation maps.** Push one fixed patch through and show each layer's channel responses.
   More compute; reveals the deeper stack.
3. **Embedding geometry.** Project the pooled embeddings of a fixed same/diff set to 2D and
   animate how they separate. Shows decision geometry, not features.

### 5. Regularization / augmentation (tidy the curve, unlikely to close the gap alone)

- Data augmentation (flips/rotations) in `getTwinBatch_nat_live`.
- Weight decay on both `adamupdate` calls in `train_cnn.m`.
- Dropout (~0.2–0.3) on the conv feature map.

### 6. Contrast-normalization ablation (empirical only)

Not expected to be the shipped fix — the Bayesian achromatic histogram is *not*
contrast-normalized, and the CNN's `img/mean(img(:))` input already matches that.

## Results log

- **Run 1** — arch B (~600K, pooling) + fixed repeating data: Brodatz peaked ~0.77, fell to
  ~0.66. Didn't fix overfitting.
- **Run 2** — arch B + on-the-fly data: memorization eliminated (train/nat plateau together
  ~0.80), but Brodatz still peaks ~0.78 then declines to ~0.68. Since data never repeats, this
  proves a genuine non-texture shortcut, not memorization.
- **Run 3** — arch C + on-the-fly data: in progress.

## Lessons learned

- **Order-invariant pooling is necessary but not sufficient** — it removes spatial-layout
  shortcuts but not other non-texture cues (e.g. shared low-frequency shading between adjacent
  patches) that survive pooling because they're in *what's* detected, not *where*.
- **Contrast is not the shortcut.** The achromatic histogram keeps contrast; only
  center-surround/edge features are contrast-normalized. `img/mean(img(:))` already matches this.
- **Patches are already local** (64×64 ≈ 1°, matches Bayesian scale) — no need to shrink
  receptive fields further.

## Architecture reference

Conv stack (`conv → relu → pool` ×4) is shared; architectures differ in the embedding.

| arch | channels | embedding | merge | conv params |
|---|---|---|---|---|
| A — large/FC | 64‑128‑128‑256 | `fullyConnectedLayer(4096)` → `sigmoid` | 1×4096 | ~600K (+16.8M FC) |
| B — lean/pooling | 64‑128‑128‑256 | mean+std → 512-d, L2-norm (`poolStats`) | 1×512 | ~600K |
| C — tiny/pooling (**active**) | 8‑16‑16‑32 | mean+std → 64-d, L2-norm (`poolStats`) | 1×64 | ~9,600 |

B/C use `poolStats(forward/predict(net,X))` in `forwardTwin.m`/`predictTwin.m` instead of a
sigmoid on the raw map (sigmoid on all-positive ReLU output saturates). To switch architectures:
layer-stack ending + `fcWeights`/`fcBias` size in `train_cnn.m`, plus the embedding line in
`forwardTwin.m`/`predictTwin.m`.

## Ruled out

- Fixed Bayesian front-end as feature source — CNN would learn nothing new.
- Shrinking receptive fields below patch size — already local enough.
- Early stopping on the Brodatz peak — hides the shortcut. (Still keep a Brodatz test split
  untouched by any decision, for the final number.)
- Trimming capacity to prevent memorization — moot; on-the-fly data already does that.
  (Arch C is being tried for a different reason — see Current state.)

## Verification

- Primary: `test (Brodatz)` > `test (nat)`, toward ~85–90%.
- Sanity: training accuracy stays near the ~78–80% plateau.
- Final number reported on a Brodatz split untouched by any architecture/checkpoint choice.
