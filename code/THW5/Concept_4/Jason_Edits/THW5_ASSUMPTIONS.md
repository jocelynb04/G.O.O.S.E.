# Current Concept 4 analysis assumptions

The active geometry is the native OpenVSP reference in `geometry.openvsp` and `OpenVSP_Import/openvsp_reference.json`. See README for geometry values, verification and run commands. Historical results and example dimensions outside this new folder describe other configurations.

- Evaluation weight 12,490 lb, payload 2,430 lb, full 1,000-statute-mile cruise distance plus explicit reserve branch.
- Exact CAD baseline: 325-ft² wing and 64-ft span. Wing-only virtual sizing family in constraint sweeps, with fixed other components.
- Source ratings and battery capacity are calculated study sizes. Battery specific energy/power, efficiencies, altitude lapse, fixed BSFC, source dispatch and thermal/aging capability remain assumptions.
- Inherited takeoff schedule 900 shaft hp for two minutes. This is not a calculated water obstacle distance.
- Water landing wall: assumed 0.15-g water deceleration and the declared approach/flare parameters. It is not a calibrated aircraft prediction.
- Ideal one-motor-out flight curve excludes failure drag/yaw. Single-generator loss and sustained battery-only endurance are unresolved.
- Native exterior float volume replaces the bounding-box/block-coefficient buoyancy volume screen. Eligible interior compartments, flooding and righting behavior remain unresolved.
- Wing, tail, hull, float, gear and equipment mass correlations remain conceptual. Matching the CAD does not establish structural sizing or complete installation mass.
- Approach duration, arrival energy, repeated-route recharge, restart transients and accessory/icing loads need completion before compliance claims.

The green regions establish only the declared flight-power sizing screens. They do not combine all mandatory RFP gates into a feasible-aircraft declaration.
