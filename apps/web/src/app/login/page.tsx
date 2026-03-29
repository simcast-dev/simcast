import LoginForm from "./LoginForm";

export default function LoginPage() {
  return (
    <main
      className="min-h-screen flex items-center justify-center px-4"
      style={{ background: "var(--bg)", color: "var(--text)" }}
    >
      <div className="w-full max-w-sm space-y-8">
        <div className="text-center">
          <h1 className="text-3xl font-bold">SimCast</h1>
          <p className="mt-2" style={{ color: "var(--text-3)" }}>Sign in to your account</p>
        </div>
        <LoginForm />
      </div>
    </main>
  );
}
