import json, subprocess, os, sys
# Run from a scratch folder (e.g. .data/): writes raw/*.json there. Re-runs skip files that exist.
API = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'api.sh')
os.makedirs('raw', exist_ok=True)
def api(p):
    out = subprocess.run([API, p], capture_output=True, text=True).stdout
    try: return json.loads(out)
    except Exception: return None
def save(name, p):
    f = f'raw/{name}.json'
    if os.path.exists(f): return json.load(open(f))
    d = api(p); json.dump(d, open(f,'w')); return d
teams = save('teams','competition-team/all?competition_id=25')['data']
save('standings','standings/competition/25/phase/183')
save('slider','schedule/game-slider/25')
for st in ['points','rebounds','assists','efficiency']:
    pass
save('rankings','player/average-rankings/25?phase_id=183')
games = {}
for t in teams:
    i = t['id']
    save(f'team_{i}', f'competition-team/find/{i}')
    save(f'roster_{i}', f'roster/team-players/{i}?competition_id=25')
    save(f'pavg_{i}', f'competition-team/player-averages/{i}')
    g = save(f'tgames_{i}', f'competition-team/statistics-by-game/total/{i}')
    for x in (g or {}).get('data', []): games[x['id']] = x['status']
for x in save('slider','')['data']: games[x['id']] = x['status']
print(len(games), sum(1 for s in games.values() if s=='finished'))
for gid, s in games.items():
    if s == 'finished':
        save(f'box_{gid}', f'boxscore/game/25/{gid}')
        save(f'ov_{gid}', f'schedule/overview/{gid}')
    save(f'game_{gid}', f'schedule/find/{gid}')
