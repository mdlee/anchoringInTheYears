% Fit anchoring-index model for COGS140J F2025 percentageEstimation (slider 0 vs 100).
% Uses version coding (1 = left/0%, 2 = right/100%), not anchor-vs-truth splits.
clear; close all;

preLoad = false;
forceRefit = false;

thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(thisDir));
addpath(fullfile(repoRoot, 'analyses', 'lib'));
addpath('/home/mdlee/Dropbox/MatlabAddOns');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master/codatools');

D = readtable(fullfile(repoRoot, 'data', 'percentageEstimationF2025Long.csv'));
question = D{:, 2};
version = D{:, 3};
estimate = D{:, 7};

engine = 'jags';
modelName = 'anchoringIndex_percentage';
dataTag = 'percentageEstimationF2025';
params = {'A', 'Aprior'};
nChains = 8;
nBurnin = 1e3;
nSamples = 2e4;
nThin = 1;
doParallel = 1;
generator = @() struct('A', rand);

if ~isfolder('storage')
    mkdir('storage');
end

nQuestions = max(question);
for qIdx = 1:nQuestions
    yL = estimate(question == qIdx & version == 1);
    yH = estimate(question == qIdx & version == 2);
    if numel(yL) < 2 || numel(yH) < 2
        warning('Skipping Q%d: nL=%d nH=%d', qIdx, numel(yL), numel(yH));
        continue;
    end

    data = struct( ...
        'yH', yH, ...
        'yL', yL, ...
        'anchorHi', 100, ...
        'anchorLo', 0);

    fileName = sprintf('anchoringIndex_%s_%d_%s.mat', dataTag, qIdx, engine);
    outPath = fullfile('storage', fileName);

    if preLoad && ~forceRefit && isfile(outPath)
        fprintf('Loading pre-stored samples for Q%d\n', qIdx);
        continue;
    end

    tic;
    [stats, chains, diagnostics, info] = callbayes(engine, ...
        'model', sprintf('%s_jags.txt', modelName), ...
        'data', data, ...
        'outputname', 'samples', ...
        'init', generator, ...
        'datafilename', modelName, ...
        'initfilename', modelName, ...
        'scriptfilename', modelName, ...
        'logfilename', sprintf('/tmp/%s_%d', modelName, qIdx), ...
        'nchains', nChains, ...
        'nburnin', nBurnin, ...
        'nsamples', nSamples, ...
        'monitorparams', params, ...
        'thin', nThin, ...
        'workingdir', sprintf('/tmp/%s_%d', modelName, qIdx), ...
        'verbosity', 0, ...
        'saveoutput', true, ...
        'allowunderscores', 1, ...
        'parallel', doParallel); %#ok<ASGLU>
    fprintf('JAGS Q%d took %.1f seconds.\n', qIdx, toc);
    save(outPath, 'chains', 'stats', 'diagnostics', 'info');
end

fprintf('Done. Samples in %s/storage/anchoringIndex_%s_*_jags.mat\n', thisDir, dataTag);
