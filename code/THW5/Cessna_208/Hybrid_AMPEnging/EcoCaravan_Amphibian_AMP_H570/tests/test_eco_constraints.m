function tests=test_eco_constraints
tests=functiontests(localfunctions);
end

function testDefaultConstraintScreen(testCase)
r=run_eco_constraint_analysis([],false);
[~,j]=min(abs(r.WS-r.reference.WS));
verifyEqual(testCase,r.reference.WP,r.reference.weight_lb/764,'AbsTol',1e-10);
verifyEqual(testCase,r.reference_power.Required_shp(end-1:end), ...
    r.cruise_check.Required_shp,'AbsTol',1e-8);
verifyEqual(testCase,r.cruise_check.Passes,[true;false]);
verifyEqual(testCase,r.reference_power.Available_shp(1:4),[543;543;764;543],'AbsTol',1e-7);
verifyEqual(testCase,r.reference.passes_primary_screen,r.feasible_mask(j));
verifyFalse(testCase,r.reference.passes_comparison_screen);
verifyTrue(testCase,any(r.feasible_mask));
verifyTrue(testCase,all(r.WS(r.feasible_mask)<=r.WS_water_wall));
verifyTrue(testCase,all(r.envelope(r.feasible_mask)>=r.reference.WP));
verifyTrue(testCase,all(r.balked_limit>r.balked_fuel_limit));
verifyEqual(testCase,r.total_propulsion_loss_limit,zeros(size(r.WS)));
end

function testWaterWallUsesMissionLandingWeight(testCase)
r=run_eco_constraint_analysis([],false);
verifyEqual(testCase,r.reference.landing_beta,r.reference.landing_weight_lb/r.reference.weight_lb);
verifyLessThan(testCase,r.reference.landing_beta,.975);
verifyEqual(testCase,r.water.CLmax,2.2,'AbsTol',1e-10);
% Same target distance, density and flap polar as the conventional calibration.
verifyEqual(testCase,r.WS_water_wall,(9062/279)/r.reference.landing_beta,'AbsTol',1e-9);
verifyEqual(testCase,r.water.airborne_and_flare_ft+r.water.water_run_budget_ft,2004);
end
