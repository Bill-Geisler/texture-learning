# Adaptive histogram optimization — what it does, and why (with a proposed reinterpretation)

*Companion note to the proximity paper (Geisler, bioRxiv 2026) and the `texture-learning` code.
Covers pipeline Stage 4 ([`pipeline/s4_optimize_bins.m`](../pipeline/s4_optimize_bins.m)) and the
histogram decision variable it feeds.*

---

## 1. TL;DR

- The histogram decision variable (DV) for spot/contour features is a **multinomial
  log-likelihood ratio (LLR)** between the two patches' per-bin feature histograms
  ([`multinomial_llr.m`](../../vislab-common/+vislab/+nat_stat_bayes/multinomial_llr.m)). Algebraically it
  is **exactly `N ×` the Jensen–Shannon divergence between the two patch histograms** — so your
  instinct that "it looks at the *difference* between the two patch histograms" is literally correct.
- The bins used to build those histograms could be chosen to **equalize the prior** (equal probability
  mass per bin — histogram equalization,
  [`make_bins.m`](../../vislab-common/+vislab/+nat_stat_bayes/make_bins.m)). You found this does not give
  the best near/far task performance.
- Stage 4's **adaptive** method keeps the *prior* only as a **candidate-generator and regularizer**:
  it greedily splits bins at prior-CDF midpoints and **keeps a split only if it measurably lowers the
  near-vs-far classification error**. The *objective* is task performance, not prior uniformity. The
  result is bins that are markedly **unequal** in prior mass — fine where the task needs resolution,
  coarse where it doesn't.
- **Your critique is fair.** The prior is doing two different jobs (candidate placement + mass
  balancing), and the reachable set of bin edges is restricted to *dyadic prior-quantiles*. A freer
  optimizer could reach configurations this greedy search cannot.
- **Your "difference histogram" idea is the right lens and is directly testable.** The LLR is a sum of
  **non-negative per-bin contributions**; the task-relevant information is where far pairs produce
  larger per-bin contributions than near pairs. Section 6 formalizes this and Section 7 gives five
  concrete experiments — including your uniform-fine-bin baseline — to test whether the adaptive bins
  are simply tracking that discriminative landscape.

---

## 2. The histogram decision variable

For one feature (say center-surround response), each patch is turned into a **histogram of counts**
over a fixed set of bins. Given per-bin counts `a` (patch 1) and `b` (patch 2), the DV is
([`multinomial_llr.m`](../../vislab-common/+vislab/+nat_stat_bayes/multinomial_llr.m)):

```
LLR = Σ_i a_i·ln(a_i/n_a)  +  Σ_i b_i·ln(b_i/n_b)  −  Σ_i (a_i+b_i)·ln((a_i+b_i)/N)
```

with `n_a = Σa`, `n_b = Σb`, `N = n_a + n_b`, empty bins skipped, and the result clamped at 0. This is
the paper's Eq. 1 / A4 (the G-test / likelihood-ratio statistic for a 2×k contingency table): the
log-likelihood that the two patches were drawn from **different** vs the **same** multinomial.

**Exact rewrite (worth keeping in mind).** Let `p_i = a_i/n_a`, `q_i = b_i/n_b` be the two normalized
histograms, weights `w_a = n_a/N`, `w_b = n_b/N`, and pooled `m_i = w_a p_i + w_b q_i`. Then

```
LLR = N · [ H(m) − w_a·H(p) − w_b·H(q) ]  =  N · JSD_{w_a,w_b}(p, q)
```

i.e. `N` times the (generalized) **Jensen–Shannon divergence** between the two patch histograms. Because
the patches are the same size, `n_a = n_b`, so `w_a = w_b = ½` and this is the ordinary ½–½ JSD. Two
consequences we will use:

1. **The DV is a distance between the two patch histograms** — small for same-texture (near) pairs,
   large for different-texture (far) pairs. This is the object your near/far bound is drawn around.
2. **The DV is a sum of per-bin terms** `t_i` (Section 6), and each `t_i ≥ 0` (by concavity of entropy).
   So "where does the LLR come from across bins?" is a well-posed, non-negative decomposition.

The bins are shared and fixed across all patches and all images (they must be — at segmentation time
there are no near/far labels to tune them). Choosing them well is what Stage 4 is about.

---

## 3. Two ways to choose the bins

### 3a. Prior-equalizing bins (histogram equalization) — the initial idea

