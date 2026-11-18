function study = run_concept1_assisted_rfp_trade()
%RUN_CONCEPT1_ASSISTED_RFP_TRADE Screen landing lift and early-return power.
% Turboprop assistance is assumed available at the go-around command.
setup_jason_edits();
current = jsondecode(fileread(concept1_requirements_path()));
if isfield(current.geometry,'openvsp')
    error('Concept1:HistoricalGeometryTrade', ...
        'This runner defines the prior geometry trade. Run run_concept1_openvsp for the imported shape, or use the pre-import backup for this historical study.');
end
here = fileparts(mfilename('fullpath'));
setup_jason_edits();
W0 = 12490;
span = 64.9;
settings = [16.9,2.4; 17.6,2.5; 18.3,2.6; 18.6,2.6];
study = table();
for k = 1:size(settings,1)
    WS = settings(k,1);
    CLmax = settings(k,2);
    wingArea = W0/WS;
    AR = span^2/wingArea;
    [~,mission,early] = run_concept1_energy_trade(DesignWeight=W0, ...
        AspectRatio=AR,LandingCLmax=CLmax,CombustionRating=1500, ...
        EngineDryWeight=340,EngineBSFC=0.595*783/750, ...
        AssistDelaySeconds=0,WriteResults=false);
    row = table(W0,span,wingArea,AR,WS,CLmax);
    study = [study;[row,mission,early]];
end
writetable(study,fullfile(here,'results','RFP_assisted_wing_trade.csv'));
disp(study(:,{'wingArea','AR','CLmax','WeightBuildup_lbf','WeightGap_lbf', ...
    'WaterTakeoff_shp','PeakTurbine_shp','SOCafterBalk_percent'}));
end
