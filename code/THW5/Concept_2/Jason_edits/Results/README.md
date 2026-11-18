# Current analysis results

`Current` contains the latest saved fixed Caravan-sized-tail trial and is the default output location of the main runner. The existing numerical artifacts were moved intact; internal filenames or absolute paths in saved metadata can record their original location.

| Output | Meaning |
|---|---|
| `concept2_study.json` / `.mat` | Complete assessment and model status |
| `comparison_metrics.csv` | Aircraft geometry, mass boundary and per-case performance |
| `constraint_margins.csv` | Source-specific static checks |
| `mission_cases.csv` and `*_trace.csv` | Mission summaries and phase traces |
| Constraint PNG/FIG and data CSV/MAT | Source diagrams and their plotted data |

Check `mass_closed`, feasibility and directional-control status before interpreting a result. The saved trial is not mass-closed. New main runs overwrite matching files in `Current`; use a separate `Results/<run-name>` for retained alternatives. Historical results and test outputs belong in `Supplemental/Results`.