[`make_bins.m`](../../vislab-common/+vislab/+nat_stat_bayes/make_bins.m) places edges at **equal steps of
cumulative prior probability** (`1/n_bins` apart). Every bin then holds the same fraction of the
natural-image feature mass. This is the efficient-coding / histogram-equalization choice, and the priors
it needs (`priors_*_otf.mat`) are already computed by the model front-end in Stage 2
([`s2_learn_feature_priors.m`](../pipeline/s2_learn_feature_priors.m)). It is the natural default — but,
as you found, equalizing the *prior* is not the same as optimizing the *task*.

### 3b. Adaptive bins (Stage 4) — what the code actually does

[`s4_optimize_bins.m`](../pipeline/s4_optimize_bins.m) is a **greedy top-down binary split** — a 1-D
decision tree grown against near/far error. Precisely:

1. **Start** with 2 bins split at the prior median (`make_bins(..., 2)`), endpoints pinned to the data
   range.
2. **Propose a split.** For a candidate bin, `find_bin_bound`
   ([`find_bin_bound.m`](../../vislab-common/+vislab/+nat_stat_bayes/find_bin_bound.m)) inserts a new edge
   at the **cumulative-probability midpoint of that bin** — i.e. the prior-median *within* the bin.
3. **Score it by the task.** `proximity_error` computes, for that single feature under the candidate
   bins, the multinomial-LLR response for every near pair and every far pair (from
   `patch_pairs_<ecc>.mat`, Stage 3), then calls `classify_normals` (IntClassNorm) to get the optimal
   near-vs-far classification error `samp_opt_err`.
4. **Keep or freeze.** If the split reduces error by more than a fixed fraction
   (`err_crit = 0.002`, i.e. 0.2 %), accept it; otherwise **freeze** that bin (never split again).
5. **Repeat** sweeping over bins until no unfrozen bin yields an accepted split (or `max_bins = 100`).

Run for features `[1 5 6 7 9 10 11 13 14]` at each eccentricity; the result is written to
`AHEO_bins.mat`.

Two structural facts fall out of this and explain *why the adapted bins look so different from the
prior-equalizing bins*:

- **Candidate edges live only at dyadic prior-quantiles.** Recursively splitting at within-bin
  cumulative-probability midpoints can only ever place an edge at a prior quantile of the form
  `k / 2^m`. The search never considers, say, the 37th percentile of a bin.
- **Accepted depth varies by region → bins are unequal in prior mass.** A region split three times holds
  ~`1/16` of the mass; an unsplit half holds `1/2`. Equalization would split *every* bin to the same
  depth. Adaptive splitting only refines where near/far error drops — so the final bins are fine in some
  feature ranges and coarse in others. **That inequality is the whole point** and is exactly what makes
  them differ from the equal-mass bins.

---

## 4. What the adaptive method is *really* doing

Three framings, all equivalent, that I find clarifying:

- **Model selection / bias–variance.** Each patch has only `psz²` pixels (4096 at the fovea, far fewer
  at higher eccentricity) to fill the histogram. Too few bins → the LLR throws away discriminative
  detail (bias). Too many bins → per-bin counts become tiny and noisy, and the LLR (a plug-in divergence
  estimate) becomes high-variance and upward-biased. Stage 4 is **local, greedy model selection**: add a
  bin only where the evidence (a 0.2 % error drop) says the information gained beats the estimation noise
  added. `err_crit` is the complexity penalty.
- **A 1-D CART tree.** Splits chosen greedily, candidate cut-points restricted to prior-quantile
  midpoints, "impurity" = near/far classification error of the resulting LLR.
- **Optimizing the separation of a divergence statistic.** Since the DV is `N·JSD(p,q)`, Stage 4 is
  choosing the histogram resolution so that this divergence **separates near pairs from far pairs** as
  well as possible (that is precisely what `classify_normals` on the near/far LLR distributions scores).

The last framing is the bridge to your idea: the thing being optimized *is* a difference-between-patch-
histograms statistic, and we are choosing bins to make its near/far separation maximal.

---

## 5. Your question: why use the prior to split at all?

You are right that there is something odd about using a basis built for one task (equalizing the prior)
to solve a different task (near/far discrimination). It helps to separate the **three distinct roles**
the prior is playing, because only one of them is really necessary:

