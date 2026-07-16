function plot_stage6(out, method)
% PLOT_STAGE6  Show the same/different self-supervised discrimination accuracy
%   on GTR patches across the grouping-criterion / mutual-similarity-weight grid.
    figure('Name', 'Stage 6: Same/Different Self-Supervised Performance on GTR Patches', 'Position', [400 400 600 500]);
    imagesc(out.wm, out.gc, out.pcav); axis xy;
    cb = colorbar; cb.Label.String = 'Same-Different Accuracy';
    xlabel('Mutual Similarity Weight');
    ylabel('Grouping Criterion');

    m_str = method;
    if strcmp(method, 'bc'), m_str = 'Border+Content'; end

    d_str = sprintf('Dataset %d', out.itype);
    if out.itype == 3, d_str = 'Brodatz'; end

    title(sprintf('Same-Diff Accuracy on GTR Patches (Method: %s, Texture set: %s)', m_str, d_str));
end
