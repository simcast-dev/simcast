import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import DashboardClient from "./dashboard/DashboardClient";

export default async function RootPage() {
  const supabase = await createClient();
  // Server-side auth check prevents flash of authenticated content for unauthenticated users
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  return <DashboardClient userEmail={user.email} userId={user.id} />;
}
