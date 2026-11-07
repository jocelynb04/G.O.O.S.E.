"""Concept 4: series-hybrid electric propulsion (THW3 class adapted for THW5).

Power path: fuel -> turboshaft -> generator -> rectifier -> DC bus ->
            inverter -> distributed electric motors -> propellers.
                  Battery <-> DC bus.

Sources and provenance:
  [S1] NASA, "Aircraft Configurations," Electrified Aircraft Propulsion;
       https://www.nasa.gov/eap-aircraft-concepts/aircraft-configurations/
  [S2] de Vries et al. (2026), AIAA 2026-4690,
       doi:10.2514/6.2026-4690; conceptual sizing method.
  [S3] Duffy & Jansen (2018), NASA NTRS 20180005327;
       electric-drive efficiency and specific-power sensitivity.
  [S4] NASA, "Power Converters," high-lift and 250-kW converter data;
       https://www.nasa.gov/eap-technology/power-converters/
  [S5] Original THW3 seaplane_prop.py + tidal_requirements.json;
       inherited assumptions marked preliminary.

Power equations are steady-state energy conservation plus component efficiencies;
NOT a validated turbogenerator map, battery thermal model, or certification model.
"""
from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any, Mapping

HP_TO_KW = 0.7456998715822702
KG_TO_LB = 2.20462262185
RHO0 = 1.225  # kg/m^3, ISA sea level


class PowerUnavailableError(RuntimeError):
    """Required electric load or battery energy cannot be met."""


@dataclass(frozen=True)
class SegmentPowerResult:
    phase: str
    shaft_power_hp: float
    duration_hr: float
    generator_bus_kw: float
    generator_available_bus_kw: float
    motor_bus_kw: float
    battery_bus_kw: float  # positive = discharge, negative = recharge
    pack_energy_change_kwh: float  # positive = battery energy consumed
    fuel_burn_lb: float
    soc_start: float
    soc_end: float
    operating_motors: int
    operating_generators: int
    electric_only: bool


