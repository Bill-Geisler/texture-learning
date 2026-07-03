function [ptchout,mnv] = ptch_norm(ptch,m0,c0,ntype,ncolr)
%
% normalize patch
% m0 = desired mean
% c0 = desired contrast
% ntype = type of normalization: 0 = none 1 = mean, 2 = mean and contrast
%                                3 = average mean
% ncolr = number of color channels (1 or 3)
%
mnv = zeros(3,1);
if ncolr == 1
  if ntype == 0
    ptchout = ptch;                          % no normalization
  elseif ntype == 1
    mnv(1) = mean(mean(ptch));               % mean    
    ptchout = ptch*m0/mnv(1);                % normalize to mean of m0
  elseif ntype == 2 
    sz = size(ptch); npix = sz(1)*sz(2);
    mnv(1) = mean(mean(ptch));               % mean
    m = mnv(1);
    ptch = ptch*m0/m;
    sd = sqrt(sum(sum((ptch-m0).^2))/npix);  % standard deviation
    ptch = c0*m0*(ptch-m0)/sd + m0;          % normalize to contrast of c0
    ptchout(:,:,1) = max(ptch,0);            % normalized to mean of m0
  end
elseif ncolr == 3
  if ntype == 0
    ptchout = ptch;                          % no normalization
  elseif ntype == 1
    mnv(1) = mean(mean(ptch(:,:,1)));        % mean    
    ptchout(:,:,1) = ptch(:,:,1)*m0/mnv(1);  % normalize to mean of m0    
%
    mnv(2) = mean(mean(ptch(:,:,2)));        % mean    
    ptchout(:,:,2) = ptch(:,:,2)*m0/mnv(2);  % normalize to mean of m0    
%
    mnv(3) = mean(mean(ptch(:,:,3)));        % mean    
    ptchout(:,:,3) = ptch(:,:,3)*m0/mnv(3);  % normalize to mean of m0
  elseif ntype == 2
    ptch0 = ptch(:,:,1);
    sz = size(ptch0); npix = sz(1)*sz(2);
    mnv(1) = mean(mean(ptch0));              % mean
    m = mnv(1);
    ptch0 = ptch0*m0/m;
    sd = sqrt(sum(sum((ptch0-m0).^2))/npix); % standard deviation
    ptch0 = c0*m0*(ptch0-m0)/sd + m0;        % normalize to contrast of c0
    ptchout(:,:,1) = max(ptch0,0);           % normalized to mean of m0
%
    ptch0 = ptch(:,:,2);
    mnv(2) = mean(mean(ptch0));              % mean
    m = mnv(2);
    ptch0 = ptch0*m0/m;
    sd = sqrt(sum(sum((ptch0-m0).^2))/npix); % standard deviation
    ptch0 = c0*m0*(ptch0-m0)/sd + m0;        % normalize to contrast of c0
    ptchout(:,:,2) = max(ptch0,0);           % normalized to mean of m0    
%
    ptch0 = ptch(:,:,3);
    mnv(3) = mean(mean(ptch0));              % mean
    m = mnv(3);
    ptch0 = ptch0*m0/m;
    sd = sqrt(sum(sum((ptch0-m0).^2))/npix); % standard deviation
    ptch0 = c0*m0*(ptch0-m0)/sd + m0;        % normalize to contrast of c0
    ptchout(:,:,3) = max(ptch0,0);           % additive-normalized mean of m0
  elseif ntype == 3
    mnv(1) = mean(mean(ptch(:,:,1)));        % mean    
    mnv(2) = mean(mean(ptch(:,:,2)));        % mean    
    mnv(3) = mean(mean(ptch(:,:,3)));        % mean    
    mn = mean(mnv);                         % scale to average mean
    % mn = mnv(1);                          % scale to achromatic mean
    ptchout = ptch*m0/mn;
  elseif ntype == 4
  % same as ntype = 3, but reverse the contrast
    mnv(1) = mean(mean(ptch(:,:,1)));        % mean    
    mnv(2) = mean(mean(ptch(:,:,2)));        % mean    
    mnv(3) = mean(mean(ptch(:,:,3)));        % mean    
    mn = mean(mnv);                         % scale to average mean
    ptchout = ptch*m0/mn;
    ptchout = -(ptchout-m0) + m0;
  end
end







