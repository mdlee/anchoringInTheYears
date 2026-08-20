function [chains, priorField, postField] = load_anchoring_chains(storageDirs, questionNameOrIdx)
%LOAD_ANCHORING_CHAINS Load per-question anchoring-index MCMC samples.
% Tries new-repo names (anchoringIndex_<k>_jags.mat with A/Aprior) then
% legacy CC2 names (anchorYears_5c_<label>_jags.mat with alpha/alphaPrior).

chains = [];
priorField = '';
postField = '';

candidates = {};
if isnumeric(questionNameOrIdx)
    qIdx = questionNameOrIdx;
    candidates{end+1} = sprintf('anchoringIndex_percentageEstimationF2025_%d_jags.mat', qIdx); %#ok<AGROW>
    candidates{end+1} = sprintf('anchoringIndex_%d_jags.mat', qIdx); %#ok<AGROW>
else
    qName = questionNameOrIdx;
    candidates{end+1} = sprintf('anchorYears_5c_%s_jags.mat', qName); %#ok<AGROW>
    candidates{end+1} = sprintf('anchoringIndex_%s_jags.mat', qName); %#ok<AGROW>
end

for c = 1:numel(candidates)
    path = resolve_storage_file(storageDirs, candidates{c});
    if isempty(path)
        continue;
    end
    S = load(path, 'chains');
    chains = S.chains;
    if isfield(chains, 'A') && isfield(chains, 'Aprior')
        postField = 'A';
        priorField = 'Aprior';
        return;
    elseif isfield(chains, 'alpha') && isfield(chains, 'alphaPrior')
        postField = 'alpha';
        priorField = 'alphaPrior';
        return;
    end
end
end
