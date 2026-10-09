"""Validate only public Supabase configuration before embedding it in the web bundle."""
import base64
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import urlsplit


def public_config(url: str, key: str) -> dict[str, str]:
    url, key = url.strip(), key.strip()
    if not url or not key:
        raise ValueError('Configura SUPABASE_URL y SUPABASE_ANON_KEY antes de publicar.')
    parsed = urlsplit(url)
    if (parsed.scheme != 'https' or not parsed.hostname or parsed.username
            or parsed.password or parsed.path not in ('', '/')
            or parsed.query or parsed.fragment):
        raise ValueError('SUPABASE_URL debe ser una URL HTTPS sin credenciales, rutas ni parámetros.')
    allowed = bool(re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]+', key))
    if not allowed and key.count('.') == 2:
        try:
            payload = key.split('.')[1]
            claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
            allowed = isinstance(claims, dict) and claims.get('role') == 'anon'
        except (ValueError, UnicodeDecodeError):
            allowed = False
    if not allowed:
        raise ValueError('Usa la clave publishable o anon; las claves administrativas no se pueden incluir en la web.')
    # This checks key TYPE, not authenticity. Hosted login must be tested separately.
    return {'SUPABASE_URL': url.rstrip('/'), 'SUPABASE_ANON_KEY': key}


def main() -> int:
    if len(sys.argv) != 2:
        print('Uso: python3 scripts/deployment_config.py ARCHIVO_TEMPORAL', file=sys.stderr)
        return 2
    try:
        config = public_config(os.environ.get('SUPABASE_URL', ''), os.environ.get('SUPABASE_ANON_KEY', ''))
        Path(sys.argv[1]).write_text(json.dumps(config), encoding='utf-8')
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1
    print('Configuración pública validada; no se han verificado credenciales contra Supabase.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
