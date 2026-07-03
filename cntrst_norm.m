function ptchout = cntrst_norm(ptch,c0,psz)
%
% normalized patch contrast to a given value
%
% c0 = desired rms contrast
%
m = mean(mean(ptch));
ptch = ptch - m;
sd = sqrt(sum(sum(ptch.*ptch))/psz^2);  
ptchout = ptch*c0*m/sd + m;
%
end