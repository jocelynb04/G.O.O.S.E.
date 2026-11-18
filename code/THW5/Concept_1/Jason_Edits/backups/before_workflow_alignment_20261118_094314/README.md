# Revised OpenVSP Concept 1

Open AmphibiousSeaplane_Concept1_Jason_Revised.vsp3 in OpenVSP. Its dimensions
are interpreted as feet. The revised wing is 713.714 ft² with 64.5 ft projected
span. Horizontal and vertical tail areas are 105 and 60 ft². The horizontal
tail was raised with the taller fin, and wingtip floats and support struts
were moved outward to retain their original relative spanwise position.

In MATLAB R2026b with Aerospace Toolbox, open this folder and run
run_concept1_openvsp to regenerate the constraints, component weights,
selected-power mission and early-return reports. run_concept1_constraints,
run_concept1_revised_constraints and run_mission_cessna_method also run this
current analysis.

Current geometry and design settings are in Concept1_requirements_template.json.
OpenVSP_ result files describe this active revised shape. The source file hash
and evaluated component areas are in results/OpenVSP_geometry_snapshot.json.
Changing the model requires rerunning OpenVSP CompGeom and synchronizing the
snapshot. The snapshot does not update merely by changing its source filename.

The mission uses the selected 574.229 hp electric rating and 1,500 shp turbine
rating. Battery performance, CLmax 2.6, engine altitude/BSFC behavior and water
resistance remain preliminary assumptions. Geometry consistency and passes
in this model support continued design work; stability, structures, hull tests,
pack validation and installation packaging remain open.

The prior configuration and superseded result files are preserved in backups.
Historical trade runners identify their scope when invoked with imported geometry.
run_concept1_feasibility_trade remains available for wing/tail sensitivity work.
