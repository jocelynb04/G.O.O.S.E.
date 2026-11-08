function [WP_required, CGRP, LD, cfg] = constraint_climb(WS,obj,con_no)
%CONSTRAINT_CLIMB Required source shaft-power loading W_TO/P_required.
% This is a DEMAND, not W_TO divided by combined installed P_SL. The source
% availability comparison belongs in evaluate_source_constraints.
    d = constraint_demand(WS,obj,con_no);
    WP_required = 1./d.hp_per_lbf;
    c = get_con(con_no,obj.cons);
    cfg = constraint_polar(obj,get_state(c.alt),c);
    CL = cfg.CL_climb;
    LD = CL/(cfg.CD0+cfg.K1*CL^2);
    CGRP = (c.G+1/LD)/sqrt(CL);
end
