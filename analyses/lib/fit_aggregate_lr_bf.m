function outFile = fit_aggregate_lr_bf(forceRefit)
%FIT_AGGREGATE_LR_BF Fit overall L vs R person-mean difference model (F2025).
% Each person's estimate is averaged over all questions; groups are slider
% left (version 1 / 0%) vs right (version 2 / 100%). Saves MCMC under
% models/anchoringIndex/storage/.

if nargin < 1
    forceRefit = false;
end

thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(thisDir));
addpath('/home/mdlee/Dropbox/MatlabAddOns');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master/codatools');

modelDir = fullfile(repoRoot, 'models', 'anchoringIndex');
storageDir = fullfile(modelDir, 'storage');
if ~isfolder(storageDir)
    mkdir(storageDir);
end

engine = 'jags';
modelName = 'aggregateLR';
dataName = 'percentageEstimationF2025';
outFile = fullfile(storageDir, sprintf('%s_%s_%s.mat', modelName, dataName, engine));
if ~forceRefit && isfile(outFile)
    fprintf('Already exists: %s\n', outFile);
    return;
end

D = readtable(fullfile(repoRoot, 'data', 'percentageEstimationF2025Long.csv'));
participant = D{:, 1};
version = D{:, 3};
estimate = D{:, 7};

% Person means over questions; exclude W2024 no-anchor (version 3)
uL = unique(participant(version == 1));
uH = unique(participant(version == 2));
yL = nan(numel(uL), 1);
yH = nan(numel(uH), 1);
for i = 1:numel(uL)
    yL(i) = mean(estimate(participant == uL(i) & version == 1));
end
for i = 1:numel(uH)
    yH(i) = mean(estimate(participant == uH(i) & version == 2));
end

% priorSD: percentage-point scale for overall mean difference under H1
priorSD = 20;

data = struct('yL', yL, 'yH', yH, 'priorSD', priorSD);
params = {'delta', 'deltaPrior', 'mu', 'muL', 'muH'};
generator = @() struct('delta', randn * priorSD);

tmpDir = fullfile(tempdir, [modelName '_' dataName]);
if ~isfolder(tmpDir)
    mkdir(tmpDir);
end

fprintf('Fitting aggregate L–R difference BF model\n');
fprintf('  nL=%d  nH=%d  observed mean(H)-mean(L)=%.3f  priorSD=%.1f\n', ...
    numel(yL), numel(yH), mean(yH) - mean(yL), priorSD);
tic;
[stats, chains, diagnostics, info] = callbayes(engine, ...
    'model', fullfile(modelDir, sprintf('%s_jags.txt', modelName)), ...
    'data', data, ...
    'outputname', 'samples', ...
    'init', generator, ...
    'datafilename', modelName, ...
    'initfilename', modelName, ...
    'scriptfilename', modelName, ...
    'logfilename', fullfile(tmpDir, modelName), ...
    'nchains', 8, ...
    'nburnin', 1e3, ...
    'nsamples', 2e4, ...
    'monitorparams', params, ...
    'thin', 1, ...
    'workingdir', tmpDir, ...
    'verbosity', 0, ...
    'saveoutput', true, ...
    'allowunderscores', 1, ...
    'parallel', 1);
fprintf('JAGS took %.1f seconds.\n', toc);

meta = struct( ...
    'nL', numel(yL), ...
    'nH', numel(yH), ...
    'obsMeanL', mean(yL), ...
    'obsMeanH', mean(yH), ...
    'obsDiff', mean(yH) - mean(yL), ...
    'priorSD', priorSD);
save(outFile, 'chains', 'stats', 'diagnostics', 'info', 'meta', 'yL', 'yH');
fprintf('Saved %s\n', outFile);
disp('Convergence statistics:');
grtable(chains, 1.05);
end
