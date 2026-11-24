import os, sqlite3, re, json, secrets, hashlib, time, hmac
from datetime import datetime, timezone, timedelta
from collections import defaultdict, deque
from threading import Lock
from urllib.request import urlopen, Request
from flask import Flask, request, jsonify, session, redirect, render_template_string, abort
from werkzeug.security import generate_password_hash, check_password_hash
from cryptography.fernet import Fernet

ROOT = '/business-docs'
API = ROOT + '/api/v1'
ADMIN = ROOT + '/admin'
DB = os.environ.get('CROWN_DOCS_DB', '/var/lib/crown-docs/data.sqlite3')
app = Flask(__name__)
app.config.update(SECRET_KEY=os.environ['CROWN_DOCS_SESSION_KEY'], MAX_CONTENT_LENGTH=8*1024*1024,
 SESSION_COOKIE_NAME='crown_docs_owner', SESSION_COOKIE_SECURE=True, SESSION_COOKIE_HTTPONLY=True,
 SESSION_COOKIE_SAMESITE='Strict', SESSION_COOKIE_PATH=ADMIN, PERMANENT_SESSION_LIFETIME=timedelta(hours=8))
cipher = Fernet(os.environ['CROWN_DOCS_BACKUP_KEY'].encode())
EVENTS = {'app_open','document_generated','document_saved','share_requested','print_requested'}
KINDS = {'invoice','receipt','quotation','proforma','purchaseOrder','deliveryNote','creditNote','debitNote','paymentVoucher','statement','letter'}
limits = defaultdict(deque)
lock = Lock()
def db():
    c=sqlite3.connect(DB,timeout=15)
    c.row_factory=sqlite3.Row
    c.execute('PRAGMA foreign_keys=ON')
    return c
def now(): return int(time.time())
def date(): return datetime.now(timezone.utc).date().isoformat()
def digest(s): return hashlib.sha256(s.encode()).hexdigest()
def init():
    with db() as c:
        c.executescript("""
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS accounts(id INTEGER PRIMARY KEY,username TEXT NOT NULL UNIQUE,password TEXT NOT NULL,role TEXT NOT NULL DEFAULT 'user',created INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS tokens(hash TEXT PRIMARY KEY,user_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,expires INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS backups(user_id INTEGER PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,data BLOB NOT NULL,updated INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS usage(id TEXT PRIMARY KEY,installation TEXT NOT NULL,day TEXT NOT NULL,event TEXT NOT NULL,kind TEXT NOT NULL);
        CREATE INDEX IF NOT EXISTS usage_day ON usage(day,event);
        CREATE INDEX IF NOT EXISTS usage_install ON usage(installation);
        """)
init()
def prune(c):
    c.execute('DELETE FROM usage WHERE day < ?',((datetime.now(timezone.utc)-timedelta(days=90)).date().isoformat(),))
    c.execute('DELETE FROM tokens WHERE expires <= ?',(now(),))
def rate(bucket,n,window):
    # nginx supplies the validated connection address. No raw addresses in the analytics DB.
    address=request.headers.get('X-Real-IP',request.remote_addr or '')
    key=bucket+':'+hmac.new(app.secret_key.encode(),address.encode(),hashlib.sha256).hexdigest()
    t=time.monotonic()
    with lock:
        if len(limits)>10000:
            for k in list(limits):
                if not limits[k] or t-limits[k][-1]>3600: limits.pop(k,None)
        if len(limits)>20000: abort(429)
        q=limits[key]
        while q and t-q[0]>window:q.popleft()
        if len(q)>=n:abort(429)
        q.append(t)
def body():
    val=request.get_json(silent=True)
    if not isinstance(val,dict):abort(400)
    return val
def token_for(c,uid):
    token=secrets.token_urlsafe(32)
    c.execute('INSERT INTO tokens VALUES(?,?,?)',(digest(token),uid,now()+30*86400))
    return token
def user():
    auth=request.headers.get('Authorization','')
    if not auth.startswith('Bearer ') or len(auth)>200:abort(401)
    with db() as c:
        row=c.execute("SELECT a.* FROM accounts a JOIN tokens t ON a.id=t.user_id WHERE t.hash=? AND t.expires>? AND a.role='user'",(digest(auth[7:]),now())).fetchone()
    if not row:abort(401)
    return row
