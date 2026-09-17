# TAAS-FPO MATLAB v2.0.0

这是独立的新工程，基于 v1.3.1 的环境库与路径评价器整理，加入论文实验协议、信用消融和可追溯记录。旧工程不作为新实验输出目录。

**交付状态：方法稿与可运行核心研究工程，不是已经完成实证的投稿终稿。** 论文结果为空；OQMGTO/TQGAOA 未冒充已实现基线；MATLAB 正式运行与平台能耗校准待完成。随附验证日志是 Octave 小规模代码测试，不得用于论文性能表。

## 1. 从哪里开始

在 MATLAB 中将当前文件夹设为本工程，执行：

~~~matlab
startup
FPO_LAB                      % 保留环境浏览、候选比较与快速演示
FPO_PAPER('help')             % 新论文协议
FPO_PAPER('tests')            % 核心测试；写入 results/verification
test_paper_extended          % 数值与真实地形扩展测试
test_paper_visualization     % 新版结果结构与只读输出测试
~~~

不要同时把旧版和新版加入 MATLAB 路径。如果此前加载过旧版，请先执行 `restoredefaultpath`，再切换到本工程并运行 `startup(true)`。用 `which FPO_LAB -all` 检查时，第一项必须是当前工程中的 `FPO_LAB.m`。

最小单场景试跑（不是论文数据）：

~~~matlab
cfg = FPO_PAPER('config','smoke');
cfg.paper.candidateIds = {'S1-B'};
cfg.paper.seedIds = 1;
R = FPO_PAPER('run',cfg,{'FPO-N','TAAS-FPO'});
~~~

第一轮开发预实验（3方法×2开发实例×3种子=18次，共90000完整评价）：

~~~matlab
cfg = FPO_PAPER('config','pilot');
R = FPO_PAPER('run',cfg,{'FPO-N','ASA-FPO','TAAS-FPO'});
~~~

默认开发实例 S2-B/S6-E 不等于未见测试集。先核对是否已经用于调参，再冻结测试划分。

## 2. 清晰分层

~~~text
FPO_LAB.m                 原有主控与环境工作室；正式入口转向新协议
FPO_PAPER.m               新论文实验入口
config/                   参数及人工核准记录
protocol/                 分组、计数、签名、终检、保存与汇总
algorithms/               FPO及七策略、奖励、概率和历史统计
initialization/           地形种子与混合初始化
uav_problems/             B样条、碰撞、运动约束、能耗与评价器
environment_library/      30候选环境与真实DSM加载
data/                     原包地形裁剪、缓存、来源及摘要
baselines/                受约束DE/PSO/GWO工程实现
experiments/ analysis/    继承的演示、筛选与旧格式分析
tests/                    继承测试及新协议测试
results/verification/     本次真实执行的代码验证；不是正式实验
results/paper/            将来的smoke/pilot/formal记录；按协议摘要隔离
paper/                    可编辑DOCX、DOC兼容副本及论文源稿
docs/                     实验计划、来源、限制与投稿检查
tools/                    文稿重建工具（不参与MATLAB搜索）
~~~

环境工作室、快速图与旧格式结果查看仍保留。新版 `results/paper/formal_*` 结果应使用 `FPO_LAB` 菜单“结果与检查→新版正式结果汇总、路径与收敛图”，或直接执行 `FPO_PAPER('visualize',batchFolder)`。可视化只读取 `run_summary.json` 和各运行的 `record.mat`，并把派生图表写入新建的 `figures_paper_时间戳` 子目录；不会覆盖正式记录。仅需查看单个记录时执行 `visualize_one_saved_run(recordFile)`。旧版冻结环境正式运行入口已明确禁用，不能绕过新协议作为本文正式实验。

## 3. 方法分组

~~~matlab
FPO_PAPER('variants','main')       % 7个核心比较方法
FPO_PAPER('variants','factorial')  % TAI×ASA×CDR，8组合，均无重启
FPO_PAPER('variants','credit')     % 7种信用/选择对照，均无重启
FPO_PAPER('variants','restart')    % 启用/禁用重启
cfg.paper.block = 'factorial';
FPO_PAPER('run',cfg);
~~~

