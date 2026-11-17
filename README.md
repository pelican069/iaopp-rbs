# Impedance-Aware Optimized Pulse Patterns (IA-OPP)

MATLAB code accompanying the paper

> J. Estaller et al., *Impedance-Aware Optimized Pulse Patterns for
> Reconfigurable Battery Systems*, submitted to IEEE Open Journal of
> Power Electronics. Preprint: arXiv:2609.16828.

IA-OPP computes event-budgeted staircase switching patterns for
reconfigurable battery (cascaded-bridge) systems whose source impedance
depends on the switching state. The optimization embeds the
level-dependent path resistance in the objective (impedance awareness),
treats the number of level changes per period as a managed budget, and
evaluates the switched RL plant in closed form (exact Fourier
coefficients of the piecewise-exponential current).

## Requirements

- MATLAB R2025b (no toolboxes required; earlier releases are untested
  but likely work — the code uses base MATLAB only).

## Quick start

```matlab
testStrictNLMVariant        % regression tests (~1 min)
benchmarkStrictNLM          % full benchmark -> Strict_NLM_Benchmark.mat (~10 min)
analyzeOPPBaseline          % classical-OPP baseline (linear plant model)
analyzeRobustness           % +-30 % parameter sweeps + 16 corner points
analyzeOperatingPoints      % modulation-index sweep (~30 min)
crossValidateEvaluator      % closed form vs. independent RK4 time stepping
exportPaperFigures          % regenerates the paper figures (fig_*.pdf)
```

The two `.mat` caches included in this repository hold the precomputed
results of `benchmarkStrictNLM`/`analyzeOPPBaseline` (plus the
three-phase runs) and `analyzeOperatingPoints`, so all plot scripts run
in seconds without recomputation. Deleting the caches and re-running the
scripts above reproduces them.

## Script map (paper artifact -> script)

| Paper artifact | Script |
| --- | --- |
| Fig. chosen solution / spectrum / predistortion / THD plane / operating points | `exportPaperFigures.m` |
| Table: dual metric + conduction losses | `benchmarkStrictNLM.m` (console) |
| Classical-OPP baseline, prediction gap | `analyzeOPPBaseline.m` |
| Robustness (sweeps + corners) | `analyzeRobustness.m` |
| Three-phase stage 1/3 + fairness baseline | cached in `Strict_NLM_Benchmark.mat` (`triplenAware`, `triplenAwareLinOPP`); evaluator flag `p.excludeTriplenTHD` |
| Solver validation | `crossValidateEvaluator.m` |
| Runtime figures | timing section in the paper; full budget run `benchmarkStrictNLM` |

Core components: `strictNLMOptimizeSchedule.m` (budget DP + timing
refinement + selection), `strictNLMEvaluateSchedule.m` (closed-form
evaluation; returns spectra), pattern generators
`fixedStepNLMSchedule.m` / `psPWMSchedule.m`, and a programmatic GUI
(`runStrictNLMOptimizer`). German axis labels in some dissertation plot
scripts are intentional; the paper figures (`exportPaperFigures.m`) are
English.

## Funding

This research out of the project MORE (Munich Mobility Research Campus)
is funded by dtec.bw -- Digitalization and Technology Research Center of
the Bundeswehr, which we gratefully acknowledge. dtec.bw is funded by
the European Union -- NextGenerationEU.

## License

MIT License, see [LICENSE](LICENSE).

## Citation

Please cite the paper above. The Zenodo DOI of this repository is
10.5281/zenodo.XXXXXXX (filled in with the first release).
