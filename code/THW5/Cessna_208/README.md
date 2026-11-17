# Grand Caravan EX Amphibian

Open this folder in MATLAB and run `result = run_profile;` for the original mission or `result = run_caravan;` for the mission and combined sizing constraints. Use `run_caravan(true)` for iterative sizing. The root runners read this folder's original JSON in `config/` and share the runtime in `Constriaint_Analysis/src/`.

| Model | Folder | MATLAB commands |
|---|---|---|
| Conventional constraint chart | [Constriaint_Analysis](Constriaint_Analysis/) | `run_profile`, `run_constraint_analysis` |
| Single AMP-H570 | [Hybrid_AMPEnging](Hybrid_AMPEnging/EcoCaravan_Amphibian_AMP_H570/) | `run_eco_caravan`, `run_eco_constraint_analysis` |
| Twin AMP-H570 | [Hybrid_MultiEngine](Hybrid_MultiEngine/) | `run_twin_hybrid`, `run_twin_constraint_analysis` |

For each model in the table, open its linked folder as the MATLAB Current Folder before running its commands. Use a fresh MATLAB session when switching between the conventional and hybrid model families because their classes share names. The chart runners recreate their generated outputs. Historical reports, previous revisions and verification material are stored in the local archive.
