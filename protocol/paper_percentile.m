function q=paper_percentile(x,p)
% Linear interpolation, type 7; base MATLAB only, empty input remains NaN.
x=sort(x(isfinite(x)));q=nan(size(p));
if isempty(x),return;end
for k=1:numel(p)
 h=1+(numel(x)-1)*p(k);lo=floor(h);hi=ceil(h);
 q(k)=x(lo)+(h-lo)*(x(hi)-x(lo));
end
end
