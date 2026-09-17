# 方法、来源与变更审计

## 继承与新增

|模块|来源/状态|本文可主张的内容|
|---|---|---|
|FPO阶段、七行为、历史信息、Lévy|Wei & Zhong 2026，DOI 10.1016/j.egyr.2026.109064|继承基础，不主张首创|
|FPO-reference|paper_reference_solver.m，公式重建+Deb+FE适配|参考适配器，不等同官方实现|
|FPO-N|v1.3.1工程搜索公式，稳定锚点/逐维符号|必须与原始重建分列|
|TAI、CDR、停滞恢复|基于v1.3.1保留|需通过全因子/重启消融验证|
|ASA信用|原搜索贡献+折扣修复贡献，除实际FE|已有AOS和成本收益先行工作；研究具体耦合|
|v2实验协议|新增protocol/|评价审计、输入签名、不可覆盖记录、失败保留与终检|
|v2平滑目标|evaluate_path.m|改为Lref×Σκ²Δs；修复量纲与采样依赖，不声称新数学理论|
|能耗|默认论文协议明确使用B；垂直修正为工程近似|参数尚未校准，不声称实飞节能|
|现代基线|OQMGTO/TQGAOA尚未实现与核准|保留为投稿缺口，不用改名算法顶替|

## 新旧结果不可直接混用

v2取消固定地速下与长度重复的时间目标权重，将长度权重由0.25调整为0.35；平滑目标改为无量纲曲率弧长积分；论文入口明确使用B模型。因评价定义变更，v1.3.1的F数值不能与v2直接比较。新配置、原始记录与代码版本应全部公开，任何权重调整须重新冻结。

FPO-reference还改变了原文迭代进度、接受规则及边界语义以适配受约束FE接口，完整随机序列不保证与作者实现一致。现代基线接入需要来源、许可、参数及同预算复现验证，而不是只添加一个方法名称。

## 引用证据与人工核验

下表为机器辅助查核，不代表作者已经阅读全文或人工确认。参考文献[7]使用已核对的ISBN，避免把不同版本书籍DOI误配到2001修订本。

|证据ID|对应参考/来源|查核程度|人工状态|
|---|---|---|---|
|E01|FPO，https://doi.org/10.1016/j.egyr.2026.109064|出版社摘要/元数据，旧查新报告及本地公式重建|pending_human|
|E02|TQGAOA，https://doi.org/10.1016/j.ast.2025.110950|出版社摘要和预览；不能据此排除正文所有相似机制|pending_human|
|E03|OQMGTO，https://doi.org/10.1016/j.isatra.2024.04.010|出版社摘要和方法介绍|pending_human|
|E04|LF-TF-CPO，https://www.mdpi.com/2504-446X/10/5/356|公开论文及前次查新报告|pending_human|
|E05|EMMOP，https://doi.org/10.1016/j.swevo.2025.102145|出版社摘要和前次查新报告|pending_human|
|E06|Tuson/Ross，https://doi.org/10.1162/evco.1998.6.2.161|前次查新中的成本收益先行基础|pending_human|
|E07|de Boor，https://link.springer.com/book/9780387953663|出版社修订版描述与ISBN978-0-387-95366-3|pending_human|
|E08|Deb，https://doi.org/10.1016/S0045-7825(99)00389-8|出版社摘要/元数据|pending_human|
|E09|Zeng等，https://arxiv.org/abs/1804.02238；期刊DOI10.1109/TWC.2019.2902559|作者公开稿/期刊元数据；三维垂直修正不是该文已验证模型|pending_human|
|E10|data/dem 与 real_dem_catalog.m|随包5组裁剪/缓存摘要；来源记录继承|pending_human|

## 主张台账

|主张ID|主张|证据|状态|
|---|---|---|---|
|C01|阶段内选择器按真实FE及折扣修复信用更新|TAAS_FPO、strategy_reward、事件日志、单测|implemented；科学收益pending|
|C02|TAI/CDR有助于有限预算可行搜索|继承实现，全因子8组已配置|hypothesis；无正式数据|
|C03|相对基线节能或更稳健|须正式配对数据、FR及终检|unsupported_pending_experiments|
|C04|模型预测能耗对应实飞能耗|须平台校准与测量|unsupported_pending_calibration|
|C05|优于最新方法|须现代基线复现、同协议结果|unsupported_pending_modern_baselines|
|C06|全过程可追溯记录|protocol源码与实际小测试记录|implementation_verified_in_Octave_only|

submission_ready = false。没有作者姓名、资助、统计值、性能图或p值由工具推断补造。

## 授权与发布

此项目保留用户提供的v1.3.1源码和数据。未擅自为原作者或用户代码赋予新的开源许可证。公开前请核验算法参考实现、继承代码与Copernicus裁剪的授权要求，并添加适当许可和出处。文稿/代码生成在本地处理，未将完整用户论文上传到外部文献服务。
