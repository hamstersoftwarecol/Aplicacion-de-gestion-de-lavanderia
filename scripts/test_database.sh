#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
container="laundry-test-${RANDOM}-$$"
trap 'docker rm -f "$container" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$container" -e POSTGRES_HOST_AUTH_METHOD=trust postgres:17 >/dev/null
for attempt in {1..30}; do
 if docker exec "$container" pg_isready -U postgres >/dev/null 2>&1; then break; fi
 sleep 1
done
run_sql() { docker exec -i "$container" psql -X -U postgres -v ON_ERROR_STOP=1 "$@"; }
run_sql < supabase/tests/bootstrap.sql >/dev/null
for migration in supabase/migrations/*.sql; do run_sql < "$migration" >/dev/null; done
for test in supabase/tests/*_test.sql; do run_sql < "$test"; done
python3 supabase/tests/concurrency_test.py "$container"
