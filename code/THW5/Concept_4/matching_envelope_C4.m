function out = matching_envelope_C4(J,geom,aero,prop,weight_lb,assumptions)
range = J.constraints.wing_loading_range_psf;
lo = range(1);
hi = range(2);
n = assumptions.design_constraint_wing_loading_points;
speeds = assumptions.design_constraint_speed_samples;
span_cap = J.rfp_performance_requirements.maximum_wingspan_ft_strictly_below;
span_design = span_cap-c4_get(assumptions,'span_design_margin_ft',1);
if span_design <= 0 || n < 3 || speeds < 3
    error('C4:Envelope', 'Invalid matching sweep bounds.');
end
lo = max(lo,weight_lb*geom.AR/span_design^2);
results = struct([]);
oldS = geom.S_ref;
try
    if lo <= hi
        for i = 1:n
            ws = lo+(hi-lo)*(i-1)/(n-1);
            area = weight_lb/ws;
            geom.S_ref = area;
            if geom.b >= span_cap, continue; end
            r0 = c4_required_climb_hp(weight_lb,area,0,2000,aero,prop.eta_p_climb,speeds);
            r10 = c4_required_climb_hp(weight_lb,area,10000,500,aero,prop.eta_p_climb,speeds);
            roei = c4_required_climb_hp(weight_lb,area,0,450,aero,prop.eta_p_climb,speeds);
            cruise = constraint_cruise_speed_C4(weight_lb,area,10000,180,aero,prop.eta_p_cruise);
            if isempty(r0) || isempty(r10) || isempty(roei) || isempty(cruise)
                continue;
            end
            f = prop.motor_continuous_fraction;
            motor_hp = max([r0.hp/f r10.hp/f cruise.hp/f ...
                roei.hp/f*prop.n_motors/(prop.n_motors-1)]);
            motor_hp = motor_hp*(1+c4_get(assumptions,'motor_power_margin_fraction',0.01));
            phi = c4_get(J.propulsion.phi,'climb',0.4);
            gen_hp = max([generator_rating(prop,cruise.hp,10000,1) ...
                generator_rating(prop,r0.hp,0,1-phi) ...
                generator_rating(prop,r10.hp,10000,1-phi)]);
            gen_hp = gen_hp*(1+assumptions.generator_power_margin_fraction);
            score = motor_hp+0.15*gen_hp+0.20*area;
            r = struct('wing_loading_psf',ws,'wing_area_ft2',area, ...
                'span_ft',geom.b,'required_motor_hp',motor_hp, ...
                'required_turboshaft_hp_each',gen_hp,'cruise_180_hp',cruise.hp, ...
                'roc_2000_sl_hp',r0.hp,'roc_500_10k_hp',r10.hp, ...
                'roc_450_oei_hp_NO_FAILURE_DRAG',roei.hp,'score',score);
            if isempty(results), results = r; else, results(end+1) = r; end
        end
    end
catch ME
    geom.S_ref = oldS;
    rethrow(ME);
end
geom.S_ref = oldS;
if isempty(results)
    out = struct('status','NO_FEASIBLE_AERODYNAMIC_POINT_WITHIN_WING_LOADING_SWEEP', ...
        'candidates',struct([]),'selected',[]);
    return;
end
[~,idx] = min([results.score]);
out = struct('status','PRELIMINARY_AERO_AND_SPAN_ONLY', ...
    'selected',results(idx),'candidates',results, ...
    'unverified',{{'Water takeoff/landing','OEI asymmetric drag and yaw', ...
    'Generator failure','Balked landing performance'}});
    function hp = generator_rating(pr,shaft_hp,alt_ft,bus_fraction)
        kw = pr.motor_bus_kw(shaft_hp)*bus_fraction;
        sigma = pr.sigma_isa(alt_ft);
        hp = kw/(pr.eta_generator*pr.eta_rectifier*0.7456998715822702) ...
            / sigma^pr.generator_lapse_exponent/pr.n_generators;
    end
end
