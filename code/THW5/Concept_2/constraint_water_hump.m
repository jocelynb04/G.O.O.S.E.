function [WP_required, detail] = constraint_water_hump(WS,obj,con_no)
%CONSTRAINT_WATER_HUMP Provisional W_TO/P_required, electric shaft basis.
% Correlation inputs come from constraints.conditions in Concept 2 JSON.
    detail = constraint_demand(WS,obj,con_no);
    WP_required = 1./detail.hp_per_lbf;
end
