function E = energy_model_A(metrics, cfg)
%ENERGY_MODEL_A 计算开发阶段使用的可解释相对能耗。
%
% 数学形式
% -------------------------------------------------------------------------
% E_A = c_L L
%     + c_H sum(max(Delta z,0))
%     + c_theta sum(theta^2)
%     + c_W sum(v_air^2 Delta t)
%
% 作用说明
% -------------------------------------------------------------------------
% 长度项近似基础巡航消耗；正爬升项反映克服重力所需额外能量；转角平方项
% 抑制频繁急转；空速平方积分项使逆风轨迹比顺风轨迹消耗更多。该模型计算
% 快、参数直观，适合算法开发与单元测试。正式论文应使用 B 模型复核主要结论。
%
% 本函数不包含随机数，也不修改 metrics 或 cfg。

% 读取 A 级能耗模型的全部固定系数。
p = cfg.energy.A;

% 计算路径长度对应的基础巡航能耗。
lengthEnergy = p.cLength * metrics.length;

% 仅累计正高度变化，下降段不产生该项爬升惩罚。
positiveClimb = sum(max(metrics.deltaZ(:), 0));

% 将总正爬升量乘以爬升能耗系数。
climbEnergy = p.cClimb * positiveClimb;

% 对所有转角平方求和，使较大的转弯受到更强惩罚。
turnEnergy = p.cTurn * sum(metrics.turnAngle(:) .^ 2);

% 强制空速与线段持续时间为列向量，避免行列方向引起维度错误。
airSpeed = metrics.airSpeed(:);

% 强制时间增量为列向量。
deltaT = metrics.deltaT(:);

% 检查每条线段是否同时拥有一个空速和一个持续时间。
if numel(airSpeed) ~= numel(deltaT)
    % 尺寸不一致说明上游评价器数据损坏，必须显式报错而不能静默修剪。
    error('energy_model_A:SizeMismatch', ...
        'airSpeed and deltaT must contain the same number of segments.');
end

% 计算空速平方随时间积分的离散近似。
airIntegral = sum((airSpeed .^ 2) .* deltaT);

% 将空速积分乘以固定系数得到风场相关能耗。
airEnergy = p.cAir * airIntegral;

% 汇总四个能耗分量。
E = lengthEnergy + climbEnergy + turnEnergy + airEnergy;
end
