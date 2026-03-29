"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

export default function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    // Email/password over OAuth: shared auth between macOS native app and web — OAuth would require different flows per platform
    const supabase = createClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });

    if (error) {
      setError("Invalid email or password.");
      setLoading(false);
      return;
    }

    router.push("/");
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="space-y-2">
        <label htmlFor="email" className="block text-sm font-medium" style={{ color: "var(--text-2)" }}>
          Email
        </label>
        <input
          id="email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          autoComplete="email"
          className="w-full px-3 py-2 rounded-lg focus:outline-none focus:ring-2 focus:border-transparent"
          style={{
            background: "var(--input-bg)",
            border: "1px solid var(--input-border)",
            color: "var(--text)",
            borderRadius: "var(--radius-sm)",
          }}
          placeholder="you@example.com"
        />
      </div>

      <div className="space-y-2">
        <label htmlFor="password" className="block text-sm font-medium" style={{ color: "var(--text-2)" }}>
          Password
        </label>
        <input
          id="password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          autoComplete="current-password"
          className="w-full px-3 py-2 rounded-lg focus:outline-none focus:ring-2 focus:border-transparent"
          style={{
            background: "var(--input-bg)",
            border: "1px solid var(--input-border)",
            color: "var(--text)",
            borderRadius: "var(--radius-sm)",
          }}
          placeholder="••••••••"
        />
      </div>

      {error && (
        <p className="text-sm rounded-lg px-3 py-2" style={{ color: "var(--error-text)", background: "var(--error-bg)", border: "1px solid var(--error-border)" }}>
          {error}
        </p>
      )}

      <button
        type="submit"
        disabled={loading}
        className="w-full py-2.5 px-4 font-semibold rounded-lg transition-colors disabled:cursor-not-allowed disabled:opacity-60"
        style={{
          backgroundImage: "linear-gradient(135deg, var(--btn-primary-from), var(--btn-primary-to))",
          border: "1px solid var(--btn-primary-border)",
          color: "var(--btn-primary-text)",
          boxShadow: "var(--btn-primary-shadow)",
          borderRadius: "var(--radius-sm)",
        }}
      >
        {loading ? "Signing in…" : "Sign in"}
      </button>
    </form>
  );
}