class SeaplaneProp:
    """State-free series-hybrid model; battery SOC passed between segments.

    Peak electrical shaft power is limited by motor/inverter ratings. Generator
    output is limited by per-generator mechanical rating and an illustrative
    atmosphere lapse; surplus generation can recharge the pack. An optional
    battery share of bus demand is a controller *target*, not a physical law.
    """

    engine_type = "Series hybrid-electric: generator + battery + distributed motors"

    def __init__(self, J: Mapping[str, Any]):
        P = J["propulsion"]
        if P.get("architecture") != "series_hybrid":
            raise ValueError("Expected propulsion.architecture='series_hybrid'.")
        self.P_SL = float(P["P_SL_hp"])  # total peak output power of all motor shafts
        self.n_motors = int(P["n_motors"])
        self.n_generators = int(P["n_generators"])
        self.n_engines = self.n_generators  # THW3 alias: NOT motor count
        self.engine_shaft_power_sl_hp_each = float(P["generator_engine_shaft_power_sl_hp_each"])
        self.generator_continuous_fraction = float(P.get("generator_continuous_fraction", 1.0))
        self.motor_continuous_fraction = float(P.get("motor_continuous_fraction", 0.85))
        self.BSFC = float(P["BSFC_lb_per_hp_hr"])  # input assumption at rated engine output
        self.generator_lapse_exponent = float(P["generator_lapse_exponent"])
        self.eta_generator = float(P["generator_efficiency"])
        self.eta_rectifier = float(P["rectifier_efficiency"])
        self.eta_inverter = float(P["inverter_efficiency"])
        self.eta_motor = float(P["motor_efficiency"])
        self.eta_battery_discharge = float(P["battery_discharge_efficiency"])
        self.eta_battery_charge = float(P["battery_charge_efficiency"])
        self.battery_capacity_kwh = float(P["battery_capacity_kwh"])
        self.battery_initial_soc = float(P["battery_initial_soc"])
        self.battery_min_soc = float(P["battery_min_soc"])
        self.battery_max_soc = float(P.get("battery_max_soc", 1.0))
        self.battery_max_charge_bus_kw = float(P["battery_charge_power_limit_kw"])
        self.battery_max_discharge_bus_kw = float(P["battery_discharge_power_limit_kw"])
        self.battery_specific_energy_kwh_per_kg = float(P["battery_specific_energy_kwh_per_kg"])
        self.battery_specific_power_kw_per_kg = float(P["battery_specific_power_kw_per_kg"])
        self.motor_specific_power_kw_per_kg = float(P["motor_specific_power_kw_per_kg"])
        self.inverter_specific_power_kw_per_kg = float(P["inverter_specific_power_kw_per_kg"])
        self.generator_specific_power_kw_per_kg = float(P["generator_specific_power_kw_per_kg"])
        self.turboshaft_specific_power_kw_per_kg = float(P["turboshaft_specific_power_kw_per_kg"])
        self.propeller_mass_kg_each = float(P["propeller_mass_kg_each"])
        self.eta_p_cruise = float(P["eta_p_cruise"])
        self.eta_p_climb = float(P["eta_p_climb"])
        self.eta_p_loiter = float(P["eta_p_loiter"])
        self.phi_table = P.get("phi", {})
        self.electric_only_phases = set(P.get("electric_only_phases", ["taxi", "takeoff", "landing"]))
        if self.n_motors < 1 or self.n_generators < 1:
            raise ValueError("Motor and generator counts must be >= 1")
        if not (0 <= self.battery_min_soc < self.battery_initial_soc <= self.battery_max_soc <= 1):
            raise ValueError("Invalid min/initial/max SOC")
        if self.battery_capacity_kwh <= 0 or self.P_SL <= 0:
            raise ValueError("Battery capacity and rated motor power must be positive")
        efficiencies = [self.eta_generator,self.eta_rectifier,self.eta_inverter,
                        self.eta_motor,self.eta_battery_discharge,self.eta_battery_charge]
        if any(not 0 < e <= 1 for e in efficiencies):
            raise ValueError("Conversion efficiencies must be in (0,1]")
        if not 0 < self.generator_continuous_fraction <= 1 or not 0 < self.motor_continuous_fraction <= 1:
            raise ValueError("Continuous rating fractions must be in (0,1]")

    def get_phi(self, miss_seg: Mapping[str, Any]) -> float:
        """THW3-compatible accessor; target battery share of electrical BUS demand.

        Positive phi: requested battery BUS discharge share.
        Zero phi: generator supplies load if available.
        Negative phi: additional generator power requested to charge the pack.
        For electric-only phases phi is automatically 1.0.
        """
        phase = str(miss_seg["type"])
        if phase in self.electric_only_phases:
            return 1.0
        return float(miss_seg.get("phi", self.phi_table.get(phase, 0.0)))

    def prop_eff(self, state: Any, miss_seg: Mapping[str, Any]) -> float:
        phase = str(miss_seg["type"])
        return {"climb":self.eta_p_climb, "loiter":self.eta_p_loiter}.get(phase, self.eta_p_cruise)

    @staticmethod
    def sigma_isa(altitude_ft: float) -> float:
        """ISA troposphere density ratio; only valid from 0 to 36,089 ft."""
        if not 0 <= altitude_ft <= 36089:
            raise ValueError("ISA model only covers 0..36089 ft")
        h_m = altitude_ft * 0.3048
        T = 288.15 - 0.0065 * h_m
        p = 101325.0 * (T / 288.15) ** 5.25588
        rho = p / (287.05287 * T)
        return rho / RHO0

    def generator_available_bus_kw(self, altitude_ft: float, *, failed_generators: int = 0) -> float:
        """Electrical DC-bus rating at altitude, in kW.

        Density-ratio exponent is INHERITED FROM THW3, not a measured engine deck.
        """
        if not 0 <= failed_generators <= self.n_generators:
            raise ValueError("Invalid number of failed generators")
        operating = self.n_generators - failed_generators
        per_engine_hp = (self.engine_shaft_power_sl_hp_each
                         * self.generator_continuous_fraction
                         * self.sigma_isa(altitude_ft) ** self.generator_lapse_exponent)
        return (operating * per_engine_hp * HP_TO_KW
                * self.eta_generator * self.eta_rectifier)

    def motor_bus_kw(self, shaft_power_hp: float) -> float:
        """DC bus power required for propulsor shaft output, in kW."""
        if shaft_power_hp < 0:
            raise ValueError("Shaft power cannot be negative")
        return shaft_power_hp * HP_TO_KW / (self.eta_motor * self.eta_inverter)

    def power_balance(
        self, shaft_power_hp: float, duration_hr: float, altitude_ft: float,
        *, phase: str, soc: float | None = None, battery_share_target: float | None = None,
        failed_generators: int = 0, failed_motors: int = 0,
        motor_rating: str = "continuous",
    ) -> SegmentPowerResult:
        """Apply electric bus balance for one CONSTANT-power flight segment.

        Input mechanical propulsor shaft power comes from the aircraft aero/
        performance analysis; do not substitute engine rated power for it.
        Uses constant-efficiency and BSFC assumptions; integrate smaller
        time steps when load, altitude, efficiency, or SOC changes materially.
        """
        if duration_hr < 0:
            raise ValueError("Duration must be nonnegative")
        if not 0 <= failed_motors < self.n_motors:
            raise ValueError("Invalid failed motor count")
        if motor_rating not in {"continuous", "takeoff"}:
            raise ValueError("motor_rating must be 'takeoff' or 'continuous'")
        if soc is None:
            soc = self.battery_initial_soc
        if not self.battery_min_soc - 1e-9 <= soc <= self.battery_max_soc + 1e-9:
            raise ValueError("Starting SOC outside permitted range")
        n_motors = self.n_motors - failed_motors
        peak_available_hp = self.P_SL * n_motors / self.n_motors
        if motor_rating == "continuous":
            peak_available_hp *= self.motor_continuous_fraction
        if shaft_power_hp > peak_available_hp + 1e-9:
            raise PowerUnavailableError(
                f"Required {shaft_power_hp:.1f} shaft hp exceeds operating motor rating "
                f"{peak_available_hp:.1f} hp ({n_motors} motors, {motor_rating}).")
        electric_only = phase in self.electric_only_phases
        target = 1.0 if electric_only else (
            float(battery_share_target) if battery_share_target is not None
            else self.get_phi({"type":phase})
        )
        if not -1.0 <= target <= 1.0:
            raise ValueError("Battery bus share target must be between -1 and 1")
        demand = self.motor_bus_kw(shaft_power_hp)
        gen_available = (0.0 if electric_only else self.generator_available_bus_kw(
            altitude_ft, failed_generators=failed_generators))
        # Allocate generator supply first for the requested motor load share.
        target_gen = max(0.0, demand * (1.0 - target))
        to_motors_from_gen = min(demand, target_gen, gen_available)
        battery_to_motors = demand - to_motors_from_gen
        # Requested recharge at negative target, subject to generator headroom
        # and battery SOC headroom over this specific segment duration.
        target_charge = max(0.0, target_gen - demand)
        charge = min(target_charge, max(0.0, gen_available - to_motors_from_gen),
                     self.battery_max_charge_bus_kw)
        if duration_hr > 0:
            max_charge_from_soc = ((self.battery_max_soc - soc) * self.battery_capacity_kwh
                                   / (duration_hr * self.eta_battery_charge))
            charge = min(charge, max(0.0, max_charge_from_soc))
        else:
            charge = 0.0
        # A segment cannot simultaneously charge and discharge the same pack.
        # Charge happens only when generator covers all motor demand.
        if battery_to_motors > 1e-9:
            charge = 0.0
        battery_bus = battery_to_motors - charge
        gen_bus = to_motors_from_gen + charge
        if battery_bus > self.battery_max_discharge_bus_kw + 1e-9:
            raise PowerUnavailableError(
                f"Battery bus discharge {battery_bus:.1f} kW exceeds installed "
                f"limit {self.battery_max_discharge_bus_kw:.1f} kW")
        if battery_bus >= 0:
            pack_energy_change = battery_bus * duration_hr / self.eta_battery_discharge
        else:
            pack_energy_change = battery_bus * duration_hr * self.eta_battery_charge
        soc_end = soc - pack_energy_change / self.battery_capacity_kwh
        if soc_end < self.battery_min_soc - 1e-9:
            raise PowerUnavailableError(
                f"SOC falls below minimum: {soc_end:.3f} < {self.battery_min_soc:.3f}. "
                "Increase capacity, reduce demand, or change generator schedule.")
        # BSFC is defined for ENGINE shaft hp-hr in original THW3; not for
        # propeller shaft hp-hr. Generator mechanical power must be calculated.
        engine_shaft_hp = (gen_bus / (self.eta_generator * self.eta_rectifier)
                           / HP_TO_KW)
        fuel_lb = engine_shaft_hp * self.BSFC * duration_hr
        return SegmentPowerResult(
            phase=phase, shaft_power_hp=shaft_power_hp, duration_hr=duration_hr,
            generator_bus_kw=gen_bus, generator_available_bus_kw=gen_available,
            motor_bus_kw=demand, battery_bus_kw=battery_bus,
            pack_energy_change_kwh=pack_energy_change, fuel_burn_lb=fuel_lb,
            soc_start=soc, soc_end=max(self.battery_min_soc, min(self.battery_max_soc, soc_end)),
            operating_motors=n_motors, operating_generators=self.n_generators-failed_generators,
            electric_only=electric_only,
        )

    def battery_mass_breakdown(self, *, minimum_usable_energy_kwh: float = 0.0,
                               peak_battery_bus_kw: float | None = None) -> dict[str, float]:
        """Battery sizing: higher of energy and power mass (preliminary pack model)."""
        usable_soc = self.battery_initial_soc - self.battery_min_soc
        energy_capacity_kwh = max(self.battery_capacity_kwh,
                                  minimum_usable_energy_kwh / usable_soc)
        energy_mass_kg = energy_capacity_kwh / self.battery_specific_energy_kwh_per_kg
        peak_bus_kw = (self.motor_bus_kw(self.P_SL) if peak_battery_bus_kw is None
                       else peak_battery_bus_kw)
        power_mass_kg = peak_bus_kw / self.eta_battery_discharge / self.battery_specific_power_kw_per_kg
        return {"energy_limited_mass_kg":energy_mass_kg,
                "power_limited_mass_kg":power_mass_kg,
                "battery_mass_kg":max(energy_mass_kg,power_mass_kg),
                "battery_mass_lb":max(energy_mass_kg,power_mass_kg)*KG_TO_LB,
                "rated_capacity_kwh":energy_capacity_kwh}

    def battery_weight(self, E_Wh: float) -> float:
        """Legacy THW3 method, now includes installed minimum capacity and power."""
        return self.battery_mass_breakdown(minimum_usable_energy_kwh=E_Wh/1000)["battery_mass_lb"]

    def installed_mass_breakdown(self) -> dict[str, float]:
        """Mass by component in lb. ALL specific-power inputs must be documented.

        No mass for cabling, power distribution, thermal management, mounting,
        containment, controls or nacelles is included here. Add separately!
        """
        shaft_kw = self.P_SL * HP_TO_KW
        bus_kw = self.motor_bus_kw(self.P_SL)
        engine_kw = (self.n_generators * self.engine_shaft_power_sl_hp_each * HP_TO_KW)
        battery_lb = self.battery_mass_breakdown()["battery_mass_lb"]
        return {
            "battery_lb":battery_lb,
            "motors_lb":shaft_kw/self.motor_specific_power_kw_per_kg*KG_TO_LB,
            "motor_inverters_lb":bus_kw/self.inverter_specific_power_kw_per_kg*KG_TO_LB,
            "generators_lb":engine_kw/self.generator_specific_power_kw_per_kg*KG_TO_LB,
            "turboshafts_lb":engine_kw/self.turboshaft_specific_power_kw_per_kg*KG_TO_LB,
            "propellers_lb":self.n_motors*self.propeller_mass_kg_each*KG_TO_LB,
        }

    def C_bhp(self, state=None, miss_seg=None):
        """Old IHW3 Breguet BSFC method is NOT valid with changing battery SOC."""
        raise NotImplementedError(
            "Use power_balance(...) for every mission segment. Series-hybrid "
            "fuel is based on turboshaft generator power, not (1-phi)*propeller BSFC.")