1. **Coordinate warp / candidate placement (benign, useful).** Using the prior CDF as the axis means
   candidate edges land only where feature values actually occur, and each candidate split roughly
   **halves the pixel mass** of its bin. Balanced counts matter here: the variance of the plug-in JSD
   estimate is governed by per-bin counts, so equal-mass candidates keep every bin statistically usable.
   This is a sensible, cheap regularizer — *not* an objective.
2. **Regularization of resolution (benign).** Restricting to dyadic prior-quantiles limits how finely you
   can carve any region, which curbs overfitting on the ~7,820 training pairs.
3. **As an objective (this is the part you're objecting to — and you're right).** The algorithm never
   optimizes "equalize the prior"; the prior only *generates candidates*. But because candidates are
   dyadic prior-quantiles, the **reachable set of bin configurations is genuinely constrained**. The
   optimizer cannot place an edge at a task-optimal location that isn't a dyadic prior-quantile, and its
   greedy acceptance never revisits earlier splits. So it finds *an* answer, not necessarily the best one.

**Would a different search be better?** Plausibly yes, and it's worth testing (Section 7):

- **Continuous edge optimization.** Fix `k` and optimize the `k−1` edge *positions* directly against
  near/far error (coordinate descent / Nelder–Mead / a smoothed surrogate), initialized from the current
  adaptive or equal-mass bins. This removes the dyadic-quantile restriction.
- **Non-greedy resolution selection.** Choose the number of bins by cross-validated near/far error rather
  than a fixed 0.2 % threshold, to see whether the greedy stop is leaving performance on the table.
- **Information-equalizing bins (Section 6).** Place edges to equalize *cumulative discriminative
  information* rather than cumulative prior mass — a principled, label-aware alternative that still needs
  no continuous optimizer.

The important corrective, though: the prior is not being (mis)used as the objective. It is the search
parameterization and a variance-control device. The legitimate critique is narrower — that this
parameterization **constrains the reachable solutions**, and a freer search might do better. That is an
empirical question, and Section 7 says how to answer it.

*(One more reason the prior is convenient: it's the only distribution available at test/segmentation
time. But note the near/far labels — the discriminative signal — **are** available during training via
the proximity proxy. So there is no fundamental reason to lean on the prior for the objective; we lean on
it only for candidate generation and regularization.)*

---

## 6. Your reinterpretation: the per-bin "difference histogram"

Your proposal — that the adaptive bins are really equalizing or tracking the *difference histogram*
between near and far pairs, and that we should just look at the per-bin LLR terms — maps cleanly onto the
math and, I think, is the most illuminating way to think about the whole stage.

### 6a. The per-bin decomposition is exact and non-negative

The LLR is a sum over bins, `LLR = Σ_i t_i`, with

```
t_i = a_i·ln(a_i/n_a) + b_i·ln(b_i/n_b) − (a_i+b_i)·ln((a_i+b_i)/N)
    = N·[ −m_i·ln m_i + w_a·p_i·ln p_i + w_b·q_i·ln q_i ]   ≥ 0
```

Each `t_i ≥ 0` by concavity of entropy (`−x ln x`). So **"a histogram of the LLR term across bins" is
well-defined**: it partitions the total same/different evidence into non-negative per-bin contributions.
For a single pair, `t_i` is large in feature-value regions where the two patch histograms disagree.

### 6b. Task information ≠ raw contribution

For choosing bins, what matters is not `t_i` for one pair but how `t_i` **discriminates near from far**.
A bin is task-useful when far pairs pile up large `t_i` there while near pairs don't. Define, per bin,

```
Δ_i = E_far[t_i] − E_near[t_i]        (mean extra per-bin evidence that far pairs generate)
d'_i = (E_far[t_i] − E_near[t_i]) / sqrt(½(Var_far[t_i] + Var_near[t_i]))
```

`Δ_i` (or `d'_i`) as a function of the feature axis is the **discriminative-information landscape**. Your
hypothesis, restated precisely: **the adaptive method places fine bins where this landscape is high and
coarse bins where it is ≈ 0**, and prior-equalization fails precisely because prior mass and this
landscape are not proportional (a lot of prior mass can sit in feature ranges that carry no near/far
signal, and vice-versa).

### 6c. Why this predicts the observed mismatch

Equal-mass bins are optimal *only if* discriminative information is spread uniformly across prior
quantiles. It generally isn't: for many of these features the near/far signal concentrates in the tails
or in a narrow band (e.g. where "structured" vs "flat" patches separate). Where `Δ_i ≈ 0`, extra bins
only add estimation noise — so the adaptive method (correctly) refuses to split there, producing coarse
bins exactly where equalization would have kept splitting. That is a concrete, checkable reason the two
bin sets diverge.

