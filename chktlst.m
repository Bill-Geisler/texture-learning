function [chkflg,xout,yout] = chktlst(dprm,x,y,map,np)
%
% check the list of patches to see if side dprm of the patch at x,y
% is untaken
%
% dprm = the side of the patch to check (1=xup, 2=yup, 3=xdown, 4=ydown)
% x,y = coordinates of the patch being checked
% map = map of locations, 0 if unfilled
% np = size of map (np x np)
%
% chkflg = 1 if the location is available, else 0
% xout,yout = new location
%
xout = x; yout = y; chkflg = 0;
if dprm == 1
  if x < np
    if map(x+1,y) == 0
     chkflg = 1;
     xout = x + 1; yout = y;
    end
  else
    chkflg = 0;  
  end
elseif dprm == 2
  if y < np
    if map(x,y+1) == 0
     chkflg = 1;
     xout = x; yout = y+1;
    end
  else
    chkflg = 0;  
  end
elseif dprm == 3
  if x > 1
    if map(x-1,y) == 0
     chkflg = 1;
     xout = x - 1; yout = y;
    end
  else
    chkflg = 0;  
  end
else
  if y > 1
    if map(x,y-1) == 0
     chkflg = 1;
     xout = x; yout = y-1;
    end
  else
    chkflg = 0;  
  end
%
end