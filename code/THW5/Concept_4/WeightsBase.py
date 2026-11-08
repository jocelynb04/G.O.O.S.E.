from abc import abstractmethod
import math
import json

class WeightsBase:
    def __init__(self,J,geom,prop):
        self.geom, self.prop = geom, prop
        W = J["weights"]
        P = J["payload"]
        self.P = P

        # sizing states 
        self.W_TO = float("nan")  # lbf, candidate gross takeoff weight
        self.W_energy = float("nan")  # lbf, total internal fuel weight

        # requirement: read from JSON
        self.W_payload_expendable = P["W_expendable_lbf"]  # lbf, expendable payload (stores)

        @property
        def W_payload_fixed(self):
            P = self.P
            n_people = P["n_passengers"] + P["n_pilots"]
            n_bags = n_people if P["baggage_includes_pilots"] else P["n_passengers"]
            W_people = P["n_passengers"] * P["W_passenger_lbf"] + P["n_pilots"] * P["W_pilot_lbf"]
            fixed_payload =P["n_passengers"] * P["W_passenger_lbf"]+ P["n_pilots"] * P["W_pilot_lbf"]+ n_bags * P["W_baggage_per_passenger_lbf"]
            return fixed_payload

        def payload(self): 
            return self.W_payload_fixed + self.W_payload_expendable
       
        @abstractmethod
        def OEW(self, W_TO):
            """Operating empty weight [lbf] at the passed W_TO"""
            if W_TO <= 0:
                raise ValueError("W_TO must be positive")
            return self.OEW_breakdown(W_TO)["total"] 
     