---

## 7. How to test all of this

Everything below reuses artifacts that already exist (`priors_*_otf.mat`, `patch_pairs_<ecc>.mat`,
`AHEO_bins.mat`) and the existing DV functions. Only one small helper is needed: a variant of
`multinomial_llr` that returns the per-bin terms as well as the sum.

```matlab
% multinomial_llr_terms.m  — returns per-bin contributions t_i (t_i >= 0), and their sum.
function [llr, t] = multinomial_llr_terms(a, b)
    a = a(:); b = b(:); tot = a + b; na = sum(a); nb = sum(b); N = na + nb;
    xlx = @(x) x .* log(max(x,realmin));            % 0*log0 -> 0
    t = xlx(a) - a*log(na) + xlx(b) - b*log(nb) - ( xlx(tot) - tot*log(N) );
    t(tot == 0) = 0;                                % empty bins contribute 0
    llr = max(sum(t), 0);
end
```

### Experiment 1 — Characterize how different the adaptive bins are

For each feature/eccentricity, take the `AHEO` edges and read off their **prior-CDF positions** (invert
the Stage-2 CDF). Plot bin-edge cumulative-probability vs edge index.
*Prediction:* equalization → a straight line (evenly spaced in probability); adaptive → a staircase that
is dense in some quantile ranges and flat in others. Quantify with the deviation from uniform spacing
(e.g. KS distance between the adaptive edge-quantiles and the uniform grid). This turns "sometimes quite
different" into a number per feature.

### Experiment 2 — Build the discriminative-information landscape (your core idea)

1. Choose a **fine, uniform-in-quantile** reference binning from 0.1 % to 99.9 % of the prior (e.g. 256
   or 1024 bins) via `make_bins`. (Uniform in *quantile* keeps per-bin counts balanced; using 0.1–99.9 %
   trims unstable tails, exactly as you suggested.)
2. For every near pair and every far pair in `patch_pairs_<ecc>.mat`, compute the per-pair per-bin terms
   `t_i` with `multinomial_llr_terms` (drive it through `dv_spot_hist`/`dv_edge_hist` so the feature
   extraction is identical to production).
3. Accumulate per bin: `E_near[t_i]`, `E_far[t_i]`, their variances, `Δ_i`, and `d'_i`.
4. Plot `E_near[t_i]`, `E_far[t_i]`, and `Δ_i` along the feature axis.
*Prediction:* `E_far > E_near` everywhere (far pairs are more different), but `Δ_i` is **peaked**, not
flat — the peaks are the informative feature ranges.

### Experiment 3 — Do the adaptive bins track the landscape?

Overlay the `AHEO` edges (Experiment 1) on the `Δ_i` / `d'_i` curve (Experiment 2).
- Qualitative: do adaptive edges cluster on the peaks of `Δ_i` and thin out on its flats?
- Quantitative: compute local adaptive **bin density** (edges per unit prior-quantile) and correlate it
  with local `|Δ_i|` (or with cumulative information `∫Δ`). A strong positive correlation confirms your
  interpretation that Stage 4 is, in effect, discovering the difference-histogram landscape indirectly.

### Experiment 4 — "Information-equalizing" bins vs prior-equalizing vs adaptive

Construct a fourth binning that places `k` edges to **equalize cumulative `Δ_i`** (or cumulative `d'_i²`,
which is the natural information measure) instead of cumulative prior mass — i.e. warp the axis by the
information landscape rather than by the prior. Then score all four schemes with the *existing*
`proximity_error` (near/far `samp_opt_err`) at matched bin counts:

| Scheme | Axis warp | Uses labels? |
|---|---|---|
| Prior-equalized (`make_bins`) | prior CDF | no |
| Adaptive (`AHEO`) | greedy, task-tested | yes (greedy) |
| Information-equalized | `Δ_i` / `d'_i²` CDF | yes (direct) |
| Continuous-optimized (opt.) | free edge positions | yes (direct) |

*Predictions / what each outcome means:*
- If **information-equalized ≈ adaptive** at equal `k`: strong support for your reinterpretation — the
  adaptive greedy search is really just tracking the difference-histogram, and a one-shot label-aware warp
  reproduces it more cheaply and transparently.
