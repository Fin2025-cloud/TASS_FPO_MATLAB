function cfg=paper_apply_variant(cfg,v)
cfg.initialization.enabled=v.tai;
cfg.strategy.enabled=v.asa;
cfg.repair.enabled=v.cdr;
cfg.stagnation.enabled=v.restart;
cfg.strategy.selector=v.selector;
cfg.strategy.creditMode=v.creditMode;
cfg.strategy.costMode=v.costMode;
cfg.strategy.lambdaRepair=v.lambda;
cfg.baseline.useTAI=v.tai;
cfg.baseline.useRepair=v.cdr;
end

