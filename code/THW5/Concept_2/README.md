# Concept 2 aircraft analysis

Conceptual sizing of a twin-float amphibian with two parallel-hybrid propulsors. The active vertical tail has a fixed 6-ft main-fin root chord, 8-ft-2-in height and 39.92-ft² total planform including its dorsal.

## Folder guide

| Folder / file | Purpose |
|---|---|
| `run_concept2_study.m` | Main analysis entry point; configures its MATLAB path automatically |
| `setup_concept2.m` | Enable active code; optionally enable supplemental tools |
| `Inputs/` | Active requirements, operating assumptions, engine catalog and input register |
| `Analysis/` | Code used by the full mission, constraints, sizing and reporting workflow |
| `Documentation/` | Model explanations, design notes, current tail validation and file map |
| `Results/Current/` | Latest saved fixed-tail study; default destination for new main runs |

See [the detailed organization guide](Documentation/ORGANIZATION.md).

## Run the full analysis

Set this project folder as MATLAB's current folder:

```matlab
[r,h] = run_concept2_study('sizing',true,'plot_visible',true);
r.status
r.sizing.converged
```

For the starting-aircraft study without weight closure:

```matlab
[r,h] = run_concept2_study();
```

Both write to `Results/Current` by default. Matching output files are overwritten. For separate runs, pass an explicit output directory, for example `fullfile(pwd,'Results','My_Study')`. Optional one-factor trades use `'sensitivities',true`; these are trial comparisons, not independently closed designs.

To use individual model functions interactively:

```matlab
setup_concept2;
[obj,opts,cfg,J] = build_concept2_study();
```

Paths to code and inputs are based on the project location, not the working directory. Keep the full folder structure together when copying the project. Add `setup_concept2(true)` to enable tests and optional studies; the main analysis does not require `Supplemental`.

## Tests and extra tools

```matlab
setup_concept2(true);
run_audit_tests;
vertical_tail_sensitivity(ttpa_requirements_path(),415)
```

Test outputs go to `Supplemental/Results/Tests`. Read [Supplemental/README.md](Supplemental/README.md) for optional tools and the distinction between active and legacy code.

## Inputs and interpretation

Edit `Inputs/Ttpa_requirements_Concept2.json` for requirements and airframe assumptions, `Inputs/concept2_study_inputs.json` for operating/electrical/search assumptions, and `Inputs/turbine_engine_catalog.json` for fixed catalog engine data. Input changes require a new run; saved results do not update automatically.

The current saved study is an unclosed 12,000-lb trial, with an approximately 18,856-lb calculated mass budget. A mission/static-constraint pass at an assumed weight does not establish a feasible aircraft. `r.mass_closed` must be true before describing a design as mass-closed. The 12,500-lb cap is an RFP target.

Model empty mass excludes crew; the 2,430-lb payload includes two pilots plus nine passengers and baggage. RFP targets remain active. Directional control, water performance, flooded stability, docking clearance and other system requirements remain unverified. 