- If **information-equalized > adaptive**: the greedy/dyadic-quantile restriction *is* costing
  performance (validates the Section-5 critique); prefer the direct method.
- If **adaptive > information-equalized**: the interaction between bins (the LLR is a *joint* statistic,
  not a sum of independent per-bin tests) matters, and greedy task-testing captures something the
  marginal landscape misses. Worth knowing either way.

### Experiment 5 — The bias–variance sanity check

Plot `proximity_error` vs number of **uniform-in-quantile** bins (2, 4, 8, …, 512) for each feature.
*Prediction:* a U-shape — error falls then rises as per-bin counts get too sparse. The minimum locates the
"right" resolution and shows *why you can't just use very fine uniform bins*. Compare the adaptive bin
count and the adaptive error to this curve: adaptive should sit at or below the uniform U's minimum while
using **fewer, cleverly-placed** bins. This directly demonstrates the model-selection role of `err_crit`.

---

## 8. Recommendations

- **Report the reframing.** Presenting the DV as `N·JSD` between the two patch histograms, and Stage 4 as
  "choose histogram resolution to best separate near/far," is clearer and more defensible than "adaptive
  histogram equalization" (which invites exactly your objection, since nothing is being equalized to the
  prior in the end).
- **Run Experiments 2–4.** They are cheap (reuse existing artifacts) and would either (a) validate that
  the adaptive bins are tracking the difference-histogram landscape — in which case you can *replace* the
  greedy dyadic search with a transparent information-equalizing warp — or (b) show the greedy search is
  leaving performance on the table, motivating a direct optimizer.
- **Keep the prior for candidate placement / variance control, drop it as the conceptual objective.** The
  honest statement is: near/far labels supply the objective; the prior supplies a balanced coordinate
  system and regularization. Your proposed direct method makes that separation explicit.
- **If Experiment 4 shows headroom, build the iterative JS-equalizing scheme in Section 9** — it places
  edges by equalizing the divergence landscape and learns the bin count by held-out error (with the
  ability to both add and remove bins). Run the cheap one-shot information-equalization first; only invest
  in the full loop if it beats the shipped bins.

---

## 9. A new iterative JS-equalizing binning scheme

You want to turn the diagnostic of Section 6 into a *training algorithm*: start from uniform bins,
measure the JS-divergence landscape, place bins that equalize it, score the task, and feed the result
back to iterate. Below is a design that does this and resolves your two worries — **(1)** what the
per-step bin update actually *is*, and **(2)** how to let it learn the number of bins the way the current
greedy scheme does. I'll also flag one theoretical fact that dictates the whole structure.

### 9a. The fact that dictates the structure: JS divergence only rises under refinement

The multinomial LLR (= `N·JSD`) is **monotonic under bin refinement**: splitting any bin can only
*increase* the divergence (data-processing / grouping inequality), and merging can only decrease it. So:

- **You cannot pick the number of bins by maximizing the JS divergence** — that number always wants to go
  to infinity. Raw divergence is the wrong thing to stop on.
- What actually peaks and then falls with more bins is the **near/far separation measured on held-out
  data**: extra bins keep adding real signal until per-bin counts get so sparse that the plug-in LLR
  becomes noisy and *anti-*generalizes (the U-curve of Experiment 5).

This splits the labor cleanly, and both of your questions map onto one side of the split:

| Role | Driven by | Answers |
|---|---|---|
| **Where** to put edges (at fixed K) | the JS-information landscape | your issue **(1)** |
| **How many** edges to keep | held-out / cross-validated near-far error | your issue **(2)** |

The information landscape is a cheap, label-aware *heuristic for placement*; task performance on held-out
data is the *only* honest arbiter of count. This is the same division as the existing scheme (propose a
split → test error → keep/freeze), but with a better proposal rule and a stopping rule that can also
*remove* bins.

### 9b. Measurement grid — the trick that makes "modify the bins" well-defined

The reason "how do I modify the bins each step" feels slippery is that the information contribution `t_i`
is only defined *on the bins you currently have* — you can't see structure inside a bin you haven't split.
Fix this once and the rest is easy:

> **Keep a fixed fine measurement grid.** Lay down `M` micro-bins (e.g. `M = 256–1024`) uniform in
> *prior-quantile* `u ∈ [0,1]` (via `make_bins`, 0.1 %–99.9 % as you suggested). Compute the near/far
> per-micro-bin contributions on this grid **once per outer iteration**. All working bins are unions of
> contiguous micro-bins, and every edge lives on a micro-grid point.

