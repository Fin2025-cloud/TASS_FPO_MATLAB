function y = clip_value(x, lo, hi)
%CLIP_VALUE 将数值限制在 [lo,hi]。
y = min(max(x, lo), hi);
end
