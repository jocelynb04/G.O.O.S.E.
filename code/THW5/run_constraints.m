function [WP_required, WS_walls, names, types, report] = run_constraints(WS,obj,W_TO,contexts)
%RUN_CONSTRAINTS Source-independent demands and optional source feasibility.
% First output: W_TO/P_required [lbf/hp], NOT installed-power limits. Rows
% have different power sources and MUST NOT be minimized as one envelope.
% Fifth output: complete source margins when W_TO and contexts are provided.
% Without operating contexts the power cases are explicitly unresolved.
    WS = reshape(WS,1,[]);
    n = numel(obj.cons);
    WP_required = NaN(n,numel(WS));
    WS_walls = NaN(1,n); names = strings(1,n); types = names;
    report = [];
    if nargout >= 5
        if nargin < 3, W_TO = obj.wts.W_TO; end
        if nargin < 4, contexts = repmat({struct()},1,n); end
        report = evaluate_source_constraints(WS,obj,W_TO,contexts);
        for k=1:n
            names(k)=report(k).name; types(k)=report(k).type;
            WS_walls(k)=report(k).WS_wall;
            WP_required(k,:)=W_TO./report(k).required_hp;
        end
        return;
    end
    for k = 1:n
        c = get_con(k,obj.cons); names(k)=c.name; types(k)=c.type;
        % Dispatch through the public wrappers to keep each condition usable
        % on its own; all share constraint_demand's physical equations.
        switch c.type
            case "landing", WS_walls(k)=constraint_landing(obj,k);
            case "takeoff", WP_required(k,:)=constraint_takeoff(WS,obj,k);
            case "climb_gradient", WP_required(k,:)=constraint_climb(WS,obj,k);
            case "cruise_speed", WP_required(k,:)=constraint_cruise_speed(WS,obj,k);
            case "climb_rate", WP_required(k,:)=constraint_climb_rate(WS,obj,k);
            case "water_hump", WP_required(k,:)=constraint_water_hump(WS,obj,k);
            otherwise, error('run_constraints:UndefinedCondition','Unknown type %s.',c.type);
        end
    end
end
