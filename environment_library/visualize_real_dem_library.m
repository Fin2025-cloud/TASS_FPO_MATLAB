function report = visualize_real_dem_library()
%VISUALIZE_REAL_DEM_LIBRARY 可视化正式与候选公开真实 DSM，不运行优化器。
%
% 本脚本只读取 GeoTIFF 并绘图，通常数秒内完成。它用于回答：
%   * 哪些区域确实来自公开真实 DSM；
%   * 每个裁剪区的高程范围和局部起伏是多少；
%   * 哪些区域适合放入正式路径规划实验。
%
% 显示的五个独立区域：
%   S3 新平行山脊谷地；S4 高山陡坡；S5/S6 高山风场底图；
%   C1 旧低起伏 S3 对照；C2 切割高原候选。
%
% 注意：C1/C2 只属于数据储备，不会被 FPO_LAB 的正式实验自动运行。

startup();
projectRoot = project_root();

formal = [dem_catalog(3),dem_catalog(4),dem_catalog(5)];
candidates = optional_dem_catalog();
items = struct('id',{},'name',{},'file',{},'sourceTile',{},'expectedSHA256',{},'isFormal',{});
for k = 1:numel(formal)
    sid = k+2;
    items(end+1) = struct( ... %#ok<AGROW>
        'id',sprintf('S%d',sid), ...
        'name',formal(k).scenarioName, ...
        'file',fullfile(projectRoot,formal(k).relativeFile), ...
        'sourceTile',formal(k).sourceTile, ...
        'expectedSHA256',formal(k).expectedSHA256, ...
        'isFormal',true);
end
for k = 1:numel(candidates)
    items(end+1) = struct( ... %#ok<AGROW>
        'id',candidates(k).id, ...
        'name',candidates(k).name, ...
        'file',fullfile(projectRoot,candidates(k).relativeFile), ...
        'sourceTile',candidates(k).sourceTile, ...
        'expectedSHA256',candidates(k).sha256, ...
        'isFormal',false);
end

figure('Name','Copernicus GLO-30 real DEM library','Color','w');
tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
rows = cell(numel(items),9);
for k = 1:numel(items)
    actualHash = sha256_file(items(k).file);
    if ~strcmpi(actualHash,items(k).expectedSHA256)
        error('visualize_real_dem_library:Checksum', ...
            'GeoTIFF 摘要不匹配：%s',items(k).file);
    end
    [Z,R] = readgeoraster(items(k).file,'OutputType','double');
    Z = squeeze(Z);
    Z(Z<-1e30) = NaN;
    valid = Z(isfinite(Z));
    if isempty(valid)
        error('visualize_real_dem_library:NoData','栅格无有效高程：%s',items(k).file);
    end

    % 绘图可按行列等间隔抽样以提高交互速度；统计值仍来自完整栅格。
    rowStep = max(1,ceil(size(Z,1)/150));
    colStep = max(1,ceil(size(Z,2)/150));
    Zd = Z(1:rowStep:end,1:colStep:end);
    x = (0:size(Zd,2)-1)*abs(double(R.CellExtentInWorldX))*colStep;
    y = (0:size(Zd,1)-1)*abs(double(R.CellExtentInWorldY))*rowStep;

    nexttile;
    surf(x,y,Zd,'EdgeColor','none');
    axis tight; view(42,32); grid on; box on;
    xlabel('X / m'); ylabel('Y / m'); zlabel('Z / m');
    relief = max(valid)-min(valid);
    role = '正式';
    if ~items(k).isFormal, role = '候选'; end
    title(sprintf('%s %s\n起伏 %.1f m',items(k).id,role,relief), ...
        'Interpreter','none');

    rows(k,:) = {string(items(k).id),string(role),string(items(k).name), ...
        string(items(k).sourceTile),min(valid),max(valid),relief, ...
        size(Z,2),size(Z,1)};
end

nexttile;
axis off;
text(0,1,{ ...
    '说明', ...
    '• 正式场景：S3、S4、S5/S6', ...
    '• 候选储备：C1、C2', ...
    '• 所有图均读取包内 GeoTIFF', ...
    '• 不执行算法，不改变任何结果', ...
    '• 完整来源与摘要见 data/provenance'}, ...
    'VerticalAlignment','top','FontSize',11);

report = cell2table(rows,'VariableNames',{ ...
    'ID','Role','Name','SourceTile','MinElevation_m','MaxElevation_m', ...
    'Relief_m','WidthCells','HeightCells'});
disp(report);
end
