function [WP_required, detail] = constraint_climb_rate(WS,obj,con_no)
%CONSTRAINT_CLIMB_RATE W_TO/P_required at bounded minimum-power speed.
% Implements P_shaft=(D*V+W_condition*ROC)/(550*eta_prop); ROC in ft/s.
    detail = constraint_demand(WS,obj,con_no);
    WP_required = 1./detail.hp_per_lbf;
end
