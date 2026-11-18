function [ledger, summary, earlyReturn, obj] = run_concept1_energy_trade(options)
%RUN_CONCEPT1_ENERGY_TRADE Screen a repeat mission with in-flight charging.
% Run from Jason_Edits. Default options reproduce the electric reserve case.
arguments
    options.DesignWeight (1,1) double {mustBePositive,mustBeFinite} = 9000
    options.AspectRatio (1,1) double {mustBePositive,mustBeFinite} = 7.2
    options.LandingCLmax (1,1) double {mustBePositive,mustBeFinite} = 2.2
    options.CombustionRating (1,1) double {mustBePositive,mustBeFinite} = 1100
    options.EngineDryWeight (1,1) double {mustBePositive,mustBeFinite} = 337
    options.EngineBSFC (1,1) double {mustBePositive,mustBeFinite} = 0.630*580/550
    options.AssistDelaySeconds (1,1) double {mustBeNonnegative} = Inf
    options.WriteResults (1,1) logical = true
    options.CruiseHours (1,1) double {mustBeNonnegative,mustBeFinite} = 0
    options.ChargerKW (1,1) double {mustBePositive,mustBeFinite} = 30
    options.PackWhPerKg (1,1) double {mustBeNonnegative,mustBeFinite} = 0
    options.DischargeC (1,1) double {mustBePositive,mustBeFinite} = 6
    options.CapacityRetention (1,1) double {mustBePositive,mustBeLessThanOrEqual(options.CapacityRetention,1)} = 1
    options.SkinFrictionFactor (1,1) double {mustBePositive,mustBeFinite} = 1
end
here = fileparts(mfilename('fullpath'));
setup_jason_edits();
cfg = jsondecode(fileread(concept1_requirements_path()));
baseline = concept1_disciplines();
cfg.geometry.AR = options.AspectRatio;
cfg.aerodynamics.CLmax_landing = options.LandingCLmax;
cfg.aerodynamics.Cfe = cfg.aerodynamics.Cfe*options.SkinFrictionFactor;
if options.PackWhPerKg > 0
    cfg.propulsion.battery_specific_energy_Wh_kg = options.PackWhPerKg;
end
cfg.propulsion.turboprop_dry_weight_lbf = options.EngineDryWeight;
cfg.propulsion.turboprop_length_ft = 61.89/12;
cfg.propulsion.turboprop_BSFC_lb_per_hp_hr = options.EngineBSFC;
cfg.propulsion.P_TO_over_P_max_continuous = 1;
candidate = [tempname() '.json'];
fid = fopen(candidate,'w');
assert(fid >= 0, 'Could not open a temporary candidate configuration.');
fprintf(fid,'%s',jsonencode(cfg));
fclose(fid);
cleanup = onCleanup(@() delete(candidate));
prop = Concept1HybridProp(candidate);
geom = Concept1Geom(candidate,prop);
aero = Concept1Aero(candidate,geom);
wts = Concept1Weights(candidate,geom,prop);
obj = struct('prop',prop,'geom',geom,'aero',aero,'wts',wts, ...
    'miss',baseline.miss,'cons',baseline.cons);

% Editable screening assumptions. The 3% gradient and charger/pack limits
% are from the Cessna 208 study. Electric power is used through 500 ft.
W0 = options.DesignWeight;
mtowCeiling = cfg.aircraft_requirements.maximum_certificated_takeoff_weight_exclusive_lbf;
assert(W0 < mtowCeiling,'Design takeoff weight must be strictly below %.0f lbf.',mtowCeiling);
span = 64.9;
balkGradient = 0.03;
balkFlaps = "landing_flaps_gear_up";
limits = struct('minimumSOC',0.20,'dischargeC',options.DischargeC,'chargeC',1, ...
    'chargerKW',options.ChargerKW,'generatorEfficiency',0.95,'chargeEfficiency',0.95);
geom.S_ref = span^2/geom.AR;
prop.P_SL = options.CombustionRating;
WS = W0/geom.S_ref;
[~,~,~,~,~,curves] = concept1_matching_envelope(WS,obj);
water = startsWith(curves.names,"Water takeoff");
waterTakeoffHp = W0/(0.95*curves.WP_all(water));
prop.electric_power_ratio = waterTakeoffHp/prop.P_SL;
approach = obj.miss.electric_final_approach;
segments = obj.miss.segments;
types = string({segments.type});
iCruise = find(types=="cruise");
iLoiter = find(types=="loiter");
if options.CruiseHours > 0
    segments(iCruise).distance_nm = segments(iCruise).ktas*options.CruiseHours;
