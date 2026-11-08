
"""Aerodynamic model for Concept 4, including component parasite drag."""
from __future__ import annotations
import math
from typing import Any, Mapping

KNOT_TO_MPS = 0.514444444444
FT_TO_M = 0.3048
SQFT_TO_SQM = FT_TO_M ** 2
PA_TO_PSF = 0.020885434273
KG_M3_TO_SLUG_FT3 = 0.00194032033


def _field(obj: Any, name: str, default: Any = None) -> Any:
    return obj.get(name, default) if isinstance(obj, Mapping) else getattr(obj, name, default)


def isa_atmosphere(altitude_ft: float) -> dict[str, float]:
    """ISA troposphere with dynamic viscosity from Sutherland's law."""
    if not 0 <= altitude_ft <= 36089:
        raise ValueError("Only ISA troposphere from 0 to 36,089 ft is supported")
    t = 288.15 - 0.0065 * altitude_ft * FT_TO_M
    p = 101325.0 * (t / 288.15) ** 5.2558797
    rho = p / (287.05287 * t)
    mu = 1.716e-5 * (t / 273.15) ** 1.5 * (273.15 + 110.4) / (t + 110.4)
    sound = math.sqrt(1.4 * 287.05287 * t)
    return {
        "T_K": t,
        "pressure_Pa": p,
        "rho_kg_m3": rho,
        "rho_slug_ft3": rho * KG_M3_TO_SLUG_FT3,
        "mu_Pa_s": mu,
        "speed_of_sound_m_s": sound,
    }


