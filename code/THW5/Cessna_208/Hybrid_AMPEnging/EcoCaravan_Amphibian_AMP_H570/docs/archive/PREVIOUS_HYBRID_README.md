# Grand Caravan EX Amphibian — parallel hybrid MATLAB project

This is a separate extension of the standalone project. It retains the original fuel-only model and adds a parallel turbine/electric drivetrain, explicit battery energy and fuel ledgers, hybrid equipment mass, selectable mission power sources, limit checks, tests and plots. No turbine removal or resizing is assumed. This is a conceptual engineering model, not a hardware retrofit design.

## Run in MATLAB Desktop

Extract the ZIP. Restart MATLAB if another copy of the baseline project has already been loaded. Set Current Folder to this extracted `GrandCaravanEX_Amphibian_Hybrid` folder, then enter:

```matlab
addpath(pwd,'-begin')
hybrid = run_hybrid_caravan;      % selected hybrid mission, table and plots
comparison = compare_hybrid_modes; % same aircraft/trajectory, fuel-only propulsion vs hybrid
verify_hybrid_project            % all baseline and hybrid tests, dependency audit, saved plot/report
```

Only MATLAB is needed. Tested with R2025a Update 1. `hybrid.feasible` must be true before treating totals as a completed mission. If false, `hybrid.failure` explains the first violated limit; the trace/totals describe only completed integration steps. Full per-segment rows cover completed segments only.

Original fuel-only behavior remains available as `baseline = run_caravan;`. See BASELINE_README.md for its assumptions. `run_caravan(true)` and the inherited sizing/envelope tools remain CONVENTIONAL models; they do not size a hybrid aircraft. Use the new runner for all hybrid studies. The new architecture does not modify the original twelve adapted equations.

## Selected demonstration

The complete 867-shp turbine and original amphibian float weight/drag are retained. Example assumptions:

| Quantity | Example value |
|---|---:|
| Battery nominal energy | 40 kWh |
| Pack-level specific energy | 250 Wh/kg |
| Battery continuous discharge limit | 6 C = 240 kW at nominal capacity |
| Initial / minimum battery SOC | 100% / 20% |
| Motor continuous shaft rating | 250 kW (about 335 hp) |
| Motor specific power | 5 kW/kg |
| Motor / inverter / electric gearbox efficiencies | 0.95 / 0.97 / 0.98 |
| Additional installation allowance | 30 kg |
| Hotel electrical load | 2 kW throughout mission |
| Loaded fuel / payload including crew | 1450 lb / 800 lb |
| Integration time step | 5 s |

These values are editable engineering assumptions, not specifications of selected, installed or qualified hardware. Motor mass is 50 kg; battery mass is 160 kg; installation allowance is 30 kg. The 529.1-lb addition remains aboard when the battery discharges. All baseline empty-weight calibration and amphibian approximations remain.

The schedule is electric taxi; two minutes at 867 total shaft hp with 25% electric share for takeoff; turbine climb; 500 nmi turbine cruise at 150 KTAS/8000 ft; descent; reserve climb and 45-minute turbine loiter; descent to 500 ft; electric 3-degree approach at 85 KTAS; and a one-minute zero-shaft-power landing-run placeholder. The 3-degree approach is modeled from 500 ft, not as the entire descent from cruise. Takeoff climb is specified by 600 fpm, not 3 degrees. All ground-segment durations and loads are assumed, and do not establish water-run distance.

At the tested settings: added mass about 529.1 lb; modeled hybrid empty weight 6504.1 lb; loaded takeoff weight 8754.1 lb; mission fuel used 1330.6 lb; battery energy used 21.01 kWh; final SOC 47.5%. The loaded aircraft starts about 307.9 lb below the 9062-lb reference MTOW. About 119.4 lb of loaded fuel remains. A 20% battery reserve is enforced, but no regulatory fuel reserve determination is made; the 45-minute loiter is an explicit mission segment.

## Switch between fuel and battery

Edit `Hybrid_requirements.json` in MATLAB's editor. Each segment has a `mode`:

- `"fuel"`: turbine supplies all propeller shaft power; motor is off. Battery still supplies the 2-kW hotel load.
- `"electric"`: turbine is assumed off and ideally declutched; motor supplies all demanded propeller power.
- `"hybrid"`: both operate. `electric_fraction` is the motor's share of demanded propeller shaft power, between 0 and 1. For example, 0.25 means 25% electric, 75% turbine.

Mode transitions occur at segment boundaries and are instantaneous idealizations. To change mode partway through cruise, split cruise into two consecutive segments with the same altitude and speeds, allocating the route distance between them. Segment start/end altitudes must connect. Changing a mode never silently changes the schedule or falls back to another energy source. Infeasible modes stop the mission with a diagnostic.

For another input file:

```matlab
hybrid = run_hybrid_caravan('My_hybrid_requirements.json');
```

