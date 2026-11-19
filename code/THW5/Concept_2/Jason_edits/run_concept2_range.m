function result=run_concept2_range(options)
%RUN_CONCEPT2_RANGE Range search over mass-admissible discrete battery packs.
% No failed pack-sizing bound is ever installed or reported as achieved range.
% A single-trip range is distinct from repeated-route/OEI/geometry compliance.
arguments
 options.OutputDirectory (1,1) string = ""
 options.WriteResults (1,1) logical = true
 options.DistanceStepMi (1,1) double {mustBePositive} = 50
 options.MaximumRangeMi (1,1) double {mustBePositive} = 1600
 options.CapacityPoints (1,1) double {mustBeInteger,mustBePositive} = 12
end
[obj,opts,cfg,J]=build_concept2_study();W=12490;WS=W/obj.geom.S_ref;
% Reuse the existing constraint rating calculation, with no energy sizing.
assessment=sizing_pass(obj,W,WS,opts.contexts,@ratingProbe);
result=struct('status','NO_FEASIBLE_RANGE_ON_DECLARED_GRID','payload_lb',obj.wts.payload(), ...
 'target_statute_mi',1000,'weight_ceiling_lb',W,'maximum_range_statute_mi',NaN, ...
 'maximum_range_nmi',NaN,'range_resolution_mi',options.DistanceStepMi,'maximum_range_searched_mi',options.MaximumRangeMi, ...
 'capacity_grid_points',options.CapacityPoints,'rfp_compliance_established',false,'best',struct([]), ...
 'scope','Single-trip normal and reserve source/SOC/fuel/mass screen on a discrete pack-distance grid. Repeated routes, OEI and float compliance remain separate.');
if ~isfield(assessment,'last_assessment')
 result.status='SOURCE_CONSTRAINTS_PREVENT_RANGE_ASSESSMENT';
 result.source_assessment=assessment;saveResult(result,struct([]));return;
end
r=assessment.last_assessment.ratings;obj.prop.P_motor_peak=r.P_motor_peak;obj.prop.P_motor_continuous=r.P_motor_continuous;
obj.prop.P_inverter_rated_kW=r.P_inverter_rated_kW;obj.geom.W_TO=W;obj.wts.W_TO=W;
quantum=cfg.cell_series_count*cfg.battery_string_count*cfg.cell_nominal_energy_Wh/1000;
obj.wts.E_battery_nominal_kWh=quantum;b=obj.wts.OEW_breakdown(W);
kgPerKWh=1000/cfg.battery_specific_energy_Wh_kg;
installedLbPerKWh=2.20462262185*kgPerKWh*(1+obj.prop.hybrid.electrical_installation_fraction);
nonBattery=b.total-installedLbPerKWh*quantum;
maximumPack=max(0,(W-obj.wts.payload()-nonBattery)/installedLbPerKWh);
result.nonbattery_OEW_lb=nonBattery;result.maximum_pack_with_zero_fuel_kWh=maximumPack;
result.motor_peak_hp=r.P_motor_peak;result.motor_continuous_hp=r.P_motor_continuous;
result.geometry_validation=concept2_geometry_validation(obj,W);
rows=struct([]);best=struct([]);bestCases=struct([]);
if maximumPack<quantum
 result.status='NO_MASS_ALLOWANCE_FOR_BATTERY_AND_FUEL';saveResult(result,rows);return;
end
packs=unique(max(quantum,floor(linspace(quantum,maximumPack,options.CapacityPoints)/quantum)*quantum));
for mi=unique([0:options.DistanceStepMi:options.MaximumRangeMi,min(1000,options.MaximumRangeMi)])
  Q=J;sg=json_as_struct_array(Q.missions.std_mission.segments);ic=find(string({sg.type})=="cruise",1);
  sg(ic).distance_nm=mi/1.150779448;Q.missions.std_mission.segments=sg;
  cases=hybrid_mission_schedule(obj,W,cfg,Q);
 for E=packs
  obj.wts.E_battery_nominal_kWh=E;bd=obj.wts.OEW_breakdown(W);
  fuelBudget=min(W-bd.total-obj.wts.payload(),obj.geom.wing_fuel_volume()*obj.wts.rho_fuel);
  outs=struct([]);
  for k=1:2
   o=hybrid_soc_simulate(cases(k).steps,E,obj,cfg,obj.prop.hybrid.battery_soc_max,false);
   o.feasible=o.feasible && cases(k).schedule_feasible;
   if isempty(outs),outs=o;else,outs(end+1)=o;end %#ok<AGROW>
  end
  fuel=NaN;if all([outs.completed]),fuel=max([outs.fuel_burn_lb])*(1+Q.missions.std_mission.reserve_fuel_fraction) ...
    /(1-Q.missions.std_mission.fuel_accounting.unusable_fuel_fraction_of_total_capacity);end
  good=all([outs.feasible]) && isfinite(fuel) && fuel<=fuelBudget;
  reasons=unique(string({outs.reason}));
  row=struct('range_statute_mi',mi,'range_nmi',mi/1.150779448,'pack_BOL_kWh',E,'evaluation_weight_lb',W, ...
   'payload_lb',obj.wts.payload(),'OEW_lb',bd.total,'fuel_capacity_by_weight_lb',fuelBudget,'required_loaded_fuel_lb',fuel, ...
   'energy_feasible',all([outs.feasible]),'range_feasible',good,'minimum_SOC',min([outs.soc_min]), ...
   'reason',strjoin(reasons(strlength(reasons)>0),'; '));
  if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
  if good && (isempty(best)||mi>best.range_statute_mi),best=row;bestCases=cases;end
 end
end
result.best=best;result.packs_searched_kWh=packs;
if ~isempty(best)
 result.status='PRELIMINARY_SINGLE_TRIP_RANGE_ON_DECLARED_GRID';
 result.maximum_range_statute_mi=best.range_statute_mi;result.maximum_range_nmi=best.range_nmi;
 additional=struct([]);
 for k=3:numel(bestCases)
  o=hybrid_soc_simulate(bestCases(k).steps,best.pack_BOL_kWh,obj,cfg,obj.prop.hybrid.battery_soc_max,false);
  o.name=bestCases(k).name;o.feasible=o.feasible && bestCases(k).schedule_feasible;
  if isempty(additional),additional=o;else,additional(end+1)=o;end %#ok<AGROW>
 end
 result.additional_route_checks=additional;
end
saveResult(result,rows);
 function m=ratingProbe(~,~,~,xs)
  m=struct('fuel_lb',0,'E_battery_nominal_kWh',1,'contexts',{xs},'mission_feasible',false,'failure_checks_complete',false);
 end
 function saveResult(answer,data)
  if ~options.WriteResults,return;end
  out=options.OutputDirectory;if out=="",out=fullfile(concept2_project_root(),'Results','Range');end
  if ~isfolder(out),mkdir(out);end
  if ~isempty(data),writetable(struct2table(data),fullfile(out,'range_sweep.csv'));end
  fid=fopen(fullfile(out,'range_summary.json'),'w');c=onCleanup(@() fclose(fid));fprintf(fid,'%s',jsonencode(answer,PrettyPrint=true));
  disp(answer);fprintf('Range reports: %s\n',out);
 end
end