class SeaplaneAero:
    """Aerodynamic model using dynamically recomputed aircraft geometry."""

    def __init__(self, J: Mapping[str, Any], geom: Any):
        self.geom = geom
        A = J["aerodynamics"]

        self.CD0_reference = float(A.get("CD0_clean", 0.028))
        self.Cfe_reference = float(A.get("Cfe", 0.0045))
        self.CLmax_clean = float(A["CLmax_clean"])
        self.CLmax_takeoff = float(A["CLmax_takeoff"])
        self.CLmax_landing = float(A["CLmax_landing"])
        self.CL_stall_margin = float(A["CL_stall_margin"])
        self.dCD0_flaps_takeoff = float(A["delta_CD0_flaps_takeoff"])
        self.dCD0_flaps_landing = float(A["delta_CD0_flaps_landing"])
        self.dCD0_gear_down = float(A["delta_CD0_gear_down"])
        self.de_flaps_takeoff = float(A["delta_e_flaps_takeoff"])
        self.de_flaps_landing = float(A["delta_e_flaps_landing"])

        G = J["concept4_geometry"]
        self.floats = G["floats"]
        self.struts = G["float_struts"]
        self.nacelles = G["motor_nacelles"]
        self.openvsp = G.get("openvsp_air_wetted_area_ft2", {})
        self.Q = G.get("interference_factors", {})

        self.ref = J.get(
            "aero_reference_condition",
            {"altitude_ft": 10000, "speed_ktas": 130},
        )

        self.extra_cd0 = float(
            J.get("concept4_aerodynamics", {}).get(
                "additional_calibrated_cd0", 0.0
            )
        )

        self.stopped_prop_cd0 = J.get(
            "concept4_aerodynamics", {}
        ).get("stopped_propeller_cd0_increment")

        self._check_inputs()

    def _check_inputs(self):
        if int(self.floats["count"]) != 2:
            raise ValueError("Concept 4 requires exactly two pontoons")

        if int(self.nacelles["count"]) < 2:
            raise ValueError("Expected more than one distributed motor nacelle")

        if not math.isfinite(self.extra_cd0) or self.extra_cd0 < 0:
            raise ValueError("Additional drag coefficient must be nonnegative")

        for k, v in self.Q.items():
            if float(v) < 1.0:
                raise ValueError(
                    f"Q[{k}] below 1 requires a validated interference model"
                )

        for k, v in self.openvsp.items():
            if float(v) <= 0:
                raise ValueError(
                    f"OpenVSP area for {k} must be positive"
                )

    @property
    def AR(self) -> float:
        return float(self.geom.AR)

    @property
    def e(self) -> float:
        e = 1.78 * (1 - 0.045 * self.AR ** 0.68) - 0.64

        if not 0 < e <= 1:
            raise ValueError(
                f"Oswald efficiency outside (0,1]: {e}"
            )

        return e

    @property
    def K(self) -> float:
        return 1 / (math.pi * self.AR * self.e)

    @property
    def CD0(self) -> float:
        return self.drag_breakdown()["CD0_total"]

    @property
    def LD_max(self) -> float:
        return 1 / (2 * math.sqrt(self.CD0 * self.K))

    def _area(self, name: str, estimate: float) -> float:
        return (
            float(self.openvsp[name])
            if name in self.openvsp
            else float(estimate)
        )

    @staticmethod
    def _wing_ff(thickness_ratio: float) -> float:
        if not 0 <= thickness_ratio < 0.5:
            raise ValueError(
                "Invalid t/c for wing-type form factor"
            )

        return (
            1
            + 2.7 * thickness_ratio
            + 100 * thickness_ratio ** 4
        )

    @staticmethod
    def _body_ff(length_ft: float, diameter_ft: float) -> float:
        if length_ft <= 0 or diameter_ft <= 0:
            raise ValueError("Body dimensions must be positive")

        f = length_ft / diameter_ft

        if f < 3.0:
            raise ValueError(
                "Body form-factor model needs L/D >= 3"
            )

        return 1 + 60 / f ** 3 + f / 400

    def _components(self):
        g = self.geom
        sf = self.floats
        st = self.struts
        na = self.nacelles

        fus_l = float(g.l_fus)
        fus_d = max(float(g.w_fus), float(g.h_fus))

        comps = {
            "wing": (
                float(g.S_wet_wing),
                float(g.MAC),
                self._wing_ff(float(g.tc_mean)),
            ),
            "horizontal_tail": (
                float(g.S_wet_ht),
                float(g.MAC_ht),
                self._wing_ff(float(g.tc_ht)),
            ),
            "vertical_tail": (
                float(g.S_wet_vt),
                float(g.MAC_vt),
                self._wing_ff(float(g.tc_vt)),
            ),
            "fuselage": (
                float(g.S_wet_fuselage),
                fus_l,
                self._body_ff(fus_l, fus_d),
            ),
            "pontoons": (
                float(g.S_wet_pontoons),
                float(sf["length_ft"]),
                self._body_ff(
                    float(sf["length_ft"]),
                    max(
                        float(sf["beam_ft"]),
                        float(sf["height_ft"]),
                    ),
                ),
            ),
            "float_struts": (
                float(g.S_wet_float_struts),
                float(st["chord_ft"]),
                self._wing_ff(float(st["thickness_ratio"])),
            ),
            "motor_nacelles": (
                float(g.S_wet_motor_nacelles),
                float(na["length_ft"]),
                self._body_ff(
                    float(na["length_ft"]),
                    float(na["diameter_ft"]),
                ),
            ),
        }

        return {
            name: (self._area(name, area), length, ff)
            for name, (area, length, ff) in comps.items()
        }

    def drag_breakdown(self, state: Any = None) -> dict:
        alt = float(
            _field(
                state,
                "alt_ft",
                _field(
                    state,
                    "altitude_ft",
                    self.ref.get("altitude_ft", 10000),
                ),
            )
        )

        speed = float(
            _field(
                state,
                "ktas",
                _field(
                    state,
                    "speed_ktas",
                    self.ref.get("speed_ktas", 130),
                ),
            )
        )

        if speed <= 0:
            raise ValueError(
                "Flight drag needs positive forward airspeed"
            )

        S = float(self.geom.S_ref)

        if S <= 0:
            raise ValueError(
                "Assign geom.S_ref inside sizing loop first"
            )

        atm = isa_atmosphere(alt)
        v = speed * KNOT_TO_MPS
        mach = v / atm["speed_of_sound_m_s"]

        rows = {}

        for name, (swet, l, ff) in self._components().items():
            re = (
                atm["rho_kg_m3"]
                * v
                * (l * FT_TO_M)
                / atm["mu_Pa_s"]
            )

            if re <= 1e4:
                raise ValueError(
                    f"{name}: Reynolds number too low"
                )

            cf = 0.455 / (
                math.log10(re) ** 2.58
                * (1 + 0.144 * mach * mach) ** 0.65
            )

            q = float(self.Q.get(name, 1.0))
            cdi = cf * ff * q * swet / S

            rows[name] = {
                "S_wet_ft2": swet,
                "length_ft": l,
                "Re": re,
                "Cf": cf,
                "FF": ff,
                "Q": q,
                "CD0": cdi,
                "area_source": (
                    "OpenVSP"
                    if name in self.openvsp
                    else "geometric estimate"
                ),
            }

        total = (
            sum(r["CD0"] for r in rows.values())
            + self.extra_cd0
        )

        return {
            "components": rows,
            "CD0_total": total,
            "reference_S_ft2": S,
            "altitude_ft": alt,
            "speed_ktas": speed,
            "extra_cd0": self.extra_cd0,
            "reference_CD0": self.CD0_reference,
            "equivalent_friction_CD0": (
                self.Cfe_reference
                * sum(r["S_wet_ft2"] for r in rows.values())
                / S
            ),
        }

    def drag_polar(self, state: Any = None) -> dict[str, float]:
        return {
            "CD0": self.drag_breakdown(state)["CD0_total"],
            "K1": self.K,
            "K2": 0.0,
        }

    def get_CLmax(
        self,
        state: Any = None,
        con: Any = None,
    ) -> float:
        cfg = str(_field(con, "config", "clean"))

        if cfg == "clean":
            return self.CLmax_clean

        if cfg.startswith("takeoff_flaps_"):
            return self.CLmax_takeoff

        if cfg.startswith("landing_flaps_"):
            return self.CLmax_landing

        raise ValueError(
            f"Unknown flap configuration: {cfg}"
        )

    def get_config_polar(
        self,
        state: Any = None,
        con: Any = None,
    ) -> dict:
        cfg = str(_field(con, "config", "clean"))

        if cfg == "clean":
            dcd0, de = 0.0, 0.0

        elif cfg == "takeoff_flaps_gear_up":
            dcd0, de = (
                self.dCD0_flaps_takeoff,
                self.de_flaps_takeoff,
            )

        elif cfg == "takeoff_flaps_gear_down":
            dcd0, de = (
                self.dCD0_flaps_takeoff + self.dCD0_gear_down,
                self.de_flaps_takeoff,
            )

        elif cfg == "landing_flaps_gear_up":
            dcd0, de = (
                self.dCD0_flaps_landing,
                self.de_flaps_landing,
            )

        elif cfg == "landing_flaps_gear_down":
            dcd0, de = (
                self.dCD0_flaps_landing + self.dCD0_gear_down,
                self.de_flaps_landing,
            )

        else:
            raise ValueError(
                f"Unsupported configuration: {cfg}"
            )

        if bool(_field(con, "propeller_stopped", False)):
            value = _field(
                con,
                "stopped_propeller_cd0_increment",
                self.stopped_prop_cd0,
            )

            if value is None:
                raise NotImplementedError(
                    "Stopped distributed propulsor drag "
                    "requires a validated input"
                )

            dcd0 += float(value)

        e = self.e + de

        if e <= 0:
            raise ValueError(
                "Configuration Oswald efficiency <= 0"
            )

        base = self.drag_polar(state)
        clmax = self.get_CLmax(state, con)

        return {
            "config": cfg,
            "CD0": base["CD0"] + dcd0,
            "e": e,
            "K1": 1 / (math.pi * self.AR * e),
            "K2": 0.0,
            "CLmax": clmax,
            "CL_climb": clmax - self.CL_stall_margin,
        }

    @staticmethod
    def compute_CL(
        L_lb: float,
        q_psf: float,
        S_ref_ft2: float,
    ) -> float:
        if q_psf <= 0 or S_ref_ft2 <= 0:
            raise ValueError(
                "q and S must be positive"
            )

        return L_lb / (q_psf * S_ref_ft2)

    @staticmethod
    def compute_CD(
        CD0: float,
        K1: float,
        K2: float,
        CL: float,
    ) -> float:
        return CD0 + K1 * CL ** 2 + K2 * CL

    def flight_forces(
        self,
        weight_lb: float,
        speed_ktas: float,
        altitude_ft: float,
        *,
        config: str = "clean",
        CL: float | None = None,
    ) -> dict:
        if weight_lb <= 0:
            raise ValueError(
                "Weight must be positive"
            )

        st = {
            "alt_ft": altitude_ft,
            "ktas": speed_ktas,
        }

        q = (
            0.5
            * isa_atmosphere(altitude_ft)["rho_slug_ft3"]
            * (speed_ktas * 1.687809857) ** 2
        )

        polar = self.get_config_polar(
            st,
            {"config": config},
        )

        c_l = (
            self.compute_CL(
                weight_lb,
                q,
                self.geom.S_ref,
            )
            if CL is None
            else float(CL)
        )

        if c_l < 0:
            raise ValueError(
                "CL must be >= 0"
            )

        cd = self.compute_CD(
            polar["CD0"],
            polar["K1"],
            polar["K2"],
            c_l,
        )

        return {
            "q_psf": q,
            "CL": c_l,
            "CD": cd,
            "lift_lb": q * self.geom.S_ref * c_l,
            "drag_lb": q * self.geom.S_ref * cd,
            "L_over_D": c_l / cd,
            "CLmax_config": polar["CLmax"],
            "CL_limit_exceeded": c_l > polar["CLmax"],
        }