On this grid, define the discriminative-information density (from Section 6b, `multinomial_llr_terms`):

```
g_m = max( E_far[t_m] − E_near[t_m], 0 )        % or d'_m²  — info at micro-bin m, m = 1..M
G(m) = Σ_{j ≤ m} g_j ,   G_tot = G(M)           % cumulative information along the axis
```

`g_m` is sub-bin-resolution and stable, which is exactly what edge placement needs.

### 9c. Issue (1) — the per-step bin update = *equalize cumulative information*

At a fixed number of bins `K`, the update is a one-line inversion — the information analogue of
`make_bins` (which inverts the *prior* CDF; here we invert the *information* CDF):

```
place interior edge k at the micro-grid point m_k with G(m_k) ≈ (k/K)·G_tot ,   k = 1..K−1
```

i.e. **each bin carries an equal share of the near/far divergence.** Where information piles up
(peaks of `g`), edges crowd together → fine bins; where `g ≈ 0`, edges spread out → coarse bins. That is
precisely the behavior you conjectured the current scheme is approximating, now done directly.

Two ways to run it, depending on how exact you want to be:

- **One-shot (recommended default).** If `g_m` is measured on the *fixed fine grid* (independent of the
  current coarse bins), the equalizing edges are obtained in a single inversion — **no position iteration
  is needed at fixed K.** This is the honest surprise: pure information-equalization of the positions
  converges immediately; it's only the *count* (K) that needs a loop.
- **Lloyd-style relaxation (if you define `t_i` on the coarse bins instead).** Then `g` depends on the
  current edges, so iterate to a fixed point with damping: move each interior edge a fraction `α ≈ 0.5`
  of the way toward its information-equalizing target, re-measure, repeat until edges stop moving. This
  matches your "feed the JS bins back and hone in" picture and is robust, at the cost of a few extra
  passes.
- **Exact, for a fixed additive surrogate (bonus).** Grouping `M` ordered micro-bins into `K` contiguous
  bins to optimize any *additive* objective (e.g. maximize summed per-bin `d'²`, or minimize an
  information-equalization cost) is solved to the **global optimum by 1-D dynamic programming** in
  `O(M²K)`. This sidesteps local minima entirely and is cheap at these sizes. Use it when you want the
  best bins at a given `K` without trusting a relaxation. (It can't directly optimize the separation of
  the *summed* LLR, which is non-additive — that stays the job of the CV score in 9d.)

### 9d. Issue (2) — learning the number of bins, with add *and* remove

Wrap the placement step (9c) in a model-selection loop scored on **held-out near/far error**, so it
inherits the current scheme's "stop when more bins hurt" behavior — and gains the ability to *shed* bins,
which the greedy freeze-only method cannot:

- **Split proposal (grow).** Instead of the current "split at the prior median," split the bin with the
  **largest information content** `Σ_{m∈bin} g_m` at its *information* midpoint. Growth is
  information-driven, consistent with the equalization philosophy, and tends to reach a good configuration
  in fewer bins.
- **Merge proposal (shrink — new capability).** Merge the adjacent pair whose combined bin loses the
  **least** information (by sub-additivity, merging always loses some; pick the smallest loss). This lets
  the method *undo* over-splitting — the current scheme can only freeze, never merge.
- **Accept / stop on cross-validated error.** After each split or merge, re-run the placement (9c) and
  score `k`-fold CV near-far error (reuse `classify_normals` / `proximity_error`, but averaged over
  held-out folds of the pairs). Accept a split only if CV error improves by more than a tolerance;
  accept a merge if CV error does not worsen. **Stop when neither a split nor a merge improves CV error.**
  Because CV error is U-shaped in K (9a), this converges to the right count instead of running away.

This is a strict generalization of the shipped algorithm:

| | Current greedy (`s4`) | Proposed |
|---|---|---|
| Split location | prior-CDF median of the bin | **information** median of the most-informative bin |
| Direction | grow only (freeze) | **grow *and* merge** |
| Accept / stop | in-sample error drop > 0.2 % | **held-out CV** error improvement |
| Overfit control | fixed threshold | CV (data-driven) |
| Optimum at fixed K | — | optional **DP** global optimum |

### 9e. The full loop (your "feed it back and iterate")

