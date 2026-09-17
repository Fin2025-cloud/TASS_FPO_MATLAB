function N = fractal_noise_2d(ny,nx,seed)
%FRACTAL_NOISE_2D Toolbox-free smooth multiscale noise with fixed seed.
state=rng; cleanup=onCleanup(@()rng(state)); %#ok<NASGU>
rng(seed+7919,'twister');
N=zeros(ny,nx); weight=1; total=0;
for coarse=[5 9 17 33]
    A=randn(coarse,coarse);
    [xc,yc]=meshgrid(linspace(1,nx,coarse),linspace(1,ny,coarse));
    [xq,yq]=meshgrid(1:nx,1:ny);
    layer=interp2(xc,yc,A,xq,yq,'cubic');
    layer=(layer-mean(layer(:)))/(std(layer(:))+eps);
    N=N+weight*layer; total=total+weight; weight=weight*.55;
end
N=N/total; N=(N-mean(N(:)))/(std(N(:))+eps);
end
