# Twin CNN — plan and to-do

## Goal

Train the twin CNN to learn **texture statistics** from near/far natural-image labels,
so the rule transfers to Brodatz same/different discrimination. Target: mid-80s–90s.
This is the learned counterpart to the Bayesian model in this repo's `pipeline/`.

## Bayesian anchors

Near/far ≈ 73–80%. Texture same/different ≈ 92.7%. These share one decision bound, but
only for order-invariant features (position-agnostic histograms / power spectrum) — that's
why the clean task scores higher despite training on the noisier one.

## To-do

Ordered roughly by expected impact on the Brodatz transfer gap.

### 1. Data ingestion — unified (done)

**Still to do:**

- **Dead B/R code** — s2 builds unused dim-2/3 color priors; s4 maps dims 2/3. Harmless; prune when convenient.
- **ecc > 1 patch size** — the Bayesian cuts `64/ecc` patches while the CNN input is fixed at 64 px;
  reconcile before comparing peripherally. Also needs same-ecc bins (s4/s5 default `eccb = 1`).

### 2. Second-order embedding — channel correlation + d′ comparison (done)

`poolStats` now returns raw per-patch stats (mean, std, and the strict upper triangle of the channel
*correlation* matrix — the Gram/co-occurrence texture statistic, dimensionless so it is comparable
across patches). `compareTwin` turns the two patches' stats into a dimensionless comparison vector:
per-channel d′ (`|Δmean|/pooled_sd`), std difference (`|Δstd|/pooled_sd`), and correlation difference
(`|Δcorr|`) → D = 2C + C(C-1)/2 = 560 for C = 32. Rationale for the scaling: a *constant* per-feature
scale is absorbed by the learned fc weights (and cushioned by Adam), so it need not be normalized;
what the weights *cannot* undo is a per-sample, data-dependent scale (raw covariance grows as
activation², the d′ denominator varies per patch), so d′ and correlation are used to make those
features per-sample stable by construction. Notes:
- Changes the architecture, so the net trains from scratch (old `net_on_nat.mat` won't load), and the
  merge weight in `train_cnn.m` is 1×560 (`nEmb = 2*nChan + nChan*(nChan-1)/2`).
- Correlation diagonal is identically 1 (would duplicate std), so only the strict upper triangle is kept.
- With a 4×4 = 16-position map the correlation is estimated from only 16 samples — a noisy per-patch
  estimate; the correlation block is the least reliable part and worth testing on its own.
- Expected effect is modest and likely within run-to-run noise until a fixed rng seed is added.

### 3. Feature visualization during training

Refresh on the existing every-50-iterations schedule.
1. **First-layer filter montage — done.** The 8 conv1 kernels are shown as a grid under the
   accuracy plot, refreshed each check. Only shows input-level features.
2. **Activation maps.** Push one fixed patch through and show each layer's channel responses.
   More compute; reveals the deeper stack. Worth adding if conv1 looks texture-like yet transfer fails.
3. **Embedding geometry.** Project the pooled embeddings of a fixed same/diff set to 2D and
   animate how they separate. Shows decision geometry, not features.

### 4. Regularization / augmentation (tidy the curve, unlikely to close the gap alone)

- Data augmentation (flips/rotations) in `getTwinBatch_nat_live`.
- Weight decay on both `adamupdate` calls in `train_cnn.m`.

### 5. Contrast-normalization ablation (empirical only)

Not expected to be the shipped fix — the Bayesian achromatic histogram is *not*
contrast-normalized, and the CNN's `img/mean(img(:))` input already matches that.

## Lessons learned

- **Order-invariant pooling is necessary but not sufficient** — it removes spatial-layout
  shortcuts but not other non-texture cues (e.g. shared low-frequency shading between adjacent
  patches) that survive pooling because they're in *what's* detected, not *where*.
- **Contrast is not the shortcut.** The achromatic histogram keeps contrast; only
  center-surround/edge features are contrast-normalized. `img/mean(img(:))` already matches this.

## Architecture reference

Conv stack `conv → relu → pool` ×4, channels **8‑16‑16‑32** (conv1 = 8 kernels of 5×5).
Embedding: `poolStats` spatially pools the final map to per-channel mean, std, and the strict upper
triangle of the channel *correlation*. `compareTwin` then turns the two patches' stats into a
dimensionless comparison — per-channel d′ (`|Δmean|/pooled_sd`), std difference (`|Δstd|/pooled_sd`),
and correlation difference (`|Δcorr|`) → **560-d**, merged by a 1×560 weight. ~9,600 conv params.

## Ruled out

- Fixed Bayesian front-end as feature source — CNN would learn nothing new.
- Shrinking receptive fields below patch size — already local enough.
- Early stopping on the Brodatz peak — hides the shortcut. (Still keep a Brodatz test split
  untouched by any decision, for the final number.)
- Trimming capacity to prevent memorization — moot; on-the-fly data already prevents it.
