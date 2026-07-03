function Reout = Re(ptcha,ptchb,thresh,bb,nb,sdg,nsdg,sdg2,nsdg2,flist)
%
% edge and bar geometry histogram log-likelihood ratios
%
% ptch1 & ptch2 = two patches that are compared
% thres = gradient threshold
% bb = bin bounds for each statistic
% nb = number of bin bounds for each statistic
% sdg = standard deviation of gaussian in pixels for edges
% nsdg = kernel width in standard deviations for edges
% sdg2 = standard deviation of gaussian in pixels for bars
% nsdg2 = kernel width in standard deviations for bars
% estat = type of edge or bar statistics
%   flist(4) = gradient count (1 = yes)
%   flist(5) = gradient magnitude (1 = yes)
%   flist(6) = gradient orientation (1 = yes)
%   flist(7) = gradient product (1 = yes)
%   flist(8) = bar count (1 = yes)
%   flist(9) = bar magnitude (1 = yes)
%   flist(10) = bar orientation (1 = yes)
%   flist(11) = bar product (1 = yes)
[~,fsz] = size(flist);
Reout = zeros(1,fsz);
%
% compute image gradient magnitude and direction
[gma,goa] = imgrad(ptcha,sdg,nsdg); % derivative of Gaussian
[gmb,gob] = imgrad(ptchb,sdg,nsdg);
[gm2a,go2a] = imgrad2(ptcha,sdg2,nsdg2); % second derivative of Gaussian
[gm2b,go2b] = imgrad2(ptchb,sdg2,nsdg2);
[psz,~] = size(gma); [psz2,~] = size(gm2a); 
% [gm1,go1] = imgradient(ptch1); % default is Sobal
% [gm2,go2] = imgradient(ptch2);
%
%***edge elements***
ga = zeros(psz^2,5);
gb = zeros(psz^2,5);
cnt1 = 0; cnt2 = 0; cnt = 0;
for i = 1:psz
  for j = 1:psz
    cnt = cnt + 1;
%      
    if gma(i,j) > thresh % count number of edge elements above a threshold
      cnt1 = cnt1 +1;    % threshold only used for counts, not histograms
    end
    ga(cnt,1) = i;
    ga(cnt,2) = j;
    ga(cnt,3) = gma(i,j);
    ga(cnt,4) = goa(i,j); 
    ga(cnt,5) = gma(i,j)*goa(i,j); % mag x orien
%
    if gmb(i,j) > thresh % count number of edge elements above a threshold
      cnt2 = cnt2 +1;    % threshold only used for counts, not histograms
    end
    gb(cnt,1) = i;
    gb(cnt,2) = j;
    gb(cnt,3) = gmb(i,j);
    gb(cnt,4) = gob(i,j);
    gb(cnt,5) = gmb(i,j)*gob(i,j); % mag x orien
  end
end
%
% edge count likelihood ratio
if flist(4) == 1
  nmx = psz^2;
  n1 = cnt1; n2 = cnt2;
  Lm = n1*log(2*n1/(n1+n2))+(nmx-n1)*log(2*(nmx-n1)/(2*nmx-n1-n2))+...
       n2*log(2*n2/(n1+n2))+(nmx-n2)*log(2*(nmx-n2)/(2*nmx-n1-n2));
  if isnan(Lm) == true
    Lm = 0;
  end
  Reout(4) = Lm;
end
%
% gradient magnitude histogram likelihood ratio
if flist(5) == 1
  N1 = histcounts(ga(1:cnt,3),bb(5,1:nb(5)));
  N2 = histcounts(gb(1:cnt,3),bb(5,1:nb(5)));
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
  Reout(5) = max(snum-sden,0);
end
%
% gradient orientation histogram likelihood ratio
if flist(6) == 1
  N1 = histcounts(ga(1:cnt,4),bb(6,1:nb(6)));
  N2 = histcounts(gb(1:cnt,4),bb(6,1:nb(6)));
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
  Reout(6) = max(snum-sden,0);
