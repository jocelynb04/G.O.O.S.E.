function report = Concept4Verification(J,result,solver)
state = result.state;
solver.write_design(state);
rfp = J.rfp_performance_requirements;
if isempty(result.final)
    f = struct();
    flight = struct();
else
    f = result.final;
    flight = f.mission;
end
checks = struct();
payload_target = rfp.n_passengers_min*(rfp.W_passenger_lbf+rfp.W_baggage_per_passenger_lbf) ...
    + rfp.n_pilots*rfp.W_pilot_lbf;
checks.payload = struct('status','MODELED_REQUIREMENT_INPUT_ONLY', ...
    'target_lb',payload_target,'modeled_lb',solver.weights.payload());
checks.range_and_reserve = struct('status','NOT_ASSESSED', ...
    'nominal_cruise_distance_nmi',rfp.required_range_nmi, ...
    'reserve_min',rfp.ifr_reserve_time_min,'mission_fuel_lb',[], ...
    'soc_end',[],'balked_landing_explicit',rfp.balked_landing_at_start_of_reserve);
if ~isempty(fieldnames(flight))
    checks.range_and_reserve.status = 'MISSION_MODELED_UNVERIFIED_ASSUMPTIONS';
    checks.range_and_reserve.mission_fuel_lb = flight.total_fuel_lb;
    checks.range_and_reserve.soc_end = flight.soc_end;
end
checks.wingspan = struct('status','NOT_ASSESSED','modeled_ft',[], ...
    'limit_ft',rfp.maximum_wingspan_ft_strictly_below);
if isfield(f,'wingspan_ft')
    checks.wingspan.modeled_ft = f.wingspan_ft;
    if f.wingspan_ft < checks.wingspan.limit_ft
        checks.wingspan.status = 'PRELIMINARY_GEOMETRY_PASS';
    else
        checks.wingspan.status = 'PRELIMINARY_GEOMETRY_FAIL';
    end
end
cruise = constraint_cruise_speed_C4(state.W_TO_lb,state.S_ref_ft2,10000,180, ...
    solver.aero,solver.prop.eta_p_cruise);
checks.cruise_180_10k = struct('status','NOT_ASSESSED', ...
    'required_motor_shaft_hp',[],'generator_bus_kw', ...
    solver.prop.generator_available_bus_kw(10000), 'required_bus_kw',[]);
if ~isempty(cruise)
    motor_hp = state.motor_shaft_hp*solver.prop.motor_continuous_fraction;
    bus = solver.prop.motor_bus_kw(cruise.hp);
    checks.cruise_180_10k.required_motor_shaft_hp = cruise.hp;
    checks.cruise_180_10k.required_bus_kw = bus;
    if cruise.hp <= motor_hp && bus <= checks.cruise_180_10k.generator_bus_kw
        checks.cruise_180_10k.status = 'PRELIMINARY_POWER_SCREEN_PASS';
    else
        checks.cruise_180_10k.status = 'PRELIMINARY_POWER_SCREEN_FAIL';
    end
end
r0 = c4_required_climb_hp(state.W_TO_lb,state.S_ref_ft2,0,2000, ...
    solver.aero,solver.prop.eta_p_climb,35);
r10 = c4_required_climb_hp(state.W_TO_lb,state.S_ref_ft2,10000,500, ...
    solver.aero,solver.prop.eta_p_climb,35);
checks.roc_2000_msl = powerCheck(r0,state.motor_shaft_hp*solver.prop.motor_continuous_fraction);
checks.roc_500_10k = powerCheck(r10,state.motor_shaft_hp*solver.prop.motor_continuous_fraction);
checks.oei_450_msl = struct('status','NOT_VERIFIED_FAILED_PROP_DRAG_AND_YAW');
checks.water_takeoff_2000ft = struct('status','NOT_VERIFIED_HUMP_AND_ACCELERATION_MISSING');
checks.water_landing_2000ft = struct('status','NOT_VERIFIED_WATER_LANDING_MODEL_MISSING');
checks.buoyancy = struct('status','NOT_ASSESSED');
if isfield(f,'buoyancy')
    checks.buoyancy.status = f.buoyancy.rfp_below_cabin_floor_screen;
end
checks.adjacent_compartment_flooding = struct('status','NOT_VERIFIED');
checks.heel_and_gust = struct('status','NOT_VERIFIED');
checks.generator_failure = struct('status','NOT_VERIFIED');
checks.no_shore_charge = struct('status','NOT_VERIFIED_OPERATIONAL_RECHARGE');
checks.dock_clearance = struct('status','NOT_VERIFIED');
checks.crosswind = struct('status','NOT_VERIFIED');
checks.turnaround = struct('status','NOT_VERIFIED');
checks.sea_state_3 = struct('status','NOT_VERIFIED');
checks.ifr_fiki = struct('status','NOT_VERIFIED');
checks.seating_egress = struct('status','NOT_VERIFIED');
checks.noise_desirable = struct('status','NOT_EVALUATED_DESIRABLE');
closure = [];
if isfield(f,'mass_closure_residual_lb'), closure = f.mass_closure_residual_lb; end
checks.weight_energy_convergence = struct('status',result.status, ...
    'mass_closure_residual_lb',closure);
report = struct('summary_status','PRELIMINARY_SCREENS_ONLY_NOT_RFP_COMPLIANT', ...
    'checks',checks, 'note', ...
    'Numerical convergence does not establish RFP performance or certification compliance.');
end

function out = powerCheck(r, available)
if isempty(r)
    out = struct('status','NOT_ASSESSED','required_shaft_hp',[]);
elseif r.hp <= available
    out = struct('status','PRELIMINARY_POWER_SCREEN_PASS','required_shaft_hp',r.hp);
else
    out = struct('status','PRELIMINARY_POWER_SCREEN_FAIL','required_shaft_hp',r.hp);
end
end
