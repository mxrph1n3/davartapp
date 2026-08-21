export type ItalonCollection = {
  slug: string;
  name: string;
  aliases: string[];
};

/** Official Italon RU collection names, longest aliases first when matching. */
export const ITALON_COLLECTIONS: ItalonCollection[] = [
  {
    slug: 'charme-extra',
    name: 'Шарм Экстра',
    aliases: ['Шарм Экстра', 'Charme Extra'],
  },
  {
    slug: 'charme-advance',
    name: 'Шарм Эдванс',
    aliases: ['Шарм Эдванс', 'Charme Advance'],
  },
  {
    slug: 'sharm-delyuks',
    name: 'Шарм Делюкс',
    aliases: ['Шарм Делюкс', 'Charme Deluxe'],
  },
  {
    slug: 'sharm-evo',
    name: 'Шарм Эво',
    aliases: ['Шарм Эво', 'Charme Evo'],
  },
  {
    slug: 'vandeful-lajf',
    name: 'Вандефул Лайф',
    aliases: ['Вандефул Лайф', 'Wonderful Life'],
  },
  {
    slug: 'rum-stone',
    name: 'Рум Стоун',
    aliases: ['Рум Стоун', 'Room Stone'],
  },
  {
    slug: 'continuum',
    name: 'Континуум',
    aliases: ['Континуум', 'Continuum'],
  },
  {
    slug: 'millennium',
    name: 'Миллениум',
    aliases: ['Миллениум', 'Millennium'],
  },
  {
    slug: 'metropolis',
    name: 'Метрополис',
    aliases: ['Метрополис', 'Metropolis'],
  },
  {
    slug: 'avantgarde',
    name: 'Авангард',
    aliases: ['Авангард', 'Avantgarde'],
  },
  {
    slug: 'stellaris',
    name: 'Стелларис',
    aliases: ['Стелларис', 'Stellaris'],
  },
  {
    slug: 'materiya',
    name: 'Материя',
    aliases: ['Материя', 'Materia'],
  },
  {
    slug: 'skajfoll',
    name: 'Скайфолл',
    aliases: ['Скайфолл', 'Skyfall'],
  },
  {
    slug: 'dzhenezis',
    name: 'Дженезис',
    aliases: ['Дженезис', 'Genesis'],
  },
  {
    slug: 'eternum',
    name: 'Этернум',
    aliases: ['Этернум', 'Eternum'],
  },
  {
    slug: 'terraviva',
    name: 'Терравива',
    aliases: ['Терравива', 'Terraviva'],
  },
  {
    slug: 'nordica',
    name: 'Нордика',
    aliases: ['Нордика', 'Nordica'],
  },
  {
    slug: 'diskaver',
    name: 'Дискавер',
    aliases: ['Дискавер', 'Discover'],
  },
  {
    slug: 'fossil',
    name: 'Фоссил',
    aliases: ['Фоссил', 'Fossil'],
  },
  {
    slug: 'forum',
    name: 'Форум',
    aliases: ['Форум', 'Forum'],
  },
  {
    slug: 'magma',
    name: 'Магма',
    aliases: ['Магма', 'Magma'],
  },
  {
    slug: 'kosmos',
    name: 'Космос',
    aliases: ['Космос', 'Cosmos'],
  },
  {
    slug: 'aura',
    name: 'Аура',
    aliases: ['Аура', 'Aura'],
  },
  {
    slug: 'velvet',
    name: 'Вельвет',
    aliases: ['Вельвет', 'Velvet'],
  },
  {
    slug: 'status',
    name: 'Статус',
    aliases: ['Статус', 'Status'],
  },
  {
    slug: 'bottega',
    name: 'Боттега',
    aliases: ['Боттега', 'Bottega'],
  },
  {
    slug: 'boutique',
    name: 'Бутик',
    aliases: ['Бутик', 'Boutique'],
  },
  {
    slug: 'voyadzher',
    name: 'Вояджер',
    aliases: ['Вояджер', 'Voyager'],
  },
  {
    slug: 'prima',
    name: 'Прима',
    aliases: ['Прима', 'Prima'],
  },
  {
    slug: 'loft',
    name: 'Лофт',
    aliases: ['Лофт', 'Loft'],
  },
  {
    slug: 'surface',
    name: 'Серфейс',
    aliases: ['Серфейс', 'Surface'],
  },
  {
    slug: 'distrikt',
    name: 'Дистрикт',
    aliases: ['Дистрикт', 'District'],
  },
  {
    slug: 'kontempora',
    name: 'Контемпора',
    aliases: ['Контемпора', 'Contempora'],
  },
  {
    slug: 'everstone',
    name: 'Эверстоун',
    aliases: ['Эверстоун', 'Everstone'],
  },
  {
    slug: 'skajlajn',
    name: 'Скайлайн',
    aliases: ['Скайлайн', 'Skyline'],
  },
  {
    slug: 'eklips',
    name: 'Эклипс',
    aliases: ['Эклипс', 'Eclipse'],
  },
  {
    slug: 'auris',
    name: 'Аурис',
    aliases: ['Аурис', 'Auris'],
  },
  {
    slug: 'nova',
    name: 'Нова',
    aliases: ['Нова', 'Nova'],
  },
  {
    slug: 'nl-vud',
    name: 'НЛ Вуд',
    aliases: ['НЛ Вуд', 'NL Wood'],
  },
  {
    slug: 'klajmb',
    name: 'Клаймб',
    aliases: ['Клаймб', 'Climb'],
  },
  {
    slug: 'manetik',
    name: 'Манетик',
    aliases: ['Манетик', 'Magnetic'],
  },
  {
    slug: 'saturn',
    name: 'Сатурн',
    aliases: ['Сатурн', 'Saturn'],
  },
  {
    slug: 'playwood',
    name: 'Плэй Вуд',
    aliases: ['Плэй Вуд', 'Playwood', 'Play Wood'],
  },
];

const aliasesByLength = ITALON_COLLECTIONS.flatMap((collection) =>
  collection.aliases.map((alias) => ({
    alias: alias.toLowerCase(),
    collection,
  })),
).sort((a, b) => b.alias.length - a.alias.length);

export function matchItalonCollection(title: string): ItalonCollection | null {
  const normalized = title.trim().toLowerCase();
  for (const entry of aliasesByLength) {
    if (
      normalized === entry.alias ||
      normalized.startsWith(`${entry.alias} `)
    ) {
      return entry.collection;
    }
  }
  return null;
}
