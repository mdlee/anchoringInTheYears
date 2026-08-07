function outFiles = fit_anchored_only_debiasing(forceRefit)
%FIT_ANCHORED_ONLY_DEBIASING Fit the full debiasing model on anchored data only.
% Saves under models/debiasing/storage/ so analyses/find_mcmc_storage can find it.
%
% Event years and Barrera Exp 2: keep trials with version ~= 3 (no-anchor).

if nargin < 1
    forceRefit = false;
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
modelPath = fullfile(modelDir, 'debiasing_jags.txt');

jobs = {
    struct('dataName', 'anchorYearsAnchoredOnly', ...
        'csv', fullfile(repoRoot, 'data', 'anchorYearsDecontaminatedLong.csv'), ...
        'nSamples', 2e4)
    struct('dataName', 'barreraEtAlExperiment2AnchoredOnly', ...
        'csv', fullfile(repoRoot, 'data', 'barreraEtAlExperiment2Long.csv'), ...
        'nSamples', 2e4)
    };

outFiles = {};
for j = 1:numel(jobs)
    outFiles{end+1} = fit_one(jobs{j}, modelPath, storageDir, forceRefit); %#ok<AGROW>
end
end

function outFile = fit_one(job, modelPath, storageDir, forceRefit)
engine = 'jags';
modelName = 'debiasing';
outFile = fullfile(storageDir, sprintf('%s_%s_%s.mat', modelName, job.dataName, engine));
if ~forceRefit && isfile(outFile)
    fprintf('Already exists: %s\n', outFile);
    return;
end

D = readtable(job.csv);
participant = D{:, 1};
question = D{:, 2};
version = D{:, 3};
anchor = D{:, 5};
estimate = D{:, 7};

keep = version ~= 3;
participant = participant(keep);
question = question(keep);
version = version(keep);
anchor = anchor(keep);
estimate = estimate(keep);

% Reindex participants to 1:n continuously (required by JAGS loops)
[uPart, ~, participant] = unique(participant);
nPeople = numel(uPart);
anchor(~isfinite(anchor)) = 0;

data = struct( ...
    'participant', participant, ...
    'question', question, ...
    'anchor', anchor, ...
    'y', estimate, ...
    'version', version);

params = {'mu', 'sigma', 'alpha'};
generator = @() struct('alpha', rand(nPeople, 1));

tmpDir = fullfile(tempdir, ['debiasing_' job.dataName]);
if ~isfolder(tmpDir)
    mkdir(tmpDir);
end

fprintf('Fitting full debiasing model on anchored-only data: %s\n', job.dataName);
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
