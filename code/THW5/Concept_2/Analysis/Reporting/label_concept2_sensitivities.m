function result=label_concept2_sensitivities(result)
%LABEL_CONCEPT2_SENSITIVITIES Keep trial checks distinct from aircraft closure.
% A failed capacity bound is not a feasible installed pack or mass estimate.
% This reporting-only transform is idempotent and changes no simulation data.
    if ~isfield(result,'sensitivities') || isempty(result.sensitivities), return; end
    for k=1:numel(result.sensitivities)
        r=result.sensitivities(k);
        if isfield(r,'constraint_mission_status')
            sourceStatus=r.constraint_mission_status;
        else
            sourceStatus=r.status;
        end
        r.constraint_mission_status=sourceStatus;
        trialW=result.W_TO;
        if isfield(r,'trial_weight_lb'), trialW=r.trial_weight_lb; end
        r.mass_closed=sourceStatus=="pass" && isfinite(r.estimated_takeoff_mass_lb) && ...
            abs(r.estimated_takeoff_mass_lb-trialW)<=1e-4*trialW;
        if ~isfield(r,'capacity_search_bound_kWh'), r.capacity_search_bound_kWh=NaN; end
        if sourceStatus=="pass" && ~r.mass_closed
            r.status="mission/constraints pass; weight not closed";
        elseif sourceStatus~="pass"
            if isfinite(r.pack_kWh), r.capacity_search_bound_kWh=r.pack_kWh; end
            r.pack_kWh=NaN; r.estimated_takeoff_mass_lb=NaN; r.fuel_lb=NaN;
        end
        if k==1, rows=r; else, rows(k)=r; end
    end
    result.sensitivities=rows;
end
