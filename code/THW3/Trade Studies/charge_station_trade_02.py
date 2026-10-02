"""Plot 2: charger power versus time required to replenish battery energy.


"""
from pathlib import Path
import csv
import math
import sys
import webbrowser

# EDIT THESE VALUES. Energy targets are alternatives, not simultaneous demands.
ENERGY_TARGETS_KWH = [30.0, 60.0, 90.0]  # Stored battery energy to replace.
SHORE_TO_BATTERY_EFFICIENCY = 0.90
BATTERY_ACCEPTANCE_LIMIT_KW = 180.0  # Maximum DC battery input power.
NONCONNECTED_OVERHEAD_MIN = 10.0  # Assumed docking/connect/disconnect/departure time.
TURNAROUND_LIMIT_MIN = 30.0  # RFP requirement.
MAX_CHARGER_POWER_KW = 300
POWER_STEP_KW = 5
PLOT_MAX_TIME_MIN = 90.0
COLORS = ['#2563eb', '#059669', '#9333ea']
OUT = Path(__file__).resolve().parent


def charge_minutes(power_kw, energy_kwh):
    if power_kw <= 0:
        return math.inf  # Zero shore power cannot replenish a positive energy target.
    battery_input_kw = min(power_kw * SHORE_TO_BATTERY_EFFICIENCY,
                           BATTERY_ACCEPTANCE_LIMIT_KW)
    return 60.0 * energy_kwh / battery_input_kw


def turnaround_minutes(power_kw, energy_kwh):
    return NONCONNECTED_OVERHEAD_MIN + charge_minutes(power_kw, energy_kwh)


def minimum_charger_kw(energy_kwh):
    available = TURNAROUND_LIMIT_MIN - NONCONNECTED_OVERHEAD_MIN
    required_battery_kw = energy_kwh * 60.0 / available
    if required_battery_kw > BATTERY_ACCEPTANCE_LIMIT_KW:
        return None  # No charger power can overcome the assumed battery limit.
    return required_battery_kw / SHORE_TO_BATTERY_EFFICIENCY


def write_svg(powers):
    left, top, width, height = 100, 95, 750, 390
    x = lambda p: left + width * p / MAX_CHARGER_POWER_KW
    y = lambda t: top + height * (1 - t / PLOT_MAX_TIME_MIN)
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1020" height="740" viewBox="0 0 1020 740">',
             '<rect width="1020" height="740" fill="white"/>',
             f'<defs><clipPath id="plot"><rect x="{left}" y="{top}" width="{width}" height="{height}"/></clipPath></defs>',
             '<g font-family="Arial, sans-serif" fill="#172033">',
             '<text x="100" y="35" font-size="24">Dock charging power and estimated turnaround time</text>',
             '<text x="100" y="62" font-size="15">Illustrative energy targets; constant battery charge acceptance</text>']
    for i in range(7):
        p = MAX_CHARGER_POWER_KW * i / 6
        parts += [f'<path d="M{x(p):.2f},{top} V{top+height}" stroke="#e2e8f0"/>',
                  f'<text x="{x(p):.2f}" y="510" text-anchor="middle" font-size="14">{p:g}</text>']
    for i in range(7):
        t = PLOT_MAX_TIME_MIN * i / 6
        parts += [f'<path d="M{left},{y(t):.2f} H{left+width}" stroke="#e2e8f0"/>',
                  f'<text x="85" y="{y(t)+5:.2f}" text-anchor="end" font-size="14">{t:g}</text>']
    parts += [f'<path d="M{left},{top} V{top+height} H{left+width}" fill="none" stroke="#172033"/>',
              '<text x="475" y="545" text-anchor="middle" font-size="17">Shore charger rated power (kW)</text>',
              '<text x="30" y="290" transform="rotate(-90 30 290)" text-anchor="middle" font-size="17">Estimated turnaround time (minutes)</text>',
              f'<path d="M{left},{y(TURNAROUND_LIMIT_MIN):.2f} H{left+width}" stroke="#dc2626" stroke-width="2" stroke-dasharray="8 5"/>',
              f'<text x="{left+width+10}" y="{y(TURNAROUND_LIMIT_MIN)+5:.2f}" fill="#dc2626" font-size="13">RFP: {TURNAROUND_LIMIT_MIN:g} min</text>']
    for i, (energy, color) in enumerate(zip(ENERGY_TARGETS_KWH, COLORS)):
        points = ' '.join(f'{x(p):.2f},{y(turnaround_minutes(p, energy)):.2f}' for p in powers if p > 0)
        parts += [f'<polyline points="{points}" fill="none" stroke="{color}" stroke-width="3" clip-path="url(#plot)"/>',
                  f'<path d="M110,{578+i*24} h35" stroke="{color}" stroke-width="3"/>',
                  f'<text x="155" y="{583+i*24}" font-size="15">Replenish {energy:g} kWh of stored battery energy</text>']
    parts += [f'<text x="100" y="665" font-size="13">Assumed nonconnected overhead: {NONCONNECTED_OVERHEAD_MIN:g} min; efficiency: {SHORE_TO_BATTERY_EFFICIENCY:.0%}; battery input limit: {BATTERY_ACCEPTANCE_LIMIT_KW:g} kW.</text>',
              f'<text x="100" y="686" font-size="13">Zero power: replenishment infeasible. Times above {PLOT_MAX_TIME_MIN:g} minutes extend beyond the displayed axis.</text>',
              '<text x="100" y="707" font-size="13">Boarding/refueling must fit this timeline; charge taper and thermal derating may increase actual time.</text>',
              '</g></svg>']
    (OUT / 'charge_station_trade_02.svg').write_text('\n'.join(parts), encoding='utf-8')


