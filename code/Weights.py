import json
import math


class TidalWeights:

    # MATLAB: the properties block and the constructor are combined in __init__
    def __init__(self, json_path):
        self.W_TO = math.nan                 # lbf, candidate takeoff weight (NaN until sizing sets it)
        self.W_energy = math.nan             # lbf, fuel + battery (NaN until mission analysis sets it)
        self.W_payload_expendable = 0        # lbf
        self.W_payload_fixed = math.nan      # lbf, computed from the payload block below

        # MATLAB: J = jsondecode(fileread(json_path));
        with open(json_path) as f:
            J = json.load(f)

        # OEW regression: We = K_sea * A * W_TO^exponent
        W = J["weights"]
        self.A = W["A"]                      # 0.911, from IHW1
        self.exponent = W["exponent"]        # 0.947, from IHW1
        self.K_sea = W["K_seaplane"]         # seaplane multiplier

        # Fixed payload: passengers + baggage + crew
        P = J["payload"]
        self.W_payload_fixed = (P["n_passengers"] * (P["passenger_weight_lb"] + P["baggage_per_passenger_lb"])
                                + P["n_pilots"] * P["pilot_weight_lb"])

    # MATLAB: function oew = OEW(obj, W_TO)
    def OEW(self, W_TO):
        # Empty Weight
        if W_TO <= 0:
            raise ValueError("W_TO must be positive")   # MATLAB: error(...)

        oew = self.K_sea * self.A * W_TO ** self.exponent   # ^ in MATLAB is ** in Python

        if oew >= W_TO:
            raise ValueError("Infeasible: OEW >= W_TO")

        return oew                                           # Python needs an explicit return
