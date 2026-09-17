function [E, power] = energy_model_B(metrics, cfg)
%ENERGY_MODEL_B 计算旋翼无人机解析推进功率及总能耗。
%
% 水平推进功率采用常见旋翼 UAV 模型：
% P_h(V) = P0(1+3V^2/U_tip^2)
%        + Pi sqrt(sqrt(1+V^4/(4v0^4))-V^2/(2v0^2))
%        + 0.5 d0 rho s A V^3
%
% 垂直修正包括正爬升功率和下降经验项。总能耗通过逐段功率乘以线段持续
% 时间后求和得到。cfg.energy.B 中的默认参数只是可运行示例，正式实验必须
% 用目标平台或可靠文献参数替换，并在结果中保存参数版本。
%
% 数值稳健性
% -------------------------------------------------------------------------
% 所有逐段量均显式转换为列向量并检查长度一致，避免 MATLAB:dimagree。

% 读取 B 级旋翼功率模型的固定参数。
p = cfg.energy.B;

% 取得每条轨迹线段的水平空速，并统一为列向量。
Vh = metrics.horizontalAirSpeed(:);

% 取得每条轨迹线段的垂直空速，并统一为列向量。
Vz = metrics.verticalAirSpeed(:);

% 取得每条轨迹线段的持续时间，并统一为列向量。
deltaT = metrics.deltaT(:);

% 检查三个逐段向量长度是否完全一致。
if numel(Vh) ~= numel(Vz) || numel(Vh) ~= numel(deltaT)
    % 不允许静默截断，因为这会改变总能耗并破坏实验真实性。
    error('energy_model_B:SizeMismatch', ...
        'horizontalAirSpeed, verticalAirSpeed and deltaT must have equal lengths.');
end

% 计算诱导功率公式中的内层无量纲项。
inducedInner = sqrt(1 + (Vh .^ 4) ./ (4 * p.v0 ^ 4)) - ...
    (Vh .^ 2) ./ (2 * p.v0 ^ 2);

% 将微小数值误差导致的负值截断为零，保证后续开方为实数。
inducedInner = max(inducedInner, 0);

% 计算桨叶剖面功率项。
profilePower = p.P0 .* (1 + 3 .* (Vh .^ 2) ./ (p.Utip ^ 2));

% 计算诱导功率项。
inducedPower = p.Pi .* sqrt(inducedInner);

% 计算机身寄生阻力功率项。
parasitePower = 0.5 .* p.d0 .* p.rho .* p.solidity .* ...
    p.rotorArea .* (Vh .^ 3);

% 汇总三个水平推进功率分量。
horizontalPower = profilePower + inducedPower + parasitePower;

% 只对正垂直空速计算克服重力的爬升功率。
climbPower = (cfg.uav.mass * cfg.uav.gravity / p.climbEfficiency) .* max(Vz, 0);

% 对负垂直空速计算下降经验修正功率。
descentPower = p.descentCoeff .* max(-Vz, 0);

% 汇总水平、爬升和下降功率，并保证功率非负。
power = max(horizontalPower + climbPower + descentPower, 0);

% 对逐段功率与持续时间乘积求和，得到总推进能耗。
E = sum(power .* deltaT);
end
