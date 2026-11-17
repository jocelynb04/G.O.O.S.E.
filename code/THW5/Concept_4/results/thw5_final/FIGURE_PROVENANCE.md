# Final THW5 figure provenance

Generated 16 November 2026 in MATLAB 26.2.0.3433840 (R2026b) Update 1, exclusively in the validation copy. No sizing runs were repeated during final figure preparation.

- Existing corrected source producers: `run_concept4_constraint_diagram_style.m` and `run_concept4_constraints_12500.m`. Both use `c4_required_climb_hp.m` and fixed 12,500-lb comparison weight. Seven generated artifacts in `../constraints_12500` were replaced after all nine existing artifacts were copied and SHA256 verified in `figure_backup_20261116/constraints_12500` in the validation copy only. This complete backup is not transferred to the repository.
- Historical curve sample at S = 357.654817 ft²: previous rated climb power 1552.529330 hp; corrected curve 1554.208707 hp. Regeneration was necessary. The scripts themselves required no edits.
- Standalone screen minimum: about 511.7 ft² / 1469.6 motor hp (diagram grid); sweep minimum 512.0 ft² / 1469.5 hp. Grid sampling explains the difference. Neither is a coupled minimum-weight candidate.
- `constraint_screen_12500.pdf` exports the regenerated matching diagram; its PNG and FIG reside in `../constraints_12500`.
- `candidate_comparison.{png,pdf,fig}` reads all three current `../fixedwing_*/summary.json` files. `verified_candidate_comparison.csv` contains every scalar numeric/logical summary field without rounding. Six panels show gross weight, mission fuel, battery capacity, installed shaft ratings, final SOC and team-target margin. Points connect the three evaluated candidates only; they do not establish an interpolated optimum.
- `sizing_convergence.{png,pdf,fig}` reads the three existing iteration histories and plots absolute CalculatedWeight_lb minus InputWeight_lb. All finite; monotonically decreasing magnitude; zero sign reversals. Final residuals: -0.0499969453, -0.0460976056 and +0.0396273150 lb. These differ from the independent final summary closure check.
- Actual-candidate/convergence figures were assembled from those saved outputs using inline MATLAB plotting commands during finalization; no new MATLAB source or engineering calculation was introduced. Editable FIGs and full-precision comparison CSV are supplied.
- The preexisting `concept4_constraint_final_candidates.png/.fig` was not regenerated or changed and must not be used as a final current-candidate figure.
- Constraint regeneration emitted no MATLAB warning. Fixed-weight screen shading excludes battery, water performance and real motor-out effects. All plots retain preliminary/pre-downselect interpretation.

Historical candidate summaries/histories, baseline backups, engineering sources and active JSON inputs are outside this figure update.

Portable regression packaging: only the three original historical summary JSONs are supplied under `regression_fixtures/historical_summary_{300,325,350}ft2.json` at the Concept 4 root. Each was SHA-256 verified against its preserved baseline source. They support historical fixed-component mission regression; the final figures use the current corrected `results/fixedwing_*` outputs. Full baseline/figure backups remain validation-only.
