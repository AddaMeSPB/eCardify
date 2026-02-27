import {
  getTranslations,
  featureKeys,
  type Locale,
  type FeatureKey,
} from "@/lib/i18n";

const APP_STORE_URL =
  "https://apps.apple.com/app/ecardify-digital-business-card/id1619504857";

const featureIcons: Record<FeatureKey, string> = {
  wallet:
    "M21 12a2.25 2.25 0 0 0-2.25-2.25H15a3 3 0 1 1-6 0H5.25A2.25 2.25 0 0 0 3 12m18 0v6a2.25 2.25 0 0 1-2.25 2.25H5.25A2.25 2.25 0 0 1 3 18v-6m18 0V9M3 12V9m18 0a2.25 2.25 0 0 0-2.25-2.25H5.25A2.25 2.25 0 0 0 3 9m18 0V6a2.25 2.25 0 0 0-2.25-2.25H5.25A2.25 2.25 0 0 0 3 6v3",
  qr: "M3.75 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0 1 3.75 9.375v-4.5ZM3.75 14.625c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5a1.125 1.125 0 0 1-1.125-1.125v-4.5ZM13.5 4.875c0-.621.504-1.125 1.125-1.125h4.5c.621 0 1.125.504 1.125 1.125v4.5c0 .621-.504 1.125-1.125 1.125h-4.5A1.125 1.125 0 0 1 13.5 9.375v-4.5Z",
  scanner:
    "M6.827 6.175A2.31 2.31 0 0 1 5.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 0 0-1.134-.175 2.31 2.31 0 0 1-1.64-1.055l-.822-1.316a2.192 2.192 0 0 0-1.736-1.039 48.774 48.774 0 0 0-5.232 0 2.192 2.192 0 0 0-1.736 1.039l-.821 1.316Z M16.5 12.75a4.5 4.5 0 1 1-9 0 4.5 4.5 0 0 1 9 0Z",
  templates:
    "M9.53 16.122a3 3 0 0 0-5.78 1.128 2.25 2.25 0 0 1-2.4 2.245 4.5 4.5 0 0 0 8.4-2.245c0-.399-.078-.78-.22-1.128Zm0 0a15.998 15.998 0 0 0 3.388-1.62m-5.043-.025a15.994 15.994 0 0 1 1.622-3.395m3.42 3.42a15.995 15.995 0 0 0 4.764-4.648l3.876-5.814a1.151 1.151 0 0 0-1.597-1.597L14.146 6.32a15.996 15.996 0 0 0-4.649 4.763m3.42 3.42a6.776 6.776 0 0 0-3.42-3.42",
  share:
    "M7.217 10.907a2.25 2.25 0 1 0 0 2.186m0-2.186c.18.324.283.696.283 1.093s-.103.77-.283 1.093m0-2.186 9.566-5.314m-9.566 7.5 9.566 5.314m0 0a2.25 2.25 0 1 0 3.935 2.186 2.25 2.25 0 0 0-3.935-2.186Zm0-12.814a2.25 2.25 0 1 0 3.933-2.185 2.25 2.25 0 0 0-3.933 2.185Z",
  privacy:
    "M9 12.75 11.25 15 15 9.75m-3-7.036A11.959 11.959 0 0 1 3.598 6 11.99 11.99 0 0 0 3 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285Z",
};

function AppleIcon({ className }: { className?: string }) {
  return (
    <svg
      className={className}
      fill="currentColor"
      viewBox="0 0 24 24"
      aria-hidden="true"
    >
      <path d="M18.71 19.5C17.88 20.74 17 21.95 15.66 21.97C14.32 21.99 13.89 21.18 12.37 21.18C10.84 21.18 10.37 21.95 9.1 21.99C7.79 22.03 6.8 20.68 5.96 19.47C4.25 16.99 2.97 12.5 4.7 9.46C5.55 7.95 7.13 7 8.82 6.97C10.1 6.95 11.32 7.82 12.11 7.82C12.89 7.82 14.37 6.77 15.92 6.93C16.57 6.96 18.39 7.21 19.56 8.91C19.47 8.97 17.09 10.35 17.12 13.18C17.15 16.58 20.11 17.72 20.15 17.73C20.12 17.82 19.69 19.35 18.71 19.5ZM13 3.5C13.73 2.67 14.94 2.04 15.94 2C16.07 3.17 15.6 4.35 14.9 5.19C14.21 6.04 13.07 6.7 11.95 6.61C11.8 5.46 12.36 4.26 13 3.5Z" />
    </svg>
  );
}

