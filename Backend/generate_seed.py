"""Export the embedded weekday timetable without changing its stop times."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
source = (root / 'BusTimeApp/Shared/BusSchedule.swift').read_text()
names = {'mansion': 'コロンブスシティ', 'station': '海浜幕張駅', 'yokado': 'ヨーカドー前'}
variables = {'columbusCity': 'mansion', 'station': 'station', 'yokado': 'yokado'}
routes = [('mansionToStation', 'mansion', 'station'), ('stationToMansion', 'station', 'mansion'),
          ('mansionToYokado', 'mansion', 'yokado'), ('stationToYokado', 'station', 'yokado'),
          ('yokadoToMansion', 'yokado', 'mansion')]
seed = {'stops': [dict(id=identifier, name=names[identifier], latitude=lat, longitude=lon)
                  for identifier, lat, lon in [('mansion', 35.6589411, 140.0357708),
                                                ('station', 35.6485608, 140.0416924),
                                                ('yokado', 35.6569440, 140.0510100)]],
        'routes': [], 'schedules': [], 'buses': []}
shopping = re.findall(r'\(columbus: "(\d+:\d+)", station: "(\d+:\d+)", yokado: "(\d+:\d+)", columbusReturn: "(\d+:\d+)"\)', source)


def add(route_id, stops, note=None):
    seed['buses'].append(dict(id=route_id + '-' + stops[0][1].replace(':', '-'), route_id=route_id,
                             schedule_id=route_id + '-weekday',
                             stops=[dict(stop_id=stop, time=time) for stop, time in stops], note=note))


for case, origin, destination in routes:
    identifier = origin + '-' + destination
    seed['routes'].append(dict(id=identifier, name=names[origin] + ' → ' + names[destination],
                               origin_stop_id=origin, destination_stop_id=destination))
    for kind in ['weekday', 'weekend', 'holiday']:
        seed['schedules'].append(dict(id=identifier + '-' + kind, route_id=identifier,
                                      kind=kind, is_suspended=kind != 'weekday'))
    match = re.search(r'timetables\[\.' + case + r'\] = \[(.*?)\n    \]', source, re.S)
    if match:
        for departure, arrival, from_var, to_var in re.findall(
                r'directBus\("(\d+:\d+)", "(\d+:\d+)", from: (\w+), to: (\w+)\)', match[1]):
            add(identifier, [(variables[from_var], departure), (variables[to_var], arrival)])
    for columbus, station, yokado, returning in shopping:
        if case == 'mansionToStation':
            add(identifier, [('mansion', columbus), ('station', station)], 'お買い物便')
        elif case == 'stationToMansion':
            add(identifier, [('station', station), ('yokado', yokado), ('mansion', returning)], 'ヨーカドー経由')
        elif case == 'mansionToYokado':
            add(identifier, [('mansion', columbus), ('station', station), ('yokado', yokado)], '海浜幕張駅経由')
        elif case == 'stationToYokado':
            add(identifier, [('station', station), ('yokado', yokado)], 'お買い物便')
        else:
            add(identifier, [('yokado', yokado), ('mansion', returning)], 'お買い物便')

if len({bus['id'] for bus in seed['buses']}) != len(seed['buses']):
    raise RuntimeError('Duplicate trip IDs')
Path(__file__).with_name('seed.json').write_text(json.dumps(seed, ensure_ascii=False, indent=2) + '\n')
print(f'Exported {len(seed["buses"])} trips across {len(routes)} routes')
