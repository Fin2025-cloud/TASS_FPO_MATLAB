function verification = verify_path_on_raw_dem(pathSamples,env,cfg)
%VERIFY_PATH_ON_RAW_DEM 在未填洞、未平滑的原始 DEM 上独立复核最优轨迹。
%
% 本函数是后处理验证，不参与优化器选择，也不消耗优化算法的 FE。它的作用
% 是检测 DEM 空洞填补或搜索用插值是否意外掩盖低净空。对原始栅格中的 NaN
% 区域不猜测高程，而是显式报告 UnverifiedFraction，论文中不得把这些位置
% 当作已验证安全。
%
% 输入：
%   pathSamples - N×3 最终密集轨迹点；
%   env         - load_dem_environment 构建且含 terrain.Zraw 的环境；
%   cfg         - 锁定配置；
%
% 输出：
%   minVerifiedClearance、maxVerifiedDeficit、verifiedFraction、
%   unverifiedFraction、isVerifiedFeasible 和逐点原始净空。

% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if ~isfield(env,'terrain')||~isfield(env.terrain,'Zraw')
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('verify_path_on_raw_dem:NoRawDEM','env.terrain.Zraw is unavailable.');
end
% [逐行说明] 计算或更新 `P`，供后续算法、评价或日志步骤使用。
P=pathSamples;
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if isempty(P)||size(P,2)~=3
    % [逐行说明] 检测到非法状态时抛出明确异常，禁止静默继续。
    error('verify_path_on_raw_dem:Path','pathSamples must be N-by-3.');
end
% [逐行说明] 计算或更新 `x`，供后续算法、评价或日志步骤使用。
x=env.terrain.x;y=env.terrain.y;Zraw=env.terrain.Zraw;
% [逐行说明] 计算或更新 `h`，供后续算法、评价或日志步骤使用。
h=interp2(x,y,Zraw,P(:,1),P(:,2),'linear',NaN);
% [逐行说明] 计算或更新 `verified`，供后续算法、评价或日志步骤使用。
verified=isfinite(h);
% [逐行说明] 计算或更新 `clearance`，供后续算法、评价或日志步骤使用。
clearance=nan(size(h));
% [逐行说明] 计算或更新 `clearance(verified)`，供后续算法、评价或日志步骤使用。
clearance(verified)=P(verified,3)-h(verified);
% [逐行说明] 计算或更新 `deficit`，供后续算法、评价或日志步骤使用。
deficit=nan(size(h));
% [逐行说明] 计算或更新 `deficit(verified)`，供后续算法、评价或日志步骤使用。
deficit(verified)=max(0,cfg.constraint.clearance-clearance(verified));

% [逐行说明] 计算或更新 `verification`，供后续算法、评价或日志步骤使用。
verification=struct();
% [逐行说明] 计算或更新 `verification.numPoints`，供后续算法、评价或日志步骤使用。
verification.numPoints=size(P,1);
% [逐行说明] 计算或更新 `verification.verifiedFraction`，供后续算法、评价或日志步骤使用。
verification.verifiedFraction=mean(verified);
% [逐行说明] 计算或更新 `verification.unverifiedFraction`，供后续算法、评价或日志步骤使用。
verification.unverifiedFraction=mean(~verified);
% [逐行说明] 计算或更新 `verification.rawTerrainHeight`，供后续算法、评价或日志步骤使用。
verification.rawTerrainHeight=h;
% [逐行说明] 计算或更新 `verification.rawClearance`，供后续算法、评价或日志步骤使用。
verification.rawClearance=clearance;
% [逐行说明] 判断当前条件是否成立，成立时执行对应分支。
if any(verified)
    % [逐行说明] 计算或更新 `verification.minVerifiedClearance`，供后续算法、评价或日志步骤使用。
    verification.minVerifiedClearance=min(clearance(verified));
    % [逐行说明] 计算或更新 `verification.maxVerifiedDeficit`，供后续算法、评价或日志步骤使用。
    verification.maxVerifiedDeficit=max(deficit(verified));
% [逐行说明] 处理前述条件均不成立的情况。
else
    % [逐行说明] 计算或更新 `verification.minVerifiedClearance`，供后续算法、评价或日志步骤使用。
    verification.minVerifiedClearance=NaN;
    % [逐行说明] 计算或更新 `verification.maxVerifiedDeficit`，供后续算法、评价或日志步骤使用。
    verification.maxVerifiedDeficit=NaN;
end
% [逐行说明] 执行当前 MATLAB 语句，完成所在步骤规定的计算或状态更新。
verification.isVerifiedFeasible=all(verified)&&verification.maxVerifiedDeficit<=cfg.constraint.feasibilityTolerance;
end
