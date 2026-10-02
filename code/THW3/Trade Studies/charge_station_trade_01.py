"""Plot 1: dock charger power versus hybrid generator fuel displaced.
"""

from pathlib import Path
import csv
import math
from html import escape


# EDIT THESE ASSUMPTIONS as your team's design becomes available.
CONNECTED_MINUTES = 20.0  # Actual plugged-in time, not the full turnaround time.
SHORE_TO_BATTERY_EFFICIENCY = 0.90
BATTERY_TO_BUS_EFFICIENCY = 0.95
GENERATOR_FUEL_TO_BUS_EFFICIENCY = 0.30  # Includes engine and generator losses.
FUEL_LOWER_HEATING_VALUE_KWH_PER_KG = 11.9  # Illustrative liquid-fuel LHV.
USABLE_BATTERY_CAPACITY_KWH = 120.0  # After protected reserve/SOC limits.
BATTERY_ACCEPTANCE_LIMIT_KW = 180.0  # DC input; constant approximation.
DEPLETED_HEADROOM_PER_STOP_KWH = 60.0
DISPLACEABLE_GENERATOR_ENERGY_PER_STOP_KWH = 60.0  # Delivered electrical bus energy.
MAX_CHARGER_POWER_KW = 300
POWER_STEP_KW = 5

# One repeatable round trip: base -> destination -> base.
# Charge at the base between cycles and optionally at the destination.
# Same beginning/end SOC and same flight duty in all cases. No free initial charge.
# Both stops are assumed identical. Asymmetric missions require separate stop models.
CASES = [("No dock charging", 0, "#64748b"),
         ("Home base only", 1, "#2563eb"),
         ("Both endpoints", 2, "#059669")]
OUT = Path(__file__).resolve().parent


def fuel_saved_kg(charger_kw, charging_stops):
    """Generator fuel displaced per round trip, compared with zero shore charge."""
    time_hours = CONNECTED_MINUTES / 60.0
    stored_kwh = min(
        charger_kw * SHORE_TO_BATTERY_EFFICIENCY * time_hours,
        BATTERY_ACCEPTANCE_LIMIT_KW * time_hours,
        DEPLETED_HEADROOM_PER_STOP_KWH,
        USABLE_BATTERY_CAPACITY_KWH,
    )
    displaced_bus_kwh = min(stored_kwh * BATTERY_TO_BUS_EFFICIENCY,
                             DISPLACEABLE_GENERATOR_ENERGY_PER_STOP_KWH)
    return charging_stops * displaced_bus_kwh / (
        GENERATOR_FUEL_TO_BUS_EFFICIENCY * FUEL_LOWER_HEATING_VALUE_KWH_PER_KG)


def validate():
    positive = [CONNECTED_MINUTES, GENERATOR_FUEL_TO_BUS_EFFICIENCY,
                FUEL_LOWER_HEATING_VALUE_KWH_PER_KG, USABLE_BATTERY_CAPACITY_KWH,
                BATTERY_ACCEPTANCE_LIMIT_KW, DEPLETED_HEADROOM_PER_STOP_KWH,
                DISPLACEABLE_GENERATOR_ENERGY_PER_STOP_KWH]
    if any(not math.isfinite(v) or v <= 0 for v in positive):
        raise ValueError("Energy, time, power, LHV, and generator efficiency must be positive.")
    for efficiency in [SHORE_TO_BATTERY_EFFICIENCY, BATTERY_TO_BUS_EFFICIENCY,
                       GENERATOR_FUEL_TO_BUS_EFFICIENCY]:
        if not 0 < efficiency <= 1:
            raise ValueError("Efficiencies must lie in (0, 1].")
    if not 0 < CONNECTED_MINUTES <= 30:
        raise ValueError("Connected time must fit within the RFP's 30-minute turnaround.")
    if MAX_CHARGER_POWER_KW <= 0 or POWER_STEP_KW <= 0:
        raise ValueError("Power range and step must be positive integers.")


