function tag = barrera_figure_tag(experimentName)
%BARRERA_FIGURE_TAG Map internal experiment names to Barrera-Lemarchand figure tags.
% e.g. navajasExperiment2 -> barreraLemarchandExperiment2
if startsWith(experimentName, 'navajas')
    tag = ['barreraLemarchand', experimentName(8:end)];
else
    tag = experimentName;
end
end
