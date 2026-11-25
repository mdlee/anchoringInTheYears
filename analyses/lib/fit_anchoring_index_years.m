function fit_anchoring_index_years(repoRoot, csvPath, dataTag, forceRefit)
%FIT_ANCHORING_INDEX_YEARS Per-question anchoring-index fits on a year scale.
% High vs low is anchor above vs below the question truth (version 3 dropped).
% Writes models/anchoringIndex/storage/anchoringIndex_<dataTag>_<q>_jags.mat.

if nargin < 4
    forceRefit = false;
end

addpath('/home/mdlee/Dropbox/MatlabAddOns');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master/codatools');

modelDir = fullfile(repoRoot, 'models', 'anchoringIndex');
storageDir = fullfile(modelDir, 'storage');
if ~isfolder(storageDir)
    mkdir(storageDir);
end

D = readtable(csvPath);
question = D{:, 2};
version = D{:, 3};
truth = D{:, 4};
anchor = D{:, 5};
estimate = D{:, 7};

engine = 'jags';
modelPath = fullfile(modelDir, 'anchoringIndex_years_jags.txt');
params = {'A', 'Aprior'};
generator = @() struct('A', rand);

nQuestions = max(question);
for qIdx = 1:nQuestions
    matchH = question == qIdx & version ~= 3 & anchor > truth;
    matchL = question == qIdx & version ~= 3 & anchor < truth;
    yH = estimate(matchH);
    yL = estimate(matchL);
    anchorHi = unique(anchor(matchH));
    anchorLo = unique(anchor(matchL));
    outPath = fullfile(storageDir, sprintf('anchoringIndex_%s_%d_%s.mat', dataTag, qIdx, engine));
    if ~forceRefit && isfile(outPath)
        fprintf('Already exists: %s\n', outPath);
        continue;
    end
    if numel(yH) < 2 || numel(yL) < 2 || numel(anchorHi) ~= 1 || numel(anchorLo) ~= 1
        error('Q%d is not a single high/low anchor pair (nH=%d nL=%d nHi=%d nLo=%d)', ...
            qIdx, numel(yH), numel(yL), numel(anchorHi), numel(anchorLo));
    end

    data = struct('yH', yH(:), 'yL', yL(:), 'anchorHi', anchorHi, 'anchorLo', anchorLo);
    tmpDir = fullfile(tempdir, sprintf('anchoringIndex_%s_%d', dataTag, qIdx));
    if ~isfolder(tmpDir)
        mkdir(tmpDir);
    end
    fprintf('Fitting anchoring index Q%d (%s): nH=%d nL=%d anchors %g / %g\n', ...
        qIdx, dataTag, numel(yH), numel(yL), anchorLo, anchorHi);
    tic;
    [stats, chains, diagnostics, info] = callbayes(engine, ...
        'model', modelPath, ...
        'data', data, ...
        'outputname', 'samples', ...
        'init', generator, ...
        'datafilename', 'anchoringIndex_years', ...
        'initfilename', 'anchoringIndex_years', ...
        'scriptfilename', 'anchoringIndex_years', ...
        'logfilename', fullfile(tmpDir, 'anchoringIndex_years'), ...
        'nchains', 8, ...
        'nburnin', 1e3, ...
        'nsamples', 2e4, ...
        'monitorparams', params, ...
        'thin', 1, ...
        'workingdir', tmpDir, ...
        'verbosity', 0, ...
        'saveoutput', true, ...
        'allowunderscores', 1, ...
        'parallel', 1); %#ok<ASGLU>
    fprintf('JAGS Q%d took %.1f seconds.\n', qIdx, toc);
    save(outPath, 'chains', 'stats', 'diagnostics', 'info');
end
fprintf('Anchoring-index samples for %s are in %s\n', dataTag, storageDir);
end
