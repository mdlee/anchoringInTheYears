%% run_percentageEstimationF2025
% Fit models then generate all manuscript-style figures/reports for the
% COGS140J F2025 percentageEstimation slider-anchor data.
%
% Run from anywhere; paths are resolved from this file's location.

clear; close all;

thisFile = mfilename('fullpath');
repoRoot = fileparts(thisFile);
if ~isfolder(fullfile(repoRoot, 'data'))
    % Fallback if run from analyses/ or models/
    if isfolder(fullfile(pwd, 'data'))
        repoRoot = pwd;
    elseif isfolder(fullfile(pwd, '..', 'data'))
        repoRoot = fileparts(pwd);
    end
end

fprintf('Repo root: %s\n', repoRoot);

%% 1) Anchoring-index fits (25 questions)
fprintf('\n=== Fitting anchoring-index models ===\n');
cd(fullfile(repoRoot, 'models', 'anchoringIndex'));
anchoringIndex_percentageEstimationF2025;

%% 2) Debiasing model fit
fprintf('\n=== Fitting debiasing model ===\n');
cd(fullfile(repoRoot, 'models', 'debiasing'));
debiasing_percentageEstimationF2025;

%% 2b) Constrained / nested debiasing variants
fprintf('\n=== Fitting constrained debiasing variants ===\n');
addpath(fullfile(repoRoot, 'analyses', 'lib'));
fit_constrained_debiasing(false);      % expertise-only + anchoring-only
fit_anchored_only_debiasing(false);    % full model on anchored participants only
fit_aggregate_lr_bf(false);            % overall L vs R mean-difference BF

%% 3) Figures / reports
fprintf('\n=== Generating figures and reports ===\n');
cd(fullfile(repoRoot, 'analyses'));
% analyses.m is already set to percentageEstimationF2025 with full analysisList
analyses;

fprintf('\nAll done for percentageEstimationF2025.\n');
