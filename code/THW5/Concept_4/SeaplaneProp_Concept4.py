
"""Series-hybrid electric propulsion and powertrain mass model for Concept 4."""
from __future__ import annotations

from dataclasses import dataclass
import math
from typing import Any, Mapping

HP_TO_KW = 0.7456998715822702
KG_TO_LB = 2.20462262185
RHO0 = 1.225


class PowerUnavailableError(RuntimeError):
    """Requested propulsion power or battery energy is unavailable."""


@dataclass(frozen=True)
class SegmentPowerResult:
    phase: str
    shaft_power_hp: float
    duration_hr: float
    generator_bus_kw: float
    generator_available_bus_kw: float
    motor_bus_kw: float
    battery_bus_kw: float
    pack_energy_change_kwh: float
    fuel_burn_lb: float
    soc_start: float
    soc_end: float
    operating_motors: int
    operating_generators: int
    electric_only: bool


class SeaplaneProp:
    """Electrical power balance, battery sizing, and component mass estimates."""

    engine_type = "Series hybrid-electric with distributed electric motors"

    def __init__(self, J: Mapping[str, Any]):
        P = J["propulsion"]

        if P.get("architecture") != "series_hybrid":
            raise ValueError("Propulsion architecture must be 'series_hybrid'")

        self.P_SL = float(P["P_SL_hp"])
        self.n_motors = int(P["n_motors"])
        self.n_generators = int(P["n_generators"])
        self.n_engines = self.n_generators

        self.engine_shaft_power_sl_hp_each = float(
            P["generator_engine_shaft_power_sl_hp_each"]
        )
        self.generator_continuous_fraction = float(
            P.get("generator_continuous_fraction", 1.0)
        )
        self.motor_continuous_fraction = float(
            P.get("motor_continuous_fraction", 0.85)
        )
        self.BSFC = float(P["BSFC_lb_per_hp_hr"])
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
        self.battery_max_discharge_bus_kw = float(
            P["battery_discharge_power_limit_kw"]
        )

        self.battery_specific_energy_kwh_per_kg = float(
            P["battery_specific_energy_kwh_per_kg"]
        )
        self.battery_specific_power_kw_per_kg = float(
            P["battery_specific_power_kw_per_kg"]
        )
        self.motor_specific_power_kw_per_kg = float(
            P["motor_specific_power_kw_per_kg"]
        )
        self.inverter_specific_power_kw_per_kg = float(
            P["inverter_specific_power_kw_per_kg"]
        )
        self.generator_specific_power_kw_per_kg = float(
            P["generator_specific_power_kw_per_kg"]
        )
        self.turboshaft_specific_power_kw_per_kg = float(
            P["turboshaft_specific_power_kw_per_kg"]
        )
        self.propeller_mass_kg_each = float(P["propeller_mass_kg_each"])

        self.eta_p_cruise = float(P["eta_p_cruise"])
        self.eta_p_climb = float(P["eta_p_climb"])
        self.eta_p_loiter = float(P["eta_p_loiter"])
        self.phi_table = P.get("phi", {})

        self.electric_only_phases = set(
            P.get("electric_only_phases", ["taxi", "takeoff", "landing"])
        )

        self._check_inputs()

    def _check_inputs(self):
        if self.n_motors < 1 or self.n_generators < 1:
            raise ValueError("Motor and generator counts must be positive")

        if not 0 <= self.battery_min_soc < self.battery_initial_soc <= self.battery_max_soc <= 1:
            raise ValueError("Invalid battery SOC limits")

        efficiencies = (
            self.eta_generator,
            self.eta_rectifier,
            self.eta_inverter,
            self.eta_motor,
            self.eta_battery_discharge,
            self.eta_battery_charge,
            self.eta_p_cruise,
            self.eta_p_climb,
            self.eta_p_loiter,
        )

        if any(not math.isfinite(e) or not 0 < e <= 1 for e in efficiencies):
            raise ValueError(
                "Conversion and propeller efficiencies must be in (0, 1]"
            )

        positive = (
            self.P_SL,
            self.engine_shaft_power_sl_hp_each,
            self.battery_capacity_kwh,
            self.battery_max_charge_bus_kw,
            self.battery_max_discharge_bus_kw,
            self.battery_specific_energy_kwh_per_kg,
            self.battery_specific_power_kw_per_kg,
            self.motor_specific_power_kw_per_kg,
            self.inverter_specific_power_kw_per_kg,
            self.generator_specific_power_kw_per_kg,
            self.turboshaft_specific_power_kw_per_kg,
        )

        if any(not math.isfinite(x) or x <= 0 for x in positive):
            raise ValueError(
                "Power, capacity, and specific-power inputs must be positive"
            )

        if self.propeller_mass_kg_each < 0 or self.BSFC <= 0:
            raise ValueError(
                "Propeller mass and BSFC must be nonnegative/positive"
            )

        if not 0 < self.motor_continuous_fraction <= 1:
            raise ValueError("Invalid continuous motor rating")

        if not 0 < self.generator_continuous_fraction <= 1:
            raise ValueError("Invalid continuous generator rating")

    def get_phi(self, miss_seg: Mapping[str, Any]) -> float:
        """Requested battery share of electrical bus power for a flight phase."""
        phase = str(miss_seg["type"])

        if phase in self.electric_only_phases:
            return 1.0

        return float(miss_seg.get("phi", self.phi_table.get(phase, 0.0)))

    def prop_eff(self, state: Any, miss_seg: Mapping[str, Any]) -> float:
        """Representative propeller efficiency for a flight phase."""
        phase = str(miss_seg["type"])

        if phase == "climb":
            return self.eta_p_climb

        if phase == "loiter":
            return self.eta_p_loiter

        return self.eta_p_cruise

    @staticmethod
    def sigma_isa(altitude_ft: float) -> float:
        """Standard-atmosphere density ratio in the troposphere."""
        if not 0 <= altitude_ft <= 36089:
            raise ValueError("Altitude must be between 0 and 36,089 ft")

        altitude_m = altitude_ft * 0.3048
        temperature_k = 288.15 - 0.0065 * altitude_m
        pressure_pa = 101325.0 * (temperature_k / 288.15) ** 5.25588
        density_kg_m3 = pressure_pa / (287.05287 * temperature_k)

        return density_kg_m3 / RHO0

    def generator_available_bus_kw(
        self, altitude_ft: float, *, failed_generators: int = 0
    ) -> float:
        """Available generator output at the electrical DC bus, kW."""
        if not 0 <= failed_generators <= self.n_generators:
            raise ValueError("Invalid failed generator count")

        operating = self.n_generators - failed_generators

        engine_hp = (
            self.engine_shaft_power_sl_hp_each
            * self.generator_continuous_fraction
            * self.sigma_isa(altitude_ft) ** self.generator_lapse_exponent
        )

        return (
            operating
            * engine_hp
            * HP_TO_KW
            * self.eta_generator
            * self.eta_rectifier
        )

    def motor_bus_kw(self, shaft_power_hp: float) -> float:
        """Electrical bus power needed for the requested motor-shaft power."""
        if not math.isfinite(shaft_power_hp) or shaft_power_hp < 0:
            raise ValueError("Shaft power must be nonnegative")

        return (
            shaft_power_hp
            * HP_TO_KW
            / (self.eta_motor * self.eta_inverter)
        )

    def power_balance(
        self,
        shaft_power_hp: float,
        duration_hr: float,
        altitude_ft: float,
        *,
        phase: str,
        soc: float | None = None,
        battery_share_target: float | None = None,
        failed_generators: int = 0,
        failed_motors: int = 0,
        motor_rating: str = "continuous",
    ) -> SegmentPowerResult:
        """Evaluate electrical energy and fuel use for a constant-power segment."""
        if not math.isfinite(duration_hr) or duration_hr < 0:
            raise ValueError("Duration must be nonnegative")

        if not 0 <= failed_motors < self.n_motors:
            raise ValueError("Invalid failed motor count")

        if motor_rating not in {"takeoff", "continuous"}:
            raise ValueError("Unknown motor power rating")

        if soc is None:
            soc = self.battery_initial_soc

        if not math.isfinite(soc) or not self.battery_min_soc <= soc <= self.battery_max_soc:
            raise ValueError("Initial SOC is outside operating limits")

        operating_motors = self.n_motors - failed_motors
        available_motor_hp = self.P_SL * operating_motors / self.n_motors

        if motor_rating == "continuous":
            available_motor_hp *= self.motor_continuous_fraction

        if shaft_power_hp > available_motor_hp + 1e-9:
            raise PowerUnavailableError(
                "Requested shaft power exceeds motor rating"
            )

        electric_only = phase in self.electric_only_phases

        if electric_only:
            battery_target = 1.0
        elif battery_share_target is None:
            battery_target = self.get_phi({"type": phase})
        else:
            battery_target = float(battery_share_target)

        if not -1.0 <= battery_target <= 1.0:
            raise ValueError("Battery share target must be between -1 and 1")

        motor_demand_kw = self.motor_bus_kw(shaft_power_hp)

        generator_available_kw = (
            0.0 if electric_only else
            self.generator_available_bus_kw(
                altitude_ft,
                failed_generators=failed_generators
            )
        )

        target_generator_kw = max(
            0.0,
            motor_demand_kw * (1.0 - battery_target)
        )

        generator_to_motors_kw = min(
            motor_demand_kw,
            target_generator_kw,
            generator_available_kw
        )

        battery_to_motors_kw = (
            motor_demand_kw - generator_to_motors_kw
        )

        target_charge_kw = max(
            0.0,
            target_generator_kw - motor_demand_kw
        )

        charge_kw = min(
            target_charge_kw,
            max(0.0, generator_available_kw - generator_to_motors_kw),
            self.battery_max_charge_bus_kw,
        )

        if duration_hr > 0:
            soc_charge_limit_kw = (
                (self.battery_max_soc - soc)
                * self.battery_capacity_kwh
                / (duration_hr * self.eta_battery_charge)
            )

            charge_kw = min(
                charge_kw,
                max(0.0, soc_charge_limit_kw)
            )
        else:
            charge_kw = 0.0

        if battery_to_motors_kw > 1e-9:
            charge_kw = 0.0

        battery_bus_kw = battery_to_motors_kw - charge_kw
        generator_bus_kw = generator_to_motors_kw + charge_kw

        if battery_bus_kw > self.battery_max_discharge_bus_kw + 1e-9:
            raise PowerUnavailableError(
                "Requested battery power exceeds discharge limit"
            )

        if battery_bus_kw >= 0:
            energy_change_kwh = (
                battery_bus_kw
                * duration_hr
                / self.eta_battery_discharge
            )
        else:
            energy_change_kwh = (
                battery_bus_kw
                * duration_hr
                * self.eta_battery_charge
            )

        soc_end = (
            soc - energy_change_kwh / self.battery_capacity_kwh
        )

        if soc_end < self.battery_min_soc - 1e-9:
            raise PowerUnavailableError(
                "Insufficient battery energy for segment"
            )

        if soc_end > self.battery_max_soc + 1e-9:
            raise PowerUnavailableError(
                "Charging would exceed maximum SOC"
            )

        engine_shaft_hp = (
            generator_bus_kw
            / (self.eta_generator * self.eta_rectifier)
            / HP_TO_KW
        )

        fuel_burn_lb = (
            engine_shaft_hp
            * self.BSFC
            * duration_hr
        )

        return SegmentPowerResult(
            phase=phase,
            shaft_power_hp=shaft_power_hp,
            duration_hr=duration_hr,
            generator_bus_kw=generator_bus_kw,
            generator_available_bus_kw=generator_available_kw,
            motor_bus_kw=motor_demand_kw,
            battery_bus_kw=battery_bus_kw,
            pack_energy_change_kwh=energy_change_kwh,
            fuel_burn_lb=fuel_burn_lb,
            soc_start=soc,
            soc_end=max(
                self.battery_min_soc,
                min(self.battery_max_soc, soc_end)
            ),
            operating_motors=operating_motors,
            operating_generators=self.n_generators - failed_generators,
            electric_only=electric_only,
        )

    def battery_mass_breakdown(
        self,
        *,
        minimum_usable_energy_kwh: float = 0.0,
        peak_battery_bus_kw: float | None = None,
    ) -> dict[str, float]:
        """Estimate installed battery mass using energy and power constraints."""
        if minimum_usable_energy_kwh < 0:
            raise ValueError("Required battery energy cannot be negative")

        usable_soc = (
            self.battery_initial_soc - self.battery_min_soc
        )

        rated_capacity_kwh = max(
            self.battery_capacity_kwh,
            minimum_usable_energy_kwh / usable_soc,
        )

        mass_energy_kg = (
            rated_capacity_kwh
            / self.battery_specific_energy_kwh_per_kg
        )

        peak_bus_kw = (
            self.motor_bus_kw(self.P_SL)
            if peak_battery_bus_kw is None
            else float(peak_battery_bus_kw)
        )

        if peak_bus_kw < 0:
            raise ValueError("Peak battery power cannot be negative")

        mass_power_kg = (
            peak_bus_kw
            / self.eta_battery_discharge
            / self.battery_specific_power_kw_per_kg
        )

        battery_mass_kg = max(
            mass_energy_kg,
            mass_power_kg
        )

        return {
            "energy_limited_mass_kg": mass_energy_kg,
            "power_limited_mass_kg": mass_power_kg,
            "battery_mass_kg": battery_mass_kg,
            "battery_mass_lb": battery_mass_kg * KG_TO_LB,
            "rated_capacity_kwh": rated_capacity_kwh,
        }

    def battery_weight(self, E_Wh: float) -> float:
        """Estimated installed battery weight for a required usable energy."""
        return self.battery_mass_breakdown(
            minimum_usable_energy_kwh=E_Wh / 1000.0
        )["battery_mass_lb"]

    def installed_mass_breakdown(self) -> dict[str, float]:
        """Component masses excluding electrical wiring, cooling, and mountings."""
        motor_shaft_kw = self.P_SL * HP_TO_KW
        inverter_bus_kw = self.motor_bus_kw(self.P_SL)

        engine_shaft_kw = (
            self.n_generators
            * self.engine_shaft_power_sl_hp_each
            * HP_TO_KW
        )

        generator_electrical_kw = (
            engine_shaft_kw * self.eta_generator
        )

        return {
            "battery_lb": (
                self.battery_mass_breakdown()["battery_mass_lb"]
            ),
            "motors_lb": (
                motor_shaft_kw
                / self.motor_specific_power_kw_per_kg
                * KG_TO_LB
            ),
            "motor_inverters_lb": (
                inverter_bus_kw
                / self.inverter_specific_power_kw_per_kg
                * KG_TO_LB
            ),
            "generators_lb": (
                generator_electrical_kw
                / self.generator_specific_power_kw_per_kg
                * KG_TO_LB
            ),
            "turboshafts_lb": (
                engine_shaft_kw
                / self.turboshaft_specific_power_kw_per_kg
                * KG_TO_LB
            ),
            "propellers_lb": (
                self.n_motors
                * self.propeller_mass_kg_each
                * KG_TO_LB
            ),
        }

    def C_bhp(self, state=None, miss_seg=None):
        """Use the segment power balance for series-hybrid fuel calculations."""
        raise NotImplementedError(
            "Call power_balance() to calculate generator fuel use for each segment"
        )