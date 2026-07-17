function P = finalize_priors(S, n_bins, coeff)
% FINALIZE_PRIORS  Turn the per-image feature samples (a struct array from
%   sample_prior_features, one element per image) into the marginal CDFs -- the
%   natural priors that Stage 23 saves. Used by s23_learn_priors_and_pairs.
%
%   Returns struct P whose fields are exactly the variables saved to the priors
%   file (prior_filename; edges e*, cumulative N*, plus coeff), so
%   callers can `save(path, '-struct', 'P')`.
    abr_all = cat(1, S.lms) * coeff;
    [P.Na, P.ea]    = histcounts(abr_all(:, 1),  n_bins, 'Normalization', 'cdf');
    [P.Nb, P.eb]    = histcounts(abr_all(:, 2),  n_bins, 'Normalization', 'cdf');
    [P.Nr, P.er]    = histcounts(abr_all(:, 3),  n_bins, 'Normalization', 'cdf');
    [P.Nm, P.em]    = histcounts(cat(1, S.g1m),  n_bins, 'Normalization', 'cdf');
    [P.No, P.eo]    = histcounts(cat(1, S.g1o),  n_bins, 'Normalization', 'cdf');
    [P.Nmo, P.emo]  = histcounts(cat(1, S.g1mo), n_bins, 'Normalization', 'cdf');
    [P.Nm2, P.em2]  = histcounts(cat(1, S.g2m),  n_bins, 'Normalization', 'cdf');
    [P.No2, P.eo2]  = histcounts(cat(1, S.g2o),  n_bins, 'Normalization', 'cdf');
    [P.Nmo2, P.emo2]= histcounts(cat(1, S.g2mo), n_bins, 'Normalization', 'cdf');
    [P.Ncs1, P.ecs1]= histcounts(cat(1, S.cs1),  n_bins, 'Normalization', 'cdf');
    [P.Ncs2, P.ecs2]= histcounts(cat(1, S.cs2),  n_bins, 'Normalization', 'cdf');
    [P.Ncs4, P.ecs4]= histcounts(cat(1, S.cs4),  n_bins, 'Normalization', 'cdf');
    P.coeff = coeff;
end
