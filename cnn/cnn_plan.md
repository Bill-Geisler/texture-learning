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

### 1. Data ingestion — unified (done; retrain pending)

The CNN and Bayesian model share one ingestion, so parameters can't diverge:
- **One parameter source:** `config.m` (optics, patch size, image list, normalization, and the
  `cfg.textures` per-database gray/gamma/resize flags). The CNN reads `config()` — nothing hardcoded.
- **One per-image function:** `vislab.nat_stat_bayes.source_to_lms` (read → gray/gamma/pertex-resize →
  OTF → RGB→LMS → downsample). Called by s1/s2/s3, `load_texture_images`, and the CNN builders.
- **One per-patch step:** `vislab.nat_stat_bayes.patch_to_a` (normalize `ptch_norm` type 3 → LMS→ABR
  rotate → keep A). Near/far pairs are stored as the **A channel only** (`patch_pairs_ecc<ecc>.mat`).
- Only the **sampling strategy** stays model-specific (Bayesian pre-generates pairs; CNN samples on
  the fly). The CNN's A is functionally unchanged — its input layer divides each patch by its own
  mean, cancelling the per-patch scale.

**Still to do:**
- **Retrain s1–s5 at ppd 60.** ppd was unified 64→60 (human display resolution), which changes the
  natural-image OTF — so the shipped color transform / priors / bins / bounds (still the ppd-64
  versions) must be regenerated, then regenerate the near/far pairs (`s3`) and the CNN texture set
  (`texture_same_diff_patches_cnn`). The model is inconsistent until this rerun.
- **Dead B/R code** — s2 builds unused dim-2/3 color priors; s4 maps dims 2/3. Harmless; prune when convenient.
- **ecc > 1 patch size** — the Bayesian cuts `64/ecc` patches while the CNN input is fixed at 64 px;
  reconcile before comparing peripherally. Also needs same-ecc bins (s4/s5 default `eccb = 1`).

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
