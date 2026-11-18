function summary = run_concept1_go_around_trade()
%RUN_CONCEPT1_GO_AROUND_TRADE Compare reserve power splits at 12,490 lbf.
% The 10-second delay is a sensitivity, not an engine start-time claim.
setup_jason_edits();
current = jsondecode(fileread(concept1_requirements_path()));
if isfield(current.geometry,'openvsp')
    error('Concept1:HistoricalGeometryTrade', ...
        'This runner defines the prior geometry trade. Run run_concept1_openvsp for the imported shape, or use the pre-import backup for this historical study.');
end
here = fileparts(mfilename('fullpath'));
cases = ["Electric only";"Assist available at command";"Assist after 10 seconds"];
delays = [Inf;0;10];
designWeight = 12490;
span = 64.9;
wingLoading = 16.9;
wingAR = span^2*wingLoading/designWeight;
summary = table();
segments = table();
for k = 1:numel(cases)
    [ledger,result] = run_concept1_energy_trade(DesignWeight=designWeight, ...
        AspectRatio=wingAR,LandingCLmax=2.4,CombustionRating=1500, ...
        EngineDryWeight=340,EngineBSFC=0.595*783/750, ...
        AssistDelaySeconds=delays(k),WriteResults=false);
    result = addvars(result,cases(k),delays(k),'Before',1, ...
        'NewVariableNames',{'Scenario','AssistDelay_s'});
    ledger = addvars(ledger,repmat(cases(k),height(ledger),1),'Before',1, ...
        'NewVariableNames','Scenario');
    summary = [summary;result];
    segments = [segments;ledger];
end
writetable(summary,fullfile(here,'results','RFP_go_around_summary.csv'));
writetable(segments,fullfile(here,'results','RFP_go_around_segments.csv'));
disp(summary);
end
