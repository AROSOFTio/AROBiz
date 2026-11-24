import os,tempfile,unittest
from cryptography.fernet import Fernet
tmp=tempfile.TemporaryDirectory()
os.environ['CROWN_DOCS_DB']=tmp.name+'/test.sqlite3'
os.environ['CROWN_DOCS_SESSION_KEY']='test-session-secret-not-production'
os.environ['CROWN_DOCS_BACKUP_KEY']=Fernet.generate_key().decode()
import server as s
from werkzeug.security import generate_password_hash
class Tests(unittest.TestCase):
    def setUp(self):
        with s.db() as db:
            for t in ['tokens','backups','usage','accounts']:db.execute('DELETE FROM '+t)
        s.limits.clear()
        self.c=s.app.test_client()
        self.base=s.API
    def register(self,n):
        r=self.c.post(self.base+'/register',json={'username':n,'password':'testing-only-passphrase'})
        self.assertEqual(r.status_code,201)
        return {'Authorization':'Bearer '+r.json['token']}
    def test_backup_isolation_encryption_delete(self):
        a=self.register('account_a');b=self.register('account_b')
        data={'profile':{'name':'Private company'},'documents':[{'id':'sample','kind':'invoice','notes':'Private text'}]}
        self.assertEqual(self.c.put(self.base+'/backup',json=data,headers=a).status_code,200)
        self.assertEqual(self.c.get(self.base+'/backup',headers=b).status_code,404)
        self.assertEqual(self.c.get(self.base+'/backup',headers=a).json['backup'],data)
        with s.db() as db:self.assertNotIn(b'Private text',db.execute('SELECT data FROM backups').fetchone()[0])
        self.assertEqual(self.c.delete(self.base+'/account',headers=a,json={'password':'wrong'}).status_code,401)
        self.assertEqual(self.c.delete(self.base+'/account',headers=a,json={'password':'testing-only-passphrase'}).status_code,200)
        self.assertEqual(self.c.get(self.base+'/backup',headers=a).status_code,401)
        with s.db() as db:self.assertEqual(db.execute('SELECT COUNT(*) FROM backups').fetchone()[0],0)
    def test_usage_is_anonymous_deduplicated_and_erasable(self):
        import uuid
        ins=str(uuid.uuid4());event={'id':str(uuid.uuid4()),'event':'document_generated','kind':'receipt'}
        data={'installation':ins,'events':[event]}
        for i in range(2):self.assertEqual(self.c.post(self.base+'/usage',json=data).status_code,200)
        with s.db() as db:
            row=db.execute('SELECT * FROM usage').fetchone()
            self.assertNotEqual(row['installation'],ins)
            self.assertEqual(db.execute('SELECT COUNT(*) FROM usage').fetchone()[0],1)
        bad={'installation':ins,'events':[dict(event,id=str(uuid.uuid4()),amount=100)]}
        self.assertEqual(self.c.post(self.base+'/usage',json=bad).status_code,400)
        self.assertEqual(self.c.delete(self.base+'/usage',json={'installation':ins}).status_code,200)
        with s.db() as db:self.assertEqual(db.execute('SELECT COUNT(*) FROM usage').fetchone()[0],0)
    def test_owner_separate_from_users(self):
        self.register('normaluser')
        with s.db() as db:db.execute("INSERT INTO accounts(username,password,role,created) VALUES(?,?,'owner',?)",('owner',generate_password_hash('owner-test-passphrase'),s.now()))
        self.assertEqual(self.c.post(self.base+'/login',json={'username':'owner','password':'owner-test-passphrase'}).status_code,401)
        self.assertIn(b'Owner sign in',self.c.get(s.ADMIN+'/').data)
        with self.c.session_transaction(path=s.ADMIN+'/',base_url='https://localhost') as ses:csrf=ses['csrf']
        self.assertEqual(self.c.post(s.ADMIN+'/',data={'username':'normaluser','password':'testing-only-passphrase','csrf':csrf}).status_code,200)
        self.assertEqual(self.c.post(s.ADMIN+'/',data={'username':'owner','password':'owner-test-passphrase','csrf':'invalid'}).status_code,403)
        self.assertEqual(self.c.post(s.ADMIN+'/',data={'username':'owner','password':'owner-test-passphrase','csrf':csrf}).status_code,302)
        s.downloads_cache[:]=[s.time.time(),12]
        page=self.c.get(s.ADMIN+'/').data
        self.assertIn(b'Usage overview',page);self.assertNotIn(b'Private text',page)
if __name__=='__main__':unittest.main()

