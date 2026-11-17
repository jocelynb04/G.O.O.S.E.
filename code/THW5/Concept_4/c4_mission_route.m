function plan = c4_mission_route(J,A,mission_name,options)
%c4_mission_route - Plan surface-specific mission phases without simulation.
%   PLAN = c4_mission_route(J,A,MISSION_NAME,OPTIONS) selects departure
%   and arrival surfaces using OPTIONS.departure_surface and
%   OPTIONS.arrival_surface, each "water" (default) or "land".
%   OPTIONS.surface_inputs may provide land_taxi, runway_takeoff and
%   runway_landing structures, each with shaft_hp and duration_min.
%   Missing inputs are reported; water values are never land defaults.
%
%   See also Concept4Mission

if nargin < 4 || isempty(options), options = struct(); end
if ~isstruct(options) || ~isscalar(options)
    error('C4:RouteOptions','Route options must be a scalar structure.');
end
allowed = {'departure_surface','arrival_surface','surface_inputs'};
if ~all(ismember(fieldnames(options),allowed))
    error('C4:RouteOptions','Unknown route option.');
end
departure = surface(c4_get(options,'departure_surface','water'));
arrival = surface(c4_get(options,'arrival_surface','water'));
inputs = c4_get(options,'surface_inputs',struct());
if ~isstruct(inputs) || ~isscalar(inputs) || ...
        ~all(ismember(fieldnames(inputs), ...
        {'land_taxi','runway_takeoff','runway_landing'}))
    error('C4:SurfaceInputs','Invalid surface input structure or key.');
end
if ~isfield(J.missions,mission_name)
    error('C4:Mission','Unknown mission name.');
end
source = c4_segments(J.missions.(mission_name).segments);
planned = {};
missing = {};
after_landing = false;
for i = 1:numel(source)
    seg = source{i};
    phase = char(seg.type);
    detail = struct('phase_name',phase,'surface','air', ...
        'aero_config','clean','power_mode','hybrid', ...
        'generator_intended_state','running_intended', ...
        'power_phase',phase,'shaft_hp',NaN,'duration_min',NaN, ...
        'input_status','EXISTING_MODEL_ASSUMPTION');
    if any(strcmp(phase,{'taxi','takeoff','landing','water_maneuver'}))
        selected = departure;
        if strcmp(phase,'landing') || after_landing, selected = arrival; end
        detail.surface = selected;
        if any(strcmp(phase,{'taxi','water_maneuver'}))
            if strcmp(selected,'water'), key = 'water_taxi';
            else, key = 'land_taxi'; end
            detail.aero_config = ['ground_gear_' gear(selected)];
        else
            if strcmp(selected,'water'), key = ['water_' phase];
            else, key = ['runway_' phase]; end
            detail.aero_config = [phase '_flaps_gear_' gear(selected)];
        end
        detail.phase_name = key;
        detail.power_mode = 'electric_only';
        detail.generator_intended_state = 'shutdown_intended';
        if strcmp(selected,'water')
            values = A.ground_phases.(phase);
            detail.shaft_hp = values.shaft_hp;
            detail.duration_min = c4_get(seg,'duration_min',[]);
            if isempty(detail.duration_min)
                detail.duration_min = values.duration_min;
            end
        elseif isfield(inputs,key)
            values = inputs.(key);
            validateSurfaceInput(values,key);
            detail.shaft_hp = values.shaft_hp;
            detail.duration_min = values.duration_min;
            detail.input_status = 'USER_SUPPLIED_UNVERIFIED';
        else
            detail.input_status = 'MISSING_SURFACE_ENERGY_INPUT';
            missing{end+1} = key; %#ok<AGROW>
        end
        seg.phi = 1;
        if strcmp(phase,'landing'), after_landing = true; end
    elseif strcmp(phase,'balked_landing')
        detail.surface = arrival;
        detail.aero_config = ['landing_flaps_gear_' gear(arrival)];
        detail.power_mode = 'electric_only';
        detail.generator_intended_state = 'shutdown_intended';
        detail.input_status = 'EXISTING_BALKED_PROFILE_UNVERIFIED';
        seg.phi = 1;
    elseif strcmp(phase,'descent')
        detail.power_mode = 'zero_power_approximation';
        detail.generator_intended_state = 'unspecified_zero_output';
        detail.input_status = 'ZERO_POWER_DESCENT_APPROACH_UNALLOCATED';
    elseif strcmp(phase,'loiter')
        detail.power_mode = 'generator_with_battery_backup';
    elseif ~any(strcmp(phase,{'climb','cruise'}))
        error('C4:Mission','Unsupported mission phase: %s',phase);
    end
    seg.route_detail = detail;
    planned{end+1} = seg; %#ok<AGROW>
    if strcmp(phase,'descent')
        % Approach is explicit but has no allocated time/energy evidence.
        % Keep the original ten-minute descent allowance unchanged.
        approach = struct('type','approach', ...
            'name','Electric approach (zero-duration unresolved marker)', ...
            'alt_ft',c4_get(seg,'alt_ft',0),'phi',1);
        detail.phase_name = 'electric_approach';
        detail.surface = arrival;
        detail.aero_config = ['landing_flaps_gear_' gear(arrival)];
        detail.power_mode = 'electric_only';
        detail.generator_intended_state = 'shutdown_intended';
        detail.power_phase = 'landing';
        detail.shaft_hp = 0;
        detail.duration_min = 0;
        detail.input_status = 'ZERO_DURATION_ZERO_POWER_APPROACH_UNVERIFIED';
        approach.route_detail = detail;
        planned{end+1} = approach; %#ok<AGROW>
    end
end
plan = struct('departure_surface',departure,'arrival_surface',arrival, ...
    'route_name',[departure '_to_' arrival], 'segments',{planned}, ...
    'missing_inputs',{unique(missing,'stable')}, ...
    'ready_for_energy_calculation',isempty(missing), ...
    'performance_status','UNVERIFIED_SURFACE_PERFORMANCE', ...
    'generator_transition_model','INTENT_ONLY_NO_START_STOP_PENALTIES', ...
    'limitations',{{ ...
    'Ground takeoff and landing energy profiles are approximations', ...
    'Descent remains zero power; approach has no allocated duration', ...
    'Generator physical state startup shutdown idle and penalties absent', ...
    'No water or runway takeoff landing distance verification', ...
    'Land balked climb retains gear down; retraction timing unverified', ...
    'Climb uses clean gear-up configuration; retraction penalties absent', ...
    'No post-landing taxi is added to the existing mission profile'}});
end

function value = surface(value)
if ~(ischar(value) && isrow(value) || isstring(value) && isscalar(value))
    error('C4:Surface','Surface must be water or land.');
end
value = lower(char(value));
if ~ismember(value,{'water','land'})
    error('C4:Surface','Surface must be water or land.');
end
end

function value = gear(selected)
if strcmp(selected,'water'), value = 'up'; else, value = 'down'; end
end

function validateSurfaceInput(values,key)
if ~isstruct(values) || ~isscalar(values) || ...
        ~isfield(values,'shaft_hp') || ~isfield(values,'duration_min')
    error('C4:SurfaceInputs','%s requires shaft_hp and duration_min.',key);
end
validateattributes(values.shaft_hp,{'numeric'}, ...
    {'scalar','real','finite','nonnegative'},mfilename,[key '.shaft_hp']);
validateattributes(values.duration_min,{'numeric'}, ...
    {'scalar','real','finite','positive'},mfilename,[key '.duration_min']);
end