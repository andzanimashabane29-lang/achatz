const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json(405, { error: "Method not allowed" });

  const authorization = request.headers.get("Authorization") ?? "";
  const match = authorization.match(/^Bearer (.+)$/i);
  if (!match) return json(401, { error: "Authentication required" });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const drixelApiUrl = Deno.env.get("DRIXEL_API_URL")?.replace(/\/+$/, "");
  const drixelServiceKey = Deno.env.get("DRIXEL_SYNC_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey || !drixelApiUrl || !drixelServiceKey) {
    return json(503, { error: "Drixel ID directory sync is not configured" });
  }

  try {
    const verifiedResponse = await fetch(\`\${supabaseUrl}/auth/v1/user\`, {
      headers: { apikey: anonKey, Authorization: \`Bearer \${match[1]}\` },
    });
    if (!verifiedResponse.ok) return json(401, { error: "Invalid authentication token" });
    const verifiedUser = await verifiedResponse.json();
    if (typeof verifiedUser.id !== "string") return json(401, { error: "Invalid authentication token" });

    const adminResponse = await fetch(
      \`\${supabaseUrl}/auth/v1/admin/users/\${encodeURIComponent(verifiedUser.id)}\`,
      { headers: { apikey: serviceRoleKey, Authorization: \`Bearer \${serviceRoleKey}\` } },
    );
    if (!adminResponse.ok) return json(503, { error: "Could not verify linked Drixel ID" });
    const adminUser = await adminResponse.json();
    const identity = Array.isArray(adminUser.identities)
      ? adminUser.identities.find((item: any) => item?.provider === "keycloak")
      : null;
    const subject = identity?.identity_data?.sub;
    if (typeof subject !== "string" || !subject) {
      return json(409, { error: "No linked Drixel ID identity was found" });
    }

    const identityData = identity.identity_data ?? {};
    const email = typeof identityData.email === "string" ? identityData.email : "";
    const emailVerified = identityData.email_verified === true;
    const displayName = typeof identityData.full_name === "string"
      ? identityData.full_name
      : typeof identityData.name === "string" ? identityData.name : "";

    const syncResponse = await fetch(\`\${drixelApiUrl}/api/service-accounts/sync\`, {
      method: "POST",
      headers: {
        Authorization: \`Bearer \${drixelServiceKey}\`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        subject,
        ...(emailVerified && email ? { email, email_verified: true } : {}),
        ...(displayName ? { display_name: displayName } : {}),
      }),
    });
    const result = await syncResponse.json().catch(() => ({}));
    if (!syncResponse.ok) {
      return json(syncResponse.status, {
        error: typeof result.error === "string" ? result.error : "Drixel ID account sync failed",
      });
    }
    return json(200, { synchronized: true });
  } catch {
    return json(503, { error: "Drixel ID account sync is temporarily unavailable" });
  }
});
