function [WP_required, extra] = constraint_cruise_speed(WS,obj,con_no)
%CONSTRAINT_CRUISE_SPEED Required shaft-power loading, drag-based balance.
% Units lbf/hp refer to W_TO/P_required, not combined installed power.
% See constraint_demand for the drag equation and evaluate_source_constraints
% for turbine-only availability, including altitude/rating/load limits.
    d = constraint_demand(WS,obj,con_no);
    WP_required = 1./d.hp_per_lbf;
    extra = d;
    extra.method = "drag_based";
end
