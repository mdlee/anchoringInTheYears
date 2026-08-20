function report_aggregate_lr_bf(repoRoot, storageDirs, forceRefit)
%REPORT_AGGREGATE_LR_BF Savage–Dickey BF for overall L vs R mean difference.
% Aggregates over questions by taking each person's mean estimate, then
% compares slider-left (0%) vs slider-right (100%) groups.
%
% Writes analyses/results/aggregateAnchorBF/percentageEstimationF2025.txt

if nargin < 3
    forceRefit = false;
end

outDir = results_dir(repoRoot, 'aggregateAnchorBF');
if ~isfolder(outDir)
    mkdir(outDir);
end

fit_aggregate_lr_bf(forceRefit);

path = resolve_storage_file(storageDirs, 'aggregateLR_percentageEstimationF2025_jags.mat');
if isempty(path)
    % Just-written file may only be under models/anchoringIndex/storage
    path = fullfile(repoRoot, 'models', 'anchoringIndex', 'storage', ...
        'aggregateLR_percentageEstimationF2025_jags.mat');
end
if ~isfile(path)
    error('Missing aggregate LR MCMC: %s', path);
end

S = load(path, 'chains', 'meta');
chains = S.chains;
meta = S.meta;

delta = chains.delta(:);
deltaPrior = chains.deltaPrior(:);
CI = 95;
bounds = prctile(delta, [(100 - CI) / 2, CI + (100 - CI) / 2]);
mn = mean(delta);

% Savage–Dickey at delta = 0 (same convention as per-question anchoring BFs)
critical = 0;
binWidth = 0.25;  % percentage points
binHalf = 40;     % cover prior ± ~2 SD
binLo = -binHalf;
binHi = binHalf;
binCenter = binLo:binWidth:binHi;
[~, criticalIdx] = min(abs(binCenter - critical));
densityPrior = histcounts(deltaPrior, ...
    'binlimits', [binLo - binWidth / 2, binHi + binWidth / 2], ...
    'binwidth', binWidth, 'normalization', 'pdf');
densityPosterior = histcounts(delta, ...
    'binlimits', [binLo - binWidth / 2, binHi + binWidth / 2], ...
    'binwidth', binWidth, 'normalization', 'pdf');
BF10 = exp(log(densityPrior(criticalIdx)) - log(densityPosterior(criticalIdx)));

outTxt = fullfile(outDir, 'percentageEstimationF2025.txt');
fid = fopen(outTxt, 'w');
if fid < 0
    error('Could not open %s', outTxt);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
w = @(varargin) local_writef(fid, varargin{:});

w('COGS140J F2025/W2024 percentageEstimation: aggregate L vs R mean difference\n');
w('\n');
w('Aggregation\n');
w('  Within each person, mean estimate across all questions.\n');
w('  Between groups: slider left / 0%% (version 1) vs slider right / 100%% (version 2).\n');
w('  W2024 no-anchor participants excluded.\n');
w('\n');
w('Model\n');
w('  yL ~ N(muL, sigmaL^2),  yH ~ N(muH, sigmaH^2)\n');
w('  delta = muH - muL,  delta ~ N(0, priorSD^2) under H1\n');
w('  Savage–Dickey BF for H0: delta = 0 vs that H1 prior.\n');
w('\n');
w('  nL (left/0%%)                         %d\n', meta.nL);
w('  nH (right/100%%)                       %d\n', meta.nH);
w('  observed mean L                       %.4f\n', meta.obsMeanL);
w('  observed mean H                       %.4f\n', meta.obsMeanH);
w('  observed difference (H - L)           %.4f\n', meta.obsDiff);
w('  prior SD for delta under H1           %.1f\n', meta.priorSD);
w('\n');
w('  posterior mean delta                  %.4f\n', mn);
w('  95%% CI                                [%.4f, %.4f]\n', bounds(1), bounds(2));
if BF10 > 1000
    w('  BF_10 (delta != 0 vs delta = 0)       > 1000\n');
elseif BF10 >= 1
    w('  BF_10 (delta != 0 vs delta = 0)       %.2f\n', BF10);
else
    w('  BF_01 (delta = 0 vs delta != 0)       %.2f\n', 1 / BF10);
    w('  BF_10                                 %.4f\n', BF10);
end
w('\n');
w('Loaded %s\n', path);

fprintf('Wrote %s\n', outTxt);
end

function local_writef(fid, varargin)
line = sprintf(varargin{:});
fprintf('%s', line);
fprintf(fid, '%s', line);
end
