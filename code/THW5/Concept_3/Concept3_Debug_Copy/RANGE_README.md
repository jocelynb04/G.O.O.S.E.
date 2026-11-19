# Concept 3 corrected mission and range

The active mission now uses **2,430 lb payload**, **1,000 statute miles = 868.9762419 nmi**, a 10,000-ft range cruise at 150 KTAS, an explicit electric balked landing, and 45 minutes of reserve. The 180-KTAS capability screen is separate. Both range definitions are stored in the JSON. Amphibious gear is restored as a provisional 7.125% gross-weight allowance; it was previously zero.

In MATLAB, set the current folder here and run:

```matlab
result = run_concept3_range;
```

Outputs are `Results/Range/range_summary.json`, `range_sweep.csv` and `target_mission_trace.csv`. Unknown/infeasible maximum range is NaN in MATLAB and null in JSON. It is never presented as zero miles or replaced by the requested distance. The scan checks 50-mi distance increments and 500-lb gross-weight increments, including the 12,490-lb ceiling. Refine with `DistanceStepMi` and `WeightStepLb`; this is not a global optimum or a fully coupled redesign.

`concept3_mission_energy` accounts for fuel, battery discharge, charging losses, accessory demand, source limits and SOC through every phase. Taxi, takeoff, approach, go-around, landing and arrival taxi have zero generator/fuel operation. There is no ground recharge. `run_mission_L2` uses this ledger for the active model and stops with `C3:MissionInfeasible` when the existing installation cannot execute the mission. The old sizing workflow can therefore stop earlier than before: invalid source power is no longer hidden by fixed combustion fuel fractions. Use the range entry point above to obtain a diagnostic report without suppressing failures.

The generator-engine rating is now independent of the motor rating. `propulsion.generator_engine_shaft_power_sl_hp_each` controls each generator engine and its modeled mass; `P_SL_hp` remains the total motor rating. Increasing motor rating in the old sizing loop no longer silently creates larger generator engines. The old loop is not a joint generator/motor/battery optimizer.

All schedules, 6-kW accessories, 80% capacity retention, 2% unusable fuel, and gear mass are explicit preliminary assumptions. The original 850-hp motor total, two 425-hp generator engines and 500-kW discharge limit are retained as the active hardware basis. They are not automatically enlarged to force range feasibility.

A separate sizing sensitivity can be run without changing the active JSON:

```matlab
candidate = run_concept3_range( ...
    MotorRatingHp=1100, GeneratorEachHp=500, BatteryDischargeKW=800, ...
    OutputDirectory=fullfile(pwd,'Results','RangeSizingSensitivity'));
```

These are assumed ratings, not selected/qualified engines, motors or batteries. Component mass correlations respond to the changed ratings. Positive mission range still does not establish full RFP compliance. The 2,000-fpm climb, source failures/OEI, water distances, sea state, docking, buoyancy, complete thermal/integration/gear installation and physical interior remain unverified. Existing demonstration climb constraints retain their explicit demonstration labels. Water takeoff power/time is scheduled rather than derived from hull resistance and obstacle clearance.

Repeated normal target-route flights retain SOC between arrivals, include the 30-minute accessory energy exposure, and report separately. A one-flight pass from the configured initial SOC is not evidence of sustainable repeated service.

Run regression checks with:

```matlab
tests = runtests('Concept3RangeTest.m');
assert(all([tests.Passed]));
```

Historical saved results from the old 800-lb/500-nmi mission are superseded for RFP comparisons. This update does not edit OpenVSP geometry or claim measured aircraft performance.
