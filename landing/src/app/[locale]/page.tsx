import type { Metadata } from "next";
import { LandingContent } from "@/components/LandingContent";
import {
  locales,
  defaultLocale,
  getTranslations,
  type Locale,
} from "@/lib/i18n";

type Props = {
  params: Promise<{ locale: string }>;
};

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale: localeParam } = await params;
  const locale = (
    locales.includes(localeParam as Locale) ? localeParam : defaultLocale
  ) as Locale;
  const t = getTranslations(locale);

  return {
    title: t.meta.title,
    description: t.meta.description,
    alternates: {
      canonical: `/${locale}`,
      languages: Object.fromEntries(
        locales.map((l) => [l, `/${l}`])
      ) as Record<string, string>,
    },
  };
}

export default async function LocalePage({ params }: Props) {
  const { locale: localeParam } = await params;
  const locale = (
    locales.includes(localeParam as Locale) ? localeParam : defaultLocale
  ) as Locale;

  return <LandingContent locale={locale} />;
}
