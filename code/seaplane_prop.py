"""
What changes for the hybrid-electric seaplane
  * Parallel hybrid: each nacelle has a turboshaft engine and an electric
    motor on the same propeller.
  * phi = share of the shaft power supplied by the BATTERY in a segment.
    Takeoff and landing are all-electric (phi = 1, RFP: zero emissions on
    the water); the climb is battery-assisted; the cruise recharges the
    battery (phi < 0, RFP: no charging infrastructure).
  * The battery does not get lighter as it discharges, so the sizing loop
    gets a battery weight fraction next to the fuel fraction.
"""
import math

# ---------------------------------------------------------------------------
# Requirements (stands in for the requirements JSON)
# ---------------------------------------------------------------------------
REQUIREMENTS = {
    "propulsion": {
        "n_engines": 2,
        "BSFC_lb_per_hp_hr": 0.60,        # small turboshaft (PT6 class)
        "eta_p_cruise": 0.85,
        "eta_p_loiter": 0.80,
        "eta_p_climb": 0.80,
        "P_TO_over_P_max_continuous": 1.1,
        "engine_power_fraction": 0.70,    # engine power / P_SL (motors = 1.0: electric takeoff)
        "eta_gearbox": 0.98,              # engine -> propeller
        "eta_electric": 0.92,             # battery -> cable -> inverter -> motor -> propeller
        "eta_battery": 0.95,              # charge / discharge
        "battery_Wh_per_kg": 250,         # pack level, 2036 assumption
        "battery_kW_per_kg": 1.5,
        "battery_usable_fraction": 0.64,  # 80% usable SOC x 80% end-of-life capacity
        "phi": {"takeoff": 1.0, "climb": 0.2, "cruise": 0.0,
                "descent": 0.0, "loiter": 0.0, "landing": 1.0},
    },
    "missions": {
        "std_mission": {
            "reserve_fuel_fraction": 0.06,
            "segments": [
                {"type": "takeoff", "alt_ft": 0, "time_min": 6, "power_fraction": 0.29},   # taxi 5 min + takeoff 1 min
                {"type": "climb",   "alt_ft": 10000},
                {"type": "cruise",  "alt_ft": 10000, "ktas": 180, "distance_nm": 869},  # 1,000 mi
                {"type": "descent", "alt_ft": 0},
                {"type": "climb",   "alt_ft": 1500},    # balked landing
                {"type": "loiter",  "alt_ft": 1500, "ktas": 150, "time_min": 45},
                {"type": "descent", "alt_ft": 0},
                {"type": "landing", "alt_ft": 0, "time_min": 9, "power_fraction": 0.19},   # approach 4 min + taxi 5 min
            ],
        }
    },
}


def get_state(alt_ft):
    #ISA density ratio
    return {"alt": alt_ft, "sigma": (1 - 6.87559e-6 * alt_ft) ** 4.2559}

# Propulsion model
class SeaplaneProp:

    engine_type = "Parallel hybrid-electric (turboshaft + electric motor)"

    def __init__(self, J):
        P = J["propulsion"]
        self.P_SL = math.nan #total propeller shaft power, SL, takeoff [hp] set by sizing
        self.n_engines = P["n_engines"]
        self.BSFC = P["BSFC_lb_per_hp_hr"]
        self.eta_p_cruise = P["eta_p_cruise"]
        self.eta_p_loiter = P["eta_p_loiter"]
        self.eta_p_climb = P["eta_p_climb"]
        self.P_TO_over_P_max_continuous = P["P_TO_over_P_max_continuous"]

        # hybrid-electric data
        self.f_engine = P["engine_power_fraction"]
        self.eta_gearbox = P["eta_gearbox"]
        self.eta_electric = P["eta_electric"]
        self.eta_battery = P["eta_battery"]
        self.battery_Wh_per_kg = P["battery_Wh_per_kg"]
        self.battery_kW_per_kg = P["battery_kW_per_kg"]
        self.battery_usable = P["battery_usable_fraction"]
        self.phi_table = P["phi"]

    #Rating factor 
    def rating_factor(self, rating):
        """Power of the rating / takeoff power [-]."""
        if rating == "takeoff":
            return 1.0
        if rating == "max_continuous":
            return 1 / self.P_TO_over_P_max_continuous
        raise ValueError(f'Power rating "{rating}" is not defined.')

    # Power lapse
    def power_lapse(self, state, rating, source="hybrid"):
        """Shaft power at the state and rating / sea-level takeoff power P_SL.
        altitude  engine:  alpha = sigma^0.8 (turboshaft, assumption)
                  motor:   alpha = 1 (the battery does not breathe air)
        rating    rating_factor(rating)
        source    'electric' (battery only), 'fuel' (engine only), 'hybrid' (both)
        """
        alpha_engine = self.f_engine * state["sigma"] ** 0.8 * self.eta_gearbox
        alpha_motor = 1.0
        alpha_altitude = {"electric": alpha_motor,
                          "fuel": alpha_engine,
                          "hybrid": min(1.0, alpha_engine + alpha_motor)}[source]
        return alpha_altitude * self.rating_factor(rating)

    #Power ratio at a constraint condition
    def power_ratio(self, state, con):
        #kP = power at the condition / sea-level takeoff power
        rating = "max_continuous" if con["max_continuous"] else "takeoff"
        source = {"takeoff": "electric", "landing": "electric",
                  "climb_gradient": "hybrid", "cruise_speed": "fuel"}[con["type"]]

        # one nacelle of n_engines when the engine-out flag is set
        f_oei = 1
        if con["oei"]:
            f_oei = 1 / self.n_engines

        kP = self.power_lapse(state, rating, source) * f_oei * con["power_setting"]
        return kP

    #Battery share of a segment
    def get_phi(self, miss_seg):
        if miss_seg.get("phi") is not None:
            return miss_seg["phi"]
        return self.phi_table[miss_seg["type"]]

    #BSFC
    def C_bhp(self, state=None, miss_seg=None):
        """Fuel per propeller shaft hp-hr [lbm/(hp*hr)] = BSFC (1 - phi) / eta_gb.
        Used in the Breguet equations exactly as in IHW1."""
        miss_seg = miss_seg or {"type": "cruise"}
        return self.BSFC * (1 - self.get_phi(miss_seg)) / self.eta_gearbox

    #Propeller efficiency
    def prop_eff(self, state, miss_seg):
        t = miss_seg["type"]
        if t == "loiter":
            return self.eta_p_loiter
        if t == "cruise":
            return self.eta_p_cruise
        if t in ("climb", "climb_gradient"):
            return self.eta_p_climb
        raise ValueError(f'Propeller efficiency is not defined for segment "{t}".')

    #Battery
    def battery_Wh_per_hphr(self, phi):
        #Battery energy per propeller shaft
        if phi >= 0:
            return 745.7 * phi / (self.eta_electric * self.eta_battery)
        return 745.7 * phi * self.eta_electric * self.eta_battery

    def battery_weight(self, E_Wh):
        """Pack weight [lb]: larger of the energy limit and the power limit
        (the motors must run at full takeoff power on the battery alone)."""
        W_energy = E_Wh / self.battery_usable / self.battery_Wh_per_kg * 2.2046
        W_power = self.P_SL * 0.7457 / self.eta_electric / self.battery_kW_per_kg * 2.2046
        return max(W_energy, W_power)


