function s23_learn_priors_and_pairs(cfg, ecc, autosave)
% S23_LEARN_PRIORS_AND_PAIRS  Learn natural feature priors AND build near/far patch
%   pairs in a single pass over the natural images (merges former stages 2 and 3).
%   s23_learn_priors_and_pairs(cfg, ecc)
%   s23_learn_priors_and_pairs(cfg, ecc, autosave)
%
%   autosave (optional) - true/false to save/skip without asking (used by run_demo,
%   which confirms once up front); omit to be asked interactively.
%
%   For each calibrated natural image -- loaded ONCE (optics, RGB->LMS, downsampled
%   to eccentricity ecc) -- this:
%     * samples isolated patches and accumulates the low-level feature values, then
%       forms the marginal CDFs (the paper's natural priors, Fig. 5), saved to
%       data/models/<prior_filename(cfg,ecc)>; and
%     * samples reference patches and forms near/far training pairs (proximity proxy),
%       saved to data/stimuli/patch_pairs_ecc<ecc>.mat.
%   Priors are eccentricity-dependent (ecc applies blur + downsampling, which changes
%   the feature statistics), so they are stored per ecc, computed from the same ecc
%   image as the pairs -- one image load feeds both.
%
%   Run `setup` first; run stage 1 (LMS->ABR rotation) before. ecc = 1, 2, 4, 8.

    n_bins = 16000;                      % prior CDF resolution
    maxval = cfg.natural.max_val;
    psz    = cfg.patch.size / ecc;       % patch size at this eccentricity

    if cfg.optics.apply, xform_file = 'cps_lms2abr_otf.mat'; else, xform_file = 'cps_lms2abr.mat'; end
    s = load(fullfile(cfg.paths.data_root, xform_file), 'coeff');   % shared lab LMS->ABR transform
    coeff = s.coeff;

    files  = list_natural_images(cfg);
    nprior = ceil(cfg.natural.target_isolated_patches   / numel(files));  % isolated patches / image
    npair  = ceil(cfg.natural.target_nearfar_references / numel(files));  % near/far references / image

    % One independent image per iteration -> parfor (runs serially without the
    % Parallel Computing Toolbox). Each image is loaded ONCE and feeds both the
    % priors (isolated patches) and the near/far pairs.
    Sc      = cell(1, numel(files));
    ptchn_c = cell(1, numel(files));
    ptchf_c = cell(1, numel(files));
    parfor f = 1:numel(files)
        [~, fname, fext] = fileparts(files{f});
        fprintf('sampling %s\n', [fname, fext]);
        img = vislab.nat_stat_bayes.source_to_lms(files{f}, cfg, struct('prescale', 255/maxval, 'ecc', ecc));
        Sc{f} = sample_prior_features(img, nprior, psz, cfg, coeff);
        [ptchn_c{f}, ptchf_c{f}] = sample_nearfar_pairs(img, npair, psz, cfg);
    end

    P = finalize_priors([Sc{:}], n_bins, coeff);   % marginal CDFs (the natural priors)
    ptchn = cat(4, ptchn_c{:});
    ptchf = cat(4, ptchf_c{:});
    pcnt  = size(ptchn, 4);

    prior_path = fullfile(cfg.paths.models, prior_filename(cfg, ecc));
    if ~isfolder(cfg.paths.stimuli), mkdir(cfg.paths.stimuli); end
    pairs_path = fullfile(cfg.paths.stimuli, sprintf('patch_pairs_ecc%d.mat', ecc));

    if nargin < 3 || isempty(autosave)
        reply = input(sprintf(['s23: Save feature priors (%s) and near/far pairs ' ...
            '(patch_pairs_ecc%d.mat)? (y/n): '], prior_filename(cfg, ecc), ecc), 's');
        do_save = strcmpi(reply, 'y');
    else
        do_save = autosave;
    end
    if do_save
        save(prior_path, '-struct', 'P');                    % fields ea,Na,...,coeff (see finalize_priors)
        save(pairs_path, 'ptchn', 'ptchf', 'pcnt');
        fprintf('s23: saved priors to %s and %d near/far pairs (ecc %d) to %s\n', ...
            prior_path, pcnt, ecc, pairs_path);
    else
        fprintf('s23: skipped saving priors and patch pairs.\n');
    end
end
