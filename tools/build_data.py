import json, glob, os, subprocess, base64, datetime
J=lambda f: json.load(open(f))
teams_raw = J('raw/teams.json')['data']
stand = J('raw/standings.json')['data']
games_files = glob.glob('raw/game_*.json')
os.makedirs('img_dl', exist_ok=True); os.makedirs('img_sm', exist_ok=True)
def img(url, key, kind):
    if not url: return None
    src=f'img_dl/{key}.png'; dst=f'img_sm/{key}.png'
    if not os.path.exists(src): subprocess.run(['curl','-s','-A','Mozilla/5.0',url,'-o',src])
    if not os.path.exists(dst):
        if kind=='logo': subprocess.run(['sips','-Z','112',src,'--out',dst],capture_output=True)
        else: subprocess.run(['sips','-Z','140',src,'--out',dst],capture_output=True)
    if not os.path.exists(dst): return None
    return "data:image/png;base64,"+base64.b64encode(open(dst,'rb').read()).decode()
IMG={}
def short_stats(s):
    keys=['minute','points','two_point_made','two_point_all','three_point_made','three_point_all','throw_made','throw_all','free_throw_made','free_throw_all','offensive_rebound','defensive_rebound','total_rebound','assist','steal','block','turnover','foul','value','plusminus']
    return [round(s.get(k) or 0,2) for k in keys]
STATKEYS=['min','pts','2pm','2pa','3pm','3pa','fgm','fga','ftm','fta','oreb','dreb','reb','ast','stl','blk','tov','pf','val','pm']
teams={}
for t in teams_raw:
    i=t['id']; td=J(f'raw/team_{i}.json')['data']
    IMG[f't{i}']=img(t['team_logo']['thumbnails'].get('small') or t['team_logo']['public_url'], f't{i}','logo')
    teams[i]=dict(id=i,name=t['name'],short=t['short_name'],country='BE' if t['club']['name']=='Belgium' else 'NL',ticket=t['ticket_url'],stats=td.get('statistics'),arena=None)
st=[]
for r in stand:
    st.append(dict(team=r['team']['id'],pos=r['position'],w=r['win'],l=r['loss'],pf=r['score'],pa=r['against'],diff=r['score_difference'],pts=r['point'],pct=r['percent'],home=r['win_loss']['home'],away=r['win_loss']['away'],streak=('W' if r['streak']['is_win'] else 'L')+str(r['streak']['count'])))
players={}
for t in teams_raw:
    i=t['id']
    for p in J(f'raw/roster_{i}.json')['data']:
        pl=p['player']; pid=pl['id']
        pi=pl.get('profile_image') or {}
        IMG[f'p{pid}']=img((pi.get('thumbnails') or {}).get('small') or pi.get('public_url'), f'p{pid}','photo')
        players[pid]=dict(id=pid,rid=p['id'],team=i,first=pl['first_name'],last=pl['last_name'],num=p['jersey'],pos=(p['player_position'] or {}).get('name'),h=p['height'],w=p['weight'],dob=pl['birthdate'],nat=pl['nationality_code'],avg=None,gp=0,log=[])
    for a in J(f'raw/pavg_{i}.json')['data']:
        pid=a['player']['id']
        if pid in players: players[pid]['avg']=short_stats(a); players[pid]['gp']=a['played_games']
        else: print('pavg miss',pid)
games=[]
for f in games_files:
    g=J(f)['data']; c=sorted(g['competitors'],key=lambda c:c['side'])
    gid=g['id']
    gm=dict(id=gid,t=g['game_time'],status=g['status'],home=c[0]['competition_team']['id'],away=c[1]['competition_team']['id'],hs=c[0]['finalScore'],as_=c[1]['finalScore'],hq=[p['score'] for p in c[0].get('period_scores') or []],aq=[p['score'] for p in c[1].get('period_scores') or []],arena=(g.get('arena') or {}).get('name'),box=None,refs=[r.get('name') if isinstance(r,dict) else r for r in g.get('referees') or []])
    if gm['arena'] and not teams[gm['home']]['arena']: teams[gm['home']]['arena']=gm['arena']
    if os.path.exists(f'raw/box_{gid}.json'):
        box={}
        for side in J(f'raw/box_{gid}.json')['data']:
            tid=side['team']['id']; rows=[]
            for p in side['players']:
                pid=p['player']['id']
                rows.append([pid,1 if p['starter'] else 0]+short_stats(p))
                if pid in players: players[pid]['log'].append(gid)
                else:
                    players[pid]=dict(id=pid,rid=p['roster_id'],team=tid,first=p['player']['first_name'],last=p['player']['last_name'],num=str(p.get('jersey') or ''),pos=None,h=None,w=None,dob=p['player']['birthdate'],nat=p['player']['nationality_code'],avg=None,gp=0,log=[gid],inactive=True)
            box[tid]=dict(players=rows,total=short_stats(side['total']))
        gm['box']=box
    games.append(gm)
games.sort(key=lambda g:g['t'])
# rounds: assign by date clusters (each team plays once per round)
rnd=0; seen=set()
for g in games:
    if g['home'] in seen or g['away'] in seen or rnd==0: rnd+=1; seen=set()
    seen|={g['home'],g['away']}; g['round']=rnd
r=J('raw/rankings.json'); rid2pid={p['rid']:p['id'] for p in players.values()}
leaders={k:[[rid2pid.get(x['roster_id'],x['player']['id']),x['value']] for x in v[:25]] for k,v in r.items()}
data=dict(season='2026-27',phase='Regular season 2026-27',asOf='2026-11-03',statKeys=STATKEYS,teams=list(teams.values()),standings=st,players=list(players.values()),games=games,leaders=leaders)
for g in games: g['as']=g.pop('as_')
open('data.js','w').write('window.BNXT='+json.dumps(data,separators=(',',':'))+';\nwindow.IMG='+json.dumps({k:v for k,v in IMG.items() if v},separators=(',',':'))+';')
print('teams',len(teams),'players',len(players),'games',len(games),'rounds',rnd, 'size',os.path.getsize('data.js'))
