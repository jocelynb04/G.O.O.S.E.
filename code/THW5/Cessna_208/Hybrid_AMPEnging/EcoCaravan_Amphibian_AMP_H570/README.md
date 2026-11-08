# Grand Caravan EX Amphibian with AMP-H570

This MATLAB project models an AMP-H570 replacement on the conventional Caravan EX amphibian airframe. The default 150-KTAS mission cruises at 10,000 ft and uses the course landing CLmax of 2.2. The separate 164-KTAS check reports the continuous-power margin.

From the repository root in MATLAB Desktop, run

```matlab
eco = run_eco_caravan;
```

For the regression tests and saved report and plot, run

```matlab
verify_eco_project
```

The two commands set up their own source paths. MATLAB R2025a was used for verification.

| Location | Contents |
|---|---|
| `run_eco_caravan.m` | Main mission and cruise-capability check |
| `verify_eco_project.m` | Test and report generator |
| `config/` | Active mission, shared aircraft and PT6-plus-motor inputs |
| `config/scenarios/` | Alternative approach, takeoff rejection and fuel-only cases |
| `src/` | Aircraft, propulsion, mission, constraints, sizing and input readers |
| `private/` | Setup used by the two root commands |
| `examples/` | Earlier conventional and PT6-plus-motor runners and checks |
| `tests/` | MATLAB tests |
| `docs/` | Assumptions, sources, reviewed verification and historical records |
| `outputs/` | Generated reports, plots and MAT files, ignored by Git |

[AMP-H570 assumptions and sources](docs/AMP_H570_ASSUMPTIONS_AND_SOURCES.md) records which inputs are published, derived or assumed. The original manufacturer fact sheet is in `docs/sources/`. The reference conventional inputs are in `docs/reference/`. The provenance hashes in `docs/provenance/` describe their original package snapshots.

To run the fuel-powered full-flap approach example, use

```matlab
eco = run_eco_caravan(fullfile('config','scenarios','AMP_H570_fuel_approach.json'));
```

For the earlier comparison runners, add `examples` to your path, then call `run_caravan` or `run_hybrid_caravan`. Their input files remain under `config/`.

For GitHub, copy the contents of this folder into your repository, including `.gitignore` and `.gitattributes`. Git ignores the generated `outputs/` folder. The reviewed verification report and mission plot are in `docs/verification/`.
