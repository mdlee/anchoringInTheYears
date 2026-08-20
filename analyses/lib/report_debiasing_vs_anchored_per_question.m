function report_debiasing_vs_anchored_per_question(repoRoot, storageDirs, dataTag)
%REPORT_DEBIASING_VS_ANCHORED_PER_QUESTION Per-question accuracy check.
% Compares the debiasing-model crowd estimate (posterior mean of mu_q) to the
% averaged anchored-crowd estimate for each question. Supports the manuscript
% claim that the model beats the anchored crowd on every event-years question
% (and reports the same comparison for Barrera Exp 2).
%
% Writes:
%   analyses/results/debiasingVsAnchoredPerQuestion/<dataTag>.txt

outDir = results_dir(repoRoot, 'debiasingVsAnchoredPerQuestion');
if ~isfolder(outDir)
    mkdir(outDir);
end
dataDir = fullfile(repoRoot, 'data');

switch dataTag
    case 'anchorYears'
        load(fullfile(dataDir, 'anchorYearsData.mat'), 'd');
        jagsCandidates = {
            'debiasing_anchorYears_jags.mat'
            'anchorYears_7b2_anchorYears_jags.mat'
            };
        fileStem = 'anchorYears';
        titleLine = 'Event-years (Lee & Dang): anchoring model vs anchor crowd';
        % Anchored groups in long data: 1 = low, 2 = high (3 = no anchor)
        anchoredGroups = [1 2];

    case 'barrera'
        load(fullfile(dataDir, 'barreraEtAlExp2.mat'), 'd');
        d = ensure_navajas_estimate_cells(d);
        if ~isfield(d, 'questionLabels') || numel(d.questionLabels) < d.nQuestions
            d.questionLabels = navajas_exp2_question_labels();
        end
        jagsCandidates = {
            'debiasing_barreraEtAlExperiment2_jags.mat'
            'debiasingNavajas_6_navajasExperiment2_jags.mat'
            };
        fileStem = 'barreraLemarchandExperiment2';
        titleLine = 'Barrera-Lemarchand Exp 2: anchoring model vs anchor crowd';
        anchoredGroups = [1 2];

    case 'percentageEstimationF2025'
        load(fullfile(dataDir, 'percentageEstimationF2025.mat'), 'd');
        if ~isfield(d, 'questionLabels') || numel(d.questionLabels) < d.nQuestions
            d.questionLabels = f2025_question_labels();
        end
        jagsCandidates = {
            'debiasing_percentageEstimationF2025_jags.mat'
            };
        fileStem = 'percentageEstimationF2025';
        titleLine = 'COGS140J F2025 percentageEstimation: anchoring model vs anchor crowd';
        anchoredGroups = [1 2];

    otherwise
        error('report_debiasing_vs_anchored_per_question:UnknownData', ...
            'Unknown dataTag: %s', dataTag);
end

jagsPath = '';
for i = 1:numel(jagsCandidates)
    jagsPath = resolve_storage_file(storageDirs, jagsCandidates{i});
    if ~isempty(jagsPath), break; end
end
if isempty(jagsPath)
    error('report_debiasing_vs_anchored_per_question:MissingMCMC', ...
        'Missing debiasing MCMC for %s (tried: %s)', dataTag, strjoin(jagsCandidates, ', '));
end

fprintf('Loading %s\n', jagsPath);
S = load(jagsPath, 'chains');
chains = S.chains;

nQ = d.nQuestions;
truth = d.truth(:);
crowdHL = nan(nQ, 1);
modelMu = nan(nQ, 1);
errHL = nan(nQ, 1);
errMu = nan(nQ, 1);
nAnchored = nan(nQ, 1);
modelBetter = false(nQ, 1);

for qIdx = 1:nQ
    yHL = d.estimateLong(ismember(d.groupLong, anchoredGroups) & d.questionLong == qIdx);
    yHL = yHL(isfinite(yHL));
    nAnchored(qIdx) = numel(yHL);
    crowdHL(qIdx) = mean(yHL);
    modelMu(qIdx) = mean(chains.(sprintf('mu_%d', qIdx))(:));
    errHL(qIdx) = abs(crowdHL(qIdx) - truth(qIdx));
    errMu(qIdx) = abs(modelMu(qIdx) - truth(qIdx));
    modelBetter(qIdx) = errMu(qIdx) < errHL(qIdx);
end

outTxt = fullfile(outDir, [fileStem '.txt']);
fid = fopen(outTxt, 'w');
if fid < 0
    error('Could not open %s for writing', outTxt);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

w = @(varargin) local_writef(fid, varargin{:});

w('%s\n', titleLine);
w('Absolute error |estimate - truth| per question.\n');
w('anchor crowd = mean of low- and high-anchor estimates for that question.\n');
w('anchoring model = posterior mean of mu_q.\n');
w('MCMC: %s\n', jagsPath);
w('\n');
w('%-4s %-28s %8s %10s %10s %10s %10s %8s\n', ...
    'Q', 'label', 'truth', 'anchor', 'model', '|errA|', '|errM|', 'modelWin');
w('%s\n', repmat('-', 1, 104));

for qIdx = 1:nQ
    if isfield(d, 'questionLabels') && numel(d.questionLabels) >= qIdx
        lab = d.questionLabels{qIdx};
    else
        lab = sprintf('Q%d', qIdx);
    end
    lab = char(lab);
    if numel(lab) > 28
        lab = lab(1:28);
    end
    w('%-4d %-28s %8.2f %10.2f %10.2f %10.2f %10.2f %8d\n', ...
        qIdx, lab, truth(qIdx), crowdHL(qIdx), modelMu(qIdx), ...
        errHL(qIdx), errMu(qIdx), modelBetter(qIdx));
end

nWin = sum(modelBetter);
w('\nSummary\n');
w('  Questions:              %d\n', nQ);
w('  Model better (abs err): %d / %d\n', nWin, nQ);
w('  Ties / worse:          %d\n', nQ - nWin);
w('  anchor crowd RMSE:      %.4f\n', sqrt(mean((crowdHL - truth).^2)));
w('  anchoring model RMSE:   %.4f\n', sqrt(mean((modelMu - truth).^2)));

if nWin == nQ
    w('\nClaim check: YES — model more accurate on every question.\n');
else
    worse = find(~modelBetter);
    w('\nClaim check: NO — model not better on question(s): %s\n', mat2str(worse(:)'));
end

fprintf('Wrote %s\n', outTxt);
fprintf('  Model better on %d / %d questions\n', nWin, nQ);
end

function local_writef(fid, varargin)
line = sprintf(varargin{:});
fprintf('%s', line);
fprintf(fid, '%s', line);
end
