"""
aero_polar.py - Drag polar and aerodynamic efficiency models.
"""

import math
from typing import Any, Dict, Union


class AeroPolarModel:
    """Handles drag polar parameters, Oswald efficiency, and incremental drag increments."""

    def __init__(
        self,
        AR: float,
        CD0: float,
        dCD0_flaps_takeoff: float,
        dCD0_flaps_landing: float,
        dCD0_gear_down: float,
        dCD0_propeller_stopped: float,
        de_flaps_takeoff: float,
        de_flaps_landing: float,
    ):
        self.AR = AR
        self.CD0 = CD0
        self.dCD0_flaps_takeoff = dCD0_flaps_takeoff
        self.dCD0_flaps_landing = dCD0_flaps_landing
        self.dCD0_gear_down = dCD0_gear_down
        self.dCD0_propeller_stopped = dCD0_propeller_stopped
        self.de_flaps_takeoff = de_flaps_takeoff
        self.de_flaps_landing = de_flaps_landing

    @property
    def e(self) -> float:
        """Clean Oswald Efficiency factor."""
        return 1.78 * (1 - 0.045 * (self.AR**0.68)) - 0.64

    @property
    def K(self) -> float:
        """Clean Induced Drag Factor."""
        e_val = self.e
        if math.isnan(e_val) or e_val <= 0 or e_val > 1:
            raise ValueError(
                f"AeroPolarModel:InvalidOswaldEfficiency - Computed Oswald efficiency e = {e_val:.4f} is invalid."
            )
        return 1.0 / (math.pi * self.AR * e_val)

    @property
    def LD_max(self) -> float:
        """Maximum Lift-to-Drag ratio (clean)."""
        return 1.0 / (2.0 * math.sqrt(self.CD0 * self.K))

    def drag_polar(self, state: Any = None) -> Dict[str, float]:
        """Base clean drag polar."""
        return {"CD0": self.CD0, "K1": self.K, "K2": 0.0}

    def get_config_polar(
        self, state: Any, con: Union[Dict[str, Any], Any]
    ) -> Dict[str, Any]:
        """Computes configuration-specific polar parameters."""
        config_name = str(
            con.get("config") if isinstance(con, dict) else getattr(con, "config")
        )

        if config_name == "clean":
            dCD0, de = 0.0, 0.0
        elif config_name == "takeoff_flaps_gear_up":
            dCD0, de = self.dCD0_flaps_takeoff, self.de_flaps_takeoff
        elif config_name == "takeoff_flaps_gear_down":
            dCD0, de = (
                self.dCD0_flaps_takeoff + self.dCD0_gear_down,
                self.de_flaps_takeoff,
            )
        elif config_name == "landing_flaps_gear_up":
            dCD0, de = self.dCD0_flaps_landing, self.de_flaps_landing
        elif config_name == "landing_flaps_gear_down":
            dCD0, de = (
                self.dCD0_flaps_landing + self.dCD0_gear_down,
                self.de_flaps_landing,
            )
        else:
            raise ValueError(
                f"AeroPolarModel:UnknownConfig - Unknown configuration name: {config_name}"
            )

        prop_stopped = (
            con.get("propeller_stopped", False)
            if isinstance(con, dict)
            else getattr(con, "propeller_stopped", False)
        )
        if prop_stopped:
            dCD0 += self.dCD0_propeller_stopped

        cfg_e = self.e + de
        return {
            "config": config_name,
            "CD0": self.CD0 + dCD0,
            "e": cfg_e,
            "K1": 1.0 / (math.pi * self.AR * cfg_e),
            "K2": 0.0,
        }