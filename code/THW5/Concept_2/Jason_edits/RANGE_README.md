# Concept 2 range calculation

The target is **1,000 statute miles = 868.9762419 nmi**, with **2,430 lb payload**. A target distance is distinct from calculated achievable range.

In MATLAB, set the current folder here and run:

```matlab
setup_concept2;
result = run_concept2_range;
```

Or include it in the existing full-study report:

```matlab
result = run_concept2_study('range_analysis',true,'plot',false);
```

The standalone outputs are in `Results/Range/`. The integrated call puts them in `Results/Current/Range/` and adds `result.range` to the study result.

The new calculation reuses the existing source-constraint motor/inverter sizing at 12,490 lb and the imported wing. It computes empty weight excluding the battery, then searches only discrete complete-string battery sizes that fit below the ceiling even before loading fuel. A failed capacity-sizing bound is never installed. For each pack and distance, the existing phase integrator checks normal and go-around/reserve flights from the stated initial SOC. Loaded fuel includes the existing contingency/unusable allowance. Reserves are retained rather than converted into additional route distance. No fuel-only Breguet estimate is reported as an achievable hybrid range.

Defaults search 12 pack candidates and 50-mi distance increments from zero to 1,600 statute miles. `CapacityPoints`, `DistanceStepMi` and `MaximumRangeMi` are editable. The largest passing grid point is reported, not an exact optimum. No feasible point produces NaN in MATLAB and null in JSON, with the actual failed phases preserved in `range_sweep.csv`.

Single-trip range and complete RFP eligibility are separate. Fixed imported float volume, repeated short-route charging balance, OEI, other source constraints, water distances and certification remain mandatory checks. The range output does not waive them. No battery-density, power-limit, engine-map or climb-schedule assumption is relaxed to create a favorable result.

Run regression checks with:

```matlab
tests = runtests('Concept2RangeTest.m');
assert(all([tests.Passed]));
```
