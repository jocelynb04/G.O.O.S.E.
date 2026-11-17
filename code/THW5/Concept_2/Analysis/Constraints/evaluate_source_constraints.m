function report = evaluate_source_constraints(WS, obj, W_TO, contexts)
%EVALUATE_SOURCE_CONSTRAINTS Standalone condition-by-condition power margins.
% contexts is one scalar struct per condition (cell array), in JSON order.
% Empty contexts produce UNRESOLVED, never a pass. Landing needs no power
% context. Reports retain demands even when source availability is unknown.
    if nargin < 4, contexts = repmat({struct()},1,numel(obj.cons)); end
    validateattributes(W_TO,{'numeric'},{'scalar','real','finite','positive'});
    WS = reshape(WS,1,[]);
    if ~iscell(contexts) || numel(contexts) ~= numel(obj.cons)
        error('evaluate_source_constraints:ContextCount','Supply one context cell per condition.');
    end
    for k = 1:numel(obj.cons)
        c = get_con(k,obj.cons);
        r = struct('name',c.name,'type',c.type,'power_source',string(c.power_source), ...
            'required_hp',NaN(size(WS)),'turbine_hp',NaN,'motor_hp',NaN, ...
            'available_hp',NaN,'margin_hp',NaN(size(WS)), ...
            'status',repmat("unresolved",size(WS)),'reason',"", ...
            'WS_wall',NaN,'speed_ktas',NaN(size(WS)),'model_status',"");
        try
            d = constraint_demand(WS,obj,k);
            r.required_hp = W_TO*d.hp_per_lbf;
            r.WS_wall = d.WS_wall;
            r.speed_ktas = d.speed_ktas;
            r.model_status = d.model_status;
            if c.type == "landing"
                r.status(:) = "pass";
                r.status(WS > d.WS_wall) = "fail";
            else
                s = get_state(c.alt);
                if isfield(contexts{k},'oat_C'), s.oat_C = contexts{k}.oat_C; end
                a = obj.prop.constraint_power_available(s,c,contexts{k});
                r.turbine_hp = a.turbine_hp;
                r.motor_hp = a.motor_hp;
                r.available_hp = a.total_hp;
                r.margin_hp = a.total_hp-r.required_hp;
                r.status(:) = "fail";
                r.status(r.margin_hp >= -1e-8) = "pass";
            end
        catch err
            % Only known missing model/operating inputs are reportable.
            % Programming errors propagate instead of hiding behind status.
            if startsWith(string(err.identifier),["source_power_available:", ...
                    "constraint_polar:","constraint_demand:","TtpaProp:", ...
                    "catalog_turbine_power:"])
                r.reason = string(err.identifier)+": "+string(err.message);
                if any(string(err.identifier)==["source_power_available:DurationExceeded", ...
                        "source_power_available:AuxiliaryPowerExceeded"])
                    r.status(:)="fail";
                end
            else
                rethrow(err);
            end
        end
        report(k) = r; %#ok<AGROW>
    end
    % Unspecified failure targets are part of the feasibility result too.
    % To resolve one, replace it with a fully specified condition in cons;
    % do not merely assert that the missing gradient/ROC has passed.
    if isfield(obj,'additional_failure_checks') && ~isempty(obj.additional_failure_checks)
        checks=json_as_struct_array(obj.additional_failure_checks);
        for j=1:numel(checks)
            r.name=string(checks(j).name); r.type="pending_failure_check";
            r.power_source=string(checks(j).power_source);
            r.required_hp=NaN(size(WS)); r.turbine_hp=NaN; r.motor_hp=NaN;
            r.available_hp=NaN; r.margin_hp=NaN(size(WS));
            r.status=repmat("unresolved",size(WS));
            r.reason="Supply the failure target and operating case as a full constraint condition.";
            r.WS_wall=NaN; r.speed_ktas=NaN(size(WS)); r.model_status="requirement missing";
            report(end+1)=r; %#ok<AGROW>
        end
    end
end
