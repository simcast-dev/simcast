import { AccessToken } from "npm:livekit-server-sdk@^2";
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  const authHeader = req.headers.get("Authorization");
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader! } } }
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }

  const { room_name, duration_minutes } = await req.json() as {
    room_name: string;
    duration_minutes: 15 | 30 | 60;
  };

  if (!room_name || ![15, 30, 60].includes(duration_minutes)) {
    return new Response(JSON.stringify({ error: "Invalid parameters" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Verify the requesting user owns this room
  const { count } = await supabase
    .from("streams")
    .select("*", { count: "exact", head: true })
    .eq("room_name", room_name)
    .eq("owner_id", user.id);

  if (!count || count === 0) {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });
  }

  const apiKey = Deno.env.get("LIVEKIT_API_KEY")!;
  const apiSecret = Deno.env.get("LIVEKIT_API_SECRET")!;
  const livekitUrl = Deno.env.get("LIVEKIT_URL")!;

  const ttl = `${duration_minutes}m`;
  const token = new AccessToken(apiKey, apiSecret, {
    identity: `guest-${crypto.randomUUID()}`,
    ttl,
  });
  token.addGrant({
    roomSubscribe: true,
    room: room_name,
    canPublish: false,
    canPublishData: false,
  });

  return new Response(
    JSON.stringify({ token: await token.toJwt(), livekit_url: livekitUrl }),
    {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
      },
    }
  );
});
