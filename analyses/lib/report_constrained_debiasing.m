function report_constrained_debiasing(repoRoot, storageDirs, dataTag)
%REPORT_CONSTRAINED_DEBIASING Compare full / expertise-only / anchoring-only models.
% Also reports the full model fit using anchored individuals only.
%
% Performance metric: RMSE of the crowd/model estimate vector across
% questions vs ground truth.
%
% Writes:
%   analyses/results/constrainedDebiasing/<dataTag>.txt

outDir = results_dir(repoRoot, 'constrainedDebiasing');
if ~isfolder(outDir)
    mkdir(outDir);
end
dataDir = fullfile(repoRoot, 'data');

switch dataTag
    case 'anchorYears'
        load(fullfile(dataDir, 'anchorYearsData.mat'), 'd');
        fileStem = 'anchorYears';
        titleLine = 'Event-years (Lee & Dang): constrained debiasing model comparison';
        fullCandidates = {
            'debiasing_anchorYears_jags.mat'
            'anchorYears_7b2_anchorYears_jags.mat'
            'anchorYears_7b2_anchorYearsF2025_jags.mat'
            };
        expertiseCandidates = {
            'anchorYears_alpha0_anchorYears_jags.mat'
            'debiasing_alpha0_anchorYears_jags.mat'
            };
        anchoringCandidates = {
            'anchorYears_commonSigma_anchorYears_jags.mat'
            'debiasing_commonSigma_anchorYears_jags.mat'
            };
        anchoredOnlyCandidates = {
            'debiasing_anchorYearsAnchoredOnly_jags.mat'
            'anchorYears_7b2_anchorYearsAnchoredOnly_jags.mat'
            };
        noAnchorGroupLong = 3;
        anchoredGroupLong = [1 2];

    case 'barrera'
        load(fullfile(dataDir, 'barreraEtAlExp2.mat'), 'd');
        d = ensure_navajas_estimate_cells(d);
        if ~isfield(d, 'questionLabels') || numel(d.questionLabels) < d.nQuestions
            d.questionLabels = navajas_exp2_question_labels();
        end
        fileStem = 'barreraLemarchandExperiment2';
        titleLine = 'Barrera-Lemarchand Exp 2: constrained debiasing model comparison';
        fullCandidates = {
            'debiasing_barreraEtAlExperiment2_jags.mat'
            'debiasingNavajas_6_navajasExperiment2_jags.mat'
            };
        expertiseCandidates = {
            'debiasingNavajas_alpha0_navajasExperiment2_jags.mat'
            'debiasing_alpha0_barreraEtAlExperiment2_jags.mat'
            };
        anchoringCandidates = {
            'debiasingNavajas_commonSigma_navajasExperiment2_jags.mat'
            'debiasing_commonSigma_barreraEtAlExperiment2_jags.mat'
            };
        anchoredOnlyCandidates = {
            'debiasing_barreraEtAlExperiment2AnchoredOnly_jags.mat'
            'debiasingNavajas_6_navajasExperiment2AnchoredOnly_jags.mat'
            };
        noAnchorGroupLong = 3;
        anchoredGroupLong = [1 2];

    case 'percentageEstimationF2025'
        load(fullfile(dataDir, 'percentageEstimationF2025.mat'), 'd');
        if ~isfield(d, 'questionLabels') || numel(d.questionLabels) < d.nQuestions
            d.questionLabels = f2025_question_labels();
        end
        fileStem = 'percentageEstimationF2025';
        titleLine = 'COGS140J F2025 percentageEstimation: constrained debiasing model comparison';
        fullCandidates = {
            'debiasing_percentageEstimationF2025_jags.mat'
            };
        expertiseCandidates = {
            'debiasing_alpha0_percentageEstimationF2025_jags.mat'
            };
        anchoringCandidates = {
            'debiasing_commonSigma_percentageEstimationF2025_jags.mat'
            };
        anchoredOnlyCandidates = {
            'debiasing_percentageEstimationF2025AnchoredOnly_jags.mat'
            };
        noAnchorGroupLong = 3;
        anchoredGroupLong = [1 2];

    case 'anchorYearsF2026'
        load(fullfile(dataDir, 'anchorYearsF2026.mat'), 'd');
        fileStem = 'anchorYearsF2026';
        titleLine = 'COGS140J F2026 event-years: constrained debiasing model comparison';
        fullCandidates = {
            'debiasing_anchorYearsF2026_jags.mat'
            };
        expertiseCandidates = {
            'debiasing_alpha0_anchorYearsF2026_jags.mat'
            };
        anchoringCandidates = {
            'debiasing_commonSigma_anchorYearsF2026_jags.mat'
            };
        anchoredOnlyCandidates = {
            'debiasing_anchorYearsF2026AnchoredOnly_jags.mat'
            };
        noAnchorGroupLong = 3;
        anchoredGroupLong = [1 2];

    otherwise
        error('report_constrained_debiasing:UnknownData', 'Unknown dataTag: %s', dataTag);
