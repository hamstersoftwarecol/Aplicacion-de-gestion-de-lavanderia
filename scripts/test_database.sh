#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
container="laundry-test-${RANDOM}-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$container" -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17 >/dev/null
ready=false
for attempt in {1..60}; do
 if docker exec "$container" pg_isready -h 127.0.0.1 -U postgres >/dev/null 2>&1; then ready=true; break; fi
 sleep 1
done
if [[ "$ready" != true ]]; then docker logs "$container"; exit 1; fi
run_sql() { docker exec -i "$container" psql -X -U postgres -v ON_ERROR_STOP=1 "$@"; }
run_sql < supabase/tests/bootstrap.sql >/dev/null
for migration in supabase/migrations/*.sql; do run_sql < "$migration" >/dev/null; done
for test in supabase/tests/*_test.sql; do run_sql < "$test"; done
python3 supabase/tests/concurrency_test.py "$container"
