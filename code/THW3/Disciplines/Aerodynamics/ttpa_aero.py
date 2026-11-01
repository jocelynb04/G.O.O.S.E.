"""
ttpa_aero.py - Aircraft aerodynamics component manager.
"""

import json
from typing import Any, Dict, Union

from aero_lift import AeroLiftModel
from aero_polar import AeroPolarModel


class AerodynamicsBase:
    """Base class for aerodynamics components."""

    pass


class TtpaAero(AerodynamicsBase):
    """Composite class combining lift and drag polar models from JSON inputs."""

    def __init__(self, json_path: str):
        if not isinstance(json_path, str) or not json_path:
            raise ValueError("json_path must be a non-empty string.")

        with open(json_path, "r", encoding="utf-8") as f:
            J = json.load(f)

        A = J["aerodynamics"]
        AR = J["geometry"]["AR"]

        # Sub-model instantiation
        self.lift_model = AeroLiftModel(
            CLmax_clean=A["CLmax_clean"],
            CLmax_takeoff=A["CLmax_takeoff"],
            CLmax_landing=A["CLmax_landing"],
            CL_stall_margin=A["CL_stall_margin"],
        )

        self.polar_model = AeroPolarModel(
            AR=AR,
            CD0=A["CD0_clean"],
            dCD0_flaps_takeoff=A["delta_CD0_flaps_takeoff"],
            dCD0_flaps_landing=A["delta_CD0_flaps_landing"],
            dCD0_gear_down=A["delta_CD0_gear_down"],
            dCD0_propeller_stopped=A["delta_CD0_propeller_stopped"],
            de_flaps_takeoff=A["delta_e_flaps_takeoff"],
            de_flaps_landing=A["delta_e_flaps_landing"],
        )

    # --- Delegated Properties ---
    @property
    def e(self) -> float:
        return self.polar_model.e

    @property
    def K(self) -> float:
        return self.polar_model.K

    @property
    def LD_max(self) -> float:
        return self.polar_model.LD_max

    # --- Delegated Methods ---
    def get_CLmax(self, state: Any, con: Union[Dict[str, Any], Any]) -> float:
        return self.lift_model.get_CLmax(state, con)

    def drag_polar(self, state: Any = None) -> Dict[str, float]:
        return self.polar_model.drag_polar(state)

    def get_config_polar(
        self, state: Any, con: Union[Dict[str, Any], Any]
    ) -> Dict[str, Any]:
        """Combines configuration drag polar and lift performance."""
        cfg = self.polar_model.get_config_polar(state, con)
        cl_max = self.lift_model.get_CLmax(state, con)

        cfg["CLmax"] = cl_max
        cfg["CL_climb"] = cl_max - self.lift_model.CL_stall_margin
        return cfg
