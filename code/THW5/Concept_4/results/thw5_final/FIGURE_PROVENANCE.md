# Final THW5 figure provenance

Initial figures were generated 16 November 2026 in MATLAB 26.2.0.3433840 (R2026b) Update 1 in the validation copy. The constraint-screen candidate-overlay correction below was subsequently generated in the repository's Concept 4 folder. No coupled-sizing runs were repeated during either figure update.

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

Constraint-screen candidate-overlay correction:

- Producer: `run_concept4_constraint_diagram_style.m`; engineering helpers and the separate `run_concept4_constraints_12500.m` sweep are unchanged.
- Removed the obsolete initial sizing marker. Current 300/325/350-ft² markers read only `results/fixedwing_*/summary.json`, using each candidate's own gross weight and installed total motor rating. Exact coordinates and weight margins are exported to `../constraints_12500/concept4_candidate_markers.csv`.
- Background curves and span lines still use 12,500 lb. With required nameplate power equal to the maximum adjusted shaft-power demand, allowable W/P is below the minimum cruise/climb W/P curve. The selected motor-screen minimum is not a coupled-sizing candidate. Actual-weight markers do not establish pass/fail against fixed-weight curves.
- A candidate close-up and explicit 350-ft² overweight label distinguish the final designs and the team target. Shading remains an AEO motor/span screen only; water performance, battery-only operation, OEI drag/yaw, hardware and sustained power/energy remain unverified.
- Regenerated only the main constraint PNG/FIG, its curve CSV, the new marker CSV and `constraint_screen_12500.pdf`. Candidate summaries/histories, candidate-comparison/convergence figures, supplemental sweeps and historical annotated figures are unchanged.
- Before editing, 13 source/documentation/output files were copied into `review_backups/constraint_diagram_before_candidates_20261116/` under the Concept 4 root and SHA-256 verified. This local review backup is excluded from delivery and must not be staged or added to the MATLAB path.

Provisional landing-stall boundary update (supersedes the earlier power/span-only shading description):

The maximum wing-loading boundary uses an assumed landing stall speed of 75 KIAS, landing CLmax of 2.2, standard sea-level density, and landing-to-takeoff weight ratio of 1.0. This is a preliminary conceptual screening assumption rather than a specified RFP requirement. Water takeoff and landing distance compliance remains unverified.

- Assumed density is 0.002377 slug/ft³. MATLAB independently converts 75 knots to 126.585739282590 ft/s and calculates W/S <= 41.897820469300 lbf/ft². KIAS is approximated as KEAS at standard sea level; no IAS calibration correction is modeled.
- The fixed 12,500-lb background retains W/S >= 24.4140625 lbf/ft² for the 64-ft design-span bound and W/P below the existing AEO power boundary. The patch is clipped to the exact span/stall boundaries using interpolated endpoint heights, while the engineering calculation grid is unchanged.
- A purple dashed vertical line and provisional legend entry identify the new screen; no separate numerical annotation is placed beside it. Candidate markers retain their actual converged weights and motor ratings.
- The curve CSV adds separate span/stall masks and the calculated W/S limits. Only its combined screen mask changes among the existing columns. Candidate-marker data, source engineering models, active inputs and candidate results are unchanged.
- Eight pre-update files, including all preceding candidate-overlay edits and outputs, are preserved with SHA-256 checks in `review_backups/constraint_diagram_before_stall_20261116/` under the Concept 4 root. Neither local review-backup directory is a delivery artifact or MATLAB path dependency.

Final single-axis report presentation (supersedes the earlier two-panel layout):

- `run_concept4_constraint_diagram_style.m` now produces exactly one data axis. The separate zoom panel is removed. Serif fonts, a focused view, transparent screening fill, offset candidate labels/leader lines and a compact lower legend provide the final report layout.
- Candidate markers remain at the saved actual W/S and W/P coordinates. Only text labels and leaders are offset. The 350-ft² candidate remains explicitly over the team weight target. Its small offset above the fixed-12,500-lb power curve is retained; overlays do not establish matched-weight pass/fail.
- PNG export is 300 dpi; FIG remains editable and PDF is vector. Numerical curve/marker CSV data, both approved wing-loading limits, active engineering inputs and saved sizing outputs are unchanged by this layout update.
- Eight preceding files were preserved with SHA-256 checks in `review_backups/constraint_diagram_before_single_axis_20261116/`. All local review backups are excluded from staging and publication.
