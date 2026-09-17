function D = polyline_distance(X,Y,P)
%POLYLINE_DISTANCE Minimum Euclidean distance from grid points to a polyline.
D=inf(size(X));
for k=1:size(P,1)-1
    a=P(k,:); b=P(k+1,:); ab=b-a;
    t=((X-a(1))*ab(1)+(Y-a(2))*ab(2))/(sum(ab.^2)+eps);
    t=max(0,min(1,t));
    px=a(1)+t*ab(1); py=a(2)+t*ab(2);
    D=min(D,hypot(X-px,Y-py));
end
end
