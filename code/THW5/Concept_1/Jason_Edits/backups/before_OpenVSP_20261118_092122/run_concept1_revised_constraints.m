function design = run_concept1_revised_constraints()
%RUN_CONCEPT1_REVISED_CONSTRAINTS Match the installed hybrid candidate.
% It uses the 683-ft^2 trade, installed motor-generators, and an assisted
% go-around. Pack performance and Cfe are design targets.
here = fileparts(mfilename('fullpath'));
setup_jason_edits();
cfg = jsondecode(fileread(concept1_requirements_path()));
W0 = 12490;
designWS = 18.3;
targetSpan = 64.9;
wingAR = targetSpan^2*designWS/W0;
referenceTurbineHp = 1500;
args = {'DesignWeight',W0,'AspectRatio',wingAR,'LandingCLmax',2.6, ...
    'AssistDelaySeconds',0,'WriteResults',false,'PackWhPerKg',300, ...
    'DischargeC',8,'CapacityRetention',0.80,'SkinFrictionFactor',0.85};
[~,mission,early,obj] = run_concept1_energy_trade(args{:}, ...
    CombustionRating=referenceTurbineHp,EngineDryWeight=340,EngineBSFC=0.595*783/750);
[~,alternate] = run_concept1_energy_trade(args{:}, ...
    CombustionRating=1360,EngineDryWeight=337,EngineBSFC=0.602*715/680);

% Evaluate the water proxy and flight curves at the area for each loading.
% The ratios of electric and turbine rated power are held fixed.
[~,landingWall,governing,~,~,atPoint] = concept1_matching_envelope(designWS,obj);
spanWall = W0*wingAR/cfg.aircraft_requirements.maximum_wingspan_ft^2;
designWP = W0/referenceTurbineHp;
shaftRatio = obj.prop.electric_power_ratio;
labels = ["180 KTAS at 10,000 ft";"500 ft/min at 10,000 ft"; ...
    "2,000 ft/min at sea level";"450 ft/min OEI at sea level";"Electric water takeoff"];
assert(nnz(atPoint.is_curve)==numel(labels));
limitWP = reshape(atPoint.WP_all(atPoint.is_curve),[],1);
requiredInstalled = W0./limitWP;
waterMinimumHp = shaftRatio*requiredInstalled(end);
availableInstalled = repmat(referenceTurbineHp,5,1);
availableInstalled(end) = obj.prop.P_electric_SL;
requiredShaftHp = requiredInstalled;
requiredShaftHp(end) = waterMinimumHp;
shaftMargin = 100*(availableInstalled./requiredShaftHp-1);
checks = table(labels,limitWP,requiredShaftHp,availableInstalled,shaftMargin, ...
    'VariableNames',{'Condition','TurbineBasisLimit_lbf_shp','RequiredRatedShaft_shp', ...
    'AvailableRatedShaft_shp','PowerMargin_percent'});
assert(all(shaftMargin>=0) && spanWall<designWS && designWS<landingWall);
assert(early.MotorWithinRating && early.BatteryWithinPowerLimit && early.SOCAboveMinimum);
installationAllowance = 130;
motorAllowance = @(hp) hp*0.745699872 / cfg.propulsion.motor_specific_power_kW_kg * ...
    2.20462262*(cfg.weights.concept1.motor_installation_factor-1);
installedGross = mission.WeightBuildup_lbf+installationAllowance-motorAllowance(mission.MotorRated_shp);
alternateGross = alternate.WeightBuildup_lbf+installationAllowance-motorAllowance(alternate.MotorRated_shp);
ceiling = cfg.aircraft_requirements.maximum_certificated_takeoff_weight_exclusive_lbf;
chargingShaftHp = 30/0.95/0.745699872;

caravanWeight = 9062;
caravanArea = 279;
caravanHp = 867;
caravanWS = caravanWeight/caravanArea;
caravanWP = caravanWeight/caravanHp;
sweep = unique([13:0.08:35,spanWall,designWS,landingWall,caravanWS]);
envelope = zeros(size(sweep));
curve = zeros(numel(labels),numel(sweep));
for k = 1:numel(sweep)
    obj.geom.S_ref = W0/sweep(k);
    [envelope(k),~,~,~,~,d] = concept1_matching_envelope(sweep(k),obj);
    curve(:,k) = d.WP_all(d.is_curve);
end
obj.geom.S_ref = W0/designWS;

design = table(W0,designWS,designWP,obj.geom.S_ref,targetSpan,wingAR, ...
    referenceTurbineHp,obj.prop.P_electric_SL,waterMinimumHp, ...
    spanWall,landingWall,100*(landingWall-designWS)/landingWall, ...
    obj.aero.CD0,string(governing),mission.NameplatePack_kWh, ...
    mission.Battery_lbf,mission.MissionFuel_lbf,installedGross,W0-installedGross, ...
    ceiling-installedGross,early.PeakTurbine_shp,early.SOCafterBalk_percent, ...
    requiredInstalled(1)+chargingShaftHp,alternateGross, ...
    'VariableNames',{'DesignWeight_lbf','WingLoading_lbf_ft2','TurbinePowerLoading_lbf_shp', ...
    'WingArea_ft2','Span_ft','AspectRatio','TurbineRating_shp','ElectricRating_shp', ...
    'WaterTakeoffMinimumElectric_shp','SpanMinWingLoading_lbf_ft2','LandingMaxWingLoading_lbf_ft2', ...
    'LandingWingLoadingMargin_percent','AssumedCD0','GoverningConstraint','BatteryNameplate_kWh', ...
    'Battery_lbf','MissionFuel_lbf','InstalledMissionWeight_lbf','DesignPointWeightMargin_lbf', ...
    'WeightCeilingMargin_lbf','EarlyGoAroundAssist_shp','EarlyReturnSOC_percent', ...
    'CruisePlusChargeMinimumShaft_shp','PT6A27InstalledMissionWeight_lbf'});

