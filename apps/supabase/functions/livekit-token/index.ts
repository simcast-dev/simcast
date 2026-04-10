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

  const body = await req.json().catch(() => ({}));
  const {
    udid,
    room_name,
    participant_identity,
    can_publish,
  } = body as {
    udid?: string;
    room_name?: string;
    participant_identity?: string;
    can_publish?: boolean;
  };

  let roomName: string | null = null;
  if (typeof room_name === "string" && room_name.length > 0) {
    const expectedPrefix = `user:${user.id}:sim:`;
    if (!room_name.startsWith(expectedPrefix)) {
      return new Response(JSON.stringify({ error: "Invalid room name" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    roomName = room_name;
  } else if (typeof udid === "string" && udid.length > 0) {
    roomName = `user:${user.id}:sim:${udid}`;
  }

  if (!roomName || !participant_identity) {
    return new Response(JSON.stringify({ error: "Bad Request" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
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
    room: roomName,
    canPublish: can_publish,
    canSubscribe: !can_publish,
    canPublishData: true,
  });

  return new Response(
    JSON.stringify({ token: await token.toJwt(), livekit_url: livekitUrl }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
