export const locales = [
  "en",
  "de",
  "es",
  "fr",
  "it",
  "ja",
  "ko",
  "pt",
  "ru",
  "zh",
] as const;

export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = "en";

export interface Translations {
  meta: {
    title: string;
    description: string;
  };
  hero: {
    badge: string;
    title: string;
    subtitle: string;
    cta: string;
    ctaSecondary: string;
  };
  features: {
    title: string;
    items: {
      wallet: { title: string; description: string };
      qr: { title: string; description: string };
      scanner: { title: string; description: string };
      templates: { title: string; description: string };
      share: { title: string; description: string };
      privacy: { title: string; description: string };
    };
  };
  cta: {
    title: string;
    subtitle: string;
    button: string;
  };
  footer: {
    tagline: string;
    privacy: string;
    terms: string;
  };
}

const translations: Record<Locale, Translations> = {
  en: {
    meta: {
      title: "eCardify - Digital Business Card for iPhone",
      description:
        "Create professional digital business cards, save to Apple Wallet, and share via QR code or AirDrop. No app needed on the other end.",
    },
    hero: {
      badge: "Free on the App Store",
      title: "Your Business Card,\nReimagined",
      subtitle:
        "Create a professional digital business card in under 2 minutes. Save to Apple Wallet. Share via QR code. No app needed on their end.",
      cta: "Download Free",
      ctaSecondary: "Learn More",
    },
    features: {
      title: "Everything You Need",
      items: {
        wallet: {
          title: "Apple Wallet",
          description:
            "Your card lives in Apple Wallet. One swipe from your lock screen and you're ready to share.",
        },
        qr: {
          title: "QR Code",
          description:
            "Every card has a unique QR code. They scan it with their camera. No app required.",
        },
        scanner: {
          title: "Card Scanner",
          description:
            "Scan paper business cards at events. The app reads and creates digital contacts automatically.",
        },
        templates: {
          title: "Pro Templates",
          description:
            "Choose from professionally designed templates and color schemes that match your brand.",
        },
        share: {
          title: "Share Anywhere",
          description:
            "QR, AirDrop, iMessage, email, WhatsApp. Recipients get a clean vCard — no app download needed.",
        },
        privacy: {
          title: "Privacy First",
          description:
            "No social account required. No CRM, no tracking. You create, you share, you control.",
        },
      },
    },
    cta: {
      title: "Go Paperless Today",
      subtitle:
        "Join thousands of professionals who ditched paper cards for eCardify.",
      button: "Get eCardify Free",
    },
    footer: {
      tagline: "Go paperless. Go professional. Go eCardify.",
      privacy: "Privacy Policy",
      terms: "Terms of Service",
    },
  },
  de: {
    meta: {
      title: "eCardify - Digitale Visitenkarte",
      description:
        "Erstelle professionelle digitale Visitenkarten, speichere sie in Apple Wallet und teile sie per QR-Code oder AirDrop.",
    },
    hero: {
      badge: "Kostenlos im App Store",
      title: "Deine Visitenkarte,\nneu gedacht",
      subtitle:
        "Erstelle eine professionelle digitale Visitenkarte in unter 2 Minuten. Speichere in Apple Wallet. Teile per QR-Code.",
      cta: "Kostenlos laden",
      ctaSecondary: "Mehr erfahren",
    },
    features: {
      title: "Alles was du brauchst",
      items: {
        wallet: {
          title: "Apple Wallet",
          description:
            "Deine Karte lebt in Apple Wallet. Ein Wisch vom Sperrbildschirm und du bist bereit zum Teilen.",
        },
        qr: {
          title: "QR-Code",
          description:
            "Jede Karte hat einen einzigartigen QR-Code. Scannen mit der Kamera. Keine App nötig.",
        },
        scanner: {
          title: "Kartenscanner",
          description:
            "Scanne Papier-Visitenkarten auf Events. Die App liest und erstellt digitale Kontakte automatisch.",
        },
        templates: {
          title: "Pro Vorlagen",
          description:
            "Wähle aus professionell gestalteten Vorlagen und Farbschemata, die zu deiner Marke passen.",
        },
        share: {
          title: "Überall teilen",
          description:
            "QR, AirDrop, iMessage, E-Mail, WhatsApp. Empfänger bekommen eine saubere vCard — kein App-Download nötig.",
        },
        privacy: {
          title: "Privacy First",
          description:
            "Kein Social-Account nötig. Kein CRM, kein Tracking. Du erstellst, du teilst, du kontrollierst.",
        },
      },
    },
    cta: {
      title: "Heute papierlos werden",
      subtitle:
        "Schließe dich Tausenden von Profis an, die Papierkarten gegen eCardify getauscht haben.",
      button: "eCardify kostenlos laden",
    },
    footer: {
      tagline: "Papierlos. Professionell. eCardify.",
      privacy: "Datenschutz",
      terms: "Nutzungsbedingungen",
    },
  },
  es: {
    meta: {
      title: "eCardify - Tarjeta de Presentación Digital",
      description:
        "Crea tarjetas de presentación digitales profesionales, guárdalas en Apple Wallet y compártelas por código QR o AirDrop.",
    },
    hero: {
      badge: "Gratis en la App Store",
      title: "Tu Tarjeta,\nReinventada",
      subtitle:
        "Crea una tarjeta de presentación digital profesional en menos de 2 minutos. Guarda en Apple Wallet. Comparte por QR.",
      cta: "Descargar Gratis",
      ctaSecondary: "Saber Más",
    },
    features: {
      title: "Todo lo que necesitas",
      items: {
        wallet: {
          title: "Apple Wallet",
          description:
            "Tu tarjeta vive en Apple Wallet. Un desliz desde la pantalla de bloqueo y estás listo.",
        },
        qr: {
          title: "Código QR",
          description:
            "Cada tarjeta tiene un código QR único. Escanean con la cámara. Sin app necesaria.",
        },
        scanner: {
          title: "Escáner",
          description:
            "Escanea tarjetas de papel en eventos. La app lee y crea contactos digitales automáticamente.",
        },
        templates: {
          title: "Plantillas Pro",
          description:
            "Elige entre plantillas y combinaciones de colores diseñadas profesionalmente.",
        },
        share: {
          title: "Comparte en cualquier lugar",
          description:
            "QR, AirDrop, iMessage, correo, WhatsApp. Los destinatarios reciben una vCard limpia.",
        },
        privacy: {
          title: "Privacidad primero",
          description:
            "Sin cuenta social necesaria. Sin CRM, sin seguimiento. Tú creas, compartes y controlas.",
        },
      },
    },
    cta: {
      title: "Pasa al digital hoy",
      subtitle:
        "Únete a miles de profesionales que dejaron las tarjetas de papel por eCardify.",
      button: "Obtener eCardify Gratis",
    },
    footer: {
      tagline: "Sin papel. Profesional. eCardify.",
      privacy: "Política de Privacidad",
      terms: "Términos de Servicio",
    },
  },
  fr: {
    meta: {
      title: "eCardify - Carte de Visite Numérique",
      description:
        "Créez des cartes de visite numériques professionnelles, enregistrez-les dans Apple Wallet et partagez-les par code QR ou AirDrop.",
    },
    hero: {
      badge: "Gratuit sur l'App Store",
      title: "Votre Carte de Visite,\nRéinventée",
      subtitle:
        "Créez une carte de visite numérique professionnelle en moins de 2 minutes. Enregistrez dans Apple Wallet. Partagez par QR.",
      cta: "Télécharger Gratuit",
      ctaSecondary: "En savoir plus",
    },
    features: {
      title: "Tout ce dont vous avez besoin",
      items: {
        wallet: {
          title: "Apple Wallet",
          description:
            "Votre carte vit dans Apple Wallet. Un glissement depuis l'écran de verrouillage et vous êtes prêt.",
        },
        qr: {
          title: "Code QR",
          description:
            "Chaque carte a un code QR unique. Ils scannent avec leur caméra. Aucune app requise.",
        },
        scanner: {
          title: "Scanner",
          description:
            "Scannez les cartes papier lors d'événements. L'app lit et crée des contacts numériques automatiquement.",
        },
        templates: {
          title: "Modèles Pro",
          description:
            "Choisissez parmi des modèles et palettes de couleurs conçus professionnellement.",
        },
        share: {
          title: "Partagez partout",
          description:
            "QR, AirDrop, iMessage, e-mail, WhatsApp. Les destinataires reçoivent une vCard propre.",
        },
        privacy: {
          title: "Confidentialité d'abord",
          description:
            "Aucun compte social requis. Pas de CRM, pas de suivi. Vous créez, partagez et contrôlez.",
        },
      },
    },
    cta: {
      title: "Passez au sans papier",
      subtitle:
        "Rejoignez des milliers de professionnels qui ont abandonné les cartes papier pour eCardify.",
      button: "Obtenir eCardify Gratuit",
    },
    footer: {
      tagline: "Sans papier. Professionnel. eCardify.",
      privacy: "Politique de Confidentialité",
      terms: "Conditions d'Utilisation",
    },
  },
  it: {
    meta: { title: "eCardify - Biglietto da Visita Digitale", description: "Crea biglietti da visita digitali professionali, salvali in Apple Wallet e condividili tramite codice QR o AirDrop." },
    hero: { badge: "Gratis sull'App Store", title: "Il tuo Biglietto,\nRipensato", subtitle: "Crea un biglietto da visita digitale professionale in meno di 2 minuti. Salva in Apple Wallet. Condividi tramite QR.", cta: "Scarica Gratis", ctaSecondary: "Scopri di più" },
    features: { title: "Tutto ciò che serve", items: { wallet: { title: "Apple Wallet", description: "Il tuo biglietto vive in Apple Wallet. Uno swipe dalla schermata di blocco e sei pronto." }, qr: { title: "Codice QR", description: "Ogni biglietto ha un codice QR unico. Scansionano con la fotocamera. Nessuna app necessaria." }, scanner: { title: "Scanner", description: "Scansiona biglietti cartacei agli eventi. L'app legge e crea contatti digitali automaticamente." }, templates: { title: "Modelli Pro", description: "Scegli tra modelli e combinazioni di colori progettati professionalmente." }, share: { title: "Condividi ovunque", description: "QR, AirDrop, iMessage, email, WhatsApp. I destinatari ricevono una vCard pulita." }, privacy: { title: "Privacy prima", description: "Nessun account social richiesto. Nessun CRM, nessun tracking. Crei, condividi, controlli." } } },
    cta: { title: "Passa al digitale oggi", subtitle: "Unisciti a migliaia di professionisti che hanno lasciato i biglietti cartacei per eCardify.", button: "Ottieni eCardify Gratis" },
    footer: { tagline: "Senza carta. Professionale. eCardify.", privacy: "Privacy Policy", terms: "Termini di Servizio" },
  },
  ja: {
    meta: { title: "eCardify - デジタル名刺アプリ", description: "プロフェッショナルなデジタル名刺を作成し、Apple Walletに保存、QRコードやAirDropで共有。" },
    hero: { badge: "App Storeで無料", title: "名刺を、\nもっとスマートに", subtitle: "2分以内にプロフェッショナルなデジタル名刺を作成。Apple Walletに保存。QRコードで共有。", cta: "無料ダウンロード", ctaSecondary: "詳しく見る" },
    features: { title: "必要なすべてが揃う", items: { wallet: { title: "Apple Wallet", description: "名刺はApple Walletに保存。ロック画面からワンスワイプで共有準備完了。" }, qr: { title: "QRコード", description: "すべてのカードに固有のQRコード。カメラでスキャンするだけ。アプリ不要。" }, scanner: { title: "スキャナー", description: "イベントで紙の名刺をスキャン。アプリが読み取り、デジタル連絡先を自動作成。" }, templates: { title: "プロテンプレート", description: "プロがデザインしたテンプレートとカラースキームから選択。" }, share: { title: "どこでも共有", description: "QR、AirDrop、iMessage、メール、WhatsApp。受信側にアプリ不要。" }, privacy: { title: "プライバシー重視", description: "ソーシャルアカウント不要。CRMもトラッキングもなし。" } } },
    cta: { title: "今日からペーパーレス", subtitle: "紙の名刺をeCardifyに替えた多くのプロフェッショナルに参加しよう。", button: "eCardifyを無料で入手" },
    footer: { tagline: "ペーパーレス。プロフェッショナル。eCardify。", privacy: "プライバシーポリシー", terms: "利用規約" },
  },
  ko: {
    meta: { title: "eCardify - 디지털 명함 앱", description: "전문적인 디지털 명함을 만들고, Apple Wallet에 저장하고, QR 코드나 AirDrop으로 공유하세요." },
    hero: { badge: "App Store에서 무료", title: "명함을,\n새롭게 상상하다", subtitle: "2분 안에 전문적인 디지털 명함을 만드세요. Apple Wallet에 저장. QR 코드로 공유.", cta: "무료 다운로드", ctaSecondary: "자세히 보기" },
    features: { title: "필요한 모든 것", items: { wallet: { title: "Apple Wallet", description: "명함이 Apple Wallet에 저장됩니다. 잠금 화면에서 스와이프 한 번으로 공유 준비 완료." }, qr: { title: "QR 코드", description: "모든 카드에 고유한 QR 코드. 카메라로 스캔. 앱 불필요." }, scanner: { title: "스캐너", description: "이벤트에서 종이 명함 스캔. 앱이 읽고 디지털 연락처를 자동 생성." }, templates: { title: "프로 템플릿", description: "전문적으로 디자인된 템플릿과 색상 조합에서 선택." }, share: { title: "어디서나 공유", description: "QR, AirDrop, iMessage, 이메일, WhatsApp. 수신자에게 앱 불필요." }, privacy: { title: "프라이버시 우선", description: "소셜 계정 불필요. CRM도 추적도 없음." } } },
    cta: { title: "오늘부터 종이 없이", subtitle: "종이 명함을 eCardify로 바꾼 수많은 전문가들과 함께하세요.", button: "eCardify 무료 받기" },
    footer: { tagline: "종이 없이. 전문적으로. eCardify.", privacy: "개인정보 처리방침", terms: "이용약관" },
  },
  pt: {
    meta: { title: "eCardify - Cartão de Visita Digital", description: "Crie cartões de visita digitais profissionais, salve na Apple Wallet e compartilhe por QR code ou AirDrop." },
    hero: { badge: "Grátis na App Store", title: "Seu Cartão,\nReinventado", subtitle: "Crie um cartão de visita digital profissional em menos de 2 minutos. Salve na Apple Wallet. Compartilhe por QR.", cta: "Baixar Grátis", ctaSecondary: "Saiba Mais" },
    features: { title: "Tudo o que você precisa", items: { wallet: { title: "Apple Wallet", description: "Seu cartão fica na Apple Wallet. Um deslize da tela de bloqueio e você está pronto." }, qr: { title: "QR Code", description: "Cada cartão tem um QR code exclusivo. Escaneiam com a câmera. Sem app necessário." }, scanner: { title: "Scanner", description: "Escaneie cartões de papel em eventos. O app lê e cria contatos digitais automaticamente." }, templates: { title: "Modelos Pro", description: "Escolha entre modelos e combinações de cores projetados profissionalmente." }, share: { title: "Compartilhe em qualquer lugar", description: "QR, AirDrop, iMessage, e-mail, WhatsApp. Destinatários recebem uma vCard limpa." }, privacy: { title: "Privacidade primeiro", description: "Sem conta social necessária. Sem CRM, sem rastreamento." } } },
    cta: { title: "Passe ao digital hoje", subtitle: "Junte-se a milhares de profissionais que trocaram cartões de papel pelo eCardify.", button: "Obter eCardify Grátis" },
    footer: { tagline: "Sem papel. Profissional. eCardify.", privacy: "Política de Privacidade", terms: "Termos de Serviço" },
  },
  ru: {
    meta: { title: "eCardify - Цифровая Визитка", description: "Создавайте профессиональные цифровые визитки, сохраняйте в Apple Wallet и делитесь через QR-код или AirDrop." },
    hero: { badge: "Бесплатно в App Store", title: "Ваша визитка,\nпо-новому", subtitle: "Создайте профессиональную цифровую визитку за 2 минуты. Сохраните в Apple Wallet. Поделитесь по QR-коду.", cta: "Скачать бесплатно", ctaSecondary: "Узнать больше" },
    features: { title: "Всё что нужно", items: { wallet: { title: "Apple Wallet", description: "Визитка хранится в Apple Wallet. Один свайп с экрана блокировки — и вы готовы." }, qr: { title: "QR-код", description: "У каждой визитки уникальный QR-код. Сканируют камерой. Приложение не нужно." }, scanner: { title: "Сканер", description: "Сканируйте бумажные визитки на мероприятиях. Приложение создаёт цифровые контакты автоматически." }, templates: { title: "Про-шаблоны", description: "Выбирайте из профессионально оформленных шаблонов и цветовых схем." }, share: { title: "Делитесь везде", description: "QR, AirDrop, iMessage, почта, WhatsApp. Получателям приложение не нужно." }, privacy: { title: "Приватность прежде всего", description: "Социальный аккаунт не нужен. Без CRM, без отслеживания." } } },
    cta: { title: "Переходите на цифру", subtitle: "Присоединяйтесь к тысячам профессионалов, выбравших eCardify вместо бумажных визиток.", button: "Получить eCardify бесплатно" },
    footer: { tagline: "Без бумаги. Профессионально. eCardify.", privacy: "Политика конфиденциальности", terms: "Условия использования" },
  },
  zh: {
    meta: { title: "eCardify - 数字名片", description: "创建专业数字名片，保存到Apple Wallet，通过二维码或AirDrop分享。" },
    hero: { badge: "App Store免费下载", title: "你的名片，\n重新定义", subtitle: "不到2分钟创建专业数字名片。保存到Apple Wallet。通过二维码分享。", cta: "免费下载", ctaSecondary: "了解更多" },
    features: { title: "一切所需", items: { wallet: { title: "Apple Wallet", description: "名片保存在Apple Wallet中。锁屏滑动一下即可准备分享。" }, qr: { title: "二维码", description: "每张卡片都有唯一二维码。用摄像头扫描即可。无需应用。" }, scanner: { title: "扫描仪", description: "在活动中扫描纸质名片。应用自动读取并创建数字联系人。" }, templates: { title: "专业模板", description: "从专业设计的模板和配色方案中选择。" }, share: { title: "随时分享", description: "二维码、AirDrop、iMessage、邮件、WhatsApp。接收者无需应用。" }, privacy: { title: "隐私优先", description: "无需社交账号。无CRM，无追踪。" } } },
    cta: { title: "今天开始无纸化", subtitle: "加入数千名选择eCardify告别纸质名片的专业人士。", button: "免费获取eCardify" },
    footer: { tagline: "无纸化。专业化。eCardify。", privacy: "隐私政策", terms: "服务条款" },
  },
};

export type FeatureKey = keyof Translations["features"]["items"];

export const featureKeys: FeatureKey[] = [
  "wallet",
  "qr",
  "scanner",
  "templates",
  "share",
  "privacy",
];

export function getTranslations(locale: Locale): Translations {
  return translations[locale] ?? translations[defaultLocale];
}
