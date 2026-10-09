"""Synthetic public-key fixtures; these values do not authenticate to a service."""
import base64
import json
import unittest
from scripts.deployment_config import public_config

def jwt_fixture(role):
    payload=base64.urlsafe_b64encode(json.dumps({'role':role}).encode()).decode().rstrip('=')
    return 'testheader.'+payload+'.testsignature'

class DeploymentConfigTest(unittest.TestCase):
    def test_missing_configuration_cannot_build_deployment(self):
        for url,key in [('', ''),('https://example.supabase.co','')]:
            with self.assertRaises(ValueError):public_config(url,key)

    def test_public_keys_are_supported(self):
        for key in ['sb_publishable_SYNTHETIC_PUBLIC_TEST_KEY',jwt_fixture('anon')]:
            self.assertEqual(public_config('https://example.supabase.co/',key),{'SUPABASE_URL':'https://example.supabase.co','SUPABASE_ANON_KEY':key})

    def test_administrative_and_malformed_keys_are_rejected_without_echo(self):
        for key in ['sb_secret_SYNTHETIC_SECRET_TEST_KEY',jwt_fixture('service_role'),'not-a-key']:
            with self.assertRaises(ValueError) as error:public_config('https://example.supabase.co',key)
            self.assertNotIn(key,str(error.exception))

    def test_url_cannot_embed_credentials_or_use_insecure_transport(self):
        for url in ['http://example.supabase.co','https://user:password@example.supabase.co','https://example.supabase.co/path','https://example.supabase.co?key=value']:
            with self.assertRaises(ValueError):public_config(url,'sb_publishable_SYNTHETIC_PUBLIC_TEST_KEY')

if __name__=='__main__':unittest.main()
