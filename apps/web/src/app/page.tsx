export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-6">
      <div className="w-full max-w-2xl rounded-lg border border-border bg-black/20 p-10 transition-colors hover:border-neutral-700">
        <p className="mb-4 font-mono text-xs uppercase tracking-[0.2em] text-muted">
          Foundation · Sprint 0
        </p>
        <h1 className="text-5xl font-semibold tracking-tight">NOXUND</h1>
        <p className="mt-3 text-lg text-muted">
          Market intelligence engine for producers.
        </p>
        <div className="mt-8 border-t border-border pt-6">
          <p className="text-sm text-muted">
            Technical foundation only. The Hotspot Artists Report UI is not built
            yet.
          </p>
        </div>
      </div>
    </main>
  );
}
