function result=run_concept3_range(options)
%RUN_CONCEPT3_RANGE Full-payload fuel/energy range at fixed installed hardware.
% Scans gross weights because a low-rated installation may fail at 12,490 lb
% but work at a lower mission weight. Grid bounds are explicit, not an optimum.
arguments
 options.OutputDirectory (1,1) string = ""
 options.WriteResults (1,1) logical = true
 options.DistanceStepMi (1,1) double {mustBePositive} = 50
 options.MaximumRangeMi (1,1) double {mustBePositive} = 1800
 options.WeightStepLb (1,1) double {mustBePositive} = 500
 options.MotorRatingHp (1,1) double {mustBeNonnegative} = 0
 options.GeneratorEachHp (1,1) double {mustBeNonnegative} = 0
 options.BatteryDischargeKW (1,1) double {mustBeNonnegative} = 0
end
here=fileparts(mfilename('fullpath'));addpath(here,fullfile(here,'framework'),'-begin');
obj=ttpa_disciplines();J=jsondecode(fileread(fullfile(here,'concept3.json')));
if options.MotorRatingHp>0,obj.prop.P_SL=options.MotorRatingHp;end
if options.GeneratorEachHp>0,obj.prop.generator_engine_shaft_power_sl_hp_each=options.GeneratorEachHp;end
if options.BatteryDischargeKW>0,obj.prop.battery_max_discharge_bus_kw=options.BatteryDischargeKW;end
Wmax=J.range_analysis.evaluation_weight_lb;payload=obj.wts.payload();
assert(payload==2430,'C3:Payload','RFP payload must remain 2430 lb.');
rows=struct([]);best=struct([]);target=struct([]);
weights=unique([8000:options.WeightStepLb:Wmax,Wmax]);
for W=weights
 bd=obj.wts.OEW_breakdown(W);fuelBudget=min(W-bd.total-payload,obj.geom.wing_fuel_volume()*obj.wts.rho_fuel);
 distances=unique([0:options.DistanceStepMi:options.MaximumRangeMi,min(1000,options.MaximumRangeMi)]);
 for mi=distances
  idx=find(string({obj.miss.segments.type})=="cruise");obj.miss.segments(idx).distance_nm=mi/1.150779448;
  r=concept3_mission_energy(W,obj,CheckLimits=false);
  loaded=r.fuel_lb/(1-J.range_analysis.unusable_fuel_fraction);
  valid=r.feasible && loaded<=fuelBudget && obj.geom.b<65;
  row=struct('range_statute_mi',mi,'range_nmi',mi/1.150779448,'evaluation_weight_lb',W,'payload_lb',payload, ...
   'OEW_lb',bd.total,'fuel_capacity_by_weight_lb',fuelBudget,'required_loaded_fuel_lb',loaded, ...
   'mass_margin_lb',W-bd.total-payload-loaded,'energy_feasible',r.feasible,'range_feasible',valid, ...
   'minimum_SOC',r.minimum_SOC,'final_SOC',r.final_SOC,'reason',strjoin(r.reasons,'; '));
  if isempty(rows),rows=row;else,rows(end+1)=row;end %#ok<AGROW>
  if mi==1000 && (isempty(target)||row.mass_margin_lb>target.mass_margin_lb),target=row;targetTrace=r.trace;end
  if valid && (isempty(best)||mi>best.range_statute_mi),best=row;end
 end
end
result=struct('status','NO_FEASIBLE_RANGE_ON_DECLARED_GRID','payload_lb',payload,'target_statute_mi',1000, ...
 'maximum_range_statute_mi',NaN,'maximum_range_nmi',NaN,'range_resolution_mi',options.DistanceStepMi, ...
 'maximum_range_searched_mi',options.MaximumRangeMi,'weight_step_lb',options.WeightStepLb, ...
 'weight_ceiling_lb',Wmax,'best',best,'target_case',target,'rfp_compliance_established',false, ...
 'scope','Fixed hardware. Mission source/energy/fuel/mass/span screen only. No water-distance or failure certification claim.');
result.hardware=struct('motor_total_hp',obj.prop.P_SL, ...
 'generator_each_hp',obj.prop.generator_engine_shaft_power_sl_hp_each,'generator_count',obj.prop.n_generators, ...
 'battery_bus_limit_kw',obj.prop.battery_max_discharge_bus_kw,'battery_nameplate_kWh',obj.prop.battery_capacity_kwh, ...
 'changed_from_config',any([options.MotorRatingHp,options.GeneratorEachHp,options.BatteryDischargeKW]>0));
if ~isempty(best)
 result.status='PRELIMINARY_RANGE_ON_DECLARED_GRID';result.maximum_range_statute_mi=best.range_statute_mi;
 result.maximum_range_nmi=best.range_nmi;
end
% Explicitly evaluate repeated normal trips without resetting SOC or charging.
obj.miss=MissionProfileReader.read_profile(fullfile(here,'concept3.json'),'normal_mission');
soc=obj.prop.battery_initial_soc;cycle=struct([]);
for leg=1:J.range_analysis.repeated_legs
 soc=soc-J.mission_assumptions.accessory_kw*J.range_analysis.turnaround_min/60 ...
  /(obj.prop.battery_capacity_kwh*J.mission_assumptions.capacity_retention);
 if leg==1,soc=obj.prop.battery_initial_soc;end
 if soc<obj.prop.battery_min_soc,break;end
 rr=concept3_mission_energy(Wmax,obj,InitialSOC=soc,CheckLimits=false);soc=rr.final_SOC;
 c=struct('leg',leg,'final_SOC',soc,'feasible',rr.feasible,'reason',strjoin(rr.reasons,'; '));
 if isempty(cycle),cycle=c;else,cycle(end+1)=c;end %#ok<AGROW>
end
result.repeat_route=cycle;result.repeated_route_feasible=false;
if numel(cycle)==J.range_analysis.repeated_legs && all([cycle.feasible])
 result.repeated_route_feasible=abs(cycle(end).final_SOC-cycle(end-1).final_SOC)<=J.range_analysis.periodic_soc_tolerance;
end
if options.WriteResults
 out=options.OutputDirectory;if out=="",out=fullfile(here,'Results','Range');end
 if ~isfolder(out),mkdir(out);end
 writetable(struct2table(rows),fullfile(out,'range_sweep.csv'));
 if ~isempty(target),writetable(struct2table(targetTrace),fullfile(out,'target_mission_trace.csv'));end
 fid=fopen(fullfile(out,'range_summary.json'),'w');c=onCleanup(@() fclose(fid));fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));
 disp(result);fprintf('Range reports: %s\n',out);
end
end
