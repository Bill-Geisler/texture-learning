# Adaptive histogram optimization — what it does, and a proposed replacement

*On pipeline Stage 4 ([`s4_optimize_bins.m`](../pipeline/s4_optimize_bins.m)) and the histogram decision
variable it feeds. Companion to the proximity paper (Geisler, bioRxiv 2026).*

## 1. The decision variable, as a per-bin divergence

For one feature, each patch becomes a histogram of counts over fixed bins $i = 1,\dots,B$. Given per-bin
counts $a_i$ (patch A) and $b_i$ (patch B), with $n_a=\sum_i a_i$, $n_b=\sum_i b_i$, $N=n_a+n_b$, the
decision variable (the log-likelihood ratio $L$;
[`multinomial_llr.m`](../../vislab-common/+vislab/+nat_stat_bayes/multinomial_llr.m), paper Eq. 1/A4) is

$$L = \sum_i L_i, \qquad L_i = a_i\ln\frac{a_i}{n_a} + b_i\ln\frac{b_i}{n_b} - (a_i+b_i)\ln\frac{a_i+b_i}{N} \;\ge 0$$

($L_i \ge 0$ by concavity of entropy.) Rewritten, $L$ is **exactly $N \cdot D$**, where
$D = \mathrm{JSD}(a,b)$ is the Jensen–Shannon divergence between the normalized patch histograms. The identity holds **bin by bin**, $L_i = N\,D_i$.