def main():
    if not 0 < SHORE_TO_BATTERY_EFFICIENCY <= 1:
        raise ValueError('Charging efficiency must be in (0, 1].')
    if not 0 <= NONCONNECTED_OVERHEAD_MIN < TURNAROUND_LIMIT_MIN:
        raise ValueError('Overhead must leave some time for charging.')
    if (len(ENERGY_TARGETS_KWH) > len(COLORS) or not ENERGY_TARGETS_KWH
            or any(not math.isfinite(e) or e <= 0 for e in ENERGY_TARGETS_KWH)):
        raise ValueError('Choose one to three positive, finite energy targets.')
    if min(BATTERY_ACCEPTANCE_LIMIT_KW, MAX_CHARGER_POWER_KW, POWER_STEP_KW, PLOT_MAX_TIME_MIN) <= 0:
        raise ValueError('Power limits, step and plot time limit must be positive.')
    powers = list(range(0, MAX_CHARGER_POWER_KW + 1, POWER_STEP_KW))
    if powers[-1] != MAX_CHARGER_POWER_KW:
        powers.append(MAX_CHARGER_POWER_KW)
    with (OUT / 'charge_station_trade_02.csv').open('w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        writer.writerow(['charger_power_kw', 'energy_target_kwh', 'charging_minutes',
                         'estimated_turnaround_minutes', 'meets_30_min_limit'])
        for p in powers:
            for energy in ENERGY_TARGETS_KWH:
                charging = charge_minutes(p, energy)
                total = turnaround_minutes(p, energy)
                writer.writerow([p, energy, round(charging, 4) if p else 'infeasible',
                                 round(total, 4) if p else 'infeasible', total <= TURNAROUND_LIMIT_MIN])
    write_svg(powers)
    try:
        import matplotlib
        matplotlib.use('Agg')
        import matplotlib.pyplot as plt
    except ImportError:
        print('Generated SVG and CSV. Matplotlib not installed; PNG skipped.')
    else:
        fig, ax = plt.subplots(figsize=(10, 6))
        for energy, color in zip(ENERGY_TARGETS_KWH, COLORS):
            ax.plot(powers[1:], [turnaround_minutes(p, energy) for p in powers[1:]],
                    label=f'Replenish {energy:g} kWh', color=color, linewidth=2.5)
        ax.axhline(TURNAROUND_LIMIT_MIN, color='#dc2626', linestyle='--', label='RFP 30-minute limit')
        ax.set(xlabel='Shore charger rated power (kW)', ylabel='Estimated turnaround time (minutes)',
               title='Dock charging power and estimated turnaround time\nIllustrative assumptions',
               xlim=(0, MAX_CHARGER_POWER_KW), ylim=(0, PLOT_MAX_TIME_MIN))
        ax.grid(alpha=0.25)
        ax.legend()
        fig.text(0.5, 0.02, f'{NONCONNECTED_OVERHEAD_MIN:g} min nonconnected overhead; no charge taper; boarding/refueling assumed to fit timeline.', ha='center', fontsize=9)
        fig.tight_layout(rect=(0, 0.05, 1, 1))
        fig.savefig(OUT / 'charge_station_trade_02.png', dpi=200)
        plt.close(fig)
    for energy in ENERGY_TARGETS_KWH:
        threshold = minimum_charger_kw(energy)
        fastest = NONCONNECTED_OVERHEAD_MIN + 60 * energy / BATTERY_ACCEPTANCE_LIMIT_KW
        outcome = f'minimum charger {threshold:.1f} kW' if threshold is not None else 'cannot meet 30 min with assumed battery limit'
        print(f'{energy:g} kWh: {outcome}; theoretical minimum turnaround {fastest:.1f} min')
    print(f'Plot: {OUT / "charge_station_trade_02.svg"}')
    if '--show' in sys.argv:
        webbrowser.open((OUT / 'charge_station_trade_02.svg').as_uri())


if __name__ == '__main__':
    main()
