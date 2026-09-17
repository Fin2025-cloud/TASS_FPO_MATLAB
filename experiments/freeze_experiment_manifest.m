function manifest = freeze_experiment_manifest(cfg,scenarioIds,algorithmNames)
%FREEZE_EXPERIMENT_MANIFEST 冻结正式实验的科学设置与环境定义。
%
% 为什么需要本函数
% -------------------------------------------------------------------------
% 正式实验可能持续数小时或数天，也可能中断后继续。仅依靠输出目录名称无法
% 防止用户误把不同环境、预算、约束或算法参数写入同一个目录。本函数把会影响
% 科学结论的配置转换为稳定 JSON，计算 SHA-256，并在恢复运行时逐字节核对。
%
% 以下改变都会触发签名不一致并终止：
%   * 环境候选、环境生成参数或真实 DEM 目录条目改变；
%   * 场景集合、算法集合、种群、MaxFEs、独立运行次数改变；
%   * 路径表示、目标函数、约束、能耗、风场/障碍、初始化或算法参数改变。
%
% 纯运行管理字段（输出目录、是否并行、是否恢复、绘图预览密度等）不参与
% 科学签名，因此同一实验可在串行/并行模式间安全恢复。

if nargin < 2 || isempty(scenarioIds), scenarioIds = 1:6; end
if nargin < 3 || isempty(algorithmNames)
    algorithmNames = {'FPO-N','ASA-FPO','TAAS-FPO','PSO','DE','GWO'};
end

% 防御性冻结选择；后续场景构建不得再次从可变选择文件读取候选编号。
if strcmpi(cfg.environment.mode,'selected_library')
    [cfg,ids,~] = resolve_environment_selection(cfg);
else
    ids = arrayfun(@(s)sprintf('V111-S%d',s),1:6,'UniformOutput',false);
end

root = cfg.experiment.outputDir;
if ~isfolder(root), mkdir(root); end
mode = char(string(cfg.environment.mode));

signature = struct();
signature.release = '1.3.0';
signature.environmentMode = mode;
signature.candidateIds = ids;
signature.scenarioIds = double(scenarioIds(:)');
signature.algorithmNames = cellstr(string(algorithmNames(:)'));
signature.scientificConfig = scientific_config_snapshot(cfg);

% 候选目录定义本身也进入签名。这样即使候选编号相同，但 recipe、seed、
% 起终点比例、风场或障碍预设被编辑，也不能继续写入旧结果目录。
if strcmpi(mode,'selected_library')
    catalogItems = repmat(get_environment_candidate(ids{1}),6,1);
    for s = 1:6
        catalogItems(s) = get_environment_candidate(ids{s});
    end
    signature.environmentCatalog = catalogItems;
else
    catalogItems = struct([]);
    signature.environmentCatalog = struct('definition','v1.1.1_featured_scenarios');
end

signatureFile = fullfile(root,'experiment_signature.json');
tempSignatureFile = fullfile(root,'experiment_signature.current.tmp.json');
write_json(tempSignatureFile,signature);
currentSHA = sha256_file(tempSignatureFile);
manifestFile = fullfile(root,'experiment_manifest.mat');

if isfile(manifestFile)
    old = load(manifestFile,'manifest');
    if ~isfield(old,'manifest') || ~isfield(old.manifest,'signatureSHA256')
        delete_if_exists(tempSignatureFile);
        error('freeze_experiment_manifest:InvalidExisting', ...
            'Existing experiment_manifest.mat is invalid: %s',manifestFile);
    end
    if ~strcmpi(char(string(old.manifest.signatureSHA256)),currentSHA)
        % 保存当前候选签名供人工比较，但不覆盖已冻结的正式签名。
        mismatchFile = fullfile(root,'experiment_signature_mismatch_current.json');
        movefile(tempSignatureFile,mismatchFile,'f');
        error('freeze_experiment_manifest:SignatureMismatch', ...
            ['输出目录已经冻结为另一组实验设置。为保证统计有效性，禁止混写。\n', ...
             '旧签名：%s\n当前签名：%s\n', ...
             '请恢复原设置，或为新环境/预算指定新的 outputDir。'], ...
             char(string(old.manifest.signatureSHA256)),currentSHA);
    end
    delete_if_exists(tempSignatureFile);
    manifest = old.manifest;
    return;
end

movefile(tempSignatureFile,signatureFile,'f');
manifest = struct();
manifest.release = '1.3.0';
manifest.createdUTC = char(datetime('now','TimeZone','UTC', ...
    'Format','yyyy-MM-dd HH:mm:ss'));
manifest.signature = signature;
manifest.signatureSHA256 = currentSHA;
manifest.projectRoot = fileparts(fileparts(mfilename('fullpath')));
manifest.MATLABVersionAtCreation = version;
manifest.computerAtCreation = computer;

% 保存完整配置和可读 JSON。frozen_config 中的 candidateIds 已经固定。
save(fullfile(root,'frozen_config.mat'),'cfg','-v7.3');
write_json(fullfile(root,'frozen_config.json'),cfg);
save(manifestFile,'manifest','-v7.3');
write_json(fullfile(root,'experiment_manifest.json'),manifest);

if strcmpi(mode,'selected_library')
    save(fullfile(root,'frozen_environment_selection.mat'), ...
        'ids','catalogItems','-v7.3');
    selectionSnapshot = struct('candidateIds',{ids}, ...
        'catalogItems',{catalogItems}, ...
        'signatureSHA256',currentSHA);
    write_json(fullfile(root,'frozen_environment_selection.json'),selectionSnapshot);
end
end

function snapshot = scientific_config_snapshot(cfg)
% 复制完整配置后只删除不影响数学问题或随机序列的运行/显示字段。
snapshot = cfg;

if isfield(snapshot,'experiment')
    operational = {'outputDir','useParallel','resume','resumeErrorRuns', ...
        'overwriteExisting','checkpointAfterScenario','autoStartParallelPool', ...
        'stripRuntimeCacheBeforeSave','failFast','saveFullLog','saveCsvSummary'};
    snapshot.experiment = remove_fields_if_present(snapshot.experiment,operational);
end
if isfield(snapshot,'environment')
    displayOnly = {'selectionFile','previewMaxGrid','previewWindGrid', ...
        'showGuideRoutes','realCachePreferred','verifyGeoTIFFChecksum'};
    snapshot.environment = remove_fields_if_present(snapshot.environment,displayOnly);
end
if isfield(snapshot,'data')
    snapshot.data = remove_fields_if_present(snapshot.data,{'verifyChecksum'});
end
if isfield(snapshot,'algorithm')
    snapshot.algorithm = remove_fields_if_present(snapshot.algorithm, ...
        {'verbose','assertInvariants','logEveryFE','seed'});
end
end

function s = remove_fields_if_present(s,names)
for k = 1:numel(names)
    if isstruct(s) && isfield(s,names{k})
        s = rmfield(s,names{k});
    end
end
end

function write_json(filename,value)
try
    text = jsonencode(value,'PrettyPrint',true);
catch
    text = jsonencode(value);
end
fid = fopen(filename,'w');
if fid < 0
    error('freeze_experiment_manifest:FileOpen','Cannot open %s.',filename);
end
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,text,'char');
end

function delete_if_exists(filename)
if isfile(filename), delete(filename); end
end
