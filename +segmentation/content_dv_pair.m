function rc = content_dv_pair(fa, fb, psz, b0, dv_h, dv_e, dv_c, spot_dims, edge_dims)
% CONTENT_DV_PAIR  Content decision variable between two patches from precomputed
%   features (compare half of the featurize/compare split; see content_features).
%   rc = segmentation.content_dv_pair(fa, fb, psz, b0, dv_h, dv_e, dv_c, ...
%           spot_dims, edge_dims)
%
%   fa, fb are per-patch feature structs from segmentation.content_features. Combines
%   the power spectra, spot histograms and edge histograms into the power/spot/edge
%   DVs and then the trained content DV -- identical to computing dv_power +
%   dv_spot_hist + dv_edge_hist per pair, but without re-featurizing either patch.
%
%   Inputs
%     fa, fb    - patch feature structs (.pspec, .hspot, .hedge).
%     psz       - patch size in pixels.
%     b0        - power (noise) suppression constant for the power DV.
%     dv_h/e/c  - trained spot / edge / content DV handles (quad2fun).
%     spot_dims, edge_dims - feature dims fed to the spot / edge DVs.
%
%   Output
%     rc - content decision variable (paper: ln L_c).
    rp = log(vislab.nat_stat_bayes.power_llr_from_spectra(fa.pspec, fb.pspec, b0, psz));
    rh = dv_h(log(pair_llrs(fa.hspot, fb.hspot, spot_dims))');
    re = dv_e(log(pair_llrs(fa.hedge, fb.hedge, edge_dims))');
    rc = dv_c([rp, rh, re]');
end

function v = pair_llrs(ha, hb, dims)
% Multinomial LLR of the two patches' histograms for each feature in dims (row vector).
    v = zeros(1, numel(dims));
    for t = 1:numel(dims)
        k = dims(t);
        v(t) = vislab.nat_stat_bayes.multinomial_llr(ha{k}, hb{k});
    end
end