% Textron and Wipaire describe the 9,062-lb float-equipped comparator.
% Jekta and REGENT serve as architecture and operations references.
reference = table(["Concept 1 trade";"Cessna Grand Caravan EX Amphibian"; ...
    "Jekta PHA-ZE 100";"REGENT Viceroy Electric"], ...
    [W0;caravanWeight;NaN;15000],[targetSpan;52+1/12;NaN;65], ...
    [designWS;caravanWS;NaN;54],[designWP;caravanWP;NaN;NaN], ...
    [180;164;110;160],[868.976;813;NaN;160],[2000;3270;NaN;NaN], ...
    ["Modeled amphibian, water takeoff is a correlation"; ...
    "Published amphibian data, 813 nmi is a ferry range"; ...
    "Development amphibian, blown lift and distributed electric propulsion"; ...
    "Wing-in-ground effect, hydrofoils, range and speed approximate"], ...
    'VariableNames',{'Aircraft','TakeoffWeight_lbf','Span_ft','WingLoading_lbf_ft2', ...
    'TurbinePowerLoading_lbf_shp','Cruise_kt','Range_nmi','WaterTakeoffOver50ft_ft','Basis'});
reference.Source = ["Concept 1 MATLAB model"; ...
    "https://cessna.txtav.com/turboprop/grand-caravan-ex ; https://wipaire.com/wipline-floats/wipline-8750-floats/"; ...
    "https://jekta.swiss/ ; https://jekta.swiss/phaze100-features/"; ...
    "https://www.regentcraft.com/seagliders/viceroy"];

fig = figure('Name','Concept 1 revised constraint diagram','Color','w', ...
    'Position',[100 100 1470 760]);
layout = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
left = nexttile(layout);
right = nexttile(layout);
colors = [0.10 0.45 0.74; 0.83 0.43 0.12; 0.61 0.25 0.38; ...
    0.46 0.39 0.63; 0.07 0.52 0.40];
fillMask = sweep>=spanWall & sweep<=landingWall & envelope>0;
for ax = [left right]
    hold(ax,'on'); grid(ax,'on'); box(ax,'on');
    set(ax,'FontName','Arial','FontSize',12,'GridAlpha',0.18,'Layer','top');
    x = sweep(fillMask);
    y = envelope(fillMask);
    patch(ax,[x,fliplr(x)],[y,zeros(size(y))],[0.31 0.69 0.64], ...
        'FaceAlpha',0.28,'EdgeColor','none','DisplayName','Feasible under modeled constraints');
    for k = 1:numel(labels)
        plot(ax,sweep,curve(k,:),'LineWidth',1.35,'Color',colors(k,:), ...
            'DisplayName',labels(k));
    end
    plot(ax,sweep,envelope,'k','LineWidth',2.2,'DisplayName','Constraint envelope');
    xline(ax,spanWall,':','Color',[0.26 0.32 0.40],'LineWidth',1.7, ...
        'DisplayName','65 ft span boundary');
    xline(ax,landingWall,'--','Color',[0.60 0.22 0.15],'LineWidth',1.7, ...
        'DisplayName','Water landing boundary');
    plot(ax,designWS,designWP,'o','MarkerSize',9,'MarkerFaceColor',[0.05 0.41 0.37], ...
        'MarkerEdgeColor','k','DisplayName','Concept 1 design point');
    xlabel(ax,'Wing loading (lbf/ft^2)');
end
plot(left,caravanWS,caravanWP,'d','MarkerSize',10,'MarkerFaceColor',[0.98 0.75 0.32], ...
    'MarkerEdgeColor','k','DisplayName','Grand Caravan EX Amphibian');
ylabel(left,'Power loading (lbf / rated turbine shp)');
xlim(left,[13 35]); ylim(left,[0 27]);
xlim(right,[17.7 19.2]); ylim(right,[7.5 10.2]);
title(left,'Concept 1 and Caravan reference');
text(left,caravanWS-0.4,caravanWP+1.0,'Caravan EX','HorizontalAlignment','right','FontSize',10);
title(right,'Design point and available wing-loading band');
text(right,designWS+0.025,designWP-0.14,sprintf('%.2f, %.2f',designWS,designWP), ...
    'FontSize',11,'Color',[0.05 0.30 0.28]);
legend(left,'Location','southoutside','NumColumns',2,'FontSize',9,'Box','off');
title(layout,'Concept 1 revised matching diagram','FontSize',18);
subtitle(layout,'12,490 lbf design weight  |  fixed electric-to-turbine rating ratio  |  preliminary water correlations');
out = fullfile(here,'results');
exportgraphics(fig,fullfile(out,'Concept1_revised_matching_diagram.png'),'Resolution',155);
savefig(fig,fullfile(out,'Concept1_revised_matching_diagram.fig'));
writetable(design,fullfile(out,'Concept1_revised_design_point.csv'));
writetable(checks,fullfile(out,'Concept1_revised_constraint_checks.csv'));
writetable(reference,fullfile(out,'Concept1_aircraft_comparison.csv'));
disp(design);
disp(checks);
end