def credentials(data):
    name=data.get('username','');password=data.get('password','')
    if not isinstance(name,str) or not isinstance(password,str):abort(400)
    name=name.strip().lower()
    if not re.fullmatch(r'[a-z0-9._-]{3,32}',name) or not 12<=len(password)<=128:abort(400)
    return name,password
@app.errorhandler(400)
@app.errorhandler(401)
@app.errorhandler(403)
@app.errorhandler(404)
@app.errorhandler(409)
@app.errorhandler(413)
@app.errorhandler(429)
def error(e):
    return jsonify(error={400:'Invalid request or account details',401:'Sign in or check credentials',403:'Access denied',404:'Not found',409:'Account already exists',413:'Backup is too large',429:'Too many requests; try later',507:'Cloud backup capacity reached. Local documents are unaffected.'}[e.code]),e.code
@app.after_request
def headers(r):
    r.headers['Cache-Control']='no-store'
    r.headers['X-Content-Type-Options']='nosniff'
    r.headers['Referrer-Policy']='no-referrer'
    r.headers['X-Frame-Options']='DENY'
    r.headers['Content-Security-Policy']="default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'"
    return r
@app.get(API+'/health')
def health():return jsonify(status='ok')
@app.post(API+'/register')
def register():
    rate('register',6,3600)
    name,password=credentials(body())
    if name in {'owner','admin','administrator','root','support'}:abort(409)
    try:
        with db() as c:
            cur=c.execute("INSERT INTO accounts(username,password,role,created) VALUES(?,?,'user',?)",(name,generate_password_hash(password),now()))
            token=token_for(c,cur.lastrowid)
    except sqlite3.IntegrityError:abort(409)
    return jsonify(token=token,username=name),201
@app.post(API+'/login')
def login():
    rate('login',12,900)
    name,password=credentials(body())
    with db() as c:
        prune(c)
        row=c.execute("SELECT * FROM accounts WHERE username=? AND role='user'",(name,)).fetchone()
        if not row or not check_password_hash(row['password'],password):abort(401)
        token=token_for(c,row['id'])
    return jsonify(token=token,username=name)
@app.post(API+'/logout')
def logout():
    user()
    with db() as c:c.execute('DELETE FROM tokens WHERE hash=?',(digest(request.headers['Authorization'][7:]),))
    return jsonify(ok=True)
@app.delete(API+'/account')
def delete_account():
    rate('delete',8,900);a=user()
    password=body().get('password','')
    if not isinstance(password,str) or len(password)>128 or not check_password_hash(a['password'],password):abort(401)
    with db() as c:c.execute('DELETE FROM accounts WHERE id=?',(a['id'],))
    return jsonify(ok=True)
@app.put(API+'/backup')
def backup_put():
    rate('backup',30,3600);a=user();data=body()
    if not isinstance(data.get('profile'),dict) or not isinstance(data.get('documents'),list) or len(data['documents'])>5000:abort(400)
    if not all(isinstance(d,dict) and isinstance(d.get('id'),str) and isinstance(d.get('kind'),str) and d.get('kind') in KINDS for d in data['documents']):abort(400)
    encrypted=cipher.encrypt(json.dumps(data,separators=(',',':'),ensure_ascii=False).encode())
    with db() as c:
        c.execute('BEGIN IMMEDIATE')
        size=c.execute('SELECT COALESCE(SUM(length(data)),0) FROM backups WHERE user_id<>?',(a['id'],)).fetchone()[0]
        if size+len(encrypted)>1024*1024*1024:return jsonify(error="Cloud backup capacity reached. Local documents are unaffected."),507
        c.execute('INSERT INTO backups VALUES(?,?,?) ON CONFLICT(user_id) DO UPDATE SET data=excluded.data,updated=excluded.updated',(a['id'],encrypted,now()))
    return jsonify(ok=True,documents=len(data['documents']))
@app.get(API+'/backup')
def backup_get():
    rate('backupread',30,3600);a=user()
    with db() as c:row=c.execute('SELECT data,updated FROM backups WHERE user_id=?',(a['id'],)).fetchone()
    if not row:abort(404)
    return jsonify(backup=json.loads(cipher.decrypt(row['data'])),updated=row['updated'])
@app.delete(API+'/backup')
def backup_delete():
    a=user()
    with db() as c:c.execute('DELETE FROM backups WHERE user_id=?',(a['id'],))
    return jsonify(ok=True)