export function LandingContent({ locale }: { locale: Locale }) {
  const t = getTranslations(locale);

  return (
    <main className="min-h-screen">
      {/* Hero */}
      <section
        aria-label="Hero"
        className="relative overflow-hidden px-6 pt-20 pb-24 sm:pt-32 sm:pb-32"
      >
        <div className="absolute inset-0 -z-10 bg-gradient-to-b from-brand-50/80 via-white to-white dark:from-brand-950/30 dark:via-surface-dark dark:to-surface-dark" />
        <div className="mx-auto max-w-3xl text-center">
          <span className="inline-flex items-center gap-1.5 rounded-full bg-brand-100 dark:bg-brand-900/40 px-4 py-1.5 text-sm font-medium text-brand-700 dark:text-brand-300 mb-8">
            <AppleIcon className="h-4 w-4" />
            {t.hero.badge}
          </span>
          <h1 className="font-serif text-5xl sm:text-7xl font-normal tracking-tight text-gray-900 dark:text-white whitespace-pre-line leading-[1.1]">
            {t.hero.title}
          </h1>
          <p className="mt-8 text-lg sm:text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto leading-relaxed">
            {t.hero.subtitle}
          </p>
          <div className="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 rounded-xl bg-gray-900 dark:bg-white px-8 py-4 text-base font-semibold text-white dark:text-gray-900 shadow-lg shadow-gray-900/20 hover:bg-gray-800 dark:hover:bg-gray-100 transition-all"
            >
              <AppleIcon className="h-6 w-6" />
              {t.hero.cta}
            </a>
            <a
              href="#features"
              className="inline-flex items-center gap-2 rounded-xl border border-gray-200 dark:border-gray-700 px-8 py-4 text-base font-semibold text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-all"
            >
              {t.hero.ctaSecondary}
              <svg
                className="h-4 w-4"
                fill="none"
                viewBox="0 0 24 24"
                strokeWidth={2}
                stroke="currentColor"
                aria-hidden="true"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  d="M19.5 13.5 12 21m0 0-7.5-7.5M12 21V3"
                />
              </svg>
            </a>
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="features" aria-label="Features" className="px-6 py-24 sm:py-32">
        <div className="mx-auto max-w-6xl">
          <h2 className="font-serif text-3xl sm:text-5xl text-center text-gray-900 dark:text-white mb-16">
            {t.features.title}
          </h2>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
            {featureKeys.map((key) => (
              <div
                key={key}
                className="group rounded-2xl border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900/50 p-8 hover:shadow-xl hover:shadow-brand-100/50 dark:hover:shadow-brand-900/20 transition-all duration-300 hover:-translate-y-1"
              >
                <div className="mb-5 inline-flex items-center justify-center rounded-xl bg-brand-50 dark:bg-brand-900/30 p-3">
                  <svg
                    className="h-6 w-6 text-brand-600 dark:text-brand-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    strokeWidth={1.5}
                    stroke="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      d={featureIcons[key]}
                    />
                  </svg>
                </div>
                <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-3">
                  {t.features.items[key].title}
                </h3>
                <p className="text-gray-600 dark:text-gray-400 leading-relaxed">
                  {t.features.items[key].description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA */}
      <section aria-label="Download" className="px-6 py-24 sm:py-32">
        <div className="mx-auto max-w-3xl text-center">
          <div className="rounded-3xl bg-gradient-to-br from-brand-600 to-brand-800 p-12 sm:p-16 shadow-2xl shadow-brand-600/30">
            <h2 className="font-serif text-3xl sm:text-5xl text-white mb-6">
              {t.cta.title}
            </h2>
            <p className="text-brand-100 text-lg mb-10 max-w-lg mx-auto">
              {t.cta.subtitle}
            </p>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 rounded-xl bg-white px-8 py-4 text-base font-semibold text-brand-700 shadow-lg hover:bg-brand-50 transition-all"
            >
              <AppleIcon className="h-6 w-6" />
              {t.cta.button}
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-100 dark:border-gray-800 px-6 py-12">
        <div className="mx-auto max-w-6xl flex flex-col sm:flex-row items-center justify-between gap-6">
          <p className="text-sm text-gray-500 dark:text-gray-400">
            {t.footer.tagline}
          </p>
          <div className="flex items-center gap-6 text-sm text-gray-500 dark:text-gray-400">
            <a
              href="https://ecardify.addame.com/privacy"
              className="hover:text-gray-900 dark:hover:text-white transition-colors"
            >
              {t.footer.privacy}
            </a>
            <a
              href="https://ecardify.addame.com/terms"
              className="hover:text-gray-900 dark:hover:text-white transition-colors"
            >
              {t.footer.terms}
            </a>
          </div>
        </div>
      </footer>
    </main>
  );
}
