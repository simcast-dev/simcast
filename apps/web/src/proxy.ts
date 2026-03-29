import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

export async function proxy(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request });

  const supabaseHost = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL!).host;

  // Cookies over localStorage: HTTP-only cookies prevent XSS token theft; server-side refresh ensures seamless renewal
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value)
          );
          supabaseResponse = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const {
    data: { user },
  } = await supabase.auth.getUser();

  const { pathname } = request.nextUrl;

  // /watch is public: guest share links must work without authentication
  if (!user && pathname !== "/login" && !pathname.startsWith("/watch")) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  if (user && pathname === "/login") {
    return NextResponse.redirect(new URL("/", request.url));
  }

  // CSP: Supabase WSS for realtime, LiveKit cloud for WebRTC signaling and TURN
  supabaseResponse.headers.set(
    "Content-Security-Policy",
    // LiveKit wildcards kept: LiveKit Cloud uses dynamic regional subdomains that can't be predicted at deploy time.
    `default-src 'self'; connect-src 'self' https://${supabaseHost} wss://${supabaseHost} wss://*.livekit.cloud https://*.livekit.cloud; img-src 'self' https://${supabaseHost} blob:; media-src 'self' https://${supabaseHost} blob:; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'`
  );
  supabaseResponse.headers.set("Strict-Transport-Security", "max-age=63072000; includeSubDomains");
  supabaseResponse.headers.set("X-Content-Type-Options", "nosniff");
  supabaseResponse.headers.set("X-Frame-Options", "DENY");

  return supabaseResponse;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
