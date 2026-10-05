# Drixel ID sign-in for A-Chatz

This change adds Keycloak sign-in and an explicit account-link action while leaving email, phone, QR, and biometric sign-in in place.

## Configure Supabase

A-Chatz uses Supabase Auth as its app session provider. Configure Keycloak as the **Keycloak** OAuth provider in the Supabase project:

- Keycloak realm issuer: `https://<your-drixel-id-host>/realms/drixel`
- Supabase callback: `https://poonntsdomkzfqidboug.supabase.co/auth/v1/callback`
- OAuth scope: `openid`
- Store the Keycloak client secret only in Supabase's provider settings. Do not add it to this repository.

The Keycloak client must be confidential and use the exact Supabase callback above. The Keycloak issuer must be publicly reachable over HTTPS because Supabase's auth service exchanges the authorization code.

In Supabase Auth URL configuration, allow the deployed A-Chatz web origin and the native redirect `a-chatz://login-callback/`. The Android and iOS callback scheme is registered in this repository.

## Link existing A-Chatz accounts

Existing users should first sign in using their current A-Chatz method, then open **Settings → Account → Link Drixel ID**. This calls Supabase's manual identity-linking flow on the signed-in account, preserving that account's Supabase user ID and its existing profile and encrypted-message associations.

Enable manual identity linking in the Supabase project before using that action. If the Keycloak identity is already attached to another A-Chatz account, stop and resolve that account through a verified recovery process. Do not delete either profile or merge based only on matching email.

New users can choose **Continue with Drixel ID**. Supabase creates the app session and the existing profile trigger creates the A-Chatz profile. A-Chatz initializes its end-to-end encryption key on first use.

## Local and production limits

The Keycloak service added to Drixel Platform is for local development only. It is not a public identity endpoint. Before enabling this sign-in on the hosted A-Chatz app, deploy Drixel ID behind HTTPS and replace the local issuer with its public issuer URL in the Supabase provider settings.

The A-Chatz login is federated through Supabase, so the Supabase session token is not the original Drixel ID token. The central directory still needs a server-side service integration to resolve business and application memberships from a Drixel ID subject. This change links sign-in identities; it does not grant employee roles or expose central directory records to A-Chatz.


## Sync the account to the Drixel directory

The A-Chatz client calls the `drixel-account-sync` Supabase Edge Function after a signed-in user has linked the Keycloak identity. The function validates the caller's Supabase session, reads the provider identity server-side, and uses a server-only Drixel service key. The browser and mobile app never receive that key.

Before enabling the function, merge the Drixel Platform service-sync API change and configure a unique secret for application slug `a-chatz` on the API host. Then set the Edge Function secrets in the A-Chatz Supabase project:

```sh
supabase secrets set DRIXEL_API_URL=https://<drixel-api-host> DRIXEL_SYNC_KEY=<a-chatz-service-secret> SUPABASE_SERVICE_ROLE_KEY=<supabase-service-role-key>
supabase functions deploy drixel-account-sync
```

`SUPABASE_URL` and `SUPABASE_ANON_KEY` are Supabase-provided function environment values. Never store `DRIXEL_SYNC_KEY` or the service-role key in app config, source control, or client code. The directory creates or reuses the exact issuer/subject identity, adds only customer and A-Chatz end-user access, and rejects an email that belongs to another Drixel account. Existing employee roles are not changed. Directory sync errors are logged server-side and do not block A-Chatz login; suspended or ended central memberships still require an administrator to restore them.
