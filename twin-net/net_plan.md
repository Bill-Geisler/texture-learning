# Twin network — plan and to-do

## Goal

Train the twin network to learn **texture statistics** from near/far natural-image labels,
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
- **ecc > 1 patch size** — the Bayesian cuts `64/ecc` patches while the network input is fixed at 64 px;
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
- Weight decay on both `adamupdate` calls in `train_net.m`.

### 5. Contrast-normalization ablation (empirical only)

Not expected to be the shipped fix — the Bayesian achromatic histogram is *not*
contrast-normalized, and the network's `img/mean(img(:))` input already matches that.

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

| Idea | Switch (`arch`) | Learned params | What changes | May benefit the goals | May not / cost | Verdict |
|---|---|---|---|---|---|---|
| **Dilated (atrous) convolution** | `dilated` | **9,681** (= baseline; dilation is parameter-free) | same small kernel spaced out to cover a larger extent; several dilations in parallel | Parallel SF channels with **few/no extra parameters** (stays lean) | One kernel *shape*; wide dilations can skip detail between sampled points ("gridding") | Cheapest way to add scales, respects the lean goal — good first experiment |
| **Multi-size filter bank at layer 1** (Inception-style) | `multiscale` | **14,561** (3×3 bank ×3 + tail) | several conv layers of different kernel sizes (e.g. 3×3, 7×7, 15×15) on the input, channels concatenated | Directly mimics V1's multiple SF channels; fully learnable | **Adds parameters** → pushes back toward overfitting | Faithful and flexible, but heavier on capacity |
| **Gaussian/Laplacian pyramid front end** | `pyramid` | **7,633** (lean config; *below* baseline) | downsample the patch into a few resolutions, convolve each, then combine and pool | Closest to the steerable-pyramid / Portilla–Simoncelli texture model and the Bayesian power-spectrum-across-scales features; most interpretable and on-theme | More plumbing; averaging levels to a common size discards some fine detail | Most principled — best V1- and Bayesian-alignment, and can be the leanest |
| **Pyramid, widened** | `pyramid_wide` | **11,137** (~1.15× baseline) | same 3-scale pyramid as `pyramid` (bc=8), tail widened to `nChan=48` (embedding 96) | Small capacity bump to lift accuracy while keeping the pyramid's texture edge | ~1.15× params; still risks locking onto natural-specific structure (on-the-fly sampling blocks *memorization*, not this) | Gentle probe — a 29k version (bc=16, nChan=64) erased the Brodatz-over-nat edge, so kept small |

Notes:
- **Parameter counts** are total learned weights + biases (conv stack + the fc head, `2C+1`: e.g. 65 for
  `C = 32`, 97 for `C = 48`). **Baseline = 9,681** for reference. Dilation is parameter-free
  (`dilated` = baseline); the bank is ~50% more; the lean `pyramid` is *below* baseline at 7,633;
  `pyramid_wide` is a small step up at 11,137 (~1.15× baseline).
- **Lean pyramid config** (the `pyramid` switch, 7,633 params): 3 scales via average-pooling (1 / 2 / 4),
  a per-scale 5×5×8 conv, each resized to a common 12×12 and depth-concatenated (24 channels), then a
  single 3×3×32 tail conv → 10×10×32. `pyramid_wide` is the same graph with the same 8 ch/scale and a
  48-channel tail (`nChan=48`). Average-pool is a box approximation to a Gaussian pyramid; a Laplacian
  variant would use scale differences.
- **`poolStats` extends naturally:** pool mean/std within each (scale, orientation) channel → per-scale
  statistics, i.e. essentially the steerable-pyramid texture descriptor.
- **The OTF sets the fine-scale limit** ([config.m](../config.m) optics): the eye's optics already remove
  spatial frequencies above the optical cutoff, so there is no point adding filters finer than the OTF passes.
- **Fixed vs learned:** a fixed Gabor/steerable bank is maximally V1-faithful and interpretable but risks the
  same objection as the ruled-out fixed Bayesian front end ("the network would learn nothing new"); a *learnable*
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

- Fixed Bayesian front-end as feature source — the network would learn nothing new.
- Shrinking receptive fields below patch size — already local enough.
- Early stopping on the Brodatz peak — hides the shortcut. (Still keep a Brodatz test split
  untouched by any decision, for the final number.)
