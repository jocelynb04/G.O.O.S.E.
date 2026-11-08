
from __future__ import annotations

import copy
import math

from Concept4GeometryAdapter import SeaplaneGeom
from Concept4Constraints import matching_envelope
from Concept4Mission import Concept4Mission, MissionInfeasible
from SeaplaneAero_Concept4 import SeaplaneAero
from SeaplaneHydro_Concept4 import SeaplaneHydro
from SeaplaneProp_Concept4 import SeaplaneProp
from SeaplaneWeights import SeaplaneWeights
from sizing_pass import sizing_pass


class SizingInfeasible(RuntimeError):
    pass


class Concept4Sizing:
    def __init__(self, J: dict, assumptions: dict):
        self.J = copy.deepcopy(J)
        self.assumptions = assumptions
        self.prop = SeaplaneProp(self.J)
        self.geom = SeaplaneGeom(self.J, self.prop)
        self.aero = SeaplaneAero(self.J, self.geom)
        self.hydro = SeaplaneHydro(self.J, self.geom, self.aero)
        self.weights = SeaplaneWeights(self.J, self.geom, self.prop)
        self.mission = Concept4Mission(
            self.J, self.geom, self.aero, self.prop, assumptions
        )

        S = self.J["sizing"]
        self.initial = {
            "W_TO_lb": float(S["W_TO_guess_lbf"]),
            "S_ref_ft2": float(S["S_ref_guess_ft2"]),
            "motor_shaft_hp": float(S["P_SL_guess_hp"]),
            "generator_engine_hp_each": float(
                S["generator_engine_shaft_power_guess_hp_each"]
            ),
            "battery_capacity_kwh": float(
                S["battery_capacity_guess_kwh"]
            ),
        }

    def _write_design(self, state):
        self.geom.S_ref = state["S_ref_ft2"]
        self.prop.P_SL = state["motor_shaft_hp"]
        self.prop.engine_shaft_power_sl_hp_each = (
            state["generator_engine_hp_each"]
        )
        self.prop.battery_capacity_kwh = state["battery_capacity_kwh"]

    def sizing_pass(self, state: dict) -> dict:
        W = state["W_TO_lb"]
        self._write_design(state)

        env = matching_envelope(
            self.J,
            self.geom,
            self.aero,
            self.prop,
            W,
            self.assumptions,
        )

        if env["selected"] is None:
            raise SizingInfeasible(env["status"])

        best = env["selected"]

        proposed = {
            "W_TO_lb": W,
            "S_ref_ft2": best["wing_area_ft2"],
            "motor_shaft_hp": best["required_motor_hp"],
            "generator_engine_hp_each": (
                best["required_turboshaft_hp_each"]
            ),
            "battery_capacity_kwh": state["battery_capacity_kwh"],
        }

        self._write_design(proposed)

        try:
            energy_probe = self.mission.run(
                W, sizing_probe=True
            )
        except MissionInfeasible as exc:
            raise SizingInfeasible(
                "Mission power infeasible at proposed motor/generator: "
                + str(exc)
            ) from exc

        usable = (
            self.prop.battery_initial_soc
            - self.prop.battery_min_soc
        )

        energy_required = (
            energy_probe["peak_cumulative_pack_deficit_kwh"] / usable
        )

        battery_min = float(
            self.assumptions.get(
                "minimum_battery_capacity_kwh", 80.0
            )
        )

        proposed["battery_capacity_kwh"] = max(
            battery_min,
            energy_required
            * (
                1.0
                + self.assumptions[
                    "battery_energy_margin_fraction"
                ]
            ),
        )

        self._write_design(proposed)

        try:
            real = self.mission.run(W)
        except MissionInfeasible as exc:
            raise SizingInfeasible(
                "Mission failed with sized battery: "
                + str(exc)
            ) from exc

        breakdown = self.weights.OEW_breakdown(W)
        payload = self.weights.payload()
        fuel = real["total_fuel_lb"]

        gross_new = breakdown["total"] + payload + fuel
        proposed["W_TO_lb"] = gross_new

        if not math.isfinite(gross_new) or gross_new <= 0:
            raise SizingInfeasible(
                "Nonphysical weight closure"
            )

        if gross_new > float(
            self.assumptions["max_gross_weight_search_lb"]
        ):
            raise SizingInfeasible(
                "Gross weight exceeds configured sizing search ceiling"
            )

        residuals = {
            k: abs(proposed[k] - state[k])
            / max(abs(proposed[k]), 1e-12)
            for k in state
        }

        span_limit = self.J[
            "rfp_performance_requirements"
        ]["maximum_wingspan_ft_strictly_below"]

        return {
            "current": dict(state),
            "proposed": proposed,
            "residuals": residuals,
            "max_residual": max(residuals.values()),
            "OEW_lb": breakdown["total"],
            "payload_lb": payload,
            "mission_fuel_lb": fuel,
            "mission_soc_end": real["soc_end"],
            "energy_probe_peak_deficit_kwh": (
                energy_probe[
                    "peak_cumulative_pack_deficit_kwh"
                ]
            ),
            "minimum_capacity_kwh_before_margin": (
                energy_required
            ),
            "span_ft": self.geom.b,
            "span_screen": (
                "PRELIMINARY_PASS"
                if self.geom.b < span_limit
                else "FAIL"
            ),
            "chosen_aero_constraints": {
                k: v for k, v in best.items()
                if k != "score"
            },
        }

    def run(
        self,
        *,
        max_iter=None,
        tol=None,
        relaxation=None,
    ):
        config = self.J["sizing"]

        n = int(max_iter or config["max_iter"])
        epsilon = float(tol or config["tol_rel"])
        alpha = float(
            relaxation or config["relaxation"]
        )

        if not 0 < alpha <= 1:
            raise ValueError(
                "relaxation must be in (0,1]"
            )

        state = dict(self.initial)
        hist = []
        reason = None
        converged = False

        for k in range(n):
            try:
                row = sizing_pass(self, state)

            except (
                SizingInfeasible,
                ValueError,
                ZeroDivisionError,
                OverflowError,
            ) as exc:
                reason = (
                    f"Iteration {k + 1}: {exc}"
                )
                break

            row["iteration"] = k + 1
            hist.append(row)

            if row["max_residual"] < epsilon:
                state = dict(row["proposed"])
                converged = True
                break

            state = {
                key: (
                    state[key]
                    + alpha
                    * (
                        row["proposed"][key]
                        - state[key]
                    )
                )
                for key in state
            }

        else:
            reason = (
                f"Maximum iterations reached ({n}), "
                "did not converge"
            )

        self._write_design(state)

        final = None
        final_error = None

        try:
            mission = self.mission.run(
                state["W_TO_lb"]
            )

            bd = self.weights.OEW_breakdown(
                state["W_TO_lb"]
            )

            closure = (
                state["W_TO_lb"]
                - bd["total"]
                - self.weights.payload()
                - mission["total_fuel_lb"]
            )

            buoyancy = self.hydro.buoyancy_screen(
                state["W_TO_lb"]
            )

            final = {
                "mission": mission,
                "OEW_breakdown_lb": bd,
                "payload_lb": self.weights.payload(),
                "mass_closure_residual_lb": closure,
                "wingspan_ft": self.geom.b,
                "CD0_reference_180kt": (
                    self.aero.drag_breakdown(
                        {
                            "alt_ft": 10000,
                            "ktas": 180,
                        }
                    )["CD0_total"]
                ),
                "buoyancy": buoyancy,
            }

            if (
                converged
                and abs(closure)
                > 2 * epsilon * state["W_TO_lb"]
            ):
                converged = False
                reason = (
                    "Final unrelaxed mass closure "
                    "did not satisfy tolerance"
                )

        except (MissionInfeasible, ValueError) as exc:
            final_error = str(exc)

            if converged:
                converged = False
                reason = (
                    "Final mission verification failed: "
                    + final_error
                )

        return {
            "status": (
                "NUMERICALLY_CONVERGED_PRELIMINARY_ONLY"
                if converged
                else "NOT_CONVERGED"
            ),
            "converged": converged,
            "failure_reason": reason,
            "final_mission_error": final_error,
            "iterations_completed": len(hist),
            "state": state,
            "history": hist,
            "final": final,
            "limitations": [
                "Water takeoff and landing distances not verified",
                "OEI drag and directional control not verified",
                "Battery thermal limits and engine maps not validated",
                "Float flooding and heel stability not verified",
                "Dock clearance, Sea State 3, FIKI and noise not verified",
                "Aircraft dimensions and component inputs are preliminary",
                "12500-lb weight is a team target, not an RFP maximum",
            ],
        }