def valid_id(v):return isinstance(v,str) and re.fullmatch(r'[a-f0-9-]{36}',v)
@app.post(API+'/usage')
def usage():
    rate('usage',180,3600);data=body();installation=data.get('installation');events=data.get('events')
    if not valid_id(installation) or not isinstance(events,list) or not 1<=len(events)<=100:abort(400)
    rows=[]
    for e in events:
        if not isinstance(e,dict) or not valid_id(e.get('id')) or not isinstance(e.get('event'),str) or e.get('event') not in EVENTS or not isinstance(e.get('kind',''),str) or e.get('kind','') not in KINDS|{''}:abort(400)
        if set(e)-{'id','event','kind'}:abort(400)
        rows.append((e['id'],digest(installation),date(),e['event'],e.get('kind','')))
    with db() as c:
        prune(c)
        c.executemany('INSERT OR IGNORE INTO usage VALUES(?,?,?,?,?)',rows)
    return jsonify(ok=True)
@app.delete(API+'/usage')
def usage_delete():
    rate('usage-delete',12,3600);installation=body().get('installation')
    if not valid_id(installation):abort(400)
    with db() as c:c.execute('DELETE FROM usage WHERE installation=?',(digest(installation),))
    return jsonify(ok=True)
def owner():
    uid=session.get('owner')
    if not isinstance(uid,int):return None
    with db() as c:return c.execute("SELECT id FROM accounts WHERE id=? AND role='owner'",(uid,)).fetchone()
def csrf():
    token=session.get('csrf')
    if not token or not hmac.compare_digest(str(token),request.form.get('csrf','')):abort(403)
def form_token():
    if 'csrf' not in session:session['csrf']=secrets.token_urlsafe(32)
    return session['csrf']
PAGE="""<!doctype html><html lang=en><head><meta charset=utf-8><meta name=viewport content="width=device-width, initial-scale=1"><title>Crown Business Docs | Owner</title><style>
*{box-sizing:border-box}body{font:15px system-ui,sans-serif;margin:0;color:#171717;background:#fafafa}main{max-width:1050px;margin:auto;padding:28px 20px}h1{font-size:30px;letter-spacing:-1px}p{color:#555;line-height:1.55}header{display:flex;justify-content:space-between;align-items:center;gap:10px;border-bottom:1px solid #ddd}form{margin:0}input,button{font:inherit;padding:12px;border:1px solid #ccc;border-radius:6px}input{width:100%;margin:6px 0 14px}button{background:#171717;color:white;cursor:pointer}label{font-weight:600}.login{max-width:400px;margin:36px auto;background:white;border:1px solid #ddd;padding:24px;border-radius:10px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(155px,1fr));gap:12px}.card{background:white;border:1px solid #ddd;border-radius:9px;padding:16px}.value{font-size:28px;font-weight:750;margin-top:8px}.note{font-size:13px;color:#555}table{border-collapse:collapse;width:100%;background:white}th,td{text-align:left;padding:12px;border-bottom:1px solid #ddd}th{background:#f1f1f1}a{color:#171717}</style></head><body><main>
<header><strong>Crown Business Docs · Owner</strong>{% if stats %}<form method=post action="{{admin}}/logout"><input type=hidden name=csrf value="{{csrf}}"><button>Sign out</button></form>{% endif %}</header>
{% if not stats %}<div class=login><h1>Owner sign in</h1><p>Private analytics dashboard.</p>{% if error %}<p role=alert>{{error}}</p>{% endif %}<form method=post><input type=hidden name=csrf value="{{csrf}}"><label>Username</label><input name=username autocomplete=username required><label>Password</label><input name=password type=password autocomplete=current-password required><button>Sign in</button></form></div>
{% else %}<h1>Usage overview</h1><p>Reports received in the last 30 days. Only opted-in installations. Registered accounts and backup accounts are current totals. Share and print counts are requests, not confirmed deliveries.</p><div class=grid>{% for label,n in stats %}<div class=card><div>{{label}}</div><div class=value>{{n}}</div></div>{% endfor %}</div><h2>Documents generated by type</h2><table><thead><tr><th>Document type</th><th>Generated</th></tr></thead><tbody>{% for row in kinds %}<tr><td>{{row[0]}}</td><td>{{row[1]}}</td></tr>{% endfor %}</tbody></table><h2>Downloads</h2><p>GitHub Crown Business Docs APK downloads: {{downloads}} (not unique installs). Google Play installation totals remain separate in Play Console.</p><p class=note>No names, PDF contents, prices, client addresses or contacts are collected in usage analytics. Backups are account-scoped and never shown here.</p>{% endif %}</main></body></html>"""
downloads_cache=[0,None]
def downloads():
    if time.time()-downloads_cache[0]<900:return downloads_cache[1] if downloads_cache[1] is not None else 'Unavailable'
    try:
        total=0
        for page in range(1,11):
            url='https://api.github.com/repos/AROSOFTio/AROBiz/releases?per_page=100&page='+str(page)
            with urlopen(Request(url,headers={'User-Agent':'CrownDocsOwner'}),timeout=4) as response:releases=json.load(response)
            total+=sum(a['download_count'] for r in releases for a in r.get('assets',[]) if a.get('name','')=='Crown-Business-Docs.apk')
            if len(releases)<100:break
        downloads_cache[:]=[time.time(),total]
    except Exception:
        downloads_cache[0]=time.time()
    return downloads_cache[1] if downloads_cache[1] is not None else 'Unavailable'
