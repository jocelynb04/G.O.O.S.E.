function [WP_env,WS_max,driving,WS_best,WP_best,report] = matching_envelope(WS,obj,W_TO,contexts)
%MATCHING_ENVELOPE Fixed-installation margin on a common REPORTING axis.
% For each condition: WP_limit=(W_TO/P_SL)*(P_available/P_required).
% This transformation is only for the evaluated source mix/operating cases;
% it is NOT permission to resize one summed engine power. Use
% source_constraint_sizing for independent motor sizing with fixed turbines.
% Missing inputs propagate NaN across the envelope instead of being omitted.
    if nargin < 3, W_TO = obj.wts.W_TO; end
    if nargin < 4, contexts = repmat({struct()},1,numel(obj.cons)); end
    report = evaluate_source_constraints(WS,obj,W_TO,contexts);
    validateattributes(obj.prop.P_SL,{'numeric'},{'scalar','finite','positive'});
    walls = [report.WS_wall]; walls = walls(isfinite(walls));
    WS_max = Inf; if ~isempty(walls), WS_max=min(walls); end
    power = find(string({report.type}) ~= "landing");
    limits = NaN(numel(power),numel(WS));
    for j=1:numel(power)
        r=report(power(j));
        limits(j,:)=(W_TO/obj.prop.P_SL)*r.available_hp./r.required_hp;
    end
    [WP_env,idx]=min(limits,[],1);
    unknown=any(isnan(limits),1); WP_env(unknown)=NaN;
    labels=string({report(power).name}); driving=labels(idx);
    driving(unknown)="unresolved";
    usable=WP_env; usable(WS>WS_max | unknown)=-Inf;
    [WP_best,j]=max(usable); WS_best=WS(j);
    if isempty(j) || ~isfinite(WP_best), WP_best=NaN; WS_best=NaN; end
end