end
%
% gradient product histogram likelihood ratio
if flist(7) == 1
  N1 = histcounts(ga(1:cnt,5),bb(7,1:nb(7)));
  N2 = histcounts(gb(1:cnt,5),bb(7,1:nb(7)));  
  ni = size(N1,1); nj = size(N1,2);
  n1 = sum(sum(N1)); n2 = sum(sum(N2));
  snum = 0;
  sden = 0;
  for i = 1:ni
    for j = 1:nj  
      if N1(i,j) > 0
        snum = snum + N1(i,j)*log(N1(i,j)/n1); 
      end
      if N2(i,j) > 0
        snum = snum + N2(i,j)*log(N2(i,j)/n2); 
      end
      if (N1(i,j) + N2(i,j)) > 0
        sden = sden + (N1(i,j)+N2(i,j))*log((N1(i,j)+N2(i,j))/(n1+n2)); 
      end
    end
  end
  Reout(7) = max(snum-sden,0);
end
%***bar elements***
ga = zeros(psz2^2,5);
gb = zeros(psz2^2,5);
cnt1 = 0; cnt2 = 0; cnt = 0;
for i = 1:psz2
  for j = 1:psz2
    cnt = cnt + 1;
%      
    if gm2a(i,j) > thresh % count number of edge elements above a threshold
      cnt1 = cnt1 +1;    % threshold only used for counts, not histograms
    end
    ga(cnt,1) = i;
    ga(cnt,2) = j;
    ga(cnt,3) = gm2a(i,j);
    ga(cnt,4) = go2a(i,j); 
    ga(cnt,5) = gm2a(i,j)*go2a(i,j); % mag x orien
%
    if gmb(i,j) > thresh % count number of edge elements above a threshold
      cnt2 = cnt2 +1;    % threshold only used for counts, not histograms
    end
    gb(cnt,1) = i;
    gb(cnt,2) = j;
    gb(cnt,3) = gm2b(i,j);
    gb(cnt,4) = go2b(i,j);
    gb(cnt,5) = gm2b(i,j)*go2b(i,j); % mag x orien
  end
end
%
% edge count likelihood ratio
if flist(8) == 1
  nmx = psz^2;
  n1 = cnt1; n2 = cnt2;
  Lm = n1*log(2*n1/(n1+n2))+(nmx-n1)*log(2*(nmx-n1)/(2*nmx-n1-n2))+...
       n2*log(2*n2/(n1+n2))+(nmx-n2)*log(2*(nmx-n2)/(2*nmx-n1-n2));
  if isnan(Lm) == true
    Lm = 0;
  end
  Reout(8) = Lm;
end
%
% gradient magnitude histogram likelihood ratio 
%  N1 = histcounts(ga(1:cnt,5),bb(3,1:nb(3)));
if flist(9) == 1
  N1 = histcounts(ga(1:cnt,3),bb(9,1:nb(9)));
  N2 = histcounts(gb(1:cnt,3),bb(9,1:nb(9)));
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
  Reout(9) = max(snum-sden,0);
end
%
% gradient orientation histogram likelihood ratio
if flist(10) == 1
  N1 = histcounts(ga(1:cnt,4),bb(10,1:nb(10)));
  N2 = histcounts(gb(1:cnt,4),bb(10,1:nb(10)));
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
  Reout(10) = max(snum-sden,0);
end
%
% gradient product histogram likelihood ratio
if flist(11) == 1
  N1 = histcounts(ga(1:cnt,5),bb(11,1:nb(11)));
  N2 = histcounts(gb(1:cnt,5),bb(11,1:nb(11)));  
  ni = size(N1,1); nj = size(N1,2);
  n1 = sum(sum(N1)); n2 = sum(sum(N2));
  snum = 0;
  sden = 0;
  for i = 1:ni
    for j = 1:nj  
      if N1(i,j) > 0
        snum = snum + N1(i,j)*log(N1(i,j)/n1); 
      end
      if N2(i,j) > 0
        snum = snum + N2(i,j)*log(N2(i,j)/n2); 
      end
      if (N1(i,j) + N2(i,j)) > 0
        sden = sden + (N1(i,j)+N2(i,j))*log((N1(i,j)+N2(i,j))/(n1+n2)); 
      end
    end
  end
  Reout(11) = max(snum-sden,0);
end
%
end

