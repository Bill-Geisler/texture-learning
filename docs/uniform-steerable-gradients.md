# TODO: unify the steerable-gradient filters across repos

**Status:** open / future work. Nothing here is required for the current pipeline
to run; this documents a clean-up we eventually want.

## Goal

Use a single, shared definition of the first- and second-derivative-of-Gaussian
steerable filters everywhere we compute image gradients — the Bayesian
texture-learning pipeline, the segmentation repo, and the camouflage-detection
repo — so that "the gradient of an image at scale sigma" means exactly the same
thing in every project, with one implementation to test and maintain.

## Where things stand today

There are (at least) **three separate implementations** of the same idea, and
they do not agree:

| Location | Function | Truncation convention | Normalization |
|---|---|---|---|
| `vislab-common/+vislab/+lib/steerable_kernels.m` | `steerable_kernels(sd, nsd)` | full **width** `sz = nsd*sd` → half-width `nsd*sd/2`; **square** support. With `nsd=3` this cuts at `1.5*sigma` (~32% of peak → "blocky"). | unit energy |
| `texture-segmentation/+lib/steerable_filter.m` | `steerable_filter([sd nsd])` | **radius** `= nsd*sd`; **circular** support. With `nsd=3` this cuts at `3*sigma` (~1% of peak → smooth). | none (L2 line commented out) |
| `camouflage_detection/+lib/steerable_filter.m` | `steerable_filter(...)` | camo variant (circular, radius `nsd*sd`, local-SD normalization) — this is what generated the efficient-coding deck. | local-SD |

Key mismatch: **the meaning of `nsd` differs.** In `steerable_kernels` it is the
kernel's full width in SDs (so `nsd=3` truncates at `1.5*sigma`); in both
`steerable_filter` variants it is the truncation *radius* in SDs (so `nsd=3`
truncates at `3*sigma`). The same `nsd=3` therefore produces very different
filters: a hard, blocky kernel in the model vs. a smooth, wide kernel in the
other two. This is exactly why the Stage 1b demo looked blocky until we widened
`nsd` locally — see `demo/plot_stage1b_gradients.m`.

Second-derivative kernels add a further wrinkle:
`vislab-common/+vislab/+lib/gauss_deriv2_kernels.m` **zero-means each kernel over
the window** (so the window size changes what DC offset is subtracted) and scales
the 45-degree kernel by a hand-tuned `scale45 = 0.22` "for accurate small-kernel
steerability." Widening the window would perturb both.

## What currently uses the model's kernel (blast radius of any change)

Within the Bayesian pipeline, `vislab.lib.steerable_kernels` /
`gauss_deriv2_kernels` are reached from:

- `vislab.lib.steerable_grad_response` and `vislab.lib.grad2_response`
  (the crop is `floor(sd*nsd/2 + 1)`, so it grows with `nsd`);
- `vislab.nat_stat_bayes.dv_edge_hist` (edge + bar histogram LLRs);
- `vislab.nat_stat_bayes.dv_border` (border DV, calls `steerable_kernels` directly);
- `pipeline/sample_prior_features.m` (the per-image sampler for the Stage 2+3
  priors) — reads `cfg.dv.sd1/nsd1/sd2/nsd2`, so its kernel stays consistent with
  the rest of the pipeline when the config changes.

`camouflage_detection` and `texture-segmentation` each use their **own**
`steerable_filter` and are **not** affected by changes to `steerable_kernels`.

## What would break if we changed the model's kernel

Mostly **silent numerical drift**, not crashes:

1. **Trained artifacts go stale.** The shipped `priors_*.mat` (s2),
   `AHEO_bins.mat` (s4), and `decision_bounds_ecc_*.mat` (s5) were all fit on
   `nsd=3` responses. Changing the kernel shifts response magnitudes/shapes, so
   the frozen histogram bins and decision bounds become miscalibrated → s6/s7
   accuracy quietly degrades with no error.
2. **Count features drift.** The binomial count LLR in `dv_edge_hist` uses the
   valid-pixel count `npix1` as `nmax`; a larger crop changes it.
3. **2nd-derivative steerability.** The zero-mean-over-window step and the tuned
   `scale45 = 0.22` in `gauss_deriv2_kernels` are calibrated for the current
   small kernel; widening it may reduce steering accuracy.
4. **Config/s2 hardcode mismatch.** Until s2 reads `cfg`, a config change alone
   silently fails to propagate to the priors.
5. **Patch fit.** Larger kernels lose more border. Only matters at large sigma
   (the multi-scale demo, already guarded by the `vpx < 1` check); the model's
   `sd=1` is unaffected.

## Best course of action (proposed)

1. **Agree on one convention** for `(sd, nsd)` — recommend: `nsd` = truncation
   **radius** in SDs, **circular** support, unit-energy normalization. Decide
   whether "smooth" (`radius = 3*sigma`) or "tight" is the intended model filter;
   this is a modeling choice, not just cosmetic.
2. **Single shared implementation** in `vislab-common` (`steerable_kernels` /
   `gauss_deriv2_kernels`), and have `texture-segmentation` and
   `camouflage_detection` call it (or a thin wrapper) instead of their local
   copies. Keep the function *signature* stable so callers don't churn.
3. **Make `nsd` a single source of truth**: fix `sample_prior_features.m` to
   read `cfg.dv.nsd1/nsd2` rather than hardcoding.
4. **Re-tune / re-verify the 2nd-derivative** `scale45` (and the zero-mean step)
   for whatever window is chosen, or hold `nsd2` fixed.
5. **Regenerate the full chain consistently** if the model kernel changes:
   s2 (priors) → s4 (bins) → s5 (bounds) → re-evaluate s6/s7. **Version the
   artifact filenames by kernel params** (e.g. `..._nsd6.mat`) so new-kernel
   test paths never silently load old-kernel artifacts.
6. **Regression check:** confirm s6/s7 same-different accuracy is unchanged (or
   improved) before adopting the unified kernel as the default.

## Related

- `demo/plot_stage1b_gradients.m` — the illustrative multi-scale figure; it
  currently sets `nsd = 6` locally, only to render smooth filters. This has **no**
  effect on the pipeline and is not the fix described above.
