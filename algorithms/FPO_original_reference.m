function [Rabbit_Energy,Rabbit_Location,CNVG,log] = FPO_original_reference(N,MaxIter,lb,ub,dim,fobj,opts)
%FPO_ORIGINAL_REFERENCE 按公开论文公式重构的原始 FPO 参考实现。
%
% 重要真实性声明
% -------------------------------------------------------------------------
% 1. 本文件用于公式核对、单元测试和理解原始算法，不应覆盖用户已经验证过
%    的作者代码或既有 FPO.m；
% 2. 论文中个别开发阶段公式/伪代码存在符号和候选选择描述不完全一致，
%    本实现采用“论文公式 + 贪婪选择”的透明解释，并在注释中明确；
% 3. 若作者官方源代码可获得，应把官方代码作为原始 FPO 基线，本文件仅作
%    对照；
% 4. 原论文按 MaxIter 停止。若用于与多候选算法公平比较，必须另外统计 FE，
%    不可仅比较相同迭代数。
%
% 典型调用：
%   [fbest,xbest,curve,log] = FPO_original_reference(30,500,-100,100,30,@sphere,struct('seed',1));

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if nargin<7, opts=struct(); end
% [逐行说明] 计算或更新 `seed`，供后续算法、评价或日志步骤使用。
seed=safe_field(opts,'seed',1);
% [逐行说明] 计算或更新 `maxFEs`，供后续算法、评价或日志步骤使用。
maxFEs=safe_field(opts,'MaxFEs',inf);
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
rng(seed,'twister');

% [逐行说明] 计算或更新 `lb`，供后续算法、评价或日志步骤使用。
lb=expand_bound(lb,dim); ub=expand_bound(ub,dim);
% [逐行说明] 计算或更新 `X`，供后续算法、评价或日志步骤使用。
X=tent_initialization(N,dim,lb,ub);
% [逐行说明] 计算或更新 `HistoricalBest`，供后续算法、评价或日志步骤使用。
HistoricalBest=X;
% [逐行说明] 计算或更新 `HistoricalBestScore`，供后续算法、评价或日志步骤使用。
HistoricalBestScore=inf(N,1);
% [逐行说明] 计算或更新 `Rabbit_Location`，供后续算法、评价或日志步骤使用。
Rabbit_Location=zeros(1,dim);
% [逐行说明] 计算或更新 `Rabbit_Energy`，供后续算法、评价或日志步骤使用。
Rabbit_Energy=inf;
% [逐行说明] 计算或更新 `CNVG`，供后续算法、评价或日志步骤使用。
CNVG=nan(MaxIter,1);
% [逐行说明] 计算或更新 `FEs`，供后续算法、评价或日志步骤使用。
FEs=0;
% [逐行说明] 计算或更新 `strategyCounts`，供后续算法、评价或日志步骤使用。
strategyCounts=zeros(1,7);

% [逐行说明] 计算或更新 `alpha`，供后续算法、评价或日志步骤使用。
alpha=safe_field(opts,'alpha',0.3);
% [逐行说明] 计算或更新 `beta`，供后续算法、评价或日志步骤使用。
beta=safe_field(opts,'beta',0.2);
% [逐行说明] 计算或更新 `pElite`，供后续算法、评价或日志步骤使用。
pElite=safe_field(opts,'pElite',0.5);

