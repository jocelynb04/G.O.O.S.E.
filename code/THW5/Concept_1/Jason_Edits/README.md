# Jason_Edits

Open this folder in MATLAB R2026b with Aerospace Toolbox installed. Run
`run_mission_cessna_method` for the eight-segment mission. It finds the shared
IHW3 course framework in the Senior Design folder and updates the mission CSV
in `results`. If the copy is moved, pass the framework folder to the function
as an absolute path.

Edit `missions.std_mission` in `Concept1_requirements_template.json` to change the
water segment durations, electric power fractions, or final approach settings.
The design point inputs are near the top of `run_mission_cessna_method.m`. Its
default takeoff weight is 9,000 lbf and its selected wing loading is 12.50 lbf/ft².

The water takeoff and landing schedule comes from the Cessna 208 hybrid example.
The final approach uses its flight path and time step with Concept 1's polar and
propulsion efficiency. The report counts propulsion battery draw.

To rerun the matching diagram from this folder, run `setup_jason_edits` and then
`run_concept1_constraints`. The `results` folder includes the previous Toolbox
constraint report and its PNG and editable MATLAB figure.
