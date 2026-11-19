function [analysis,hist]=run_concept4_study(options)
%RUN_CONCEPT4_STUDY Reproducible CAD-matched geometry, mass/mission and plots.
arguments
 options.Visible (1,1) logical = false
 options.Plot (1,1) logical = true
 options.SweepPoints (1,1) double {mustBeInteger,mustBeGreaterThanOrEqual(options.SweepPoints,3)} = 251
end
root=fileparts(mfilename('fullpath'));addpath(root,'-begin');out=fullfile(root,'Results','Current');if ~isfolder(out),mkdir(out);end
geometry=verify_openvsp_geometry();[obj,J,A]=concept4_context();
[summary,flight]=concept4_size_at_weight(obj,J,A);
data=concept4_constraint_data(obj,J,A,options.SweepPoints);
analysis=struct('summary',summary,'geometry',geometry,'constraints',data,'mission',flight, ...
 'buoyancy',obj.hydro.buoyancy_screen(J.analysis_design.evaluation_weight_lb));hist=[];
write_json_C4(fullfile(out,'summary.json'),summary);
write_json_C4(fullfile(out,'mission.json'),flight);
write_json_C4(fullfile(out,'geometry_and_buoyancy.json'),struct('geometry',rmfield(geometry,'checks'),'buoyancy',analysis.buoyancy));
writetable(struct2table(flight.segments),fullfile(out,'mission_segments.csv'));
D=obj.aero.drag_breakdown();names=fieldnames(D.components);rows=struct([]);
for i=1:numel(names)
 row=D.components.(names{i});row.name=names{i};if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
end
writetable(struct2table(rows),fullfile(out,'drag_breakdown.csv'));
T=table(data.WS',data.span_ft',data.motor_limits(1,:)',data.motor_limits(2,:)',data.motor_limits(3,:)', ...
 data.motor_limits(4,:)',data.motor_limits(5,:)',data.flight_envelope', ...
 'VariableNames',{'WS_psf','span_ft','WP_climb2000','WP_climb500','WP_one_motor_out_IDEAL','WP_balked','WP_cruise180','WP_flight_boundary'});
writetable(T,fullfile(out,'constraint_sweep.csv'));
G=table(data.WS',data.generator_limits(1,:)',data.generator_limits(2,:)',data.generator_limits(3,:)', ...
 'VariableNames',{'WS_psf','WP_gen_climb2000','WP_gen_climb500','WP_gen_cruise180'});
writetable(G,fullfile(out,'generator_constraint_sweep.csv'));
save(fullfile(out,'concept4_study.mat'),'analysis');
if options.Plot,analysis.figures=plot_concept4_constraints(data,out,options.Visible);end
disp(summary);fprintf('Geometry matches OpenVSP. Full RFP compliance is not established.\nReports: %s\n',out);
end
