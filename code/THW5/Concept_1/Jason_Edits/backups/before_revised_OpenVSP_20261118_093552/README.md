# Concept 1 matched to OpenVSP

Open this folder in MATLAB R2026b with Aerospace Toolbox. Run
`run_concept1_openvsp` to regenerate the constraint diagram, component weight
report and mission diagnostics. `run_concept1_constraints`,
`run_concept1_revised_constraints`, and `run_mission_cessna_method` call the
same current configuration. Rerunning them overwrites the `OpenVSP_` outputs.

Edit `analysis_design` in `Concept1_requirements_template.json` for takeoff
weight and selected propulsion/battery assumptions. The geometry and its
source dimensions are in `geometry.openvsp`. The current imported wing is
360 ft² with 59.963 ft projected span. Tail and body surfaces stay fixed;
wing-area sensitivity sweeps scale only the wing at the imported aspect ratio.
The evaluated wetted-area snapshot must be recomputed in OpenVSP after shape
edits. Editing just a source label does not regenerate the surface mesh.

The source model is `Git/OpenVSP Models/AmphibiousSeaplane_Concept1.vsp3`.
Dimensions are assumed to be feet. Model coordinates do not establish a
loaded waterline, interior cabin geometry or underfloor buoyancy.

Current results use the `OpenVSP_` prefix. Earlier `Concept1_` and `RFP_`
results describe the earlier sizing studies. The four fixed-geometry trade
runners now identify that historical scope when invoked. Their original
sources and the old active sources are preserved in the pre-import backup.
Use the current runner for the imported shape. The JSON still contains
preliminary lift, engine, water resistance and battery targets.

The imported design fails the water takeoff and water landing checks at
12,490 lb. The mission energy diagnostic sizes electric power to the model's
takeoff requirement and separately reports whether the selected motor rating
can supply it. Its resized-system fuel and weight totals must be read with
that failed power check. See `results/OpenVSP_import_notes.md`.
