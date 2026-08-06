function [omegaHL, omegaN, deltaHL, deltaN, epsilon2HL, epsilon2N] = ...
    load_or_compute_diversity(storageDirs, fileName, yLo, yHi, yNo, truth, nReps)
%LOAD_OR_COMPUTE_DIVERSITY Use cached diversityAccuracy mat or recompute.

if nargin < 7
    nReps = 1e4;
end

path = resolve_storage_file(storageDirs, fileName);
yHiLo = [yHi(:)', yLo(:)'];
if ~isempty(path)
    S = load(path, 'omegaHL', 'omegaN', 'deltaHL', 'deltaN', 'epsilon2HL', 'epsilon2N');
    if size(S.omegaHL, 1) == numel(yHiLo) && size(S.omegaN, 1) == numel(yNo)
        omegaHL = S.omegaHL;
        omegaN = S.omegaN;
        deltaHL = S.deltaHL;
        deltaN = S.deltaN;
        epsilon2HL = S.epsilon2HL;
        epsilon2N = S.epsilon2N;
        return;
    end
end

fprintf('Computing diversity metrics (%d reps) for %s ...\n', nReps, fileName);
M = compute_diversity_metrics(yLo(:)', yHi(:)', yNo(:)', truth, nReps);
omegaHL = M.omegaHL;
omegaN = M.omegaN;
deltaHL = M.deltaHL;
deltaN = M.deltaN;
epsilon2HL = M.epsilon2HL;
epsilon2N = M.epsilon2N;
end
