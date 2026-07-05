function [imgr, imgg, imgb, nimg] = load_texture_images(cfg, itype, ecc)
% LOAD_TEXTURE_IMAGES  Load and preprocess the texture-source sheets for a GTR type.
%   [imgr, imgg, imgb, nimg] = load_texture_images(cfg, itype, ecc)
%
%   Loads the texture sheets for the requested itype, applies eye optics, converts
%   to LMS, and downsamples to eccentricity `ecc`. Returns the three LMS
%   channel stacks (each sz x sz x nimg). Shared by pipeline stages s6 and s7.
%
%   itype: 1 Pertex | 2 Fabric | 3 Brodatz | 4 Brodatz+Fabric | 5 VisTex | 6 McGill.
%
%   Texture sheets are read from cfg.paths.textures/<dataset>/ . Currently
%   supported: Fabric (fabric/FC*.png), Brodatz (brodatz/B*.gif), and their union.
%   Pertex/VisTex/McGill are not yet wired up (see USER_TODO.md / QUESTIONS_FOR_GEISLER.md).

    sz = cfg.patch.image_size / ecc;
    tex = cfg.paths.textures;

    switch itype
        case 2                                   % Fabric
            nimg = 60;
            files = arrayfun(@(k) fullfile(tex, 'fabric',  sprintf('FC%d.png', k)), 1:nimg, 'uni', 0);
            gray  = false(1, nimg);
            gamma = true(1, nimg);
        case 3                                   % Brodatz
            nimg = 60;
            files = arrayfun(@(k) fullfile(tex, 'brodatz', sprintf('B%d.gif', k)),  1:nimg, 'uni', 0);
            gray  = true(1, nimg);
            gamma = false(1, nimg);
        case 4                                   % Brodatz + Fabric
            nimg = 120;
            files = [ arrayfun(@(k) fullfile(tex, 'brodatz', sprintf('B%d.gif', k)),  1:60, 'uni', 0), ...
                      arrayfun(@(k) fullfile(tex, 'fabric',  sprintf('FC%d.png', k)), 1:60, 'uni', 0) ];
            gray  = [true(1,60),  false(1,60)];
            gamma = [false(1,60), true(1,60)];
        case 1
            error('load_texture_images:pertexPending', ...
                ['Pertex (itype 1) loading is unresolved: the code expects P<n>.mat (grayscale dimg) ', ...
                 'but global_data/textures/pertex has PNGs. See QUESTIONS_FOR_GEISLER.md (D1).']);
        case {5, 6}
            name = 'VisTex'; if itype == 6, name = 'McGill'; end
            error('load_texture_images:datasetMissing', ...
                ['%s (itype %d) textures are not in global_data/textures. Add them per USER_TODO.md.'], name, itype);
        otherwise
            error('load_texture_images:badItype', 'itype must be 1-6, got %g.', itype);
    end

    imgr = zeros(sz, sz, nimg);
    imgg = zeros(sz, sz, nimg);
    imgb = zeros(sz, sz, nimg);
    for k = 1:nimg
        raw = double(imread(files{k}));
        if gray(k)
            cimg = repmat(raw(:, :, 1), 1, 1, 3);
        else
            cimg = raw;
        end
        if gamma(k)
            cimg = vislib.gamma_expand(cimg);            % linearize gamma-compressed sheets (Fabric)
        end
        if cfg.optics.apply
            cimg = vislib.otf_filter(cimg, cfg.optics.ppd, cfg.optics.pupil_diameter, cfg.optics.wavelength);
        end
        cimg = vislib.rgb2lms(cimg, cfg.color.rgb_to_lms);
        cimg = vislib.downsample(cimg, ecc);
        imgr(:, :, k) = cimg(:, :, 1);
        imgg(:, :, k) = cimg(:, :, 2);
        imgb(:, :, k) = cimg(:, :, 3);
    end
end
