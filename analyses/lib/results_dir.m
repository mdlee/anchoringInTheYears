function outDir = results_dir(repoRoot, analysisName)
%RESULTS_DIR Return analyses/results/<analysisName> for an analyses script run.
outDir = fullfile(repoRoot, 'analyses', 'results', analysisName);
end