`run_hybrid_caravan([],false)` suppresses plots. Inspect `hybrid.segments`, `hybrid.trace`, `hybrid.final_soc`, `hybrid.fuel_remaining_lb`, and `hybrid.mtow_margin_lb`. To show the table again, use `struct2table(hybrid.segments)`.

Changing the takeoff segment to electric-only WILL fail with the default motor: 867 hp needs about 646.5 kW shaft power, above the 250-kW motor rating. Both motor and pack discharge power would need to increase; their added mass and energy requirements must then be evaluated. The selected takeoff assist replaces part of turbine power; it does not exceed the retained 867-hp propeller/drivetrain cap.

## Calculation method

The hybrid runner integrates the flight path directly instead of multiplying conventional fuel-only Breguet fractions. It reuses the original geometry, configuration drag polars, CL limits, turbine altitude lapse, BSFC and efficiencies. At each airborne step:

```
V_z = V*sin(gamma)                (or entered climb/descent rate)
CL = W*cos(gamma)/(q*S)
D = q*S*(CD0 + K1*CL^2)
P_required_hp = max(0,(D*V + W*V_z)/(550*eta_propeller))
P_motor_kW = electric_fraction * P_required_hp * 0.745699872
P_turbine_hp = (1-electric_fraction) * P_required_hp
P_battery_kW = P_motor_kW/(eta_motor*eta_inverter*eta_gearbox) + hotel_load_kW
energy_used_kWh = P_battery_kW * dt_hours
fuel_used_lb = BSFC * P_turbine_hp * dt_hours
W_next = W - fuel_used_lb
battery_mass_lb = capacity_kWh*1000/specific_energy_Wh_per_kg*2.20462262185
```

The battery energy ledger includes hotel loads even during fuel propulsion. There is no in-flight charging or regeneration. Negative required descent propulsive power is clipped to zero and recorded as dissipated energy; a descent drag-management or propeller control solution is not modeled. The baseline convention uses numerical lbf and lbm interchangeably under standard gravity for weight/fuel accounting.

Checks include initial MTOW and tank limits; altitude continuity and ceiling; configured stall margin; turbine altitude-adjusted power; continuous motor rating; combined shaft rating; battery C-rate and minimum SOC; available fuel; and energy/mass conservation. Input validation rejects invalid efficiency, SOC, capacity and basic mission values. A 5-s vs 2.5-s integration regression checks time-step sensitivity.

## How to interpret the comparison

`Hybrid_fuel_only.json` uses the SAME added battery/motor hardware, fuel load, payload and flight path, with turbine-only propulsion. It still powers hotel loads from the battery. The demonstrated source switch displaces about 8.30 lb of fuel compared with that same-aircraft case (1338.93 vs 1330.63 lb). This is not a comparison with the lighter unmodified Caravan and does not establish a net hybrid benefit. The inherited baseline run uses different ground-fuel fractions, climb scheduling and loading, so its roughly 1550-lb fuel result is not directly comparable. Battery mass, installation mass, hardware drag and revised engine operating efficiency can erase fuel benefits.

## Limits and assumptions

The engine is ideally shut down/declutched in electric mode. No windmilling drag, clutch, restart/start energy, synchronization, idle/standby operation, redundancy, failure recovery or switch transient is simulated. The configurable turbine idle fuel floor defaults to zero; this makes low-power turbine fuel burn optimistic. Electric gearbox efficiency is applied on the electrical path; the inherited turbine rating is treated as power available at the propeller shaft.

No engine generator, battery recharge or regenerative descent is implemented. Battery maximum power is a constant nominal-capacity C-rate model, not a voltage/current, temperature or aging model. SOC reserve is an energy reserve, not a guaranteed go-around capability. The 250-kW motor cannot independently replace all 867 shp. No cooling-system sizing, electrical protection, packaging, CG, float buoyancy/load balance, structural reinforcement or certification analysis is performed. The installation allowance is not an engineered bill of materials, and no additional external hardware drag is assumed. Existing float drag and water-performance limitations remain.

Parallel architecture reference: NASA, Aircraft Configurations, https://www.nasa.gov/eap-aircraft-concepts/aircraft-configurations/ . NASA describes parallel propulsion as a fuel engine and battery-powered motor driving a shared shaft, either individually or together. Parameter values here are illustrative choices, not values sourced or endorsed by NASA. NASA's discussion of electric powertrain tradeoffs: https://ntrs.nasa.gov/citations/20180007414 .

## Verification artifacts

HYBRID_VERIFICATION.txt contains the actual MATLAB run and required-products audit. hybrid_mission.png shows battery SOC, fuel and power over time. hybrid_demo_results.mat contains the mission, same-aircraft comparison and test results. The original verification records remain under their baseline filenames. Numerical tests establish software consistency; they do not validate the aircraft or hardware assumptions.
