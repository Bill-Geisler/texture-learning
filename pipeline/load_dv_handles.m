function dv = load_dv_handles(cfg, lev, load_bc)
% LOAD_DV_HANDLES  Load trained decision-variable function handles for a level.
%   dv = load_dv_handles(cfg, lev, load_bc)
%
%   Builds function handles for the trained decision variables from the
%   dbnd*NO<lev>.mat artifacts (via quad2fun): dv.h (spot), dv.e (edge),
%   dv.c (content), dv.b (border). If load_bc is true, also dv.bc (border+
%   content). Shared by pipeline stages s6 and s7.
%
%   Requires the IntClassNorm add-on (quad2fun) and the stage-5 artifacts in
%   cfg.paths.models. Run `setup` first.

    if nargin < 3 || isempty(load_bc), load_bc = false; end
    tag = num2str(lev);
    dv.h = handle_for('dbndh');
    dv.e = handle_for('dbnde');
    dv.c = handle_for('dbndc');
    dv.b = handle_for('dbndb');
    if load_bc
        dv.bc = handle_for('dbndbc');
    end

    function h = handle_for(var)
        s = load(fullfile(cfg.paths.models, [var 'NO' tag '.mat']), var);
        h = quad2fun(s.(var), 0);
    end
end
