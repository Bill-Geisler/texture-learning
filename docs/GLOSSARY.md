# Glossary — texture-learning

Decoder for the terse names in this codebase: code term ↔ paper symbol/notation ↔ meaning.
Paper = Geisler proximity paper (`proximity-paper.pdf`) and the foundational Geisler & Das
segmentation paper (`segmentation-paper.pdf`).

## Colour & optics
| Code | Paper | Meaning |
|---|---|---|
| `LMS` / `lms` | L,M,S | long/medium/short-wavelength cone responses per pixel |
| `ABR` / `abr` | a, b, r | opponent colour axes from PCA of LMS: **A**chromatic, **B**lue-yellow, **R**ed-green |
| `coeff` / `color_rotation` | — | 3×3 LMS→ABR rotation matrix (PCA components) |
| `OTF` | — | optical transfer function of the eye (Watson 2013) |
| `ppd` | — | pixels per degree (**60** for display/GTR images, **64** for the natural images: 64 px = 1°) |
| `pd`, `w` | d, λ | pupil diameter (mm), wavelength (nm) |
| `m0`, `c0` | — | target mean (128) and RMS contrast (0.25) for patch normalization |

## Task-independent feature dimensions (indices 1–14)
1 A pixel · 2 B pixel · 3 R pixel · 4 edge count · 5 edge magnitude · 6 edge orientation ·
7 edge mag×ori · 8 bar count · 9 bar magnitude · 10 bar orientation · 11 bar mag×ori ·
12 center-surround ratio (small) · 13 center-surround linear (small) · 14 center-surround linear (large).
The pipeline uses spot dims **[1 13 14]** and edge dims **[5 9 10]** in the content DV.

## Decision variables (paper log-likelihood ratios ln L → code)
| Code (vislab `vislab.nat_stat_bayes.*`) | Was | Paper | Meaning |
|---|---|---|---|
| `dv_power` | `Rp` | ln L_p | power-spectrum DV (complex-cell-like) |
| `dv_spot_hist` | `Rh` | ln L_h | spot/colour + center-surround histogram DV |
| `dv_edge_hist` | `Re` | ln L_e | edge/bar steerable-filter histogram DV |
| `dv_border` | `Rb` | E_b, Ē_b | border edge-energy DVs (+ cross-correlation) |
| `multinomial_llr` | (inline) | Eq. 1 / A4 | multinomial histogram log-likelihood ratio |
| (content) | — | ln L_c | content DV = combination of power+spot+edge |
| (border+content) | — | ln L_bc | joined similarity DV = combination of border+content |

## Similarity & grouping
| Code | Paper | Meaning |
|---|---|---|
| `phi` / `phiall` | φ_ij | content similarity (log-likelihood ratio) between patches i,j |
| `mu`, `u`, `rho` | μ_ij, u_ij | mutual similarity = cosine similarity of the two patches' similarity vectors |
| `wm` | w_m | mutual-similarity weight |
| `gc` | γ_l | local-similarity grouping criterion |
| `cc` | γ_c | confidence criterion (weak links near the bound left unlinked) |
| `mc` / `merge_criterion` | γ_r | region-similarity merge criterion |
| `copt` | — | per-image optimal criterion shift learned self-supervised |
| `p_s`, `p_d` | p_s, p_d | prob. same for near pairs / prob. different for far pairs (mixture params) |

## Eccentricities, datasets, methods
| Code | Meaning |
|---|---|
| `ecc` | eccentricity downsample factor 1/2/4/8 (≈ fovea, 1.65°, 4.95°, 11.55°) |
| `btype` | histogram-bound type: **5** = natural images, **4** = Brodatz/Fabric |
| `itype` | texture dataset: 1 Pertex · 2 Fabric · 3 Brodatz · 4 Brodatz+Fabric · 5 VisTex · 6 McGill |
| `NO` (in `dbnd*NO`) | **N**atural-image-trained + **O**TF applied (vs `BF` = Brodatz/Fabric-trained) |
| N, NC, NCB, NM, NCM, NCBM | training methods: N=natural-image-trained; +C content-criterion adjust; +B border adjust; +M mutual-similarity weight |
| GTR | grown-texture-region image (random regions filled with random textures) |
| `b0` | β, weak Fourier-power suppression constant |

## Function renames (old flat name → new)
`otf`→`vislab.lib.watson_otf`, `aply_otf`→`vislab.lib.otf_filter`, `dsmp`→`vislab.lib.downsample`,
`adobe_compress/expand`→`vislab.lib.gamma_compress/expand`, `mk_dg_hv`→`vislab.lib.steerable_kernels`,
`mk_2dg_sf`→`vislab.lib.gauss_deriv2_kernels`, `imgrad`→`vislab.lib.steerable_grad_response`,
`imgrad2`→`vislab.lib.grad2_response`, `cen_sur`→`vislab.lib.center_surround`, `rot`→`vislab.nat_stat_bayes.apply_color_rotation`,
`mk_bins`→`vislab.nat_stat_bayes.make_bins`, `find_bnd`→`vislab.nat_stat_bayes.find_bin_bound`,
`mk_bb`→`vislab.nat_stat_bayes.load_bin_bounds`, `Rcc`→`vislab.nat_stat_bayes.xcorr_patches`;
`mk_phi`→`segmentation.content_similarity_matrix`, `mk_groups`→`segmentation.group_patches`,
`iso_patch`→`segmentation.assign_isolated_patches`, `merge_groups`→`segmentation.merge_similar_regions`,
`reg_count`→`segmentation.count_correct_regions`; `mk_texs`→`gtr.sample_texture_ids`,
`mk_masks`→`gtr.grow_region_masks`. Pipeline scripts `mk_rot_mtrx`→`s1_learn_color_transform`,
`cdfs_of_features`→`s2_learn_feature_cdfs`, `nat_near_far_patches`→`s3_make_nearfar_pairs`,
`opt_bins_nat`→`s4_optimize_bins`, `nat_near_far_dv_2`→`s5_train_decision_vars`.