% [逐行说明] 开始按给定索引范围逐项执行循环。
for t=1:MaxIter
    % 先评价当前种群并更新个体历史最优和全局最优。
    fitness=inf(N,1);
    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for i=1:N
        % [逐行说明] 计算或更新 `X(i,:)`，供后续算法、评价或日志步骤使用。
        X(i,:)=min(max(X(i,:),lb),ub); % 原始基线通常使用边界截断
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if FEs>=maxFEs, break; end
        % [逐行说明] 计算或更新 `fitness(i)`，供后续算法、评价或日志步骤使用。
        fitness(i)=fobj(X(i,:));
        % [逐行说明] 计算或更新 `FEs`，供后续算法、评价或日志步骤使用。
        FEs=FEs+1;
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if fitness(i)<HistoricalBestScore(i)
            % [逐行说明] 计算或更新 `HistoricalBestScore(i)`，供后续算法、评价或日志步骤使用。
            HistoricalBestScore(i)=fitness(i);
            % [逐行说明] 计算或更新 `HistoricalBest(i,:)`，供后续算法、评价或日志步骤使用。
            HistoricalBest(i,:)=X(i,:);
        end
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if fitness(i)<Rabbit_Energy
            % [逐行说明] 计算或更新 `Rabbit_Energy`，供后续算法、评价或日志步骤使用。
            Rabbit_Energy=fitness(i);
            % [逐行说明] 计算或更新 `Rabbit_Location`，供后续算法、评价或日志步骤使用。
            Rabbit_Location=X(i,:);
        end
    end
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if FEs>=maxFEs
        % [逐行说明] 计算或更新 `CNVG(t:end)`，供后续算法、评价或日志步骤使用。
        CNVG(t:end)=Rabbit_Energy;
        % [逐行说明] 提前结束当前循环。
        break;
    end

    % [逐行说明] 计算或更新 `progress`，供后续算法、评价或日志步骤使用。
    progress=t/MaxIter;
    % [逐行说明] 计算或更新 `E1`，供后续算法、评价或日志步骤使用。
    E1=2*(1-progress^2);
    % [逐行说明] 计算或更新 `H`，供后续算法、评价或日志步骤使用。
    H=0.9-0.8*progress;
    % [逐行说明] 计算或更新 `meanX`，供后续算法、评价或日志步骤使用。
    meanX=mean(X,1);
    % [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
    [~,eliteOrder]=sort(HistoricalBestScore,'ascend');
    % [逐行说明] 计算或更新 `kElite`，供后续算法、评价或日志步骤使用。
    kElite=max(1,ceil(0.10*N));
    % [逐行说明] 计算或更新 `eliteMean`，供后续算法、评价或日志步骤使用。
    eliteMean=mean(HistoricalBest(eliteOrder(1:kElite),:),1);

    % [逐行说明] 开始按给定索引范围逐项执行循环。
    for i=1:N
        % [逐行说明] 计算或更新 `E0`，供后续算法、评价或日志步骤使用。
        E0=2*(rand-0.5);
        % [逐行说明] 计算或更新 `E`，供后续算法、评价或日志步骤使用。
        E=E1*E0;
        % [逐行说明] 计算或更新 `r`，供后续算法、评价或日志步骤使用。
        r=rand;
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if abs(E)>=1
            % [逐行说明] 计算或更新 `q`，供后续算法、评价或日志步骤使用。
            q=rand;
            % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
            if q<0.33
                % [逐行说明] 计算或更新 `strategyCounts(1)`，供后续算法、评价或日志步骤使用。
                strategyCounts(1)=strategyCounts(1)+1;
                % [逐行说明] 计算或更新 `ridx`，供后续算法、评价或日志步骤使用。
                ridx=randi(N); Xrand=X(ridx,:);
                % [逐行说明] 计算或更新 `r1`，供后续算法、评价或日志步骤使用。
                r1=rand; r2=rand;
                % [逐行说明] 计算或更新 `Xnew`，供后续算法、评价或日志步骤使用。
                Xnew=Xrand-r1.*abs(Xrand-2*r2.*X(i,:));
            % [逐行说明] 在前一条件不成立时继续判断当前条件。
            elseif q<0.66
                % [逐行说明] 计算或更新 `strategyCounts(2)`，供后续算法、评价或日志步骤使用。
                strategyCounts(2)=strategyCounts(2)+1;
                % [逐行说明] 计算或更新 `rr`，供后续算法、评价或日志步骤使用。
                rr=rand;
                % [逐行说明] 计算或更新 `Xnew`，供后续算法、评价或日志步骤使用。
                Xnew=(Rabbit_Location-meanX)-rr.*((ub-lb).*rr+lb);
            % [逐行说明] 处理前述条件均不成立的情况。
            else
                % [逐行说明] 计算或更新 `strategyCounts(3)`，供后续算法、评价或日志步骤使用。
                strategyCounts(3)=strategyCounts(3)+1;
                % [逐行说明] 计算或更新 `rr`，供后续算法、评价或日志步骤使用。
                rr=rand; c=4*rr*(1-rr);
                % [逐行说明] 计算或更新 `ridx`，供后续算法、评价或日志步骤使用。
                ridx=randi(N);
                % [逐行说明] 计算或更新 `Xnew`，供后续算法、评价或日志步骤使用。
                Xnew=X(i,:)+c.*(HistoricalBest(ridx,:)-X(i,:))+ ...
                    rr.*(2*rr-1).*(ub-lb).*0.1;
            end
            % [逐行说明] 计算或更新 `X(i,:)`，供后续算法、评价或日志步骤使用。
            X(i,:)=min(max(Xnew,lb),ub);
        % [逐行说明] 处理前述条件均不成立的情况。
        else
            % [逐行说明] 计算或更新 `jumpR`，供后续算法、评价或日志步骤使用。
            jumpR=max(rand,eps);
            % [逐行说明] 计算或更新 `J`，供后续算法、评价或日志步骤使用。
            J=2*(1-jumpR^(1-progress));
            % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
            if r>=0.5 && abs(E)<0.5
                % [逐行说明] 计算或更新 `strategyCounts(4)`，供后续算法、评价或日志步骤使用。
                strategyCounts(4)=strategyCounts(4)+1;
                % [逐行说明] 计算或更新 `Xnew`，供后续算法、评价或日志步骤使用。
                Xnew=Rabbit_Location-E.*abs(Rabbit_Location-X(i,:))+ ...
                    alpha*rand.*(HistoricalBest(i,:)-X(i,:));
                % [逐行说明] 计算或更新 `X(i,:)`，供后续算法、评价或日志步骤使用。
                X(i,:)=min(max(Xnew,lb),ub);
            % [逐行说明] 在前一条件不成立时继续判断当前条件。
            elseif r>=0.5 && abs(E)>=0.5
                % [逐行说明] 计算或更新 `strategyCounts(5)`，供后续算法、评价或日志步骤使用。
                strategyCounts(5)=strategyCounts(5)+1;
                % [逐行说明] 计算或更新 `Xnew`，供后续算法、评价或日志步骤使用。
                Xnew=(Rabbit_Location-X(i,:))-E.*abs(J.*Rabbit_Location-X(i,:));
                % [逐行说明] 计算或更新 `X(i,:)`，供后续算法、评价或日志步骤使用。
                X(i,:)=min(max(Xnew,lb),ub);
            % [逐行说明] 在前一条件不成立时继续判断当前条件。
            elseif r<0.5 && abs(E)>=0.5
                % [逐行说明] 计算或更新 `strategyCounts(6)`，供后续算法、评价或日志步骤使用。
                strategyCounts(6)=strategyCounts(6)+1;
                % [逐行说明] 计算或更新 `Y1`，供后续算法、评价或日志步骤使用。
                Y1=Rabbit_Location-E.*abs(J.*Rabbit_Location-X(i,:));
                % [逐行说明] 计算或更新 `Y1`，供后续算法、评价或日志步骤使用。
                Y1=(1-beta).*Y1+beta.*HistoricalBest(i,:);
                % [逐行说明] 计算或更新 `Y1`，供后续算法、评价或日志步骤使用。
                Y1=min(max(Y1,lb),ub);
                % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
                if FEs<maxFEs
                    % [逐行说明] 计算或更新 `f1`，供后续算法、评价或日志步骤使用。
                    f1=fobj(Y1); FEs=FEs+1;
                % [逐行说明] 处理前述条件均不成立的情况。
                else
                    % [逐行说明] 计算或更新 `f1`，供后续算法、评价或日志步骤使用。
                    f1=inf;
                end
                % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
                if f1<fitness(i)
                    % [逐行说明] 计算或更新 `X(i,:)`，供后续算法、评价或日志步骤使用。
                    X(i,:)=Y1; fitness(i)=f1;
                % [逐行说明] 在前一条件不成立时继续判断当前条件。
                elseif FEs<maxFEs
                    % [逐行说明] 计算或更新 `Y2`，供后续算法、评价或日志步骤使用。
                    Y2=Rabbit_Location-E.*abs(J.*Rabbit_Location-X(i,:))+ ...
                        0.01.*rand(1,dim).*levy_flight(1,dim,1.3+0.3*rand);
                    % [逐行说明] 计算或更新 `Y2`，供后续算法、评价或日志步骤使用。
                    Y2=min(max(Y2,lb),ub);
                    % [逐行说明] 计算或更新 `f2`，供后续算法、评价或日志步骤使用。
                    f2=fobj(Y2); FEs=FEs+1;
                    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
                    if f2<fitness(i), X(i,:)=Y2; fitness(i)=f2; end
                end
            % [逐行说明] 处理前述条件均不成立的情况。
            else
                % [逐行说明] 计算或更新 `strategyCounts(7)`，供后续算法、评价或日志步骤使用。
                strategyCounts(7)=strategyCounts(7)+1;
                % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
                if rand<pElite
                    % [逐行说明] 计算或更新 `center`，供后续算法、评价或日志步骤使用。
                    center=H.*meanX+(1-H).*eliteMean;
                % [逐行说明] 处理前述条件均不成立的情况。
                else
                    % [逐行说明] 计算或更新 `center`，供后续算法、评价或日志步骤使用。
                    center=H.*meanX+(1-H).*Rabbit_Location;
                end
                % [逐行说明] 计算或更新 `Y1`，供后续算法、评价或日志步骤使用。
                Y1=Rabbit_Location-E.*abs(J.*Rabbit_Location-center);
                % [逐行说明] 计算或更新 `Y1`，供后续算法、评价或日志步骤使用。
                Y1=min(max(Y1,lb),ub);
                % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
                if FEs<maxFEs
                    % [逐行说明] 计算或更新 `f1`，供后续算法、评价或日志步骤使用。
                    f1=fobj(Y1); FEs=FEs+1;
                % [逐行说明] 处理前述条件均不成立的情况。
                else
                    % [逐行说明] 计算或更新 `f1`，供后续算法、评价或日志步骤使用。
                    f1=inf;
                end
                % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
                if f1<fitness(i)
                    % [逐行说明] 计算或更新 `X(i,:)`，供后续算法、评价或日志步骤使用。
                    X(i,:)=Y1; fitness(i)=f1;
                % [逐行说明] 在前一条件不成立时继续判断当前条件。
                elseif FEs<maxFEs
                    % [逐行说明] 计算或更新 `Y2`，供后续算法、评价或日志步骤使用。
                    Y2=Rabbit_Location-E.*abs(J.*Rabbit_Location-meanX)+ ...
                        0.01.*rand(1,dim).*levy_flight(1,dim,1.3+0.3*rand);
                    % [逐行说明] 计算或更新 `Y2`，供后续算法、评价或日志步骤使用。
                    Y2=min(max(Y2,lb),ub);
                    % [逐行说明] 计算或更新 `f2`，供后续算法、评价或日志步骤使用。
                    f2=fobj(Y2); FEs=FEs+1;
                    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
                    if f2<fitness(i), X(i,:)=Y2; fitness(i)=f2; end
                end
            end
        end
        % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
        if FEs>=maxFEs, break; end
    end
    % [逐行说明] 计算或更新 `CNVG(t)`，供后续算法、评价或日志步骤使用。
    CNVG(t)=Rabbit_Energy;
    % [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
    if FEs>=maxFEs
        % [逐行说明] 计算或更新 `CNVG(t:end)`，供后续算法、评价或日志步骤使用。
        CNVG(t:end)=Rabbit_Energy;
        % [逐行说明] 提前结束当前循环。
        break;
    end
end

% [逐行说明] 计算或更新 `log`，供后续算法、评价或日志步骤使用。
log=struct('FEs',FEs,'strategyCounts',strategyCounts,'seed',seed, ...
    'note','Formula-level reconstruction; official author code supersedes this file.');
end

function b=expand_bound(b,dim)
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isscalar(b), b=repmat(b,1,dim); else, b=reshape(b,1,[]); end
end

function X=tent_initialization(N,D,lb,ub)
% [逐行说明] 计算或更新 `seq`，供后续算法、评价或日志步骤使用。
seq=tent_sequence(N*D,rand);
% [逐行说明] 计算或更新 `X`，供后续算法、评价或日志步骤使用。
X=reshape(seq,N,D);
% [逐行说明] 计算或更新 `X`，供后续算法、评价或日志步骤使用。
X=lb+X.*(ub-lb);
end
