function dirs = find_mcmc_storage(repoRoot)
%FIND_MCMC_STORAGE Candidate directories for precomputed JAGS / diversity mats.
% Prefers in-repo model storage; falls back to the CC2 working copy.

dirs = {};
candidates = {
    fullfile(repoRoot, 'models', 'anchoringIndex', 'storage')
    fullfile(repoRoot, 'models', 'debiasing', 'storage')
    fullfile(repoRoot, 'storage')
    '/home/mdlee/Dropbox/CC2/code/anchorYears/storage'
    '/home/mdlee/Dropbox/CC2/code/anchorYears/git/storage'
    };

for i = 1:numel(candidates)
    if isfolder(candidates{i})
        dirs{end+1} = candidates{i}; %#ok<AGROW>
    end
end

if isempty(dirs)
    error('find_mcmc_storage:None', 'No MCMC/diversity storage directories found.');
end
end
