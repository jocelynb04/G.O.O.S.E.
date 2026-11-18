function report = run_concept1_openvsp()
%RUN_CONCEPT1_OPENVSP Evaluate the imported shape at the JSON design weight.
% Constraint failures are reported and plotted so an infeasible import can
% still be inspected. Energy and high-lift inputs remain screening targets.
here = fileparts(mfilename('fullpath'));
setup_jason_edits();
J = jsondecode(fileread(concept1_requirements_path()));
assert(isfield(J.geometry,'openvsp'),'The JSON has no imported OpenVSP geometry.');
D = J.analysis_design;
obj = concept1_disciplines();
W0 = D.takeoff_weight_lbf;
obj.geom.S_ref = J.geometry.reference_area_ft2;
S = obj.geom.S_ref;
AR = obj.geom.AR;
WS = W0/S;
WP = W0/obj.prop.P_SL;
[envelope,landingWall,driving,~,~,detail] = concept1_matching_envelope(WS,obj);
spanWall = W0*AR/J.aircraft_requirements.maximum_wingspan_ft^2;
curveIds = find(detail.is_curve);
limits = reshape(detail.WP_all(curveIds),[],1);
requiredHp = W0./limits;
availableHp = repmat(obj.prop.P_turboprop_SL,numel(curveIds),1);
waterRow = string({obj.cons(curveIds).type})' == "water_takeoff";
requiredHp(waterRow) = requiredHp(waterRow)*obj.prop.electric_power_ratio;
availableHp(waterRow) = obj.prop.P_electric_SL;
checks = table(detail.names(curveIds)',requiredHp,availableHp,availableHp>=requiredHp, ...
    'VariableNames',{'Requirement','RequiredRatedShaft_hp','AvailableRatedShaft_hp','Pass'});
landIds = find(~detail.is_curve);
landing = table(detail.names(landIds)',detail.wall_each(landIds)', ...
    repmat(WS,numel(landIds),1),WS<=detail.wall_each(landIds)', ...
    'VariableNames',{'Requirement','MaxWingLoading_lbf_ft2','ActualWingLoading_lbf_ft2','Pass'});
report = table(W0,S,obj.geom.b,AR,WS,WP,obj.geom.S_ht,obj.geom.S_vt,obj.geom.l_fus, ...
    obj.geom.S_wet,obj.aero.CD0,spanWall,landingWall,landingWall*S, ...
    obj.geom.b<65,WS<=landingWall,all(checks.Pass), ...
    'VariableNames',{'DesignWeight_lbf','WingArea_ft2','ProjectedSpan_ft','AspectRatio', ...
    'WingLoading_lbf_ft2','TurbinePowerLoading_lbf_hp','HorizontalTailArea_ft2', ...
    'VerticalTailArea_ft2','FuselageLength_ft','AirframeWetArea_ft2','CD0', ...
    'SpanMinimumWingLoading','LandingMaximumWingLoading','LandingLimitedWeight_lbf', ...
    'SpanPass','LandingPass','PowerConstraintsPass'});
out = fullfile(here,'results');
if ~isfolder(out), mkdir(out); end
writetable(report,fullfile(out,'OpenVSP_design_point.csv'));
writetable(checks,fullfile(out,'OpenVSP_power_checks.csv'));
writetable(landing,fullfile(out,'OpenVSP_landing_checks.csv'));
bd = obj.wts.OEW_breakdown(W0);
names = string(fieldnames(bd));
values = struct2array(bd)';
writetable(table(names,values),fullfile(out,'OpenVSP_weight_breakdown.csv'));

analysis = concept1_matchingdiagram(); %#ok<NASGU>

% Return a useful diagnostic even when this imported shape fails the RFP.
missionStatus = "Pending";
try
    [ledger,mission,early] = run_concept1_energy_trade(DesignWeight=W0, ...
        AspectRatio=AR,LandingCLmax=J.aerodynamics.CLmax_landing, ...
        CombustionRating=D.turbine_rating_hp,EngineDryWeight=J.propulsion.turboprop_dry_weight_lbf, ...
        EngineBSFC=J.propulsion.turboprop_BSFC_lb_per_hp_hr,AssistDelaySeconds=D.assist_delay_seconds, ...
        ElectricRating=D.electric_rating_hp,PackWhPerKg=D.pack_Wh_kg,DischargeC=D.discharge_C,CapacityRetention=D.capacity_retention, ...
        SkinFrictionFactor=D.skin_friction_factor,RequireFeasible=false,WriteResults=false);
    motorBare = mission.MotorRated_shp*.745699872/J.propulsion.motor_specific_power_kW_kg*2.20462262;
    oldAllowance = motorBare*(J.weights.concept1.motor_installation_factor-1);
    mission.InstalledMissionWeight_lbf = mission.WeightBuildup_lbf-oldAllowance+D.hybrid_installation_allowance_lbf;
    mission.RequiredElectricRating_hp = mission.MotorRated_shp;
    mission.SelectedElectricRating_hp = D.electric_rating_hp;
    mission.SelectedMotorPowerPass = D.electric_rating_hp>=mission.RequiredElectricRating_hp;
    % This energy calculation uses the selected installed motor rating. Its
    % energy ledger and weight totals describe that selected system.
    writetable(ledger,fullfile(out,'OpenVSP_mission_segments.csv'));
    writetable(mission,fullfile(out,'OpenVSP_mission_summary.csv'));
    writetable(early,fullfile(out,'OpenVSP_early_return.csv'));
    missionStatus = "Calculated with the selected installed electric rating";
    disp(mission);
catch problem
    missionStatus = "Failed: " + string(problem.identifier) + " " + string(problem.message);
end
fid = fopen(fullfile(out,'OpenVSP_run_status.txt'),'w');
assert(fid>=0,'Cannot open the run-status output.');
fprintf(fid,'Mission %s\n',missionStatus);
fprintf(fid,'Imported design point satisfies all modeled constraints: %d\n', ...
    report.SpanPass && report.LandingPass && report.PowerConstraintsPass);
fprintf(fid,'Model units interpreted as feet. See OpenVSP_geometry_snapshot.json.\n');
fclose(fid);
disp(report); disp(checks); disp(landing); disp(missionStatus);
end
