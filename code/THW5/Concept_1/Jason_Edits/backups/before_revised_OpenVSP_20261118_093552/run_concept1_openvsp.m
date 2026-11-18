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

% The sweep changes only wing area at fixed AR, retaining the imported
% tails, body, nacelles and floats. At WS the shape matches the input model.
sweep = unique([10:0.2:45,spanWall,landingWall,WS]);
curves = zeros(numel(curveIds),numel(sweep));
env = zeros(size(sweep));
for k = 1:numel(sweep)
    obj.geom.S_ref = W0/sweep(k);
    [env(k),~,~,~,~,d] = concept1_matching_envelope(sweep(k),obj);
    curves(:,k) = d.WP_all(curveIds);
end
obj.geom.S_ref = S;
fig = figure('Name','OpenVSP Concept 1 constraints','Color','w','Position',[90 90 1350 800]);
ax = axes(fig); hold(ax,'on'); grid(ax,'on'); box(ax,'on');
for k = 1:numel(curveIds)
    plot(ax,sweep,curves(k,:),'LineWidth',1.4,'DisplayName',detail.names(curveIds(k)));
end
plot(ax,sweep,env,'k','LineWidth',2.4,'DisplayName','Constraint envelope');
xline(ax,spanWall,':','LineWidth',2,'DisplayName','Minimum W/S from 65 ft span');
xline(ax,landingWall,'--','Color',[.65 .18 .13],'LineWidth',2,'DisplayName','Maximum W/S from water landing');
plot(ax,WS,WP,'o','MarkerSize',11,'MarkerFaceColor',[.8 .19 .16], ...
    'MarkerEdgeColor','k','DisplayName','Imported geometry at selected weight');
plot(ax,9062/279,9062/867,'d','MarkerSize',9,'MarkerFaceColor',[.95 .7 .18], ...
    'MarkerEdgeColor','k','DisplayName','Grand Caravan EX Amphibian reference');
if spanWall<landingWall
    mask = sweep>=spanWall & sweep<=landingWall;
    patch(ax,[sweep(mask),fliplr(sweep(mask))],[env(mask),zeros(size(env(mask)))], ...
        [.4 .7 .6],'FaceAlpha',.2,'EdgeColor','none','DisplayName','Modeled feasible region');
else
    text(ax,12,2.0,'No feasible wing-loading band at this weight and aspect ratio', ...
        'FontSize',12,'Color',[.65 .1 .1]);
end
xlabel(ax,'Wing loading (lbf/ft^2)');
ylabel(ax,'Weight / rated turbine power (lbf/hp)');
title(ax,'Concept 1 constraints from the imported OpenVSP geometry');
subtitle(ax,sprintf('%.0f lbf | %.0f ft^2 wing | %.2f ft projected span | fixed power-source rating ratio',W0,S,obj.geom.b));
xlim(ax,[10 45]); ylim(ax,[0 25]);
legend(ax,'Location','southoutside','NumColumns',2,'Box','off','FontSize',9);
exportgraphics(fig,fullfile(out,'OpenVSP_matching_diagram.png'),'Resolution',150);
savefig(fig,fullfile(out,'OpenVSP_matching_diagram.fig'));

% Return a useful diagnostic even when this imported shape fails the RFP.
missionStatus = "Pending";
try
    [ledger,mission,early] = run_concept1_energy_trade(DesignWeight=W0, ...
        AspectRatio=AR,LandingCLmax=J.aerodynamics.CLmax_landing, ...
        CombustionRating=D.turbine_rating_hp,EngineDryWeight=J.propulsion.turboprop_dry_weight_lbf, ...
        EngineBSFC=J.propulsion.turboprop_BSFC_lb_per_hp_hr,AssistDelaySeconds=D.assist_delay_seconds, ...
        PackWhPerKg=D.pack_Wh_kg,DischargeC=D.discharge_C,CapacityRetention=D.capacity_retention, ...
        SkinFrictionFactor=D.skin_friction_factor,RequireFeasible=false,WriteResults=false);
    motorBare = mission.MotorRated_shp*.745699872/J.propulsion.motor_specific_power_kW_kg*2.20462262;
    oldAllowance = motorBare*(J.weights.concept1.motor_installation_factor-1);
    mission.InstalledMissionWeight_lbf = mission.WeightBuildup_lbf-oldAllowance+D.hybrid_installation_allowance_lbf;
    mission.RequiredElectricRating_hp = mission.MotorRated_shp;
    mission.SelectedElectricRating_hp = D.electric_rating_hp;
    mission.SelectedMotorPowerPass = D.electric_rating_hp>=mission.RequiredElectricRating_hp;
    % This energy calculation sizes motors to the takeoff requirement. Its
    % energy ledger describes that resized system, with selected power checked above.
    writetable(ledger,fullfile(out,'OpenVSP_mission_segments.csv'));
    writetable(mission,fullfile(out,'OpenVSP_mission_summary.csv'));
    writetable(early,fullfile(out,'OpenVSP_early_return.csv'));
    missionStatus = "Calculated using resized electric power; see selected-power check";
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
