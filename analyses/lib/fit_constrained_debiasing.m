function outFiles = fit_constrained_debiasing(forceRefit, dataName)
%FIT_CONSTRAINED_DEBIASING Fit expertise-only (alpha=0) and anchoring-only
% (common sigma) variants. Saves under models/debiasing/storage/.
%
% dataName defaults to percentageEstimationF2025 (F2025 slider + W2024 no-anchor).
% Pass 'anchorYearsF2026' to fit the F2026 event-years files instead.

if nargin < 1
    forceRefit = false;
end
if nargin < 2 || isempty(dataName)
    dataName = 'percentageEstimationF2025';
end

thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(thisDir));
addpath('/home/mdlee/Dropbox/MatlabAddOns');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master/codatools');

modelDir = fullfile(repoRoot, 'models', 'debiasing');
storageDir = fullfile(modelDir, 'storage');
if ~isfolder(storageDir)
    mkdir(storageDir);
end

jobs = {
    struct('dataName', 'percentageEstimationF2025', ...
        'variant', 'alpha0', ...
        'csv', fullfile(repoRoot, 'data', 'percentageEstimationF2025Long.csv'), ...
        'nSamples', 2e4)
    struct('dataName', 'percentageEstimationF2025', ...
        'variant', 'commonSigma', ...
        'csv', fullfile(repoRoot, 'data', 'percentageEstimationF2025Long.csv'), ...
        'nSamples', 2e4)
    struct('dataName', 'anchorYearsF2026', ...
        'variant', 'alpha0', ...
        'csv', fullfile(repoRoot, 'data', 'anchorYearsF2026Long.csv'), ...
        'nSamples', 2e4)
    struct('dataName', 'anchorYearsF2026', ...
        'variant', 'commonSigma', ...
        'csv', fullfile(repoRoot, 'data', 'anchorYearsF2026Long.csv'), ...
        'nSamples', 2e4)
    };
keepJob = false(1, numel(jobs));
for j = 1:numel(jobs)
    keepJob(j) = strcmp(jobs{j}.dataName, dataName);
end
jobs = jobs(keepJob);
if isempty(jobs)
    error('No constrained-debiasing jobs for %s', dataName);
end

outFiles = {};
for j = 1:numel(jobs)
    outFiles{end+1} = fit_one(jobs{j}, modelDir, storageDir, forceRefit); %#ok<AGROW>
end
end

function outFile = fit_one(job, modelDir, storageDir, forceRefit)
engine = 'jags';
modelName = sprintf('debiasing_%s', job.variant);
modelPath = fullfile(modelDir, sprintf('%s_jags.txt', modelName));
outFile = fullfile(storageDir, sprintf('%s_%s_%s.mat', modelName, job.dataName, engine));
if ~forceRefit && isfile(outFile)
    fprintf('Already exists: %s\n', outFile);
    return;
end
if ~isfile(modelPath)
    error('Missing model file: %s', modelPath);
end

D = readtable(job.csv);
participant = D{:, 1};
question = D{:, 2};
version = D{:, 3};
anchor = D{:, 5};
estimate = D{:, 7};
anchor(~isfinite(anchor)) = 0;
nPeople = numel(unique(participant));

data = struct( ...
    'participant', participant, ...
    'question', question, ...
    'anchor', anchor, ...
    'y', estimate, ...
    'version', version);

switch job.variant
    case 'commonSigma'
        params = {'mu', 'sigma', 'alpha'};
        generator = @() struct('alpha', rand(nPeople, 1));
    case 'alpha0'
        params = {'mu', 'sigma'};
        generator = @() struct('dummy', randn);
    otherwise
        error('Unknown variant %s', job.variant);
end

tmpDir = fullfile(tempdir, [modelName '_' job.dataName]);
if ~isfolder(tmpDir)
    mkdir(tmpDir);
end

fprintf('Fitting %s on %s\n', modelName, job.dataName);
fprintf('  nTrials=%d  nParticipants=%d  nQuestions=%d\n', ...
    numel(estimate), nPeople, numel(unique(question)));
tic;
[stats, chains, diagnostics, info] = callbayes(engine, ...
    'model', modelPath, ...
    'data', data, ...
    'outputname', 'samples', ...
    'init', generator, ...
    'datafilename', modelName, ...
    'initfilename', modelName, ...
    'scriptfilename', modelName, ...
    'logfilename', fullfile(tmpDir, modelName), ...
    'nchains', 8, ...
    'nburnin', 1e3, ...
    'nsamples', job.nSamples, ...
    'monitorparams', params, ...
    'thin', 1, ...
    'workingdir', tmpDir, ...
    'verbosity', 0, ...
    'saveoutput', true, ...
    'allowunderscores', 1, ...
    'parallel', 1);
fprintf('%s took %.1f seconds.\n', upper(engine), toc);

save(outFile, 'chains', 'stats', 'diagnostics', 'info');
fprintf('Saved %s\n', outFile);
disp('Convergence statistics:');
grtable(chains, 1.05);
end