def write_svg(powers):
    """Dependency-free vector plot so the script also runs without matplotlib."""
    left, top, width, height = 100, 90, 750, 365
    ymax = max(5, math.ceil(fuel_saved_kg(MAX_CHARGER_POWER_KW, 2) / 5) * 5)
    x = lambda p: left + width * p / MAX_CHARGER_POWER_KW
    y = lambda v: top + height * (1 - v / ymax)
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="670" viewBox="0 0 1000 670">',
             '<rect width="1000" height="670" fill="white"/>',
             '<g font-family="Arial, sans-serif" fill="#172033">',
             '<text x="100" y="35" font-size="24">Dock charging and hybrid generator fuel savings</text>',
             '<text x="100" y="61" font-size="15">Illustrative assumptions | repeatable round trip | equal start and end battery SOC</text>']
    for i in range(7):
        p = MAX_CHARGER_POWER_KW * i / 6
        parts += [f'<path d="M{x(p):.2f},{top} V{top+height}" stroke="#e2e8f0"/>',
                  f'<text x="{x(p):.2f}" y="480" text-anchor="middle" font-size="14">{p:g}</text>']
    for i in range(6):
        v = ymax * i / 5
        parts += [f'<path d="M{left},{y(v):.2f} H{left+width}" stroke="#e2e8f0"/>',
                  f'<text x="85" y="{y(v)+5:.2f}" text-anchor="end" font-size="14">{v:g}</text>']
    parts += [f'<path d="M{left},{top} V{top+height} H{left+width}" fill="none" stroke="#172033"/>',
              '<text x="475" y="514" text-anchor="middle" font-size="17">Shore charger rated power (kW)</text>',
              '<text x="30" y="275" transform="rotate(-90 30 275)" text-anchor="middle" font-size="17">Generator fuel saved (kg per round trip)</text>']
    for i, (name, stops, color) in enumerate(CASES):
        points = ' '.join(f'{x(p):.2f},{y(fuel_saved_kg(p, stops)):.2f}' for p in powers)
        parts += [f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="3"/>',
                  f'<path d="M110,{548+i*24} h35" stroke="{color}" stroke-width="3"/>',
                  f'<text x="155" y="{553+i*24}" font-size="15">{escape(name)}</text>']
    note = f'{CONNECTED_MINUTES:g} min connected/stop; shore efficiency {SHORE_TO_BATTERY_EFFICIENCY:.0%}; battery-to-bus {BATTERY_TO_BUS_EFFICIENCY:.0%}; generator efficiency {GENERATOR_FUEL_TO_BUS_EFFICIENCY:.0%}'
    parts += [f'<text x="100" y="635" font-size="13">{escape(note)}</text>',
              '<text x="100" y="655" font-size="13">Fuel savings only; shore electricity cost, infrastructure cost, battery aging, and aircraft resizing excluded.</text>',
              '</g></svg>']
    (OUT / 'charge_station_trade_01.svg').write_text('\n'.join(parts), encoding='utf-8')


def main():
    validate()
    powers = list(range(0, MAX_CHARGER_POWER_KW + 1, POWER_STEP_KW))
    if powers[-1] != MAX_CHARGER_POWER_KW:
        powers.append(MAX_CHARGER_POWER_KW)
    with (OUT / 'charge_station_trade_01.csv').open('w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        writer.writerow(['charger_power_kw'] + [name + '_fuel_saved_kg_per_round_trip' for name, _, _ in CASES])
        for p in powers:
            writer.writerow([p] + [round(fuel_saved_kg(p, n), 5) for _, n, _ in CASES])
    write_svg(powers)
    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
    except ImportError:
        print('Matplotlib unavailable: generated SVG plot and CSV with no extra dependencies.')
    else:
        fig, ax = plt.subplots(figsize=(10, 6))
        for name, stops, color in CASES:
            ax.plot(powers, [fuel_saved_kg(p, stops) for p in powers], label=name, color=color, linewidth=2.5)
        ax.set(xlabel='Shore charger rated power (kW)', ylabel='Generator fuel saved (kg per round trip)',
               title='Dock charging and hybrid generator fuel savings\nIllustrative assumptions; equal start/end battery SOC',
               xlim=(0, MAX_CHARGER_POWER_KW), ylim=(0, None))
        ax.grid(alpha=0.25)
        ax.legend()
        fig.text(0.5, 0.02, f'{CONNECTED_MINUTES:g} min connected per stop; fuel savings exclude electricity and infrastructure costs.', ha='center', fontsize=9)
        fig.tight_layout(rect=(0, 0.05, 1, 1))
        fig.savefig(OUT / 'charge_station_trade_01.png', dpi=200)
        plt.close(fig)
    for p in [0, 50, 100, 150, 200, 300]:
        print(f'{p:3d} kW: base only {fuel_saved_kg(p, 1):6.2f} kg; both endpoints {fuel_saved_kg(p, 2):6.2f} kg saved/round trip')
    print(f'Outputs: {OUT}')
    print('Plateaus reflect assumed battery acceptance, headroom, or displaceable generator energy limits.')
    print('This model does not establish no-charge mission feasibility, reserve compliance, or net cost savings.')


if __name__ == '__main__':
    main()
