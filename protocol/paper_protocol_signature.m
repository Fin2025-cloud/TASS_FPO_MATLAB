function h=paper_protocol_signature(cfg,V,code)
% Resume/output location are operational, not scientific. Everything else frozen.
canonical=cfg;
canonical.paper=rmfield(canonical.paper,{'resume','outputRoot','attestationFile'});
h=paper_hash(jsonencode(struct('config',canonical,'variants',V,'code',code.sha256)));
end

