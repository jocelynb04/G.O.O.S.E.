function check=eco_cruise_check(config,weight_lb)
%ECO_CRUISE_CHECK Steady cruise screen with no boost or generator load.
root=eco_project_root();
ref=jsondecode(fileread(fullfile(root,'docs','reference','CONVENTIONAL_CONSTRAINT_INPUTS.json')));
obj=ttpa_disciplines(); train=AMPH570Powertrain(config.hybrid);
segments=json_as_struct_array(config.segments); cruise=segments(find(string({segments.type})=="cruise",1));
state=get_state(cruise.alt_ft); polar=obj.aero.drag_polar(state);
speeds=[cruise.ktas;ref.cruise_speeds_ktas(:)]; V=speeds*6076.11549/3600;
q=.5*state.rho*V.^2; CL=ref.cruise_beta*weight_lb./(q*obj.geom.S_ref);
D=q*obj.geom.S_ref.*(polar.CD0+polar.K1*CL.^2);
required=D.*V/(550*obj.prop.eta_p_cruise);
available=repmat(min(train.combustion_available_hp(state),config.hybrid.combined_continuous_hp),size(speeds));
margin=available-required;
check=table(speeds,repmat(cruise.alt_ft,size(speeds)),required,available,margin, ...
    margin>=0 & CL<=obj.aero.CLmax_clean-obj.aero.CL_stall_margin, ...
    'VariableNames',{'Speed_KTAS','Altitude_ft','Required_shp','Continuous_shp','Margin_shp','Passes'});
end
