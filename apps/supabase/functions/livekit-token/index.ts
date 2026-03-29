import { AccessToken } from "npm:livekit-server-sdk@2";
import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { room_name, participant_identity, can_publish } = await req.json();
  if (!room_name || !participant_identity) {
    return new Response(JSON.stringify({ error: "Bad Request" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (can_publish) {
    // Publisher: upsert ownership record to establish/refresh ownership
    await supabase
      .from("streams")
      .upsert({ room_name, owner_id: user.id }, { onConflict: "room_name" });
  } else {
    // Viewer: verify the requesting user owns this room
    const { count } = await supabase
      .from("streams")
      .select("*", { count: "exact", head: true })
      .eq("room_name", room_name)
      .eq("owner_id", user.id);

    if (!count || count === 0) {
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
  }

  const apiKey = Deno.env.get("LIVEKIT_API_KEY")!;
  const apiSecret = Deno.env.get("LIVEKIT_API_SECRET")!;
  const livekitUrl = Deno.env.get("LIVEKIT_URL")!;

  const token = new AccessToken(apiKey, apiSecret, {
    identity: participant_identity,
    ttl: "1h",
  });
  token.addGrant({
    roomJoin: true,
    room: room_name,
    canPublish: can_publish,
    canSubscribe: !can_publish,
    canPublishData: true,
  });

  return new Response(
    JSON.stringify({ token: await token.toJwt(), livekit_url: livekitUrl }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
