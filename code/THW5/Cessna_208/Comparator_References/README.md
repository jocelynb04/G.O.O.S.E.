# Cessna 208B comparator references

The conventional PT6A-140 Grand Caravan EX Amphibian is the team's comparator. The single and twin AMP-H570 installations are sensitivity studies on that airframe. The team's candidate concepts are documented separately.

| Item | Location |
|---|---|
| Comparator report draft | [Comparator write-up](Comparator_Writeup.md) |
| Conventional geometry | [Original OpenVSP model](../../../../OpenVSP%20Models/Cessna208%28Orig%29%20-%20Final%28Original%29.vsp3) |
| Twin installation geometry | [Hybrid OpenVSP model](../../../../OpenVSP%20Models/Cessna208%28Orig%29%20-%20FinalHybird%29%20-%20Copy.vsp3) |
| Conventional MATLAB model | [Run instructions](../Constriaint_Analysis/README.md) |
| Single AMP-H570 study | [Run instructions](../Hybrid_AMPEnging/EcoCaravan_Amphibian_AMP_H570/README.md) |
| Twin AMP-H570 study | [Run instructions](../Hybrid_MultiEngine/README.md) |
| Propulsion documentation | [Ampaire fact sheet](../Hybrid_AMPEnging/EcoCaravan_Amphibian_AMP_H570/docs/sources/AMP_H570_datasheet.pdf) |

## Sources and supporting data

- **Textron Aviation.** Use the Grand Caravan EX Amphibian column for the published weights, water run, maximum climb rate, cruise speed, and ferry range. [Cessna Caravan Amphibian Series product card](https://cessna.txtav.com/-/media/cessna/files/product-cards/turboprop/caravan_amphibian_productcard.pdf)
- **Ampaire.** Published system ratings for the exploratory conversions. The per-source power split and battery installation are documented model assumptions. [AMP-H570 engine](https://www.ampaire.com/amp-h570)
- **OpenVSP.** Comp Geom meshes and trims the selected exterior components and reports wetted area. [OpenVSP Comp Geom documentation](https://openvsp.org/api_docs/3.55.0/group___computations.html)
- **Course sizing method.** IHW3 supplies the sizing workflow and drag-polar structure. The MATLAB aero model implements the equivalent skin-friction relation attributed in the code to Raymer, Eq. 12.23. [Conventional aero code](../Constriaint_Analysis/src/models/TtpaAero.m)

## Before the team PDF

1. Add the two responsible students' names to the draft. Insert a labeled view of the conventional OpenVSP model.
2. Export the original model's component and total wetted areas in ft² from OpenVSP Comp Geom. Save the CSV here and record the model revision, OpenVSP version, geometry set, and treatment of propeller blades and deployed gear. Apply the same convention to the twin if its wetted-area difference is discussed.
3. Update the draft with the measured-from-geometry wetted-area estimate. Report separately whether the MATLAB drag model uses that value or the existing component-area approximation. If adopting the OpenVSP total, account for floats and other included components before applying any existing drag increments.
4. Add an independent comparator check at matched conditions and any team-selected measures of merit. Include an AFM performance point if available. Use the published brochure conditions when interpreting the maximum figures.
