function [weights, power] = run_concept1_installation_trade()
%RUN_CONCEPT1_INSTALLATION_TRADE Compare installed generation architectures.
% These are editable planning allowances for hardware across both nacelles.
% Architecture reference: NASA Parallel Hybrid Turboprop Performance Modeling
% and Optimization (NTRS 20240014710), combining gearbox and motor/generator.
% Dedicated machine mass reference: https://www.h3x.tech/products/hpdm-30
% 750 shp and 2200 rpm reference: PT6A-34 JCAB TADS 745.
here = fileparts(mfilename('fullpath'));
setup_jason_edits();
cfg = jsondecode(fileread(concept1_requirements_path()));
W0 = 12490;
wingAR = 64.9^2*18.3/W0;
args = {'DesignWeight',W0,'AspectRatio',wingAR,'LandingCLmax',2.6, ...
    'CombustionRating',1500,'EngineDryWeight',340,'EngineBSFC',0.595*783/750, ...
    'AssistDelaySeconds',0,'WriteResults',false};
[~,full,early] = run_concept1_energy_trade(args{:});
[~,short] = run_concept1_energy_trade(args{:},CruiseHours=1);
[~,singleChannel] = run_concept1_energy_trade(args{:},ChargerKW=15);

lbPerKg = 2.20462262;
kWPerHp = 0.745699872;
bareMotorWeight = full.MotorRated_shp*kWPerHp / ...
    cfg.propulsion.motor_specific_power_kW_kg*lbPerKg;
oldAllowance = bareMotorWeight*(cfg.weights.concept1.motor_installation_factor-1);
architecture = repelem(["Propulsion motor-generators";"Dedicated generator"],3);
estimate = repmat(["Low";"Planning";"High"],2,1);
% Incremental hardware over the conventional PT6 reduction gearbox and
% engine installation already carried in the airframe model.
coupling = repmat([40;70;110],2,1);
invertersWiringCooling = repmat([30;50;75],2,1);
chargeIntegration = [5;10;20;20;25;45];
% Dedicated unit and integrated inverter only. The drive, heat rejection,
% and charge wiring are carried in chargeIntegration.
generatorMachine = [zeros(3,1);repmat(4.1*lbPerKg,3,1)];
explicitAllowance = coupling+invertersWiringCooling+chargeIntegration+generatorMachine;
change = explicitAllowance-oldAllowance;
gross = full.WeightBuildup_lbf+change;
ceiling = cfg.aircraft_requirements.maximum_certificated_takeoff_weight_exclusive_lbf;
weights = table(architecture,estimate,coupling,invertersWiringCooling,chargeIntegration, ...
    generatorMachine,explicitAllowance,repmat(oldAllowance,6,1),change,gross,gross-ceiling, ...
    'VariableNames',{'Architecture','Estimate','IncrementalCoupling_lbf', ...
    'InvertersWiringCooling_lbf','ChargeIntegration_lbf','DedicatedMachine_lbf', ...
    'NewAllowance_lbf','PreviousAllowance_lbf','AddedWeight_lbf', ...
    'WeightBuildup_lbf','Over12500_lbf'});

% The battery model uses 95% shaft-to-DC and 95% charge efficiency.
chargerDC = 30;
chargeDCPerNacelle = chargerDC/2;
shaftChargeKW = chargerDC/0.95;
propRPM = 2200;
shaftRadiansPerSecond = propRPM*2*pi/60;
motorHpPerNacelle = full.MotorRated_shp/2;
motorTorque = motorHpPerNacelle*kWPerHp*1000/shaftRadiansPerSecond;
chargeTorquePerNacelle = 0.5*shaftChargeKW*1000/shaftRadiansPerSecond;
combinedEarlyTorque = 0.5*(early.PeakElectric_shp+early.PeakTurbine_shp)* ...
    kWPerHp*1000/shaftRadiansPerSecond;
turbineTorque = 750*kWPerHp*1000/shaftRadiansPerSecond;
unrestrictedTorque = motorTorque+turbineTorque;
singleChannelMaxStoredShort = 15*(1+0.75)*0.95;
power = table(motorHpPerNacelle,motorTorque,chargerDC,chargeDCPerNacelle,shaftChargeKW, ...
    chargeTorquePerNacelle,combinedEarlyTorque,turbineTorque,unrestrictedTorque, ...
    full.TotalStoredCharge_kWh,short.TotalStoredCharge_kWh, ...
    singleChannelMaxStoredShort,singleChannel.MinSOC_percent, ...
    'VariableNames',{'MotorRatingPerSide_shp','MotorTorquePerSide_Nm_at2200', ...
    'ChargeTotalDC_kW','ChargeDCPerSide_kW','TotalChargeShaft_kW', ...
    'GeneratingTorquePerSide_Nm_at2200','EarlyBalkTorquePerSide_Nm_at2200', ...
    'TurbineRatedTorquePerSide_Nm_at2200','CombinedNameplateTorquePerSide_Nm_at2200', ...
    'FullMissionStored_kWh','OneHourCruiseStored_kWh', ...
    'OneHourCruiseMaxStoredAt15kW_kWh','FullMissionMinSOCAt15kW_percent'});
disp(weights);
disp(power);
writetable(weights,fullfile(here,'results','RFP_installation_weights.csv'));
writetable(power,fullfile(here,'results','RFP_installation_power.csv'));
end
