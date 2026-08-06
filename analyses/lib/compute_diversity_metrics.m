function M = compute_diversity_metrics(yLo, yHi, yNo, truth, nReps)
%COMPUTE_DIVERSITY_METRICS Crowd error, diversity, and individual error.
if nargin < 5
    nReps = 1e4;
end
rng(1);

yHiLo = [yHi, yLo];
truth = truth(1);

M.epsilon2HL = mean((yHiLo - truth).^2);
M.epsilon2N = mean((yNo - truth).^2);

nHL = numel(yHiLo);
nN = numel(yNo);

M.omegaHL = nan(nHL, nReps);
M.deltaHL = nan(nHL, nReps);
M.omegaN = nan(nN, nReps);
M.deltaN = nan(nN, nReps);

for sIdx = 1:nHL
    for rIdx = 1:nReps
        keep = randperm(nHL, sIdx);
        sample = yHiLo(keep);
        M.omegaHL(sIdx, rIdx) = (mean(sample) - truth)^2;
        M.deltaHL(sIdx, rIdx) = mean((sample - mean(sample)).^2);
    end
end

for sIdx = 1:nN
    for rIdx = 1:nReps
        keep = randperm(nN, sIdx);
        sample = yNo(keep);
        M.omegaN(sIdx, rIdx) = (mean(sample) - truth)^2;
        M.deltaN(sIdx, rIdx) = mean((sample - mean(sample)).^2);
    end
end
end
