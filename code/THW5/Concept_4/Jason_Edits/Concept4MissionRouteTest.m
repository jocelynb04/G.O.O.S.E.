classdef Concept4MissionRouteTest < matlab.unittest.TestCase
    %Concept4MissionRouteTest - Test routes without writing result files.
    %   Synthetic land fixtures exercise software only, not performance.
    properties (TestParameter)
        departure = {'water','land'}
        arrival = {'water','land'}
        wingArea = {300,325,350}
        landRoute = struct( ...
            'waterLand',struct('departure_surface','water','arrival_surface','land'), ...
            'landWater',struct('departure_surface','land','arrival_surface','water'), ...
            'landLand',struct('departure_surface','land','arrival_surface','land'))
    end
    methods (Test)
        function routeSelection(testCase,departure,arrival)
            m = Concept4MissionRouteTest.fixture(325);
            p = m.plan('std_mission',struct( ...
                'departure_surface',departure,'arrival_surface',arrival));
            d = cellfun(@(s) s.route_detail,p.segments);
            testCase.verifyEqual(p.route_name,[departure '_to_' arrival]);
            testCase.verifyEqual(d(1).surface,departure);
            testCase.verifyEqual(d(2).surface,departure);
            testCase.verifyEqual(d(end).surface,arrival);
            testCase.verifyEqual(d(2).phase_name, ...
                Concept4MissionRouteTest.phaseName(departure,'takeoff'));
            testCase.verifyEqual(d(end).phase_name, ...
                Concept4MissionRouteTest.phaseName(arrival,'landing'));
            testCase.verifyEqual(d(2).aero_config, ...
                ['takeoff_flaps_gear_' Concept4MissionRouteTest.gear(departure)]);
            testCase.verifyEqual(d(end).aero_config, ...
                ['landing_flaps_gear_' Concept4MissionRouteTest.gear(arrival)]);
            testCase.verifyEqual(p.ready_for_energy_calculation, ...
                strcmp(departure,'water') && strcmp(arrival,'water'));
            testCase.verifyEqual(p.performance_status,'UNVERIFIED_SURFACE_PERFORMANCE');
        end
        function missingLandInputsStopBeforeCalculation(testCase,landRoute)
            m = Concept4MissionRouteTest.fixture(325);
            originalCapacity = m.prop.battery_capacity_kwh;
            testCase.verifyError(@() m.run(12500,'std_mission',true,landRoute), ...
                'C4:MissingSurfaceInputs');
            testCase.verifyEqual(m.prop.battery_capacity_kwh,originalCapacity,'AbsTol',1e-12);
        end
        function routingAndContinuityWithTestFixtures(testCase,departure,arrival)
            [m,s] = Concept4MissionRouteTest.fixture(325);
            ground = m.assumptions.ground_phases;
            % Test-only copies are NOT default land engineering allowances.
            options = struct('departure_surface',departure,'arrival_surface',arrival, ...
                'surface_inputs',struct('land_taxi',ground.taxi, ...
                'runway_takeoff',ground.takeoff,'runway_landing',ground.landing));
            r = m.run(s.weight_lb+s.mass_closure_residual_lb,'std_mission',false,options);
            rows = r.segments;
            electric = strcmp({rows.power_mode},'electric_only');
            hybrid = strcmp({rows.power_mode},'hybrid');
            reserve = strcmp({rows.phase},'loiter');
            balked = strcmp({rows.phase},'balked_landing');
            testCase.verifyEqual([rows(electric).generator_bus_kw], ...
                zeros(1,sum(electric)),'AbsTol',1e-12);
            testCase.verifyTrue(all([rows(electric).electric_only]));
            testCase.verifyTrue(all([rows(hybrid).generator_bus_kw]>0));
            testCase.verifyTrue(all([rows(reserve).generator_bus_kw]>0));
            testCase.verifyEqual([rows(2:end).soc_start],[rows(1:end-1).soc_end], ...
                'AbsTol',1e-12);
            testCase.verifyEqual(sum([rows(reserve).duration_min]),45,'AbsTol',1e-12);
            testCase.verifyEqual(sum([rows(balked).duration_min]),8,'AbsTol',1e-12);
            testCase.verifyTrue(all(strcmp({rows(balked).aero_config}, ...
                ['landing_flaps_gear_' Concept4MissionRouteTest.gear(arrival)])));
            testCase.verifyTrue(all(strcmp({rows.generator_physical_state},'NOT_MODELED')));
            testCase.verifyTrue(all(strcmp({rows(electric).generator_intended_state}, ...
                'shutdown_intended')));
            testCase.verifyTrue(all(strcmp({rows(hybrid).generator_intended_state}, ...
                'running_intended')));
        end
        function defaultMatchesExplicitWater(testCase)
            [m,s] = Concept4MissionRouteTest.fixture(325);
            w = s.weight_lb+s.mass_closure_residual_lb;
            actual = m.run(w);
            explicit = m.run(w,'std_mission',false, ...
                struct('departure_surface','water','arrival_surface','water'));
            testCase.verifyEqual(actual,explicit);
        end
        function preservedCandidateBaseline(testCase,wingArea)
            [m,s] = Concept4MissionRouteTest.fixture(wingArea);
            r = m.run(s.weight_lb+s.mass_closure_residual_lb);
            testCase.verifyEqual(r.total_fuel_lb,s.mission_fuel_lb,'AbsTol',1e-9);
            testCase.verifyEqual(r.soc_end,s.mission_final_SOC,'AbsTol',1e-12);
            testCase.verifyEqual(r.peak_battery_discharge_bus_kw, ...
                s.peak_mission_battery_bus_kw,'AbsTol',1e-9);
            testCase.verifyEqual(m.prop.battery_capacity_kwh, ...
                s.battery_capacity_kwh,'AbsTol',1e-12);
        end
        function explicitUnresolvedApproach(testCase)
            [m,s] = Concept4MissionRouteTest.fixture(325);
            r = m.run(s.weight_lb+s.mass_closure_residual_lb);
            rows = r.segments;
            descent = strcmp({rows.phase},'descent');
            approach = strcmp({rows.phase},'approach');
            landing = strcmp({rows.phase},'landing');
            testCase.verifyEqual(sum(approach),2);
            testCase.verifyEqual([rows(descent).duration_min],[10 10],'AbsTol',1e-12);
            testCase.verifyEqual([rows(descent).shaft_power_hp],[0 0],'AbsTol',1e-12);
            testCase.verifyEqual([rows(approach).duration_min],[0 0],'AbsTol',1e-12);
            testCase.verifyEqual([rows(approach).pack_energy_change_kwh],[0 0], ...
                'AbsTol',1e-12);
            testCase.verifyEqual([rows(landing).shaft_power_hp],80,'AbsTol',1e-12);
            testCase.verifyTrue(all(strcmp({rows(descent).generator_intended_state}, ...
                'unspecified_zero_output')));
        end
        function electricPolicyOverridesShare(testCase)
            [m,s] = Concept4MissionRouteTest.fixture(325);
            segments = c4_segments(m.J.missions.std_mission.segments);
            segments{1}.phi = 0;
            segments{2}.phi = 0;
            segments{end}.phi = 0;
            m.J.missions.std_mission.segments = segments;
            r = m.run(s.weight_lb+s.mass_closure_residual_lb);
            ground = ismember({r.segments.phase},{'taxi','takeoff','landing'});
            testCase.verifyEqual([r.segments(ground).generator_bus_kw], ...
                zeros(1,sum(ground)),'AbsTol',1e-12);
        end
        function preserveHybridManagement(testCase)
            [m,s] = Concept4MissionRouteTest.fixture(325);
            r = m.run(s.weight_lb+s.mass_closure_residual_lb);
            rows = r.segments;
            climb = strcmp({rows.phase},'climb');
            cruise = strcmp({rows.phase},'cruise');
            expected = 0.4*[rows(climb).shaft_power_hp]*0.7456998715822702 ...
                /(m.prop.eta_motor*m.prop.eta_inverter);
            testCase.verifyEqual([rows(climb).battery_bus_kw],expected,'AbsTol',1e-9);
            testCase.verifyTrue(all([rows(cruise).battery_bus_kw]<=0));
        end
        function rejectInvalidSurface(testCase)
            m = Concept4MissionRouteTest.fixture(325);
            testCase.verifyError(@() m.plan('std_mission', ...
                struct('departure_surface','snow')),'C4:Surface');
        end
        function rejectUnknownOption(testCase)
            m = Concept4MissionRouteTest.fixture(325);
            testCase.verifyError(@() m.plan('std_mission', ...
                struct('depart_surface','land')),'C4:RouteOptions');
        end
        function rejectIncompleteLandInput(testCase)
            m = Concept4MissionRouteTest.fixture(325);
            options = struct('arrival_surface','land','surface_inputs', ...
                struct('runway_landing',struct('shaft_hp',80)));
            testCase.verifyError(@() m.plan('std_mission',options),'C4:SurfaceInputs');
        end
        function optionalProfileUsesRoutePlanner(testCase)
            m = Concept4MissionRouteTest.fixture(325);
            p = m.plan('typical_500nmi_route',struct('arrival_surface','land'));
            testCase.verifyEqual(p.missing_inputs,{'runway_landing'});
            testCase.verifyEqual(p.route_name,'water_to_land');
        end
    end
    methods (Static, Access=private)
        function [m,s] = fixture(area)
            root = fileparts(mfilename('fullpath'));
            J = jsondecode(fileread(fullfile(root,'regression_fixtures','historical_requirements.json')));
            A = jsondecode(fileread(fullfile(root,'Concept4_integration_assumptions.json')));
            fixture = fullfile(root,'regression_fixtures', ...
                sprintf('historical_summary_%dft2.json',area));
            s = jsondecode(fileread(fixture));
            p = SeaplaneProp_Concept4(J);
            p.P_SL = s.motor_shaft_rating_hp;
            p.engine_shaft_power_sl_hp_each = s.generator_engine_rating_hp;
            p.battery_capacity_kwh = s.battery_capacity_kwh;
            p.battery_installed_mass_kg = s.battery_mass_lb/2.20462262185;
            g = SeaplaneGeom(J,p);
            g.S_ref = area;
            a = SeaplaneAero_Concept4(J,g);
            m = Concept4Mission(J,g,a,p,A);
        end
        function value = gear(surface)
            if strcmp(surface,'water'), value='up'; else, value='down'; end
        end
        function value = phaseName(surface,phase)
            if strcmp(surface,'water'), value=['water_' phase];
            else, value=['runway_' phase]; end
        end
    end
end
