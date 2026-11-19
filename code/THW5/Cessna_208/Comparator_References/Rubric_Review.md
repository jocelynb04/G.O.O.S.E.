# Comparator section rubric review

The PT6A-140 Caravan is the existing-aircraft comparator. The single and twin AMP-H570 cases are exploratory comparator variants. Shayla Ashton and Jason Bradshaw author this section.

| Proposed subsection | Evidence needed for the rubric | Current gap |
|---|---|---|
| Comparator Overview | Aircraft selection rationale, RFP relevance, baseline architecture and role of the exploratory variants | Identify both hybrid variants explicitly and attribute the 867-shp and 164-KTAS specifications to the Grand Caravan EX Amphibian |
| MATLAB Model | Sizing workflow, convergence criterion and residual, drag polar, propulsion and weight methods, mission and reserve, sourced installation effects, validity limits | Current fixed-aircraft mission pass and imposed takeoff weight do not establish TOGW convergence. Cite and justify float drag, installation mass, and propulsion assumptions |
| OpenVSP Model | Labeled views, dimension table, component wetted areas and total, explicit VSP versus MATLAB comparison | Add Comp Geom results and reconcile them with MATLAB analytical wetted areas. Explain full versus projected span and equivalent fuselage and tail geometry |
| Results and Key Takeaways | Predicted versus published table with percent error, diagnosis, calibrated quantities identified, weight breakdown, W/S and P/W, L/D, CLmax, fuel and energy, constraint design point, uncertainty bounds and MoMs | Supply matched-condition validation, sizing convergence evidence and sensitivity runs. Default hybrid missions have different payloads and cruise distances |

The shared framework and cross-concept comparison are team-wide requirements. This section should show how the comparator checks the shared methods and identify which calibration is carried into the actual candidate concepts. The team comparison table belongs in the integrated report and needs the same mission and assumptions across candidates.

## Evidence to add before submission

- Report percent error as 100 times (predicted minus reference) divided by reference. For calibrated empty weight and imposed MTOW, label the calibration or input explicitly. Their agreement has a different evidentiary role from an independent prediction.
- Compare range with the same payload, cruise condition, fuel load and reserve. Compare maximum climb using a maximum-rate calculation at matched conditions. A prescribed 3-degree climb and a published maximum rate describe different tests.
- Include baseline geometry and area sources, CD0, induced-drag factor, cruise L/D, CLmax and the weight breakdown. Give the units and definition of each MoM.
- Quantify float or installation effects with controlled runs and report the change in fuel, empty weight, TOGW or a selected MoM. Cite the method and its applicable range. The current lumped drag and reinforcement allowances need stronger support.
- Show uncertainty with a justified range on weak inputs and its effect on the result. Define the range as an assumed sensitivity interval when empirical bounds are unavailable.
- Preserve the electric takeoff power check's scope. Zero fuel burn over a prescribed power segment verifies energy accounting. Water takeoff performance needs a thrust and water-resistance calculation.

## Suggested space within the pair write-up

Use roughly half a page for the overview, one page for the MATLAB methods, one page for geometry and area consistency, and one to one-and-a-half pages for validation, results and interpretation. Fit tables and figures within the required three to four pages after rendering. This allocation is a planning estimate.
