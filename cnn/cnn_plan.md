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

### 6. Architecture variants — pooling & loss (to consider)

Judged against the network's goals: transfer to texture same/different, stay **lean** (avoid overfitting
natural images), and keep an **interpretable, statistics-based** embedding comparable to the Bayesian model.

| Idea | What changes | May benefit the goals | May not / cost | Verdict |
|---|---|---|---|---|
| **Average pooling** | mean instead of max in the intermediate pools | Matches `poolStats`' mean/std philosophy — "pool statistics" end to end; **adds no parameters** (stays lean) | Can wash out sparse-but-strong features that max's "present-anywhere" behavior keeps; task-dependent | Cheap and on-theme — try first; but a small change, so the effect may sit within run-to-run noise |
| **Strided convolution** | conv steps by 2 and does the downsampling (learned) instead of a max-pool | Learnable downsampling can preserve more texture structure than a fixed max | **Adds parameters** → pushes back toward overfitting natural images (the original problem) | Small likely gain, wrong direction on capacity — deprioritize |
| **Metric-learning loss** (contrastive / triplet) | shape the embedding space directly (same → close, different → far) instead of `abs`-diff → fc → cross-entropy | Makes the **embedding the object of study** — a distance space to visualize and compare geometrically to the Bayesian features; drops the somewhat arbitrary fc comparison head | Near/far is a noisy *proxy* for same/different, so margin losses are finicky; reintroduces margin + decision-threshold knobs; not guaranteed to transfer better | Biggest lever — most likely to *clearly* exceed noise (in either direction); the real experiment |

**Sequencing for a clearly-visible, seed-independent effect:** the pooling tweaks are small enough that
run-to-run variation may swamp them; the loss change is the one big enough to move the needle
unambiguously. Try average pooling first (free, on-theme), then metric learning as the main experiment.

### 7. Features across scales — V1-like multi-scale front end (to consider)

Currently the net is single-scale per layer (conv1 = one 5×5 filter); larger scales appear only
*sequentially* as depth + pooling grow the receptive field (~5 px → ~40 px). V1 instead has **parallel**
spatial-frequency channels at one stage. Options to add that, cheapest → most principled:

| Idea | What changes | May benefit the goals | May not / cost | Verdict |
|---|---|---|---|---|
| **Dilated (atrous) convolution** | same small kernel spaced out to cover a larger extent; several dilations in parallel | Parallel SF channels with **few/no extra parameters** (stays lean) | One kernel *shape*; wide dilations can skip detail between sampled points ("gridding") | Cheapest way to add scales, respects the lean goal — good first experiment |
| **Multi-size filter bank at layer 1** (Inception-style) | several conv layers of different kernel sizes (e.g. 3×3, 7×7, 15×15) on the input, channels concatenated | Directly mimics V1's multiple SF channels; fully learnable | **Adds parameters** → pushes back toward overfitting | Faithful and flexible, but heavier on capacity |
| **Gaussian/Laplacian pyramid front end** | downsample the patch into a few resolutions, convolve each, then `poolStats` per scale | Closest to the steerable-pyramid / Portilla–Simoncelli texture model and the Bayesian power-spectrum-across-scales features; most interpretable and on-theme | More plumbing; separate convs per level add parameters | Most principled — best V1- and Bayesian-alignment |

Notes:
- **`poolStats` extends naturally:** pool mean/std within each (scale, orientation) channel → per-scale
  statistics, i.e. essentially the steerable-pyramid texture descriptor.
- **The OTF sets the fine-scale limit** ([config.m](../config.m) optics): the eye's optics already remove
  spatial frequencies above the optical cutoff, so there is no point adding filters finer than the OTF passes.
- **Fixed vs learned:** a fixed Gabor/steerable bank is maximally V1-faithful and interpretable but risks the
  same objection as the ruled-out fixed Bayesian front end ("CNN would learn nothing new"); a *learnable*
  multi-scale first layer (dilated or multi-size) keeps the network learning while adding scale diversity.

## Lessons learned

- **Order-invariant pooling is necessary but not sufficient** — it removes spatial-layout
  shortcuts but not other non-texture cues (e.g. shared low-frequency shading between adjacent
  patches) that survive pooling because they're in *what's* detected, not *where*.
- **Contrast is not the shortcut.** The achromatic histogram keeps contrast; only
  center-surround/edge features are contrast-normalized. `img/mean(img(:))` already matches this.

## Architecture reference

Conv stack `conv → relu → pool` ×4, channels **8‑16‑16‑32** (conv1 = 8 kernels of 5×5).
Embedding: mean+std pooling of the final map → **64-d, L2-normalized** (`poolStats`), merged by a
1×64 weight. ~9,600 conv params.

## Ruled out

- Fixed Bayesian front-end as feature source — CNN would learn nothing new.
- Shrinking receptive fields below patch size — already local enough.
- Early stopping on the Brodatz peak — hides the shortcut. (Still keep a Brodatz test split
  untouched by any decision, for the final number.)
- Trimming capacity to prevent memorization — moot; on-the-fly data already prevents it.
