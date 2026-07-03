function Rhout = Rh(ptch1,ptch2,psz,bb,nb,flist)
%
% color histograms: log likelihood ratio of different vs same
% assuming multinomial probability distributions
%
% ptch1, ptch2 = two patches being compared
% psz = patch width in pixels
% bb = bin bounds for three channels
% nb = number of bin bounds for three channels
% hstat = color stats to compute (1 = compute)
%   1 = a channel
%   2 = b channel
%   3 = r channel
%   12 = a channel center/surround 
%   13 = a channel center - surround small
%   14 = a channel center - surround large
%
[~,fsz] = size(flist);
Rhout = zeros(1,fsz);
npix = psz^2;
abr1 = reshape(ptch1,[],3);
abr2 = reshape(ptch2,[],3);
%
% pixel histograms*****************
if flist(1) == 1
  N1 = histcounts(abr1(1:npix,1),bb(1,1:nb(1)));
  N2 = histcounts(abr2(1:npix,1),bb(1,1:nb(1)));
  n = size(N1,2); n1 = sum(N1); n2 = sum(N2);
  snum = 0;
  sden = 0;
  for i = 1:n
    if N1(i) > 0
      snum = snum + N1(i)*log(N1(i)/n1); 
    end
    if N2(i) > 0
      snum = snum + N2(i)*log(N2(i)/n2); 
    end
    if (N1(i) + N2(i)) > 0
      sden = sden + (N1(i)+N2(i))*log((N1(i)+N2(i))/(n1+n2)); 
    end
  end
  Rhout(1) = max(snum-sden,0);
end
%
if flist(2) == 1
  N1 = histcounts(abr1(1:npix,2),bb(2,1:nb(2)));
  N2 = histcounts(abr2(1:npix,2),bb(2,1:nb(2)));
  n = size(N1,2); n1 = sum(N1); n2 = sum(N2);
  snum = 0;
  sden = 0;
  for i = 1:n
    if N1(i) > 0
      snum = snum + N1(i)*log(N1(i)/n1); 
    end
    if N2(i) > 0
      snum = snum + N2(i)*log(N2(i)/n2); 
    end
    if (N1(i) + N2(i)) > 0
      sden = sden + (N1(i)+N2(i))*log((N1(i)+N2(i))/(n1+n2)); 
    end
  end
  Rhout(2) = max(snum-sden,0);
end
%
if flist(3) == 1
  N1 = histcounts(abr1(1:npix,3),bb(3,1:nb(3)));
  N2 = histcounts(abr2(1:npix,3),bb(3,1:nb(3)));
  n = size(N1,2); n1 = sum(N1); n2 = sum(N2);
  snum = 0;
  sden = 0;
  for i = 1:n
    if N1(i) > 0
      snum = snum + N1(i)*log(N1(i)/n1); 
    end
    if N2(i) > 0
      snum = snum + N2(i)*log(N2(i)/n2); 
    end
    if (N1(i) + N2(i)) > 0
      sden = sden + (N1(i)+N2(i))*log((N1(i)+N2(i))/(n1+n2)); 
    end
  end
  Rhout(3) = max(snum-sden,0);
end
%
% center-surround histograms*************
if flist(12) == 1
  swid = 3;
  cstype = 1;
  c0 = 0.25;
  ptch1a = cntrst_norm(ptch1(:,:,1),c0,psz);
  ptch2a = cntrst_norm(ptch2(:,:,1),c0,psz);                    
  cs1 = cen_sur(ptch1a,swid,cstype);
  cs2 = cen_sur(ptch2a,swid,cstype);
  npix = (psz-2)^2;
  csr1 = reshape(cs1,[],1);
  csr2 = reshape(cs2,[],1);
  %
  N1 = histcounts(csr1(1:npix,1),bb(12,1:nb(12)));
  N2 = histcounts(csr2(1:npix,1),bb(12,1:nb(12)));
  n = size(N1,2); n1 = sum(N1); n2 = sum(N2);
  snum = 0;
  sden = 0;
  for i = 1:n
    if N1(i) > 0
      snum = snum + N1(i)*log(N1(i)/n1); 
    end
    if N2(i) > 0
      snum = snum + N2(i)*log(N2(i)/n2); 
    end
    if (N1(i) + N2(i)) > 0
      sden = sden + (N1(i)+N2(i))*log((N1(i)+N2(i))/(n1+n2)); 
    end
  end
  Rhout(12) = max(snum-sden,0);
end
%
if flist(13) == 1
  swid = 3;
  cstype = 2;
  c0 = 0.25;
  ptch1a = cntrst_norm(ptch1(:,:,1),c0,psz);
  ptch2a = cntrst_norm(ptch2(:,:,1),c0,psz);                    
  cs1 = cen_sur(ptch1a,swid,cstype);
  cs2 = cen_sur(ptch2a,swid,cstype);
  npix = (psz-2)^2;
  csr1 = reshape(cs1,[],1);
  csr2 = reshape(cs2,[],1);
  %
  N1 = histcounts(csr1(1:npix,1),bb(13,1:nb(13)));
  N2 = histcounts(csr2(1:npix,1),bb(13,1:nb(13)));
  n = size(N1,2); n1 = sum(N1); n2 = sum(N2);
  snum = 0;
  sden = 0;
  for i = 1:n
    if N1(i) > 0
      snum = snum + N1(i)*log(N1(i)/n1); 
    end
    if N2(i) > 0
      snum = snum + N2(i)*log(N2(i)/n2); 
    end
    if (N1(i) + N2(i)) > 0
      sden = sden + (N1(i)+N2(i))*log((N1(i)+N2(i))/(n1+n2)); 
    end
  end
  Rhout(13) = max(snum-sden,0);
end
%
if flist(14) == 1
  swid = 5;
  cstype = 4;
  c0 = 0.25;
  ptch1a = cntrst_norm(ptch1(:,:,1),c0,psz);
  ptch2a = cntrst_norm(ptch2(:,:,1),c0,psz);                    
  cs1 = cen_sur(ptch1a,swid,cstype);
  cs2 = cen_sur(ptch2a,swid,cstype);
  npix = (psz-4)^2;
  csr1 = reshape(cs1,[],1);
  csr2 = reshape(cs2,[],1);
  %
  N1 = histcounts(csr1(1:npix,1),bb(14,1:nb(14)));
  N2 = histcounts(csr2(1:npix,1),bb(14,1:nb(14)));
  n = size(N1,2); n1 = sum(N1); n2 = sum(N2);
  snum = 0;
  sden = 0;
  for i = 1:n
    if N1(i) > 0
      snum = snum + N1(i)*log(N1(i)/n1); 
    end
    if N2(i) > 0
      snum = snum + N2(i)*log(N2(i)/n2); 
    end
    if (N1(i) + N2(i)) > 0
      sden = sden + (N1(i)+N2(i))*log((N1(i)+N2(i))/(n1+n2)); 
    end
  end
  Rhout(14) = max(snum-sden,0);
end
%
end
%
% Hi Bill,
% here's a quick demo of 3d rgb histograms from images.
% Matlab's 'Home' tab > Add-Ons > Get Add-Ons > Search 'N-dimensional histogram'.
% Click the one by Bruno Luong with 11.4K downloads. Then click Add to Matlab.
% Run the code attached to this email.
% Abhranil Das

