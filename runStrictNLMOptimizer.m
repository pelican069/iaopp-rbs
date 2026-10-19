function app = runStrictNLMOptimizer
%RUNSTRICTNLMOPTIMIZER Launch the isolated strict-NLM optimization GUI.
app = StrictNLMOptimizerApp();
if nargout == 0
    clear app
end
end
