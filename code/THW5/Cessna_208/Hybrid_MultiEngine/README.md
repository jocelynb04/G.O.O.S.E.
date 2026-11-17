# Twin hybrid Grand Caravan EX Amphibian

This MATLAB concept retains the Caravan cabin and fuselage behind the original nose, the 279-ft² high wing, the tail, and the amphibious float assumptions. A new equipment nosecone replaces the nose engine installation. Two identical parallel-hybrid AMP-H570 powertrains each drive a propeller, with one installation on each wing. The Twin Otter amphibian provides the layout reference. [De Havilland Canada](https://dehavilland.com/twin-otter/)

## Run in MATLAB

Open this folder as the MATLAB Current Folder and run

```matlab
twin = run_twin_hybrid;
twin.weight_breakdown
twin.installation.climb_screen
```

The runner uses the sibling `Hybrid_AMPEnging/EcoCaravan_Amphibian_AMP_H570` model for the inherited airframe, atmosphere, propeller efficiencies and per-side powertrain behavior. Keep both folders in their current checkout layout. The constraint runner also reads the sibling model's [conventional constraint inputs](../Hybrid_AMPEnging/EcoCaravan_Amphibian_AMP_H570/docs/reference/CONVENTIONAL_CONSTRAINT_INPUTS.json). For a run without figures, use `run_twin_hybrid([],false)`. To run a separate scenario, pass its JSON file as the first argument.

The mission figure shows battery state of charge per side on the blue left axis and total fuel remaining on the orange right axis. Both use elapsed mission time. The cruise charging schedule raises battery charge to its target while the engines continue burning fuel.

The default mission uses battery power only for taxi, the two-minute takeoff power screen (288 shp total), final approach, and landing roll. Climb, descent, and reserve flight use fuel, and cruise permits engine-driven charging. The prescribed takeoff power and duration check the electric system. Water acceleration, liftoff, and obstacle clearance require separate analysis. The balked-landing constraint represents a separate go-around and retains its existing power assumptions.

## Constraint analysis

```matlab
analysis = run_twin_constraint_analysis;
analysis.reference_power
```

The runner plots wing loading versus power loading and saves a PNG and PDF to the Git-ignored `outputs/` directory. Use `run_twin_constraint_analysis([],false)` to calculate the curves without opening or exporting a figure. The entry points are at the project root, the mission inputs are in `config/`, the calculation and plotting functions are in `src/`, and the path setup is in `private/`.

The reference star uses the mission takeoff weight, the retained 279-ft² wing, and the pair's fresh-pack-limited sea-level peak rating. The green envelope shows where a scaled installation with the same power ratios could meet the modeled constraints. Its dark green horizontal segment identifies the wing loadings the installed pair can support at the same takeoff weight.

The primary screen includes clean 3° climbs at sea level and 10,000 ft with both engines and with one engine inoperative, a 3% all-engines balked landing on continuous power, the mission cruise speed (150 KTAS at 10,000 ft by default), and the inherited 50-ft water-landing proxy. The 164-KTAS comparator uses the same cruise altitude and is shown separately. Cruise uses the inherited 97.5% takeoff-weight fraction and continuous combustion power with charging disabled. Balked landing and the water proxy use mission ending weight. The water calibration inherits the full-flap polar and the 2,004-ft distance assumption. Water takeoff distance, rudder authority and minimum control speed require separate analysis.

## Editable assumptions

| Input | Default and how it is used |
|---|---|
| Wing stations | 9 ft either side of centerline, with assumed 8-ft propeller diameters. The model reports the lateral gap to the fuselage envelope. |
| Nosecone | A conical envelope 4 ft long and 4.5 ft in base diameter. The usable volume allowance is 50% of the geometric cone. Set `nose_equipment_lb` to include equipment in the takeoff weight. |
| Weight | Remove the inherited 595-lb nose PT6 installation once. Add two 950-lb hybrid assemblies, two installation allowances of 30 kg, both batteries, a 60-lb nosecone, and a 120-lb wing reinforcement allowance. |
| Power | Ampaire lists 764 shp at takeoff and 543 shp maximum continuous per unit. Per-side boost also depends on pack discharge, available energy, efficiencies, motor and propeller limits. The inherited 120-second burst duration is a modeling assumption. |
| Battery | Two 20-kWh packs, one per side, at assumed 250 Wh/kg and 6C maximum discharge. The mission propagates an identical state for each side under symmetric demand. Fuel, battery energy and shaft power in the mission output are totals for both sides. |
| Drag | Add 0.010 to the inherited parasite drag coefficient for the net nose and nacelle change. Add another 0.012 for the feathered propeller and trim proxy during one-engine-inoperative flight. Both are sensitivity inputs. |
| Mission | 400 lb payload, 500 lb fuel and a 100-nmi cruise at 150 KTAS and 10,000 ft. The electric takeoff segment demands 288 total shp as a power screen. Cruise permits engine-driven charging. Reserve segments include a 45-minute loiter. |

Edit [twin_hybrid.json](config/twin_hybrid.json) to change these values. The power ratings come from Ampaire. The installation geometry, loads, weight allowances and pack sizing are engineering assumptions. [Ampaire AMP-H570](https://www.ampaire.com/amp-h570) · [Inherited AMP-H570 assumptions](../Hybrid_AMPEnging/EcoCaravan_Amphibian_AMP_H570/docs/AMP_H570_ASSUMPTIONS_AND_SOURCES.md)

The model keeps the baseline 9,062-lb takeoff limit as a screening cap. The fuel allowance at 800 lb of payload is a weight-and-tank check. The climb table evaluates a 3° clean climb at sea level and 10,000 ft with both units and with one unit providing continuous power. It estimates asymmetric thrust moment about the aircraft centerline. A power pass leaves rudder authority, minimum control speed, and transient response to be evaluated. The concept also needs wing structural loads, center of gravity, equipment fit, float and propeller clearances, and water performance evaluated before drawing installation or operating conclusions.
