export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-6">
      <section className="w-full max-w-2xl border border-alpha-200 bg-surface-100 p-10 transition-colors duration-200 ease-[cubic-bezier(0.16,1,0.3,1)] hover:border-alpha-300">
        <p className="mb-4 font-mono text-xs uppercase tracking-[0.2em] text-muted tabular-nums">
          Foundation · Sprint 0
        </p>
        <h1 className="text-5xl font-semibold tracking-[-0.06em] text-primary">
          NOXUND
        </h1>
        <p className="mt-3 text-lg text-muted">
          Market intelligence engine for producers.
        </p>
        <div className="mt-8 border-t border-alpha-200 pt-6">
          <dl className="grid grid-cols-2 gap-y-2 font-mono text-xs text-muted tabular-nums">
            <dt className="uppercase tracking-wider">Keyword</dt>
            <dd className="text-right text-primary">chicago drill type beat</dd>
            <dt className="uppercase tracking-wider">Status</dt>
            <dd className="text-right text-primary">technical foundation only</dd>
          </dl>
        </div>
      </section>
    </main>
  );
}
