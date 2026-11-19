classdef SeaplanePropBatteryTest < matlab.unittest.TestCase
    %SeaplanePropBatteryTest - Check installed-pack power enforcement.
    %   Artificial masses and limits below are software boundary fixtures,
    %   not new engineering inputs or hardware performance claims.
    properties (TestParameter)
        wingArea = {300,325,350}
    end
    methods (Test)
        function candidateLimitMatchesInstalledMass(testCase,wingArea)
            [p,s] = SeaplanePropBatteryTest.fixture(wingArea);
            testCase.verifyEqual(p.battery_discharge_limit_bus_kw(), ...
                s.battery_bus_power_capability_kw,'AbsTol',1e-9);
            testCase.verifyLessThan(p.battery_discharge_limit_bus_kw(), ...
                p.battery_max_discharge_bus_kw);
        end
        function rejectAboveInstalledPackBelowConfiguredCeiling(testCase)
            p = SeaplanePropBatteryTest.fixture(325);
            shaft = 850*p.eta_motor*p.eta_inverter/0.7456998715822702;
            testCase.verifyError(@() p.power_balance(shaft,0.01,0,'takeoff'), ...
                'C4:PowerUnavailable');
        end
        function nominalTakeoffStillAllowed(testCase,wingArea)
            [p,s] = SeaplanePropBatteryTest.fixture(wingArea);
            r = p.power_balance(900,2/60,0,'takeoff');
            testCase.verifyEqual(r.battery_bus_kw, ...
                s.peak_mission_battery_bus_kw,'AbsTol',1e-9);
            testCase.verifyEqual(r.generator_bus_kw,0,'AbsTol',1e-12);
        end
        function capabilityChangesWithMass(testCase)
            p = SeaplanePropBatteryTest.fixture(325);
            p.battery_installed_mass_kg = 100;
            first = p.battery_discharge_limit_bus_kw();
            p.battery_installed_mass_kg = 200;
            second = p.battery_discharge_limit_bus_kw();
            testCase.verifyEqual(second,2*first,'AbsTol',1e-12);
        end
        function configuredCeilingStillApplies(testCase)
            p = SeaplanePropBatteryTest.fixture(325);
            p.battery_installed_mass_kg = 1000;
            p.battery_max_discharge_bus_kw = 100;
            shaft = 110*p.eta_motor*p.eta_inverter/0.7456998715822702;
            testCase.verifyEqual(p.battery_discharge_limit_bus_kw(),100,'AbsTol',1e-12);
            testCase.verifyError(@() p.power_balance(shaft,0.01,0,'takeoff'), ...
                'C4:PowerUnavailable');
        end
        function defaultUsesLegacyModeledMass(testCase)
            p = SeaplanePropBatteryTest.fixture(325);
            p.battery_installed_mass_kg = [];
            p.P_SL = 100;
            p.battery_capacity_kwh = 10;
            b = p.battery_mass_breakdown();
            expected = min(p.battery_max_discharge_bus_kw, ...
                b.battery_mass_kg*p.J.propulsion.battery_specific_power_kw_per_kg ...
                *p.eta_battery_discharge);
            testCase.verifyEqual(p.battery_discharge_limit_bus_kw(),expected, ...
                'AbsTol',1e-12);
            testCase.verifyLessThan(expected,p.battery_max_discharge_bus_kw);
        end
        function hybridChecksBatteryShareRatherThanTotalBus(testCase)
            [p,s] = SeaplanePropBatteryTest.fixture(325);
            r = p.power_balance(s.required_climb2000_hp,0.01,0,'climb');
            testCase.verifyGreaterThan(r.motor_bus_kw,p.battery_discharge_limit_bus_kw());
            testCase.verifyLessThan(r.battery_bus_kw,p.battery_discharge_limit_bus_kw());
            testCase.verifyGreaterThan(r.generator_bus_kw,0);
        end
        function generatorFailureUsesSamePackLimit(testCase)
            p = SeaplanePropBatteryTest.fixture(325);
            shaft = 850*p.eta_motor*p.eta_inverter/0.7456998715822702;
            testCase.verifyError(@() p.power_balance(shaft,0.01,0,'climb', ...
                p.battery_initial_soc,0,1,0,'continuous'),'C4:PowerUnavailable');
        end
        function energyProbeCannotIncreaseExplicitPackPower(testCase)
            p = SeaplanePropBatteryTest.fixture(325);
            before = p.battery_discharge_limit_bus_kw();
            p.battery_capacity_kwh = 100000;
            testCase.verifyEqual(p.battery_discharge_limit_bus_kw(),before,'AbsTol',1e-12);
        end
    end
    methods (Static, Access=private)
        function [p,s] = fixture(area)
            root = fileparts(mfilename('fullpath'));
            J = jsondecode(fileread(fullfile(root,'concept4_aero_hydro_requirements.json')));
            s = jsondecode(fileread(fullfile(root,'regression_fixtures', ...
                sprintf('historical_summary_%dft2.json',area))));
            p = SeaplaneProp_Concept4(J);
            p.P_SL = s.motor_shaft_rating_hp;
            p.engine_shaft_power_sl_hp_each = s.generator_engine_rating_hp;
            p.battery_capacity_kwh = s.battery_capacity_kwh;
            p.battery_installed_mass_kg = s.battery_mass_lb/2.20462262185;
        end
    end
end
