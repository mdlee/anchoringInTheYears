% Anchoring Index Inference
clear; close all;

preLoad = true;

questionList = 1:11;

%% Load data
D = readtable('anchorYearsDecontaminatedLong.csv');
question = D{:, 2};
version = D{:, 3};
truth = D{:, 4};
anchor = D{:, 5};
estimate = D{:, 7};

%% Credible Intervals and Savage-Dickey constants
CI = 95;
lo = 00; hi = 1; eps = 0.01; tick = 0.2;
scale = 5;
binsE = lo-eps/2:eps:hi+eps/2;
binsC = lo:eps:hi;
[~, critIdx] = min(abs(binsC - 0));

%% MCMC sampling from graphical model

% which engine to use
engine = 'jags';

% graphical model script
modelName = 'anchoringIndex';

% parameters to monitor
params = {'A', 'Aprior'};

% MCMC properties
nChains    = 8;     % number of MCMC chains
nBurnin    = 1e3;   % number of discarded burn-in samples
nSamples   = 2e4;   % number of collected samples
nThin      = 1;     % number of samples between those collected
doParallel = 1;     % whether MATLAB parallel toolbox parallizes chains

 for questionIdx = 1:numel(questionList)


    matchH = find(question == questionList(questionIdx) & version~=3 &  anchor > truth);
    yH = estimate(matchH);
    matchL = find(question == questionList(questionIdx) & version~=3 & anchor < truth);
   yL = estimate(matchL);

   % assign MATLAB variables to the observed nodes
   data = struct('yH', yH, 'yL', yL);

   % generator for initialization
   generator = @()struct('A', rand);

   %% Sample using Trinity
   fileName = sprintf('%s_%d_%s.mat', modelName, questionList(questionIdx), engine);

   if preLoad && exist(sprintf('storage/%s', fileName), 'file')
      fprintf('Loading pre-stored samples for model %s on question %d\n', modelName, questionList(questionIdx));
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
      fprintf('Saving samples for model %s on question %d\n', modelName, questionList(questionIdx));
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

   %% Inferences

       fprintf('\n\nAnchoring index inferences for question %d:\n',  questionList(questionIdx));

               bounds = prctile(chains.A(:), [(100-CI)/2 CI+(100-CI)/2]);
            fprintf('Anchoring index mean is %1.2f and 95%% CI is (%1.2f, %1.2f)\n', mean(chains.A(:)), bounds);


   % Savage-Dickey
   densityPrior = histcounts(chains.Aprior(:), binsE, ...
       'normalization' , 'pdf'    );
   density = histcounts(chains.A(:), binsE, ...
   'normalization' , 'pdf'    );

   BF = density(critIdx)/densityPrior(critIdx);
   if BF > 1
      fprintf('BF_{01} = %1.1f\n', BF);
   else
      fprintf('BF_{10} = %1.1f\n', 1/BF);
   end

end
