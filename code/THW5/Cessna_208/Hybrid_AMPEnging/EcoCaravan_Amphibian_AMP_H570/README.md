# Grand Caravan EX Amphibian with AMP-H570

This MATLAB project models an AMP-H570 replacement on the conventional Caravan EX amphibian airframe. The default 150-KTAS mission cruises at 10,000 ft and uses the course landing CLmax of 2.2. The separate 164-KTAS check reports the continuous-power margin.

Open this AMP-H570 folder as the MATLAB Current Folder and run

```matlab
eco = run_eco_caravan;
```

The commands set up their own source paths. MATLAB R2025a was used for verification. Use a fresh MATLAB session when switching between the conventional and AMP-H570 projects because they share class names.

The default mission uses battery power only for taxi, the two-minute takeoff power screen (220 shp total), final approach, and landing roll. Climb, descent, and reserve flight use fuel, and cruise permits engine-driven charging. The prescribed takeoff power and duration check the electric system. Water acceleration, liftoff, and obstacle clearance require separate analysis. The balked-landing constraint represents a separate go-around and retains its existing power assumptions.

## Mission constraint diagram

```matlab
analysis = run_eco_constraint_analysis;
analysis.reference_power
```

The chart shows 3° climbs at sea level and 10,000 ft, balked landing, continuous cruise at 150 and 164 KTAS, the 50-ft water-landing proxy, loss of propulsion, and the loaded AMP-H570 reference point. The 150-KTAS line drives the cruise part of the shaded screening region. The 164-KTAS line is a separate comparator. The PNG and PDF are saved to `outputs/`. Use `run_eco_constraint_analysis([],false)` for the calculation without a plot or exported files.

See [constraint calculations and assumptions](docs/AMP_H570_CONSTRAINT_ANALYSIS.md) for the power-loading denominator, go-around boost budget, water-landing calibration and how to interpret the green region.

| Location | Contents |
|---|---|
| `run_eco_caravan.m` | Main mission and cruise-capability check |
| `run_eco_constraint_analysis.m` | Constraint diagram and reference power margins |
| `config/` | Active AMP-H570 mission and shared aircraft inputs |
| `config/scenarios/` | Alternative AMP-H570 approach and takeoff cases |
| `src/` | Aircraft, propulsion, mission, constraints, sizing and input readers |
| `private/` | Setup used by the root commands |
| `docs/` | Assumptions, sources and runtime reference inputs |
| `outputs/` | Generated constraint PNG and PDF, ignored by Git |

[AMP-H570 assumptions and sources](docs/AMP_H570_ASSUMPTIONS_AND_SOURCES.md) records which inputs are published, derived or assumed. The original manufacturer fact sheet is in `docs/sources/`. The reference conventional inputs are in `docs/reference/`.

The separate fuel-powered full-flap approach example uses its own propulsion schedule. To run that comparison case, use

```matlab
eco = run_eco_caravan(fullfile('config','scenarios','AMP_H570_fuel_approach.json'));
```
