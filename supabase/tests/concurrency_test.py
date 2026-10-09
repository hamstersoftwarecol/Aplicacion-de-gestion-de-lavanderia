"""Behavioral concurrency checks against a disposable local PostgreSQL container."""
import concurrent.futures
import subprocess
import sys
import uuid

container = sys.argv[1]
def sql(query, check=True):
    p = subprocess.run(['docker', 'exec', '-i', container, 'psql', '-X', '-U', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1'], input=query, text=True, capture_output=True)
    if check and p.returncode:
        raise AssertionError(p.stderr)
    return p

def as_user(uid, query):
    return f"BEGIN; SET LOCAL ROLE authenticated; SET LOCAL request.jwt.claim.sub='{uid}'; {query}; COMMIT;"

a, b, c, svc = [str(uuid.uuid4()) for _ in range(4)]
sql(f"INSERT INTO auth.users VALUES ('{a}'),('{b}'); INSERT INTO profiles(id,name,role) VALUES ('{a}','A','admin'),('{b}','B','admin'); INSERT INTO clients(id,name,phone) VALUES ('{c}','Concurrency','123'); INSERT INTO services(id,name,unit,price_minor) VALUES ('{svc}','Wash','piece',1000);")
# Transactions overlap while the first holds the administrator lock.
queries = [as_user(a, f"SELECT set_profile_access('{a}','employee',false); SELECT pg_sleep(0.4)"), as_user(b, f"SELECT pg_sleep(0.1); SELECT set_profile_access('{b}','employee',false)")]
with concurrent.futures.ThreadPoolExecutor() as pool:
    results = list(pool.map(lambda q: sql(q,False), queries))
assert sorted(p.returncode == 0 for p in results) == [False,True], [p.stderr for p in results]
assert sql("SELECT count(*) FROM profiles WHERE role='admin' AND active").stdout.strip() == '1'
admin = sql("SELECT id FROM profiles WHERE role='admin' AND active").stdout.strip()
order = sql(as_user(admin, f"SELECT create_order('{c}',now()+interval '1 day','', '[{{\"service_id\":\"{svc}\",\"quantity\":1}}]')")).stdout.splitlines()[-2]
queries = [as_user(admin, f"SELECT record_payment('{order}',600,'cash',NULL,'{uuid.uuid4()}'); SELECT pg_sleep(0.2)") for _ in range(2)]
with concurrent.futures.ThreadPoolExecutor() as pool:
    results = list(pool.map(lambda q: sql(q,False),queries))
assert sorted(p.returncode == 0 for p in results)==[False,True], [p.stderr for p in results]
assert sql(f"SELECT sum(amount_minor) FROM payments WHERE order_id='{order}'").stdout.strip()=='600'
# Cancellation must serialize with payment and leave one consistent outcome.
order2 = sql(as_user(admin, f"SELECT create_order('{c}',now()+interval '1 day','', '[{{\"service_id\":\"{svc}\",\"quantity\":1}}]')")).stdout.splitlines()[-2]
queries=[as_user(admin,f"SELECT change_order_status('{order2}','received','cancelled'); SELECT pg_sleep(0.3)"),as_user(admin,f"SELECT pg_sleep(0.1); SELECT record_payment('{order2}',500,'cash',NULL,'{uuid.uuid4()}')")]
with concurrent.futures.ThreadPoolExecutor() as pool:
    results=list(pool.map(lambda q:sql(q,False),queries))
assert sorted(p.returncode==0 for p in results)==[False,True], [p.stderr for p in results]
assert sql(f"SELECT NOT(status='cancelled' AND EXISTS(SELECT 1 FROM payments WHERE order_id='{order2}')) FROM orders WHERE id='{order2}'").stdout.strip()=='t'
print('CONCURRENCY TESTS PASSED: last admin, overpayment, cancellation/payment')
