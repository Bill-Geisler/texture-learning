function [csout] = cen_sur(ptch,swid,cstype)
%
% center/surround response ratio
% ptch = image patch
% swid = surround  width in pixels
% cstype (1 = ratio, 2, 3, 4 = linear)
%
[sz,~] = size(ptch); dsz = floor(swid/2 + 1);
if cstype == 1
  kcs = ones(swid,swid)/swid^2;
  s = conv2(ptch,kcs,'same');
  cs = ptch./s; % center/surround
  csout = log(max(cs(dsz:sz-dsz+1,dsz:sz-dsz+1),0));
elseif  cstype == 2
  n = swid^2;
  kcs = -ones(swid,swid)/n;
  kcs(dsz,dsz) = kcs(dsz,dsz) + 1;
  ptchs = conv2(ptch,kcs,'same');
  cs = ptchs; % center - surround
  csout = cs(dsz:sz-dsz+1,dsz:sz-dsz+1);  
elseif  cstype == 3
  n = 16; c = 1/8; dsz = 3;
  kcs = -ones(4,4)/n;
  kcs(2:3,2:3) = c;
  ptchs = conv2(ptch,kcs,'same');
  cs = ptchs; % center - surround
  csout = cs(dsz:sz-dsz+1,dsz:sz-dsz+1);  
elseif  cstype == 4
  c = 1/18; dsz = 3;
  kcs = -ones(5,5)/32;
  kcs(2:4,2:4) = c;
  ptchs = conv2(ptch,kcs,'same');
  cs = ptchs; % center - surround
  csout = cs(dsz:sz-dsz+1,dsz:sz-dsz+1);  
end
%
end