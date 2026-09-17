function cfg = environment_config()
%ENVIRONMENT_CONFIG Configuration shared by environment screening and later experiments.
% The physical constraints remain compatible with the retained path evaluator.
cfg = default_config();

% Environment screening is not an optimization run. These fields only control
% terrain construction, quick diagnostics, and drawing density.
cfg.environment.syntheticMapSize = [1800,1500];   % [xLength,yLength] m
cfg.environment.syntheticGridSize = [181,151];    % [nx,ny]
cfg.environment.previewMaxGrid = 105;              % drawing only; never evaluator data
cfg.environment.previewWindGrid = [4,3];
cfg.environment.showGuideRoutes = true;            % only for environment screening
cfg.environment.realCachePreferred = true;
cfg.environment.verifyGeoTIFFChecksum = false;     % call verify_real_dem_library explicitly
cfg.environment.selectionFile = fullfile('data','selections','selected_environments.mat');

% Keep the physical definitions visible and fixed while selecting scenes.
cfg.constraint.clearance = 30.0;
cfg.uav.radius = 1.5;
cfg.data.verifyChecksum = false;

% These lower values affect only optional make_problem smoke checks. Formal
% experiments should reset them before optimization.
cfg.path.M = 160;
cfg.path.maxAdaptivePoints = 300;
cfg.algorithm.N = 20;
cfg.algorithm.MaxFEs = 2000;
cfg.algorithm.verbose = false;
end