@app.route(ADMIN+'/',methods=['GET','POST'])
def dashboard():
    err=''
    if request.method=='POST':
        rate('owner',8,900);csrf()
        name=request.form.get('username','').lower().strip();pw=request.form.get('password','')
        with db() as c:row=c.execute("SELECT * FROM accounts WHERE username=? AND role='owner'",(name,)).fetchone()
        if row and len(pw)<=128 and check_password_hash(row['password'],pw):
            session.clear();session['owner']=row['id'];session.permanent=True
            return redirect(ADMIN+'/')
        err='Incorrect credentials.'
    if not owner():return render_template_string(PAGE,stats=None,csrf=form_token(),error=err,admin=ADMIN)
    start=(datetime.now(timezone.utc)-timedelta(days=29)).date().isoformat()
    with db() as c:
        prune(c)
        count={r[0]:r[1] for r in c.execute('SELECT event,COUNT(*) FROM usage WHERE day>=? GROUP BY event',(start,))}
        stats=[('Active opted-in installations',c.execute('SELECT COUNT(DISTINCT installation) FROM usage WHERE day>=?',(start,)).fetchone()[0]),('App opens',count.get('app_open',0)),('Documents generated',count.get('document_generated',0)),('Documents saved',count.get('document_saved',0)),('Share requests',count.get('share_requested',0)),('Print requests',count.get('print_requested',0)),('Registered accounts',c.execute("SELECT COUNT(*) FROM accounts WHERE role='user'").fetchone()[0]),('Accounts with backup',c.execute('SELECT COUNT(*) FROM backups').fetchone()[0])]
        kinds=list(c.execute("SELECT kind,COUNT(*) FROM usage WHERE day>=? AND event='document_generated' GROUP BY kind ORDER BY COUNT(*) DESC",(start,)))
    return render_template_string(PAGE,stats=stats,kinds=kinds,downloads=downloads(),csrf=form_token(),admin=ADMIN)
@app.post(ADMIN+'/logout')
def owner_logout():
    csrf();session.clear();return redirect(ADMIN+'/')
if __name__=='__main__':
    import sys,getpass
    if sys.argv[1:]==['maintenance']:
        with db() as c:prune(c)
        raise SystemExit(0)
    if len(sys.argv)!=3 or sys.argv[1]!='create-admin':raise SystemExit('Usage: server.py create-admin USERNAME | maintenance')
    name=sys.argv[2].lower()
    if not re.fullmatch(r'[a-z0-9._-]{3,32}',name):raise SystemExit('Invalid username')
    pw=getpass.getpass('New owner password (12+ characters): ')
    if not 12<=len(pw)<=128 or pw!=getpass.getpass('Confirm password: '):raise SystemExit('Passwords invalid or do not match')
    with db() as c:
        if c.execute('SELECT 1 FROM accounts WHERE username=?',(name,)).fetchone():raise SystemExit('Username already exists')
        c.execute("INSERT INTO accounts(username,password,role,created) VALUES(?,?,'owner',?)",(name,generate_password_hash(pw),now()))
    print('Owner account created.')

