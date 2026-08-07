function report_constrained_debiasing(repoRoot, storageDirs, dataTag)
%REPORT_CONSTRAINED_DEBIASING Compare full / expertise-only / anchoring-only models.
% Also reports the full model fit using anchored individuals only.
%
% Performance metric matches the manuscript performance figure: RMSE of the
% crowd/model estimate vector across questions vs ground truth.
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
w('Performance = RMSE across questions of the estimate vector vs truth\n');
w('(same aggregate metric as the manuscript performance figure).\n');
w('\n');
w('Model variants\n');
w('  full                 person-specific expertise (sigma) and anchoring (alpha)\n');
w('  expertise only       alpha fixed at 0 (no anchoring adjustment)\n');
w('  anchoring only       shared expertise (common sigma), person-specific alpha\n');
w('  full, anchored only  full model fit using only low/high-anchor individuals\n');
w('\n');

w('Baselines (data averages)\n');
w('  %-26s%8.4f\n', 'full crowd RMSE:', crowdFull);
w('  %-26s%8.4f\n', 'anchored crowd RMSE:', crowdHL);
w('  %-26s%8.4f\n', 'no-anchor crowd RMSE:', crowdN);
w('\n');

w('Models\n');
w('  %-33s%-6s %12s  %14s  %14s\n', ...
    'model', 'RMSE', 'vs full model', 'vs full crowd', 'vs anchor crowd');
w('  %s\n', repmat('-', 1, 90));

rows = {
    'full', fullRmse
    'expertise only (alpha=0)', expRmse
    'anchoring only (common sigma)', ancRmse
    'full, anchored individuals only', aoRmse
    };

for i = 1:size(rows, 1)
    label = rows{i, 1};
    rmse = rows{i, 2};
    if ~isfinite(rmse)
        w('  %-33s%-6s %12s  %14s  %14s\n', label, 'NA', 'NA', 'NA', 'NA');
    else
        w('  %-33s%.4f  %12.4f  %14.4f  %14.4f\n', ...
            label, rmse, rmse - fullRmse, rmse - crowdFull, rmse - crowdHL);
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
    yN = d.estimateLong(d.groupLong == noAnchorGroup & d.questionLong == q);
    estFull(q) = mean(yAll(isfinite(yAll)));
    estHL(q) = mean(yHL(isfinite(yHL)));
    estN(q) = mean(yN(isfinite(yN)));
end
crowdFull = sqrt(mean((estFull - truth).^2));
crowdHL = sqrt(mean((estHL - truth).^2));
crowdN = sqrt(mean((estN - truth).^2));
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
