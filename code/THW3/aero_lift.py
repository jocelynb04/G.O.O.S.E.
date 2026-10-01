""" aero_lift.py - Maximum lift coefficient models for aircraft performance analysis. """ 
from typing import Any, Dict, Union class AeroLiftModel: 
"""Handles maximum lift coefficients and stall/climb margins across configurations.""" 
def __init__( 
    self, 
    CLmax_clean: float, 
    CLmax_takeoff: float, 
    CLmax_landing: float, 
    CL_stall_margin: float, 
    ): 
    self.CLmax_clean = CLmax_clean 
    self.CLmax_takeoff = CLmax_takeoff 
    self.CLmax_landing = CLmax_landing 
    self.CL_stall_margin = CL_stall_margin 

def get_CLmax(self, state: Any, con: Union[Dict[str, Any], Any]) -> float: 
    """Computes CLmax based on aircraft configuration.""" 
    config_name = str( con.get("config") if isinstance(con, dict) else getattr(con, "config") ) 
    if config_name == "clean": 
        return self.CLmax_clean 
    elif config_name in ("takeoff_flaps_gear_up", "takeoff_flaps_gear_down"): 
        return self.CLmax_takeoff 
    elif config_name in ("landing_flaps_gear_up", "landing_flaps_gear_down"): 
        return self.CLmax_landing 
    else: 
        raise ValueError( f"AeroLiftModel:UnknownConfig - Unknown configuration name: {config_name}" ) 

def get_CL_climb(self, state: Any, con: Union[Dict[str, Any], Any]) -> float: 
    """Computes climb CL including stall margin.""" 
    return self.get_CLmax(state, con) - self.CL_stall_margin
