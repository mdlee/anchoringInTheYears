% Debiasing model fit for COGS140J F2025 percentageEstimation (slider 0 vs 100).
clear; close all;
preLoad = false;

thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(thisDir));
addpath('/home/mdlee/Dropbox/MatlabAddOns');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master/codatools');

dataName = 'percentageEstimationF2025';
D = readtable(fullfile(repoRoot, 'data', 'percentageEstimationF2025Long.csv'));

participant = D{:, 1};
question = D{:, 2};
version = D{:, 3};
anchor = D{:, 5};
estimate = D{:, 7};
anchor(~isfinite(anchor)) = 0;

engine = 'jags';
modelName = 'debiasing';
params = {'mu', 'sigma', 'alpha'};
nChains = 8;
nBurnin = 1e3;
nSamples = 2e4;
nThin = 1;
doParallel = 1;

data = struct( ...
    'participant', participant, ...
    'question', question, ...
    'anchor', anchor, ...
    'y', estimate, ...
    'version', version);
generator = @() struct('alpha', rand(length(unique(participant)), 1));

fileName = sprintf('%s_%s_%s.mat', modelName, dataName, engine);
if ~isfolder('storage')
    mkdir('storage');
end
outPath = fullfile('storage', fileName);

if preLoad && exist(outPath, 'file')
    fprintf('Loading pre-stored samples for model %s on data %s\n', modelName, dataName);
    load(outPath, 'chains', 'stats', 'diagnostics', 'info');
else
    tic;
    [stats, chains, diagnostics, info] = callbayes(engine, ...
        'model', sprintf('%s_%s.txt', modelName, engine), ...
        'data', data, ...
        'outputname', 'samples', ...
        'init', generator, ...
        'datafilename', modelName, ...
        'initfilename', modelName, ...
        'scriptfilename', modelName, ...
        'logfilename', sprintf('/tmp/%s', modelName), ...
        'nchains', nChains, ...
        'nburnin', nBurnin, ...
        'nsamples', nSamples, ...
        'monitorparams', params, ...
        'thin', nThin, ...
        'workingdir', sprintf('/tmp/%s_%s', modelName, dataName), ...
        'verbosity', 0, ...
        'saveoutput', true, ...
        'allowunderscores', 1, ...
        'parallel', doParallel);
    fprintf('%s took %f seconds!\n', upper(engine), toc);
    save(outPath, 'chains', 'stats', 'diagnostics', 'info');
    disp('Convergence statistics:');
    grtable(chains, 1.05);
    disp('Descriptive statistics for all chains:');
    codatable(chains);
end

mu = codatable(chains, 'mu', @mean); %#ok<NASGU>
sigma = codatable(chains, 'sigma', @mean); %#ok<NASGU>
alpha = codatable(chains, 'alpha', @mean); %#ok<NASGU>
fprintf('Saved %s\n', outPath);