FPO-reference 是公式重建并适配受约束接口的版本，不是官方源码；FPO-N 包含稳定锚点、逐维符号等重参数化，不是完全原始的FPO。相关来源和适配差异见 docs/METHOD_AND_SOURCE_AUDIT.md。

OQMGTO/TQGAOA 的来源、授权与逐公式复现仍待补齐。未知 solver 会直接报错，不会静默改为本地另一个算法。

## 4. 正式实验为什么默认不能直接运行

formal 要求人工核准能耗参数、原始基线、数据划分、统计计划、MATLAB测试及现代基线研究方案。config/study_attestation.json 默认全为 false，绝不能为了绕过报错而批量改为 true。

1. 在 MATLAB 完成测试；确认地形来源、能耗参数、归一化及各基线适配。
2. 在 cfg.paper.candidateIds 填入真正冻结的测试实例；partition 改为 test；种子至少30个。
3. 将 energyStatus 改为有真实记录支持的状态，例如 literature_parameter_set_reviewed 或 platform_calibrated，并在文档记录具体证据。
4. 用 cfg=paper_config('formal') 设置全部协议。调用 paper_preflight(cfg) 会显示需要批准的摘要，然后在尚未核准时阻止执行。
5. 真实审核人在 study_attestation.json 填姓名、日期、审核状态及该 protocol_sha256。任何代码、配置或输入数据变化都会使签名失效，需重新核准。
6. 通过预检后再用 FPO_PAPER('run',cfg,variantIds) 启动。对子集的核准要用 paper_preflight(cfg,V) 传入相同的变体集；各实验块需各自核准。
7. formal 在 Octave 下被阻止；Octave验证不能冒充 MATLAB 正式实验。

当前核准条件是研究过程检查，不是软件能证明数据真实或论文创新性的证书。稿件的先进性论断还需要现代基线数据；不能以人工勾选代替复现工作。

## 5. 真实记录与恢复

每次运行保存 summary.json 和 record.mat。原始记录含配置、环境、控制点、评价轨迹、策略事件、算法输出和两级终检结果；summary含记录文件SHA-256。protocol.json保存代码与输入文件摘要、配置、方法组和运行环境。

- 初始化、二候选、修复和重启调用完整评价器都计FE；要求实际次数等于预算。
- A*等预处理不计FE但计耗时；两次终检独立计时，不反馈搜索。
- 代码或输入地形改变，不能合并旧结果；每次运行前重新检查摘要。
- 已完成记录恢复前再次核验MAT文件摘要。错误运行保留且不自动重做。
- 未完成目录不能直接覆盖。应先人工检查原因，再明确归档；不要删除失败记录“美化”数据。
- 不可行路径的能耗统计为缺失值，绝不写0；失败/错误仍进入成功率分母。
- results/paper下每个批次有run_summary.csv/.json；paper_report输出成功率、Wilson区间、成功样本数和条件能耗分位数。配对检验与分层置信区间必须依冻结统计计划补齐，不应将此基础汇总误称完整统计分析。

## 6. Word文件

paper/TAAS-FPO_论文稿_待填实验结果.docx 是编辑主文件，包含原生 Office Math 公式、可编辑表格和标题层级。DOC为实际Word97兼容副本；其中公式为可编辑线性表达式，以避免旧公式对象转换丢符号。标准排版与公式编辑请使用DOCX。PDF只用于版式预览。

作者、单位、基金、利益冲突、数据地址和实验结论均未虚构。见 docs/SUBMISSION_CHECKLIST.md。默认参数表是设置值，不是实验数据。

## 7. 运行环境与已知限制

主要目标为 MATLAB（建议 R2021a 或更新版本；实际测试版本需作者填写）。核心不要求 Optimization Toolbox；Java用于MATLAB中的SHA-256。继承的交互工作室使用table/string及绘图功能，未声称全套界面兼容Octave。当前新协议串行执行，旧版并行模块保留但未接入新协议。

旧包CEC功能保留作辅助，未把未授权外部CEC实现当作本次正式证据，也未运行不透明MEX。
