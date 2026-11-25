function outFile = fit_debiasing_from_csv(repoRoot, csvPath, dataName, forceRefit)
%FIT_DEBIASING_FROM_CSV Fit debiasing_jags.txt on a long-format CSV.
% Writes models/debiasing/storage/debiasing_<dataName>_jags.mat.

if nargin < 4
    forceRefit = false;
end

addpath('/home/mdlee/Dropbox/MatlabAddOns');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master/codatools');

modelDir = fullfile(repoRoot, 'models', 'debiasing');
storageDir = fullfile(modelDir, 'storage');
if ~isfolder(storageDir)
    mkdir(storageDir);
end

engine = 'jags';
modelName = 'debiasing';
outFile = fullfile(storageDir, sprintf('%s_%s_%s.mat', modelName, dataName, engine));
if ~forceRefit && isfile(outFile)
    fprintf('Already exists: %s\n', outFile);
    return;
end

[participant, question, version, anchor, estimate] = read_long_csv(csvPath);
anchor(~isfinite(anchor)) = 0;
nPeople = numel(unique(participant));

data = struct( ...
    'participant', participant, ...
    'question', question, ...
    'anchor', anchor, ...
    'y', estimate, ...
    'version', version);
generator = @() struct('alpha', rand(nPeople, 1));

tmpDir = fullfile(tempdir, [modelName '_' dataName]);
if ~isfolder(tmpDir)
    mkdir(tmpDir);
end

fprintf('Fitting %s on %s\n', modelName, dataName);
fprintf('  nTrials=%d  nParticipants=%d  nQuestions=%d\n', ...
    numel(estimate), nPeople, numel(unique(question)));
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
    'monitorparams', {'mu', 'sigma', 'alpha'}, ...
    'thin', 1, ...
    'workingdir', tmpDir, ...
    'verbosity', 0, ...
    'saveoutput', true, ...
    'allowunderscores', 1, ...
    'parallel', 1); %#ok<ASGLU>
fprintf('%s took %.1f seconds.\n', upper(engine), toc);
save(outFile, 'chains', 'stats', 'diagnostics', 'info');
fprintf('Saved %s\n', outFile);
disp('Convergence statistics:');
grtable(chains, 1.05);
end

function [participant, question, version, anchor, estimate] = read_long_csv(csvPath)
D = readtable(csvPath);
participant = D{:, 1};
question = D{:, 2};
version = D{:, 3};
anchor = D{:, 5};
estimate = D{:, 7};
participant = participant(:);
question = question(:);
version = version(:);
anchor = anchor(:);
estimate = estimate(:);
end
