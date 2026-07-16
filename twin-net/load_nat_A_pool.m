function A_pool = load_nat_A_pool(cfg, down_level)
% LOAD_NAT_A_POOL  Build the pool of achromatic (A) natural images once.
%   A_pool = load_nat_A_pool(cfg, down_level)
%
%   Processes every calibrated natural image (the same list the Bayesian pipeline
%   uses, via list_natural_images(cfg)) into its achromatic (A) channel and returns
%   them as a cell array of uint8 images, one per source image.
%
%   Ingestion goes through the shared vislab.nat_stat_bayes.source_to_lms, so the
%   twin network's natural-image processing (optics ppd/pupil/wavelength, RGB->LMS->A) uses
%   the SAME function and the SAME parameters (from cfg / config.m) as the Bayesian
%   pipeline -- they cannot drift apart. The per-image scaling (255/max_val) matches
%   the Bayesian natural stages; any per-patch scale is removed later by the network
%   input layer, so this A is equivalent to the Bayesian per-patch-normalized A.
%
%   This is the expensive, one-time step for on-the-fly training: it runs at the
%   start of training, after which getTwinBatch_nat_live cuts fresh patches out of
%   this pool cheaply, so patch pairs never repeat and there is nothing to memorize.
%
%   Inputs
%     cfg        - config struct (see config.m): optics, paths, natural sets, max_val.
%     down_level - resolution scale-down (eccentricity factor); 1 = full resolution.
%
%   Output
%     A_pool     - 1 x n_img cell array; A_pool{k} is a uint8 achromatic image.

    if nargin < 2 || isempty(down_level), down_level = 1; end

    files = list_natural_images(cfg);
    prescale = 255 / cfg.natural.max_val;      % 16-bit linear -> 0..255 (matches s1/s2/s3)
    n_img = numel(files);

    A_pool = cell(1, n_img);
    parfor k = 1:n_img
        [~, a] = vislab.nat_stat_bayes.source_to_lms(files{k}, cfg, ...
            struct('prescale', prescale, 'ecc', down_level));
        a = a * 255 / max(a(:));               % 0..255 for compact 8-bit storage
        A_pool{k} = uint8(a);
    end
end
