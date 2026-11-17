function result = run_caravan(do_sizing)
% Baseline mission by default; true also runs exploratory resized-aircraft sizing.
root=setup_project();
if nargin == 0, do_sizing = false; end
jsonPath=fullfile(root,'config','GrandCaravanEX_requirements_IHW3.json');
obj = ttpa_disciplines(jsonPath);
result.benchmark = grand_caravan_ex_check_json(jsonPath);
[result.fuel_lb,result.fuel_fraction,result.burn,result.weight,result.wf,result.detail] = mission_fuel(obj.wts.W_TO,obj);
result.empty_lb = obj.wts.OEW(obj.wts.W_TO);
result.mass_margin_lb = obj.wts.W_TO-result.empty_lb-obj.wts.payload()-result.fuel_lb;
result.tank_margin_lb = 2246-result.fuel_lb;
[result.envelope,result.WS_wall,result.driving,result.WS,result.WP] = matching_envelope(wing_loading_sweep(obj),obj);
if do_sizing
    [result.history,result.converged,result.state] = sizing_mainloop(obj,grand_caravan_ex_initial_opts(obj));
end
fprintf('Baseline fuel %.1f lb; mass margin %.1f lb; tank margin %.1f lb\n',result.fuel_lb,result.mass_margin_lb,result.tank_margin_lb);
end