```
init:   bins = uniform-in-prior-quantile (small K, e.g. 2–4)
repeat (outer):
    measure:   histogram all near & far pairs on the fixed fine grid  ->  g_m, G(m)   [9b]
    place:     set the K−1 edges to equalize cumulative information    [9c: invert G, or Lloyd, or DP]
    score:     CV near-far error of the summed LLR on these bins       [classify_normals over folds]
    adapt K:   try split (most-informative bin) and merge (least-loss pair);
               keep whichever improves CV error; update K              [9d]
until   no split or merge improves CV error  AND  edges are at the information fixed point
return  bins
```

**Why the feedback loop is real (not just cosmetic).** If you only ever equalized the *fixed* fine-grid
information, positions would be one-shot and there'd be nothing to iterate. The loop earns its keep
because the quantity that actually matters — held-out separation of the *summed, count-limited* LLR —
differs from the raw fine-grid information in two ways the placement step can't see on its own:
sub-additivity under merging, and count-noise at the coarse resolution actually used. Re-measuring after
each K change (and, in the Lloyd variant, after each move) is what lets those effects steer the next step.
That is the principled version of "feed the JS bins back to the start."

### 9f. Practicalities and pitfalls

- **Always score on held-out pairs.** In-sample JS/LLR rises monotonically with K (9a) and will
  over-split. CV is not optional here — it *is* the mechanism that answers issue (2).
- **Balanced counts.** Measuring on prior-quantile-uniform micro-bins keeps per-micro-bin occupancy even,
  so `g_m` isn't dominated by a few dense micro-bins. You can still let final coarse bins be very unequal
  in prior mass — that's expected and desired.
- **Clamp/regularize `g`.** The `max(·,0)` and a small floor avoid chasing noise in near-empty micro-bins;
  optionally smooth `g_m` (a short moving average in `u`) before inverting.
- **Per feature, per eccentricity**, exactly like `s4` today; the outer loop is independent across the
  features `[1 5 6 7 9 10 11 13 14]`.
- **Cost.** One fine-grid pass over the ~7,820 pairs per outer iteration; a handful of outer iterations.
  Comparable to the current greedy sweep, and the DP option is `O(M²K)` per K — negligible at `M≈512`.
- **Validation.** Compare against the three baselines already defined in Experiment 4 (prior-equalized,
  shipped `AHEO`, one-shot information-equalized). Success = matches or beats shipped `AHEO` at equal or
  fewer bins on held-out near/far error, and (bonus) transfers to GTR segmentation accuracy in Stage 7.

### 9g. Honest caveats

- Information-equalization is a **placement heuristic**, not a proof of optimal separation; the summed LLR
  is non-additive, so only the CV score certifies a configuration. Keep placement and acceptance separate.
- Features are binned **marginally**; the DVs are combined downstream (content/border bounds). Per-feature
  bin optimization ignores cross-feature redundancy — the same limitation the current scheme has, not a
  regression.
- If the one-shot information-equalized bins (Experiment 4) already match `AHEO`, the elaborate loop may
  be unnecessary — run that cheap test first and only build the full 9e loop if it shows headroom.

---

## Appendix — code map

| Concept | File |
|---|---|
| Multinomial LLR (histogram DV, Eq. 1 / A4) | [`multinomial_llr.m`](../../vislab-common/+vislab/+nat_stat_bayes/multinomial_llr.m) |
| Spot / center-surround histogram DVs | [`dv_spot_hist.m`](../../vislab-common/+vislab/+nat_stat_bayes/dv_spot_hist.m) |
| Edge / bar histogram DVs | [`dv_edge_hist.m`](../../vislab-common/+vislab/+nat_stat_bayes/dv_edge_hist.m) |
| Equal-probability (prior-equalizing) bins | [`make_bins.m`](../../vislab-common/+vislab/+nat_stat_bayes/make_bins.m) |
| Candidate split at within-bin prior median | [`find_bin_bound.m`](../../vislab-common/+vislab/+nat_stat_bayes/find_bin_bound.m) |
| Adaptive bin optimization (Stage 4) | [`s4_optimize_bins.m`](../pipeline/s4_optimize_bins.m) |
| Feature priors (Stage 2) | [`s2_learn_feature_priors.m`](../pipeline/s2_learn_feature_priors.m) |
| Near/far training pairs (Stage 3) | [`s3_make_nearfar_pairs.m`](../pipeline/s3_make_nearfar_pairs.m) |
