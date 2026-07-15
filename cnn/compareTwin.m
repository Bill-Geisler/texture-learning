function Y = compareTwin(S1, S2)
% compareTwin  Two-patch comparison vector for the twin network.
%   Y = compareTwin(S1,S2) takes two per-patch stat structs from poolStats and
%   returns the dimensionless comparison features fed to the fully connected
%   layer, as an "SSCB" dlarray [1 1 D B]. Per channel k:
%     d'      = |m1_k - m2_k| / pooled_sd_k   (mean separation vs. noise)
%     stdDiff = |s1_k - s2_k| / pooled_sd_k   (contrast/spread difference)
%   plus the elementwise |corr1 - corr2| of the channel-correlation upper
%   triangle (co-occurrence difference). pooled_sd = sqrt((s1^2 + s2^2)/2).
%   All three blocks are dimensionless and per-sample stable, so the fc layer
%   sees features on a common scale by construction.
%   With C = 32, D = 2C + C(C-1)/2 = 64 + 496 = 560.

    pooledSd = sqrt((S1.s.^2 + S2.s.^2) / 2 + 1e-6);   % [1 1 C B]
    dprime   = abs(S1.m - S2.m) ./ pooledSd;           % [1 1 C B]
    stdDiff  = abs(S1.s - S2.s) ./ pooledSd;           % [1 1 C B]
    corrDiff = abs(S1.corr - S2.corr);                 % [1 1 C(C-1)/2 B]

    Y = cat(3, dprime, stdDiff, corrDiff);             % [1 1 D B]
end
