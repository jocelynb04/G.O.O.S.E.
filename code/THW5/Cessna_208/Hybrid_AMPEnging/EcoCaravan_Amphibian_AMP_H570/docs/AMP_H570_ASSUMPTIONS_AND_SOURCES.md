# AMP-H570 amphibian model: assumptions and sources

This is a conceptual **AMP-H570 replacement** on our Grand Caravan EX amphibian model. The PT6-plus-motor model is the separate `rev0_base` comparison. Ampaire describes its Eco Caravan as a 208B/EX retrofit with battery packaging in the cargo pod; that does not establish compatibility with the floats or validate this installation.

## What the manufacturer publishes

| Item | Published value | Where to find it |
|---|---:|---|
| Combined takeoff shaft power | 764 shp (570 kW, rounded) | [Ampaire engine page](https://www.ampaire.com/amp-h570), and fact sheet pp. 2–3 |
| Combined maximum continuous shaft power | 543 shp (405 kW, rounded) | [Ampaire engine page](https://www.ampaire.com/amp-h570) |
| Cruise BSFC without boost | 0.34 lb/(hp·hr) | [Bundled fact sheet](sources/AMP_H570_datasheet.pdf), p. 3 |
| Net boost BSFC | 0.32 lb/(hp·hr), recorded only | Fact sheet p. 3 |
| Dry mass bound | Less than 1,000 lb | Fact sheet p. 3 |
| Engine envelope | 29.5 in high × 33.5 in wide × 51 in long | Fact sheet p. 3 |

The model uses the published **system** limits. It does not apply advertised fuel-saving percentages or range targets. The unboosted BSFC is applied to estimated combustion shaft work, including generator work. Applying the advertised net boost BSFC on top of an already reduced combustion-power share would risk counting the same benefit twice.

## Assumed inputs and why they are present

| Input or model rule | Current assumption | Implication |
|---|---|---|
| Individual sources | 543 shp combustion + up to 221 shp electric | Allocates the published continuous/peak system numbers; neither component rating is independently established by those system ratings. |
| Peak duration | 120 s above 543 shp; timer resets at/below the threshold | Keeps boost finite in the example. No thermal or cooldown model; 120 s is not a manufacturer rating. |
| Altitude power | Core flat-rated to 10,000 ft; density-ratio exponent 0.65 above it | Placeholder for absent engine map. No hot-day, torque or RPM model. |
| Combustion fuel map | Constant 0.34 lb/(hp·hr); zero idle floor | The 0.34 datum is published for cruise without boost, but applying it across all loads is an assumption. Zero idle floor is optimistic. |
| Assembly and installation | 950-lb dry assembly; 30 kg additional installation | 950 lb is selected below the published bound; exact scope, installed mass, cooling and mounts are unknown. Motor is included in assembly mass. |
| Removed PT6 | 595-lb installed weight allowance (425 × 1.4) | Inherited model allowance subtracted from the 5,975-lb calibrated amphibian empty weight, not measured installed weight. |
| Battery | 40 kWh nominal, 250 Wh/kg pack, 100% starting SOC, 20% minimum | Assumed external pack adds about 353 lb. Dry-mass definition is unclear, so separate pack addition is a stated accounting choice. |
| Battery power | 6C discharge and 1C charge | Constant limits, not cell electrical/thermal data. |
| Electrical losses | Motor and generator 95%, inverter 97%, gearbox 98%, charging 95% | Assumed conversion efficiencies; not efficiency maps. |
| Charging | 30-kW request, 90% target SOC, 2-kW hotel load | Engine supplies generator shaft work, limited by spare power, machine rating and battery headroom. Fuel pays for generation; no regeneration assumed. |
| Power switching | Fuel, electric, assist and charge selected by segment | Ideal clutch/engine shutdown, no restart energy or transient. No verified fault recovery or OEI/boost independence. |
| Ground segments | Fixed shaft power and durations; 764 shp assisted takeoff for two minutes | Energy bookkeeping only. Does not predict float takeoff distance or prove an equal water run. |
| Final approach | 3° at 85 KTAS using partial-flap proxy; fuel full-flap alternative supplied | Full-flap electric case can exceed the assumed motor rating. Neither configuration is an approved approach schedule. |

No validated pack integration, center-of-gravity change, new cowling/pod drag, float interference, cooling, water hydrodynamics, or structural loads are calculated. The unchanged float model is a drag/weight proxy. The reference approach/water wall in the conventional chart is calibrated, not measured; it is not a hybrid water-performance prediction.

## Shared conventional inputs and comparison method

- The original course landing **CLmax = 2.2** is restored. It is an educational assumption; the partial-flap proxy uses the takeoff-flap polar rather than the landing-flap CLmax. Clean and takeoff CLmax are unchanged.
- Main cruise and adjoining altitude transitions use **10,000 ft**. The 150-KTAS mission still uses its existing 600-ft/min climb schedule. The conventional chart's 3° climb requirements at sea level and 10,000 ft are recorded in [the comparator settings](reference/CONVENTIONAL_CONSTRAINT_INPUTS.json); they are not the mission's prescribed climb rate.
- `run_eco_caravan` prints a steady cruise power check for 150 and 164 KTAS at the same 97.5%-of-loaded-takeoff-weight condition as the comparator convention, without boost or charging load. The actual mission instead uses its evolving segment weights and includes charging work. The check is a modeled power comparison, not a certified speed, range, or matched-weight fuel-saving claim.
- 164 KTAS comes from [Textron's amphibian specifications](https://specialmissions.txtav.com/en/float-operations). The chosen 10,000 ft is an analysis condition, not a verified altitude for that published maximum. The [Jettly article](https://jettly.com/post/cessna-caravan-cruise-speed) was user-selected Caravan-family context, not an amphibian performance source.

## Source files and editable inputs

- [Ampaire AMP-H570](https://www.ampaire.com/amp-h570) — published system ratings.
- [Ampaire Eco Caravan](https://www.ampaire.com/vehicles/eco-caravan) — architecture and cargo-pod battery context; stated performance targets are not calibration inputs.
- [User-supplied original fact sheet](https://fd46bca4-8fdb-4a60-bb5a-984ecb406747.filesusr.com/ugd/1fdb50_1426d830e26d49dbb6397c657b0c0d62.pdf) — also saved under `sources/` with the project.
- `config/AMP_H570_requirements.json` — active mission and model assumptions; `docs/provenance/AMP_H570_SPEC_PROVENANCE.json` records the published versus assumed inputs. See the current verification report for run results.

## Verified result for these assumptions

At 10,000 ft the 150-KTAS mission completes: about 723.5 lb fuel burned, 4.25 kWh recharged and 78.1% final SOC. At the comparison weight, 150 KTAS requires 463.1 shp and 164 KTAS requires 557.8 shp; modeled continuous power is 543 shp, so the latter fails by 14.8 shp. These are separate checks. The mission still uses 150 KTAS and does not rely on boosting through a sustained continuous-power shortfall.

MATLAB R2025a: 39 tests passed, including the aligned settings, comparison shortfall, charging/fuel conservation and unsupported takeoff/approach cases.