end
assert(iLoiter==iCruise+2 && types(iLoiter-1)=="descent");
obj.miss.segments = segments(1:iCruise);
[fuel,weights,~,~,~,battery] = concept1_run_mission_L2(W0,obj);
takeoffEnergy = sum(battery);
takeoffKw = prop.battery_energy_kWh(waterTakeoffHp,1);
cruise = get_miss_seg(iCruise,obj.miss);
cruiseHours = cruise.dist/cruise.ktas;
cruiseWeight = weights(iCruise);
WAfterCruise = weights(end);
obj.miss.segments = segments;
loiter = get_miss_seg(iLoiter,obj.miss);

% Size against the heavier balked landing before subtracting charging fuel.
% Retain the original model's 0.992 weight fraction on each turboprop descent.
% During assistance the motors keep the water-takeoff power margin.
assist = struct('delay',options.AssistDelaySeconds,'electricCap',0.95*waterTakeoffHp);
[~,~,balkPeak] = electric_path(obj,0.992*WAfterCruise,approach, ...
    approach.end_alt_ft,approach.start_alt_ft,atand(balkGradient),balkFlaps, ...
    prop.eta_p_takeoff,assist);
ratingHp = max(waterTakeoffHp,balkPeak/0.95);
prop.electric_power_ratio = ratingHp/prop.P_SL;
requiredKw = max(takeoffKw,prop.battery_energy_kWh(balkPeak,1));
packKWh = requiredKw/limits.dischargeC;
cruiseChargeKW = charge_rate(obj,cruise,cruiseWeight,packKWh,limits);

% The departure deficit equals the prior flight's end-state deficit. Solve
% the repeating cycle while the cruise and reserve recharge toward full.
departureDeficit = 0;
for iteration = 1:20
    [cruiseStored,cruiseFuel] = recharge(departureDeficit+takeoffEnergy, ...
        cruiseChargeKW,cruiseHours,prop.BSFC,limits);
    beforeApproach = 0.992*(WAfterCruise-cruiseFuel);
    [firstEnergy,firstMinutes,firstPeak] = electric_path(obj,beforeApproach,approach, ...
        approach.start_alt_ft,approach.end_alt_ft,approach.flight_path_angle_deg, ...
        approach.config,prop.eta_p_landing);
    [balkEnergy,balkMinutes,actualBalkPeak,balkFuel,balkTurbinePeak] = electric_path( ...
        obj,beforeApproach,approach,approach.end_alt_ft,approach.start_alt_ft, ...
        atand(balkGradient),balkFlaps,prop.eta_p_takeoff,assist);
    afterBalkDeficit = departureDeficit+takeoffEnergy-cruiseStored+firstEnergy+balkEnergy;

    % Existing mission climb from the electric transition altitude to reserve.
    obj.miss.segments = segments;
    obj.miss.segments(iLoiter-1).alt_ft = approach.start_alt_ft;
    obj.miss.segments(iLoiter).type = 'climb';
    [loiterStart,climbFuel,~,climbInfo] = concept1_climb(beforeApproach-balkFuel,obj,iLoiter);
    obj.miss.segments = segments;
    [loiterEnd,loiterFuel] = concept1_loiter_lift(loiterStart,obj,iLoiter);
    reserveChargeKW = charge_rate(obj,loiter,loiterStart,packKWh,limits);
    [reserveStored,reserveFuel] = recharge(afterBalkDeficit,reserveChargeKW, ...
        loiter.time_min/60,prop.BSFC,limits);
    finalWeight = 0.992*(loiterEnd-reserveFuel);
    [finalEnergy,finalMinutes,finalPeak] = electric_path(obj,finalWeight,approach, ...
        approach.start_alt_ft,approach.end_alt_ft,approach.flight_path_angle_deg, ...
        approach.config,prop.eta_p_landing);
    endDeficit = afterBalkDeficit-reserveStored+finalEnergy;
    if abs(endDeficit-departureDeficit) < 1e-8
        break
    end
    departureDeficit = endDeficit;
end
assert(iteration < 20,'The assumed generator schedule did not close a repeat mission.');

