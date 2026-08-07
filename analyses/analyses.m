%% analyses
% Consolidated results generation for this repository.
%
% Combines analyses previously split across
%   CC2/code/anchorYears/anchorYears_0.m
%   CC2/code/anchorYears/anchorYearsNavajas_0.m
%
% Outputs go under analyses/results/<analysisName>/{png,eps}/
% (plus any non-figure artifacts such as contaminantVsOutlier.txt).
%
% Comment entries in/out of dataList and analysisList to choose what to run.
% Some analyses apply to only one dataset; choose combinations that make sense.

clear; close all;

printFigures = true;

%% Fine tune
% Adjust figure styling here; more knobs can be added later.
fineTune.font.diversityPredictionTheorem = 24;  % two-panel DPT figures (axis); labels use +2 / annotations -2
fineTune.font.anchoringIndex          = 24;  % Firefox prior/posterior (axis); xlabel +2
fineTune.font.allQanchoring           = 24;  % event-years all-question forest (BF text -2)
fineTune.font.allQanchoringBarrera    = 18;  % Barrera all-question forest (BF text -4)
fineTune.font.performance             = 16;  % performance comparison (xlabel +2)
fineTune.font.debiasingModel          = 18;  % debiasing schematic (labels +2)
fineTune.font.expertiseVsAnchoring    = 16;  % expertise–anchoring scatter (axis labels +2)
fineTune.font.outlierRuleComparison   = 12;  % outlier-rule bar chart

%% Paths
thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(thisDir);
addpath(thisDir);
addpath(fullfile(thisDir, 'lib'));
addpath('/home/mdlee/Dropbox/MatlabAddOns');
addpath('/home/mdlee/Dropbox/MatlabAddOns/trinity-master/codatools');

storageDirs = find_mcmc_storage(repoRoot);
fprintf('Using storage dirs:\n');
fprintf('  %s\n', storageDirs{:});

%% Datasets (comment in/out)
dataList = {
   'anchorYears'   % event-years experiment
   'barrera'       % Barrera-Lemarchand Experiment 2
   };

%% Analyses (comment in/out)
% Each analysis writes under analyses/results/<name>/
%   diversityPredictionTheorem — both
%   anchoringIndex          — anchorYears only (Firefox prior/posterior); writes anchoringIndex/
%   allQanchoring           — both; also writes under anchoringIndex/
%   performance             — both
%   debiasingModel          — schematic; dataset-independent
%   expertiseVsAnchoring    — both (additional / not in paper)
%   outlierRuleComparison   — anchorYears only (additional / not in paper)
%   debiasingVsAnchoredPerQuestion — both; text report of per-question accuracy
%   constrainedDebiasing — both; text report of expertise-only / anchoring-only /
%       full / full-anchored-only RMSE vs crowd averages and full model
analysisList = {
   % 'diversityPredictionTheorem'
   % 'anchoringIndex'
   % 'allQanchoring'
   % 'performance'
   % 'debiasingModel'
   % 'expertiseVsAnchoring'
   % 'outlierRuleComparison'
   % 'debiasingVsAnchoredPerQuestion'
   'constrainedDebiasing'
   };

%% Draw
for dataIdx = 1:numel(dataList)
   dataName = dataList{dataIdx};
   fprintf('\n=== Dataset: %s ===\n', dataName);
   switch dataName
      case 'anchorYears'
         plot_anchor_years_manuscript(repoRoot, storageDirs, printFigures, analysisList, fineTune);
      case 'barrera'
         plot_barrera_manuscript(repoRoot, storageDirs, printFigures, analysisList, fineTune);
      otherwise
         warning('Unknown dataset: %s', dataName);
   end
end

fprintf('\nDone. Outputs are under analyses/results/<analysis>/{png,eps}.\n');
