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
%   Texture sheets are read from cfg.paths.textures/<dataset>/ . Supported:
%   Pertex (pertex/<nnn>.png, grayscale), Brodatz (brodatz/B*.gif, grayscale),
%   Fabric (fabric/FC*.png, RGB gamma-compressed), their union, VisTex
%   (vistex/VS*.png) and McGill (mcgill/M*.png) -- both RGB gamma-compressed.
%   Pertex/VisTex/McGill use Bill's fixed 60-image selections.
%
%   Pertex source PNGs are 1024x1024; they are resized to cfg.patch.image_size
%   (640) on load, reproducing byte-for-byte the P<n>.mat sheets Bill distributed
%   (imresize by 640/1024, round, uint8 -- verified identical for all images).
%   The .mat sheets are therefore no longer needed; only the source PNGs are kept.

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
        case 5                                   % VisTex (Bill's vindx 60-image selection; RGB, gamma-compressed)
            vindx = [1 3 5 9 10 14 18 19 36 39 42 43 46 48 50 52 53 56 58 60 ...
                     63 64 66 68 69 73 77 79 80 81 82 83 84 85 87 88 89 90 91 92 93 ...
                     95 97 98 100 103 104 105 120 124 127 128 129 130 143 144 153 158 163 166];
            nimg  = numel(vindx);
            files = arrayfun(@(n) fullfile(tex, 'vistex', sprintf('VS%d.png', n)), vindx, 'uni', 0);
            gray  = false(1, nimg);
            gamma = true(1, nimg);
        case 6                                   % McGill (Bill's mindx 60-image selection; RGB, gamma-compressed)
            mindx = [1 6 12 14 15 16 20 22 24 25 26 31 32 34 35 37 40 41 42 ...
                     43 44 45 46 48 49 52 53 55 57 58 61 62 63 64 66 68 69 73 74 75 ...
                     77 78 80 81 82 84 85 86 88 90 97 100 105 107 110 111 114 117 120 125];
            nimg  = numel(mindx);
            files = arrayfun(@(n) fullfile(tex, 'mcgill', sprintf('M%d.png', n)), mindx, 'uni', 0);
            gray  = false(1, nimg);
            gamma = true(1, nimg);
        case 1                                   % Pertex (Bill's fixed 60: source images 271-330; grayscale, no gamma)
            del   = 270;                         % Bill's offset: the PerTex sheets are images 271..330
            nimg  = 60;
            files = arrayfun(@(k) fullfile(tex, 'pertex', sprintf('%03d.png', k + del)), 1:nimg, 'uni', 0);
            gray  = true(1, nimg);
            gamma = false(1, nimg);
        otherwise
            error('load_texture_images:badItype', 'itype must be 1-6, got %g.', itype);
    end

    resize_pertex = (itype == 1);            % PerTex source PNGs are 1024x1024 (all other datasets already 640)

    imgr = zeros(sz, sz, nimg);
    imgg = zeros(sz, sz, nimg);
    imgb = zeros(sz, sz, nimg);
    for k = 1:nimg
        raw = double(imread(files{k}));
        if resize_pertex                         % reproduce Bill's P<n>.mat sheet: 1024 -> 640, round, uint8
            raw = double(uint8(round(imresize(raw, cfg.patch.image_size / 1024))));
        end
        if gray(k)
            cimg = repmat(raw(:, :, 1), 1, 1, 3);
        else
            cimg = raw;
        end
        if gamma(k)
            cimg = vislab.lib.gamma_expand(cimg);            % linearize gamma-compressed sheets (Fabric)
        end
        if cfg.optics.apply
            cimg = vislab.lib.otf_filter(cimg, cfg.optics.ppd, cfg.optics.pupil_diameter, cfg.optics.wavelength);
        end
        cimg = vislab.lib.rgb2lms(cimg);              % shared lab RGB->LMS calibration
        cimg = vislab.lib.downsample(cimg, ecc);
        imgr(:, :, k) = cimg(:, :, 1);
        imgg(:, :, k) = cimg(:, :, 2);
        imgb(:, :, k) = cimg(:, :, 3);
    end
end
