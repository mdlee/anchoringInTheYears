%% run_percentageEstimationF2025
% Fit models and write figures for one of:
%   percentageEstimationF2025  COGS140J F2025 slider 0% vs 100%, W2024 no-anchor
%   barrera                    Barrera-Lemarchand Experiment 2 (figures from stored samples)
%   anchorYearsF2026           COGS140J F2026 event-years
%
% F2026 asks the same 11 event-year questions as the original anchor-years
% study. The two anchors on each question are the 1st and 99th percentiles of
% that study's no-anchor group. F2026 has no no-anchor condition (anchored forms only).
%
% Comment entries in dataList in or out. Lives under data/; run from anywhere.

clear; close all;

forceRefit = false;

dataList = {
    % 'percentageEstimationF2025'
    % 'barrera'
    'anchorYearsF2026'
    };

% Analyses that do not apply to a dataset are skipped inside that plotter.
analysisList = {
    'diversityPredictionTheorem'
    'anchoringIndex'
    'allQanchoring'
    'allQanchoringReplication'   % original vs F2026 dual forest (from analyses.m)
    'performance'
    'expertiseVsAnchoring'
    'outlierRuleComparison'
    'debiasingVsAnchoredPerQuestion'
    'constrainedDebiasing'
    'aggregateAnchorBF'
    };

scriptDir = fileparts(mfilename('fullpath'));
if isfolder(fullfile(scriptDir, 'analyses')) && isfolder(fullfile(scriptDir, 'data'))
    repoRoot = scriptDir;
elseif isfolder(fullfile(scriptDir, '..', 'analyses'))
    repoRoot = fileparts(scriptDir);
elseif isfolder(fullfile(pwd, 'data')) && isfolder(fullfile(pwd, 'analyses'))
    repoRoot = pwd;
else
    error('Could not locate repository root from %s', scriptDir);
end
fprintf('Repo root: %s\n', repoRoot);

addpath(fullfile(repoRoot, 'analyses'));
addpath(fullfile(repoRoot, 'analyses', 'lib'));
addpath('/home/mdlee/Dropbox/MatlabAddOns');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master/codatools');
addpath(fullfile(repoRoot, 'analyses', 'lib'), '-begin');

fineTune = default_fine_tune();
storageDirs = find_mcmc_storage(repoRoot);

for dataIdx = 1:numel(dataList)
    dataName = dataList{dataIdx};
    fprintf('\n=== Dataset: %s ===\n', dataName);
    switch dataName
        case 'percentageEstimationF2025'
            run_percentage_f2025(repoRoot, storageDirs, analysisList, fineTune, forceRefit);
        case 'barrera'
            run_barrera(repoRoot, storageDirs, analysisList, fineTune);
        case 'anchorYearsF2026'
            run_anchor_years_f2026(repoRoot, storageDirs, analysisList, fineTune, forceRefit);
        otherwise
            warning('Unknown dataset: %s', dataName);
    end
end

fprintf('\nAll done.\n');

function run_percentage_f2025(repoRoot, storageDirs, analysisList, fineTune, forceRefit)
fprintf('\n=== Fitting anchoring-index models ===\n');
cd(fullfile(repoRoot, 'models', 'anchoringIndex'));
isolated_run(fullfile(repoRoot, 'models', 'anchoringIndex', 'anchoringIndex_percentageEstimationF2025.m'));

fprintf('\n=== Fitting debiasing model ===\n');
cd(fullfile(repoRoot, 'models', 'debiasing'));
isolated_run(fullfile(repoRoot, 'models', 'debiasing', 'debiasing_percentageEstimationF2025.m'));

fprintf('\n=== Fitting constrained debiasing variants ===\n');
fit_constrained_debiasing(forceRefit, 'percentageEstimationF2025');
fit_anchored_only_debiasing(forceRefit, 'percentageEstimationF2025AnchoredOnly');
fit_aggregate_lr_bf(forceRefit);

fprintf('\n=== Generating figures and reports ===\n');
plot_percentage_estimation_f2025_manuscript(repoRoot, storageDirs, true, analysisList, fineTune);
end

function run_barrera(repoRoot, storageDirs, analysisList, fineTune)
fprintf('Barrera figures use the stored anchoring-index and debiasing samples.\n');
plot_barrera_manuscript(repoRoot, storageDirs, true, analysisList, fineTune);
end

function run_anchor_years_f2026(repoRoot, storageDirs, analysisList, fineTune, forceRefit)
fprintf('\n=== Preparing F2026 data (contaminant removal) ===\n');
prepare_anchor_years_f2026(repoRoot);

csvPath = fullfile(repoRoot, 'data', 'anchorYearsF2026Long.csv');
fprintf('\n=== Fitting anchoring-index models ===\n');
fit_anchoring_index_years(repoRoot, csvPath, 'anchorYearsF2026', forceRefit);

fprintf('\n=== Fitting debiasing model ===\n');
fit_debiasing_from_csv(repoRoot, csvPath, 'anchorYearsF2026', forceRefit);

fprintf('\n=== Fitting constrained debiasing variants ===\n');
fit_constrained_debiasing(forceRefit, 'anchorYearsF2026');
fit_anchored_only_debiasing(forceRefit, 'anchorYearsF2026AnchoredOnly');

fprintf('\n=== Generating figures and reports ===\n');
plot_anchor_years_f2026_manuscript(repoRoot, storageDirs, true, analysisList, fineTune);
end

function isolated_run(scriptFile)
% Run a script that calls clear without clearing the caller's workspace.
run(scriptFile);
end
