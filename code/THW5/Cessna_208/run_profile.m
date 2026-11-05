function result = run_profile()
%RUN_PROFILE Fly the active L2 mission on the reference aircraft, without resizing.
setup_project();
obj=ttpa_disciplines();
[result.fuel_lb,result.fuel_fraction,result.burn,result.weight,result.wf,result.detail] = ...
    mission_fuel(obj.wts.W_TO,obj);
result.empty_lb=obj.wts.OEW(obj.wts.W_TO);
result.payload_lb=obj.wts.payload();
result.mass_margin_lb=obj.wts.W_TO-result.empty_lb-result.payload_lb-result.fuel_lb;
p=grand_caravan_ex_params();
result.tank_margin_lb=p.usable_fuel_lb-result.fuel_lb;
segment=string({obj.miss.segments.type})'; fuel_lb=result.burn';
start_weight_lb=result.weight(1:end-1)'; end_weight_lb=result.weight(2:end)';
weight_fraction=result.wf';
result.segment_table=table(segment,fuel_lb,start_weight_lb,end_weight_lb,weight_fraction);
disp(result.segment_table);
fprintf('Mission fuel %.1f lb; mass margin %.1f lb; tank margin %.1f lb\n', ...
    result.fuel_lb,result.mass_margin_lb,result.tank_margin_lb);
end
