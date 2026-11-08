function J = validate_caravan_json(path)
% Validate operational inputs before constructing the mutually linked models.
J = jsondecode(fileread(path));
required = {'geometry','aerodynamics','propulsion','weights','sizing','missions','constraints','caravan'};
for k=1:numel(required)
    assert(isfield(J,required{k}),'Caravan:MissingBlock','Missing JSON block: %s',required{k});
end
assert(J.caravan.enabled && J.propulsion.n_engines==1,'Caravan:Variant','Standalone entry point requires single-engine EX mode.');
validateattributes(J.sizing.W_TO_guess_lbf,{'numeric'},{'scalar','positive','finite'});
validateattributes(J.sizing.S_ref_guess_ft2,{'numeric'},{'scalar','positive','finite'});
validateattributes(J.propulsion.BSFC_lb_per_hp_hr,{'numeric'},{'scalar','positive','finite'});
for key = {'eta_p_cruise','eta_p_climb','eta_p_loiter'}
    validateattributes(J.propulsion.(key{1}),{'numeric'},{'scalar','>',0,'<=',1,'finite'});
end
m = J.missions.std_mission;
validateattributes(m.reserve_fuel_fraction,{'numeric'},{'scalar','nonnegative','finite'});
validateattributes(m.cruise_segments,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(m.climb_segments,{'numeric'},{'scalar','integer','positive','finite'});
s = json_as_struct_array(m.segments);
for k=1:numel(s)
    validateattributes(s(k).alt_ft,{'numeric'},{'scalar','>=',0,'<=',20000,'finite'});
    kind = string(s(k).type);
    assert(any(kind==["takeoff","climb","cruise","descent","loiter","landing"]),'Caravan:Segment','Unsupported mission segment.');
    if any(kind==["cruise","loiter"])
        validateattributes(s(k).ktas,{'numeric'},{'scalar','positive','finite'});
    end
    if kind=="cruise", validateattributes(s(k).distance_nm,{'numeric'},{'scalar','nonnegative','finite'}); end
    if kind=="loiter", validateattributes(s(k).time_min,{'numeric'},{'scalar','nonnegative','finite'}); end
end
end