phase = ["Water takeoff";"Initial turboprop climb";"Cruise with recharge"; ...
    "Descent to 500 ft";"Electric approach";"Balked landing"; ...
    "Turboprop climb to reserve";"IFR reserve loiter with recharge"; ...
    "Descent to final approach";"Electric final approach";"Water landing run"];
draw = [takeoffEnergy;0;0;0;firstEnergy;balkEnergy;0;0;0;finalEnergy;0];
stored = [0;0;cruiseStored;0;0;0;0;reserveStored;0;0;0];
peak = [waterTakeoffHp;0;0;0;firstPeak;actualBalkPeak;0;0;0;finalPeak;0];
segmentFuel = [0;fuel(iCruise-1);fuel(iCruise)+cruiseFuel; ...
    WAfterCruise-cruiseFuel-beforeApproach;0;balkFuel;climbFuel;loiterFuel+reserveFuel; ...
    loiterEnd-reserveFuel-finalWeight;0;0];
minutes = [segments(1).time_min;NaN;60*cruiseHours;NaN;firstMinutes;balkMinutes; ...
    60*climbInfo.time_hr;loiter.time_min;NaN;finalMinutes;segments(end).time_min];
soc = 1-(departureDeficit+cumsum(draw-stored))/packKWh;
peakBusKW = prop.battery_energy_kWh(peak,1);
assert(abs(sum(segmentFuel)-(W0-finalWeight))<1e-7,'Fuel ledger did not balance.');
assert(abs(sum(draw-stored))<1e-7,'Electric energy ledger did not balance.');
assert(min(soc)>=limits.minimumSOC,'Battery falls below the reserve SOC limit.');
assert(all(peakBusKW <= limits.dischargeC*packKWh+1e-7),'Discharge limit exceeded.');
assert(all(peak <= ratingHp),'Motor rating exceeded.');
[~,~,~,~,~,curves] = concept1_matching_envelope(WS,obj);
assert(curves.feasible && all(curves.WP_all(curves.is_curve)>=W0/prop.P_SL));

turbineAssist = zeros(size(peak));
turbineAssist(6) = balkTurbinePeak;
ledger = table(phase,minutes,peak,turbineAssist,peakBusKW,draw,stored,100*soc,segmentFuel, ...
    'VariableNames',{'Phase','Duration_min','ElectricPeak_shp','TurbineAssistPeak_shp','BatteryPeak_kW', ...
    'Draw_kWh','StoredCharge_kWh','EndSOC_percent','Fuel_lbf'});
% Charge and discharge were simulated at retained capacity. Size installed
% nameplate energy separately to cover capacity loss over service life.
nameplatePackKWh = packKWh/options.CapacityRetention;
batteryWeight = 1000*nameplatePackKWh/prop.battery_specific_energy_Wh_kg*2.20462262;
gross = wts.OEW(W0)+wts.payload()+batteryWeight+sum(segmentFuel);
summary = table(waterTakeoffHp,actualBalkPeak,ratingHp,packKWh,batteryWeight, ...
    100*(1-departureDeficit/packKWh),100*min(soc),100*soc(end), ...
    sum(draw),sum(stored),cruiseFuel+reserveFuel,sum(segmentFuel),gross,gross-W0,balkTurbinePeak,balkFuel,nameplatePackKWh, ...
    'VariableNames',{'WaterTakeoff_shp','BalkPeak_shp','MotorRated_shp','Pack_kWh', ...
    'Battery_lbf','DepartureSOC_percent','MinSOC_percent','ArrivalSOC_percent', ...
    'TotalDraw_kWh','TotalStoredCharge_kWh','ChargingFuel_lbf','MissionFuel_lbf', ...
    'WeightBuildup_lbf','WeightGap_lbf','BalkTurbinePeak_shp','BalkFuel_lbf','NameplatePack_kWh'});