So the DV measures how *divergent* the two patch histograms are, and $\{D_i\}$ is a per-bin **divergence
profile** summing to $D$: near-zero in every bin for near pairs (alike histograms), large in bins where
far pairs diverge. This frames the whole diagnostic — **compare the near-pair and far-pair distributions
of $D_i$, bin by bin:** bins where far pairs' $D_i$ systematically exceeds near pairs' (a large near/far
gap) carry the discriminative signal; bins where near and far look alike carry none (§4 makes this
precise). *(From here on we use the divergence form $D$, $D_i$; recall $L=ND$, $L_i=ND_i$, so nothing
below changes if you'd rather track the LLR directly — only the overall scale $N$ differs.)*

## 2. Two ways to choose bins

- **Prior-equalizing** ([`make_bins.m`](../../vislab-common/+vislab/+nat_stat_bayes/make_bins.m)): edges at
  equal steps of prior cumulative probability (histogram equalization). The priors are already computed by
  the front-end (Stage 2). You found this doesn't give the best near/far performance.
- **Adaptive** (Stage 4): a greedy top-down binary split — a 1-D decision tree. Start at the prior median;
  propose splitting a bin **at its within-bin prior-CDF midpoint** ([`find_bin_bound.m`](../../vislab-common/+vislab/+nat_stat_bayes/find_bin_bound.m));
  keep the split only if the near/far classification error (`classify_normals` on the single-feature LLR
  over Stage-3 pairs) drops by > 0.2 %, else freeze the bin. Repeat until nothing improves.

Two facts explain why the adapted bins look so different from equalized ones: candidate edges can only
land at **dyadic prior-quantiles** ($k/2^m$), and regions get split to *different depths*, so the final
bins are deliberately **unequal in prior mass** — fine where the task needs it, coarse where it doesn't.

## 3. Why use the prior at all? (your objection)

The prior plays three roles, and only the first two are needed:
1. **Candidate placement** — edges land where feature values occur, and each split ~halves a bin's pixel
   mass, keeping per-bin counts balanced (the LLR's estimation variance depends on counts).
2. **Regularization** — restricting to dyadic prior-quantiles curbs overfitting on ~7,820 pairs.
3. *(Not an objective.)* The method never optimizes "equalize the prior"; it optimizes near/far error.

So the prior is the **search parameterization + variance control**, not the goal. Your critique is still
valid but narrower: this parameterization *constrains the reachable edges*, and a freer, label-aware
search could do better. Note the near/far labels (the real signal) are available at training via
proximity — so there's no fundamental reason to lean on the prior for the objective.

## 4. Theory: what should the optimal bins do to $D_i$?

**Notation.** $\langle\cdot\rangle_{\text{far}}$ and $\langle\cdot\rangle_{\text{near}}$ denote an
**average over the training set of far pairs / near pairs** respectively.

Your hypothesis is essentially right, and here is the mechanism. The task classifies a pair by its total
$D = \sum_i D_i$, so accuracy is governed by the separation of the near-pair and far-pair distributions
of $D$, e.g. by a discriminability index that decomposes into one per-bin term $\delta_i$:

$$d' \;=\; \frac{\langle D\rangle_{\text{far}} - \langle D\rangle_{\text{near}}}{\mathrm{SD}_{\text{pooled}}(D)} \;=\; \sum_i \delta_i, \qquad \delta_i \;=\; \frac{\langle D_i\rangle_{\text{far}} - \langle D_i\rangle_{\text{near}}}{\sqrt{\tfrac12\sum_j\big(\mathrm{Var}_{\text{far}}(D_j) + \mathrm{Var}_{\text{near}}(D_j)\big)}}$$

The pooled SD averages the spread of $D$ over the two sets, $\mathrm{SD}_{\text{pooled}}(D) = \sqrt{\tfrac12(\mathrm{Var}_{\text{far}}(D)+\mathrm{Var}_{\text{near}}(D))}$, and within each set $\mathrm{Var}(D) \approx \sum_j \mathrm{Var}(D_j)$ (bins are only weakly coupled).

**Each bin adds noise; only some bins add signal.** With finitely many pixels, even two same-texture
patches have histograms that differ a little in each bin by chance; since $D_i \ge 0$ that mismatch adds
a small positive $D_i$ with its own variance. So each extra bin adds one more positive term under the
denominator's root, raising the SD — for same-texture pairs $2ND \sim \chi^2_{B-1}$, giving
$\mathrm{Var}(D) \propto B-1$ regardless of where the edges sit. A far pair adds that same random mismatch
**plus** signal wherever the two histograms genuinely differ. So an extra bin always grows the
denominator (noise), but grows the numerator $\sum_i \Delta D_i$ only where far-pair histograms differ.

This settles both questions:

1. **How many bins ($B$).** Keep adding bins while each one adds more signal than noise. The real
   between-texture divergence is finite, so the numerator saturates while the denominator keeps rising
   with $B$ — $d'$ rises, peaks, then falls. That peak sets the best $B$ (the bias–variance U-curve).
2. **Where the edges go (fixed $B$).** Put fine bins where the gap $\Delta D_i$ is large, coarse bins
   where it's ≈ 0. Because every bin costs about the same noise, the best split gives **each bin an equal
   share of the signal $\sum_i \Delta D_i$** — i.e. equalize $\Delta D_i$ across bins.

**So, to answer your question directly: yes.** Equalize the per-bin gap $\Delta D_i$ across bins, and stop
adding bins once a new one's gap no longer beats the noise it costs. Equalizing the *prior* is the wrong
target because prior mass says nothing about where $\Delta D_i$ lives — it wastes bins on smooth,
high-probability regions with no near/far signal and starves the sharp, low-probability structure that
carries it. §6 operationalizes exactly this (equalize the cumulative gap; stop on held-out error). The
"equal noise per bin" picture is an idealization, so §6 still certifies each choice with held-out error
rather than the gap alone.

## 5. Test: does the current method equalize the gap?

The theory's core, falsifiable claim is: **the shipped adaptive (AHEO) bins make the per-bin near/far gap
$\Delta D_i$ roughly equal across bins** — equivalently, the cumulative gap $\sum_{j\le i}\Delta D_j$ is
linear in bin index $i$. The tests below verify exactly this.

**Setup.** One helper is needed — a variant of `multinomial_llr` returning per-bin LLR terms `L` (then
$D_i = L_i/N$):

```matlab
function [llr, L] = multinomial_llr_terms(a, b)
    a=a(:); b=b(:); tot=a+b; na=sum(a); nb=sum(b); N=na+nb;
    xlx=@(x) x.*log(max(x,realmin));
    L = xlx(a)-a*log(na) + xlx(b)-b*log(nb) - (xlx(tot)-tot*log(N));
    L(tot==0)=0;  llr=max(sum(L),0);
end
```

For each feature/eccentricity, run every near and far training pair (`patch_pairs_<ecc>`) through it under
the shipped **AHEO** bins and average to get $\langle D_i\rangle_{\text{near}}$, $\langle D_i\rangle_{\text{far}}$,
and the gap $\Delta D_i = \langle D_i\rangle_{\text{far}} - \langle D_i\rangle_{\text{near}}$.

1. **Main test — is $\Delta D_i$ flat?** Plot $\Delta D_i$ vs bin index for the AHEO bins. Predicted:
   ≈ constant. Quantify with the coefficient of variation of $\{\Delta D_i\}$ (predicted small), or fit a
   straight line to the cumulative gap $\sum_{j\le i}\Delta D_j$ vs $i$ and report $R^2$ (predicted ≈ 1).
2. **Control — prior-equalizing bins are *not* flat.** Recompute $\Delta D_i$ under prior-equalizing bins
   at the same bin count $B$. Predicted: strongly non-uniform (peaked), high CV — showing gap-flatness is
   specific to the adaptive bins, not automatic for any binning.
3. **Control — adaptive edges sit at equal-cumulative-gap quantiles.** On a fine uniform-in-quantile grid
   ($0.1$–$99.9\%$, $\sim 256$–$1024$ micro-bins), build the gap profile and its cumulative $C$. Check
   each AHEO edge $k$ satisfies $C(\text{edge}_k) \approx (k/B)\,C_{\text{tot}}$; overlaid on $C$, the
   edges should land on evenly spaced cumulative-gap levels (and cluster where the gap profile peaks).
4. **Mechanism premise — noise is ~equal per bin.** Confirm $\langle D_i\rangle_{\text{near}}$ (and
   $\mathrm{Var}_{\text{near}}(D_i)$) is roughly constant across the AHEO bins. If so, equalizing the gap
   *is* equalizing signal-per-noise — the assumption that makes a flat $\Delta D_i$ optimal.

If tests 1–3 hold, the current method is (approximately) equalizing the $D$-gap histogram — confirming
the theory. Two further checks close the loop: (a) the **information-equalized** bins of §6 (edges placed
to equalize the cumulative gap directly) should then reproduce the AHEO bins and their near/far
`proximity_error`; (b) `proximity_error` vs number of uniform bins should trace the predicted U-shape,
verifying the bin-count half of the theory.

## 6. A new iterative JS-equalizing scheme

Turning §4 into a training algorithm resolves your two questions once you note **one fact**: JS divergence
only *rises* under refinement (data-processing inequality), so you can't pick the bin count by maximizing
it — it wants infinitely many bins. What peaks-then-falls is **held-out near/far separation**. Hence:

| Role | Driven by | Your issue |
|---|---|---|
| **Where** edges go (fixed $B$) | the near/far gap in $D_i$ | (1) how to modify bins |
| **How many** edges | cross-validated near/far error | (2) how to learn $B$ |

**Measurement grid (makes the update well-defined).** Keep a fixed fine grid of $M \approx 256$–$1024$
micro-bins (uniform in prior-quantile); working bins are unions of contiguous micro-bins, every edge sits
on a micro-grid point. On it, compute each micro-bin's near/far gap in $D_i$ (mean over far pairs − mean
over near pairs, floored at 0) and its cumulative $C(m)$.

**(1) The per-step update = equalize the cumulative gap** — the near/far analogue of `make_bins`:

$$\text{place edge } k \text{ where } C(m_k) \approx \frac{k}{B}\,C_{\text{tot}} \qquad \text{(each bin carries equal near/far signal)}$$

Honest surprise: measured on the *fixed grid*, edge positions converge in **one shot** — no position
iteration is needed at fixed $B$. (If you instead recompute the gap on the *coarse* bins each step, use a
damped Lloyd relaxation; for the global optimum of an additive surrogate at fixed $B$, 1-D dynamic
programming solves it exactly in $O(M^2B)$.)

**(2) Learning $B$, with add *and* remove.** Wrap placement in a loop scored on **held-out CV** near/far
error: propose a **split** of the most-informative bin (vs the current "split at prior median") and a
**merge** of the least-informative adjacent pair (new — the greedy scheme can only freeze, never merge);
keep whichever improves CV error; **stop when neither helps.** CV error is U-shaped in $B$, so this
converges instead of running away. This is a strict generalization of `s4`:

| | Current `s4` | Proposed |
|---|---|---|
| Split location | prior median | **information** median of most-informative bin |
| Direction | grow only | **grow + merge** |
| Stop | in-sample error > 0.2 % | **held-out CV** error |

**Full loop:**

```
bins = uniform-in-prior-quantile (B≈2–4)
repeat:
    on the fixed grid, get each micro-bin's near/far gap in D_i, and its cumulative C(m)
    place B−1 edges to equalize the cumulative gap (invert C / Lloyd / DP)
    score CV near-far error of the summed LLR (classify_normals over folds)
    try split (most-informative bin) and merge (least-loss pair); keep if CV error improves
until no split or merge improves CV error
```

**Why the feedback is real:** if you only equalized the fixed-grid info, positions would be one-shot and
nothing would iterate. The loop earns its keep because held-out separation of the *summed, count-limited*
LLR differs from raw fine-grid info via sub-additivity under merging and count-noise at the coarse
resolution — re-measuring after each $B$ change lets those steer the next step.

**Caveats.** Always score on held-out pairs (in-sample JS rises monotonically and over-splits).
Information-equalization is a placement *heuristic*; only the CV score certifies a configuration. Bins are
optimized per-feature (ignores cross-feature redundancy — same as now). **Run the cheap one-shot
information-equalization (test 4) first; only build the full loop if it beats the shipped `AHEO` bins.**

## Appendix — code map

| Concept | File |
|---|---|
| Multinomial LLR (Eq. 1/A4) | [`multinomial_llr.m`](../../vislab-common/+vislab/+nat_stat_bayes/multinomial_llr.m) |
| Spot / center-surround DVs | [`dv_spot_hist.m`](../../vislab-common/+vislab/+nat_stat_bayes/dv_spot_hist.m) |
| Edge / bar DVs | [`dv_edge_hist.m`](../../vislab-common/+vislab/+nat_stat_bayes/dv_edge_hist.m) |
| Prior-equalizing bins | [`make_bins.m`](../../vislab-common/+vislab/+nat_stat_bayes/make_bins.m) |
| Candidate split (prior median) | [`find_bin_bound.m`](../../vislab-common/+vislab/+nat_stat_bayes/find_bin_bound.m) |
| Adaptive bins (Stage 4) | [`s4_optimize_bins.m`](../pipeline/s4_optimize_bins.m) |
| Feature priors (Stage 2) | [`s2_learn_feature_priors.m`](../pipeline/s2_learn_feature_priors.m) |
| Near/far pairs (Stage 3) | [`s3_make_nearfar_pairs.m`](../pipeline/s3_make_nearfar_pairs.m) |
