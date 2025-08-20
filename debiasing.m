% anchor years 6
% basic Gaussian WOC model

clear; close all;
preLoad = true;

%% Load data
dataName = 'anchorYears';
D = readtable('anchorYearsDecontaminatedLong.csv');
participant = D{:, 1};
question = D{:, 2};
version = D{:, 3};
truth = D{:, 4};
anchor = D{:, 5};
estimate = D{:, 7};

anchor(find(isnan(anchor))) = 0; % never used, but keeps  declarative JAGS happy

%% MCMC sampling from graphical model

% which engine to use
engine = 'jags';

% graphical model script
modelName = 'debiasing';

% parameters to monitor
params = {'mu', 'sigma', 'alpha'};

% MCMC properties
nChains    = 8;     % number of MCMC chains
nBurnin    = 1e3;   % number of discarded burn-in samples
nSamples   = 2e4;   % number of collected samples
nThin      = 1;     % number of samples between those collected
doParallel = 1;     % whether MATLAB parallel toolbox parallizes chains

% assign MATLAB variables to the observed nodes
data = struct('participant', participant, ...
   'question', question, ...
   'anchor', anchor, ...
   'y', estimate, ...
   'version', version);

% generator for initialization
generator = @()struct('alpha', rand(length(unique(participant)), 1));

%% Sample using Trinity
fileName = sprintf('%s_%s_%s.mat', modelName, dataName, engine);

if preLoad && exist(sprintf('storage/%s', fileName), 'file')
  fprintf('Loading pre-stored samples for model %s on data %s\n', modelName, dataName);
  load(sprintf('storage/%s', fileName), 'chains', 'stats', 'chains', 'diagnostics', 'info');
else
  tic; % start clock
  [stats, chains, diagnostics, info] = callbayes(engine, ...
    'model'           , sprintf('%s_%s.txt', modelName, engine)   , ...
    'data'            , data                                      , ...
    'outputname'      , 'samples'                                 , ...
    'init'            , generator                                 , ...
    'datafilename'    , modelName                                 , ...
    'initfilename'    , modelName                                 , ...
    'scriptfilename'  , modelName                                 , ...
    'logfilename'     , sprintf('/tmp/%s', modelName)             , ...
    'nchains'         , nChains                                   , ...
    'nburnin'         , nBurnin                                   , ...
    'nsamples'        , nSamples                                  , ...
    'monitorparams'   , params                                    , ...
    'thin'            , nThin                                     , ...
    'workingdir'      , sprintf('/tmp/%s', modelName)             , ...
    'verbosity'       , 0                                         , ...
    'saveoutput'      , true                                      , ...
    'allowunderscores', 1                                         , ...
    'parallel'        , doParallel                                );
  fprintf('%s took %f seconds!\n', upper(engine), toc); % show timing
  fprintf('Saving samples for model %s on data %s\n', modelName, dataName);
  if ~isfolder('storage')
    !mkdir storage
  end
  save(sprintf('storage/%s', fileName), 'chains', 'stats', 'chains', 'diagnostics', 'info');

% convergence of each parameter
disp('Convergence statistics:')
grtable(chains, 1.05)

% basic descriptive statistics
disp('Descriptive statistics for all chains:')
codatable(chains);

end

mu = codatable(chains, 'mu', @mean); 
sigma = codatable(chains, 'sigma', @mean);
alpha = codatable(chains, 'alpha', @mean);