if nargout >= 3
    % Conservative early return: hold the design takeoff weight throughout
    % approach and go-around, with no recharge after the water takeoff.
    [earlyApproachEnergy,~,earlyApproachHp] = electric_path(obj,W0,approach, ...
        approach.start_alt_ft,approach.end_alt_ft,approach.flight_path_angle_deg, ...
        approach.config,prop.eta_p_landing);
    [earlyBalkEnergy,~,earlyElectricHp,~,earlyTurbineHp] = electric_path( ...
        obj,W0,approach,approach.end_alt_ft,approach.start_alt_ft, ...
        atand(balkGradient),balkFlaps,prop.eta_p_takeoff,assist);
    earlyBatteryKW = prop.battery_energy_kWh(earlyElectricHp,1);
    afterBalkSOC = 1-(departureDeficit+takeoffEnergy+earlyApproachEnergy+earlyBalkEnergy)/packKWh;
    maxEarlyElectricHp = max([waterTakeoffHp,earlyApproachHp,earlyElectricHp]);
    maxEarlyBusKW = prop.battery_energy_kWh(maxEarlyElectricHp,1);
    earlyReturn = table(W0,earlyElectricHp,earlyTurbineHp,earlyBatteryKW, ...
        100*afterBalkSOC,maxEarlyElectricHp<=ratingHp, ...
        maxEarlyBusKW<=limits.dischargeC*packKWh+1e-7, ...
        afterBalkSOC>=limits.minimumSOC,curves.WS_wall, ...
        'VariableNames',{'GoAroundWeight_lbf','PeakElectric_shp','PeakTurbine_shp', ...
        'PeakBattery_kW','SOCafterBalk_percent','MotorWithinRating','BatteryWithinPowerLimit', ...
        'SOCAboveMinimum','LandingLimit_lbf_ft2'});
end

if options.WriteResults
    disp(ledger);
    disp(summary);
    writetable(ledger,fullfile(here,'results','RFP_energy_segments.csv'));
    writetable(summary,fullfile(here,'results','RFP_energy_summary.csv'));
end
end

function kW = charge_rate(obj,seg,W,capacity,limits)
% Check shaft headroom at segment entry, before fuel burn reduces drag.
state = get_state(seg.alt);
V = seg.ktas*6076.11549/3600;
polar = obj.aero.drag_polar(state);
qS = 0.5*state.rho*V^2*obj.geom.S_ref;
drag = qS*(polar.CD0+polar.K1*(W/qS)^2);
requiredHp = drag*V/(550*obj.prop.prop_eff(state,seg));
availableHp = obj.prop.P_SL*obj.prop.power_lapse(state,"max_continuous");
headroomKW = max(0,availableHp-requiredHp)*0.745699872;
kW = min([headroomKW*limits.generatorEfficiency,limits.chargerKW,limits.chargeC*capacity]);
end

function [stored,fuel] = recharge(deficit,dcKW,hours,bsfc,limits)
stored = min(deficit,dcKW*hours*limits.chargeEfficiency);
shaftKWh = stored/(limits.generatorEfficiency*limits.chargeEfficiency);
fuel = bsfc*shaftKWh/0.745699872;
end

function [energy,minutes,peak,fuel,turbinePeak] = electric_path(obj,W,schedule,h0,h1,angle,config,eta,assist)
if nargin < 9
    assist = struct('delay',Inf,'electricCap',Inf);
end
V = schedule.ktas*6076.11549/3600;
verticalSpeed = V*sind(angle);
seconds = (h1-h0)/verticalSpeed;
n = ceil(seconds/schedule.time_step_s);
edges = unique([linspace(0,seconds,n+1),min(assist.delay,seconds)]);
dt = diff(edges);
con = struct('config',config,'propeller_stopped',false);
power = zeros(size(dt));
turbine = zeros(size(dt));
for k = 1:numel(dt)
    midpoint = (edges(k)+edges(k+1))/2;
    altitude = h0+verticalSpeed*midpoint;
    state = get_state(altitude);
    polar = obj.aero.get_config_polar(state,con);
    qS = 0.5*state.rho*V^2*obj.geom.S_ref;
    CL = W*cosd(angle)/qS;
    assert(CL <= polar.CL_climb,'Electric flight segment violates stall margin.');
    drag = qS*(polar.CD0+polar.K1*CL^2);
    power(k) = max(0,(drag*V+W*verticalSpeed)/(550*eta));
    if midpoint >= assist.delay
        turbine(k) = max(0,power(k)-assist.electricCap);
        available = obj.prop.P_SL*obj.prop.power_lapse(state,"max_continuous");
        assert(turbine(k)<=available,'Turboprop assistance exceeds available power.');
        power(k) = power(k)-turbine(k);
    end
end
peak = max(power);
turbinePeak = max(turbine);
energy = obj.prop.battery_energy_kWh(sum(power.*dt),1/3600);
fuel = obj.prop.BSFC*sum(turbine.*dt)/3600;
minutes = seconds/60;
end

