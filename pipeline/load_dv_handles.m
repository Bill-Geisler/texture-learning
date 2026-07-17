function dv = load_dv_handles(cfg, ecc, load_bc)
% LOAD_DV_HANDLES  Load trained decision-variable function handles for an eccentricity.
%   dv = load_dv_handles(cfg, ecc, load_bc)
%
%   Builds function handles for the trained decision variables from the
%   decision_bounds_ecc_<ecc>.mat artifact (via quad2fun): dv.h (spot), dv.e (edge),
%   dv.c (content), dv.b (border). If load_bc is true, also dv.bc (border+
%   content). Shared by pipeline stages s6 and s7.
%
%   Requires the IntClassNorm add-on (quad2fun) and the stage-5 artifacts in
%   cfg.paths.models. Run `setup` first.

    if nargin < 3 || isempty(load_bc), load_bc = false; end
    tag = num2str(ecc);
    S = load(fullfile(cfg.paths.models, ['decision_bounds_ecc_' tag '.mat']), 'dbnd');
    dbnd = S.dbnd;
    
    dv.h = quad2fun(dbnd.h, 0);
    dv.e = quad2fun(dbnd.e, 0);
    dv.c = quad2fun(dbnd.c, 0);
    dv.b = quad2fun(dbnd.b, 0);
    
    if load_bc
        dv.bc = quad2fun(dbnd.bc, 0);
    end
end
