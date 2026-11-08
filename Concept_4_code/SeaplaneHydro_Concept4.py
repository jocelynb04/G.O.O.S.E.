"""Twin-float buoyancy, hydrostatics, and planing-resistance calculations."""
from __future__ import annotations

import math
from typing import Any

FT_TO_M = 0.3048
KNOT_TO_MPS = 0.514444444444
LBF_TO_N = 4.4482216153
G = 9.80665

FRESH_WATER_WEIGHT_LB_FT3 = 62.4
FRESH_WATER_DENSITY_KG_M3 = 998.2
KINEMATIC_VISCOSITY_M2_S = 1.004e-6


class HydrodynamicValidityError(ValueError):
    """Operating condition lies beyond the selected planing correlation."""


class SeaplaneHydro:
    """Buoyancy and twin-float planing calculations."""

    def __init__(self, J: dict, geom: Any, aero: Any = None):
        self.geom = geom
        self.aero = aero

        H = J["hydrodynamics"]

        self.water_gamma = float(
            H.get("fresh_water_specific_weight_lb_ft3", 62.4)
        )
        self.rho = float(
            H.get("fresh_water_density_kg_m3", 998.2)
        )
        self.nu = float(
            H.get("water_kinematic_viscosity_m2_s", 1.004e-6)
        )

        self.cb = float(H["float_block_coefficient"])
        self.cwp = float(H["float_waterplane_coefficient"])
        self.deadrise_deg = float(H["deadrise_deg"])
        self.trim_deg = float(H["trim_angle_deg"])
        self.kg_ft = float(H["cg_height_above_float_keel_ft"])

        self.approved_fraction = H.get(
            "verified_below_cabin_floor_volume_fraction",
            None,
        )

        self.extra_eligible_volume = float(
            H.get(
                "verified_other_below_cabin_floor_volume_ft3",
                0.0,
            )
        )

        for name, val in [
            ("block coefficient", self.cb),
            ("waterplane coefficient", self.cwp),
        ]:
            if not 0 < val <= 1:
                raise ValueError(
                    f"{name} must be in (0,1]"
                )

        if (
            self.water_gamma <= 0
            or self.rho <= 0
            or self.nu <= 0
        ):
            raise ValueError(
                "Water physical properties must be positive"
            )

        if self.approved_fraction is not None:
            if not 0 <= float(self.approved_fraction) <= 1:
                raise ValueError(
                    "Verified below-floor volume fraction "
                    "outside [0,1]"
                )

        if not 0 <= self.deadrise_deg <= 30:
            raise ValueError(
                "Planing model requires 0 to 30 deg deadrise"
            )

    @property
    def float_count(self):
        return int(self.geom.float_data["count"])

    @property
    def length_ft(self):
        return float(self.geom.float_data["length_ft"])

    @property
    def beam_ft(self):
        return float(self.geom.float_data["beam_ft"])

    @property
    def height_ft(self):
        return float(self.geom.float_data["height_ft"])

    @property
    def spacing_ft(self):
        return float(
            self.geom.float_data["centerline_spacing_ft"]
        )

    @property
    def float_volume_ft3(self):
        return (
            self.float_count
            * self.length_ft
            * self.beam_ft
            * self.height_ft
            * self.cb
        )

    def buoyancy_screen(self, weight_lb: float) -> dict:
        if weight_lb <= 0:
            raise ValueError(
                "Takeoff weight must be positive"
            )

        needed = (
            1.8 * weight_lb / self.water_gamma
        )

        max_total = self.float_volume_ft3

        eligible = (
            None
            if self.approved_fraction is None
            else (
                max_total * float(self.approved_fraction)
                + self.extra_eligible_volume
            )
        )

        if eligible is None:
            status = "NOT_ASSESSED"
        elif eligible >= needed:
            status = "PASS_VOLUME_ONLY"
        else:
            status = "FAIL_VOLUME"

        return {
            "weight_lb": weight_lb,
            "required_180pct_displacement_ft3": needed,
            "external_float_volume_ft3": max_total,
            "external_float_only_screen_pass": (
                max_total >= needed
            ),
            "verified_eligible_volume_ft3": eligible,
            "rfp_below_cabin_floor_screen": status,
            "adjacent_compartments_flooding": "NOT_ASSESSED",
            "heel_20deg": "NOT_ASSESSED",
            "note": (
                "Volume is an approximate upper-bound "
                "displacement, not validated watertight geometry."
            ),
        }

    def hydrostatics(self, weight_lb: float) -> dict:
        if weight_lb <= 0:
            raise ValueError(
                "Weight must be positive"
            )

        vol = weight_lb / self.water_gamma

        draft = vol / (
            self.float_count
            * self.length_ft
            * self.beam_ft
            * self.cb
        )

        A = (
            self.float_count
            * self.length_ft
            * self.beam_ft
            * self.cwp
        )

        I_trans = self.float_count * (
            self.length_ft
            * self.beam_ft ** 3
            * self.cwp
            / 12
            + self.length_ft
            * self.beam_ft
            * self.cwp
            * (self.spacing_ft / 2) ** 2
        )

        KB = draft / 2
        BM = I_trans / vol
        GM = KB + BM - self.kg_ft

        emergence_deg = math.degrees(
            math.atan2(
                2 * draft,
                self.spacing_ft,
            )
        )

        return {
            "weight_lb": weight_lb,
            "displaced_volume_ft3": vol,
            "estimated_draft_ft": draft,
            "float_height_ft": self.height_ft,
            "float_submergence_screen_pass": (
                draft <= self.height_ft
            ),
            "waterplane_area_ft2": A,
            "waterplane_I_transverse_ft4": I_trans,
            "KB_ft": KB,
            "BM_ft": BM,
            "KG_ft": self.kg_ft,
            "small_angle_GM_ft": GM,
            "small_angle_GM_positive": GM > 0,
            "approx_float_emergence_heel_deg": emergence_deg,
            "20deg_heel_requirement": "NOT_ASSESSED",
            "limitations": (
                "Fixed waterplane approximation; unsuitable "
                "for finite-heel stability and flooding."
            ),
        }

    @staticmethod
    def savitsky_lift_coefficient(
        wetted_length_to_beam: float,
        cv: float,
        trim_angle_deg: float,
        deadrise_deg: float,
    ) -> float:
        lam = wetted_length_to_beam

        if (
            min(lam, cv, trim_angle_deg) <= 0
            or not 0 <= deadrise_deg <= 30
        ):
            raise ValueError(
                "Invalid planing lift parameters"
            )

        cl0 = trim_angle_deg ** 1.1 * (
            0.012 * math.sqrt(lam)
            + 0.0055 * lam ** 2.5 / cv ** 2
        )

        return (
            cl0
            - 0.0065
            * deadrise_deg
            * cl0 ** 0.6
        )

    def planing_resistance(
        self,
        speed_kt: float,
        weight_lb: float,
        *,
        aerodynamic_lift_lb: float = 0.0,
        trim_angle_deg: float | None = None,
    ) -> dict:
        if speed_kt <= 0 or weight_lb <= 0:
            raise ValueError(
                "Speed and weight must be positive"
            )

        if aerodynamic_lift_lb < 0:
            raise ValueError(
                "Aerodynamic lift must be nonnegative"
            )

        water_load = max(
            0.0,
            weight_lb - aerodynamic_lift_lb,
        )

        if water_load == 0:
            return {
                "speed_kt": speed_kt,
                "regime": "airborne",
                "water_load_lb": 0.0,
                "hydrodynamic_drag_lb": 0.0,
                "lambda": 0.0,
                "wetted_length_ft": 0.0,
            }

        trim = float(
            self.trim_deg
            if trim_angle_deg is None
            else trim_angle_deg
        )

        if not 2 <= trim <= 15:
            raise HydrodynamicValidityError(
                "Planing model requires trim 2 to 15 deg"
            )

        v = speed_kt * KNOT_TO_MPS
        b = self.beam_ft * FT_TO_M

        cv = v / math.sqrt(G * b)

        if not 0.6 <= cv <= 13:
            raise HydrodynamicValidityError(
                f"Cv={cv:.3f} outside 0.6 to 13"
            )

        load_per_float_n = (
            water_load / self.float_count
        ) * LBF_TO_N

        cl_required = load_per_float_n / (
            0.5
            * self.rho
            * v * v
            * b * b
        )

        lo = 1e-5
        hi = 4.0

        if (
            self.savitsky_lift_coefficient(
                hi,
                cv,
                trim,
                self.deadrise_deg,
            )
            < cl_required
        ):
            raise HydrodynamicValidityError(
                "Planing lift requires lambda > 4"
            )

        if (
            self.savitsky_lift_coefficient(
                lo,
                cv,
                trim,
                self.deadrise_deg,
            )
            > cl_required
        ):
            raise HydrodynamicValidityError(
                "Planing lift requires lambda < 1e-5"
            )

        for _ in range(90):
            mid = (lo + hi) / 2

            calculated_cl = self.savitsky_lift_coefficient(
                mid,
                cv,
                trim,
                self.deadrise_deg,
            )

            if calculated_cl < cl_required:
                lo = mid
            else:
                hi = mid

        lam = (lo + hi) / 2
        wetted_length_m = lam * b

        if wetted_length_m > self.length_ft * FT_TO_M:
            raise HydrodynamicValidityError(
                "Required wetted length exceeds float length"
            )

        reynolds = (
            v * wetted_length_m / self.nu
        )

        if reynolds <= 1e5:
            raise HydrodynamicValidityError(
                "Friction correlation outside valid Reynolds range"
            )

        cf = 0.075 / (
            math.log10(reynolds) - 2
        ) ** 2

        tau_rad = math.radians(trim)
        beta_rad = math.radians(
            self.deadrise_deg
        )

        q = 0.5 * self.rho * v * v

        pressure_drag_n = (
            load_per_float_n
            * math.tan(tau_rad)
        )

        friction_drag_n = (
            q
            * lam
            * b * b
            * cf
            / (
                math.cos(beta_rad)
                * math.cos(tau_rad)
            )
        )

        drag_lb = (
            self.float_count
            * (pressure_drag_n + friction_drag_n)
            / LBF_TO_N
        )

        return {
            "speed_kt": speed_kt,
            "regime": "prismatic_planing_screen",
            "water_load_lb": water_load,
            "Cv": cv,
            "CLbeta_required": cl_required,
            "lambda": lam,
            "wetted_length_ft": (
                wetted_length_m / FT_TO_M
            ),
            "trim_deg": trim,
            "deadrise_deg": self.deadrise_deg,
            "water_reynolds": reynolds,
            "Cf_ittc1957": cf,
            "pressure_drag_lb": (
                self.float_count
                * pressure_drag_n
                / LBF_TO_N
            ),
            "friction_drag_lb": (
                self.float_count
                * friction_drag_n
                / LBF_TO_N
            ),
            "hydrodynamic_drag_lb": drag_lb,
            "verified_50ft_obstacle_takeoff": "NOT_ASSESSED",
            "limitations": (
                "Assumed trim and symmetric loading; "
                "no hump resistance, spray, or equilibrium solution."
            ),
        }

    def water_run_point(
        self,
        speed_kt: float,
        weight_lb: float,
        *,
        wing_cl: float = 0.6,
        trim_angle_deg: float | None = None,
    ) -> dict:
        if self.aero is None:
            raise ValueError(
                "SeaplaneAero object required for water-run calculation"
            )

        a = self.aero.flight_forces(
            weight_lb,
            speed_kt,
            0.0,
            config="takeoff_flaps_gear_up",
            CL=wing_cl,
        )

        h = self.planing_resistance(
            speed_kt,
            weight_lb,
            aerodynamic_lift_lb=a["lift_lb"],
            trim_angle_deg=trim_angle_deg,
        )

        return {
            **h,
            "aero_lift_lb": a["lift_lb"],
            "aero_drag_lb": a["drag_lb"],
            "combined_drag_lb": (
                a["drag_lb"]
                + h["hydrodynamic_drag_lb"]
            ),
            "wing_CL_assumed": wing_cl,
            "wing_CLmax_takeoff": a["CLmax_config"],
        }
