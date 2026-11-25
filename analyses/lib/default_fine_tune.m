function fineTune = default_fine_tune()
%DEFAULT_FINE_TUNE Fallback figure styling when analyses.m fineTune is omitted.
fineTune.font.diversityPredictionTheorem = 24;
fineTune.font.anchoringIndex       = 24;
fineTune.font.allQanchoring        = 24;
fineTune.font.allQanchoringBarrera = 18;
fineTune.font.allQanchoringReplication = 18;  % original vs F2026 forest
fineTune.font.performance          = 16;
fineTune.font.debiasingModel       = 20;
fineTune.font.expertiseVsAnchoring = 16;
fineTune.font.outlierRuleComparison = 12;

fineTune.performance.xlim = [0 65];
fineTune.performance.xtick = 0:10:70;
fineTune.performance.insetExpertise.bottomLeft = [0.75 0.5];
fineTune.performance.insetAnchoring.bottomLeft = [0.5 0.5];
fineTune.performance.insetWidth = 0.2;
fineTune.performance.insetHeight = 0.4;
fineTune.performance.font.axis = 16;
fineTune.performance.font.xlabel = 18;
fineTune.performance.font.crowdLabel = 16;
fineTune.performance.font.insetAxis = 16;
fineTune.performance.font.insetLabel = 16;
fineTune.performance.font.insetCorr = 16;
end