end

[crowdFull, crowdHL, crowdN] = crowd_rmses(d, anchoredGroupLong, noAnchorGroupLong);

[~, fullRmse] = load_model_rmse(storageDirs, fullCandidates, d.truth);
[~, expRmse] = load_model_rmse(storageDirs, expertiseCandidates, d.truth);
[~, ancRmse] = load_model_rmse(storageDirs, anchoringCandidates, d.truth);
[~, aoRmse] = load_model_rmse(storageDirs, anchoredOnlyCandidates, d.truth);

outTxt = fullfile(outDir, [fileStem '.txt']);
fid = fopen(outTxt, 'w');
if fid < 0
    error('Could not open %s for writing', outTxt);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
w = @(varargin) local_writef(fid, varargin{:});

w('%s\n', titleLine);
w('Performance = RMSE across questions of the estimate vector vs truth.\n');
w('\n');
w('Model variants\n');
w('  anchoring model                 person-specific expertise (sigma) and anchoring (alpha)\n');
w('  expertise only                  alpha fixed at 0 (no anchoring adjustment)\n');
w('  anchoring only                  shared expertise (common sigma), person-specific alpha\n');
w('  anchoring model, anchored only  full model fit using only low/high-anchor individuals\n');
w('\n');

w('  %-36s%s\n', 'method', 'RMSE');
w('  %s\n', repmat('-', 1, 45));

rows = {
    'full crowd', crowdFull
    'anchor crowd', crowdHL
    'no-anchor crowd', crowdN
    'anchoring model', fullRmse
    'expertise only', expRmse
    'anchoring only', ancRmse
    'anchoring model, anchored only', aoRmse
    };

for i = 1:size(rows, 1)
    label = rows{i, 1};
    rmse = rows{i, 2};
    if ~isfinite(rmse)
        w('  %-36s%s\n', label, 'NA');
    else
        w('  %-36s%.4f\n', label, rmse);
    end
end

if ~isfinite(aoRmse)
    fprintf('Note: anchored-only full-model samples were not found for %s.\n', dataTag);
    fprintf('Run analyses/lib/fit_anchored_only_debiasing.m then re-run this report.\n');
end

fprintf('Wrote %s\n', outTxt);
end

function [crowdFull, crowdHL, crowdN] = crowd_rmses(d, anchoredGroups, noAnchorGroup)
nQ = d.nQuestions;
truth = d.truth(:);
estFull = nan(nQ, 1);
estHL = nan(nQ, 1);
estN = nan(nQ, 1);
for q = 1:nQ
    yAll = d.estimateLong(d.questionLong == q);
    yHL = d.estimateLong(ismember(d.groupLong, anchoredGroups) & d.questionLong == q);
    if noAnchorGroup > 0
        yN = d.estimateLong(d.groupLong == noAnchorGroup & d.questionLong == q);
        estN(q) = mean(yN(isfinite(yN)));
    end
    estFull(q) = mean(yAll(isfinite(yAll)));
    estHL(q) = mean(yHL(isfinite(yHL)));
end
crowdFull = sqrt(mean((estFull - truth).^2));
crowdHL = sqrt(mean((estHL - truth).^2));
if noAnchorGroup > 0
    crowdN = sqrt(mean((estN - truth).^2));
else
    crowdN = NaN;
end
end

function [path, rmse] = load_model_rmse(storageDirs, candidates, truth)
path = '';
for i = 1:numel(candidates)
    path = resolve_storage_file(storageDirs, candidates{i});
    if ~isempty(path), break; end
end
if isempty(path)
    rmse = NaN;
    return;
end
S = load(path, 'chains');
rmse = model_rmse_from_mu(S.chains, truth);
end

function local_writef(fid, varargin)
line = sprintf(varargin{:});
fprintf('%s', line);
fprintf(fid, '%s', line);
end
