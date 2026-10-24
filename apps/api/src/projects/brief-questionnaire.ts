export type BriefField = {
  id: string;
  label: string;
  /** Rows of answer buttons in the app; '' is stored under the field id, others under «id.key». */
  groups?: Array<{ key: string; label?: string }>;
};

export type BriefRoomSection = {
  id: string;
  title: string;
  fields: BriefField[];
};

export const BRIEF_INTRO =
  'На основании данной анкеты и приложенных к ней файлов я буду проектировать ваш интерьер. Прошу максимально точно и развернуто описать все пожелания, чтобы результат моей работы обрадовал вас.';

export const BRIEF_GENERAL_FIELDS: BriefField[] = [
  { id: 'address', label: 'Адрес (город, ЖК, улица, дом, квартира)' },
  { id: 'phone', label: 'Контактный телефон' },
  { id: 'email', label: 'Электронная почта' },
  { id: 'objectType', label: 'Тип объекта' },
  { id: 'floors', label: 'Количество этажей' },
  { id: 'area', label: 'Площадь, м²' },
  { id: 'commercialType', label: 'Тип коммерческого объекта' },
  { id: 'householdKind', label: 'Кто будет жить' },
  { id: 'householdMembers', label: 'Состав семьи' },
  { id: 'household', label: 'Состав проживающих (имена и возраст)' },
  { id: 'kids', label: 'Дети' },
  { id: 'pets', label: 'Домашние животные' },
  { id: 'routine', label: 'Распорядок дня' },
  { id: 'routineNote', label: 'Уточнение к распорядку' },
  { id: 'hobbies', label: 'Хобби' },
  { id: 'hobbiesNote', label: 'Уточнение к хобби' },
  { id: 'interests', label: 'Что обязательно должно быть дома' },
  { id: 'interestsNote', label: 'Уточнение к увлечениям' },
  { id: 'likedColors', label: 'Цвета, которые нравятся' },
  { id: 'likedStyles', label: 'Стили, которые нравятся' },
  { id: 'likedStylesCustom', label: 'Свой стиль' },
  { id: 'disliked', label: 'Что категорически не нравится' },
  { id: 'dislikedNote', label: 'Комментарий' },
  { id: 'budget', label: 'Бюджет на ремонт' },
  { id: 'replan', label: 'Перепланировка: стены оставляем или двигаем?' },
  { id: 'zones', label: 'Комнаты и зоны в помещении' },
  { id: 'split', label: 'Кондиционер' },
  {
    id: 'gadgetOutlets',
    label: 'Розетки под гаджеты (робот-пылесос, увлажнитель и т.д.)',
  },
  { id: 'radiators', label: 'Что меняем' },
  { id: 'floorHeating', label: 'Тёплый пол' },
  { id: 'washerLocation', label: 'Где планируется стиральная машина?' },
  { id: 'replanNote', label: 'Перепланировка — комментарий' },
  { id: 'radiatorsNote', label: 'Что меняем — комментарий' },
  { id: 'splitNote', label: 'Кондиционер — комментарий' },
  { id: 'gadgetOutletsNote', label: 'Розетки — комментарий' },
  { id: 'floorHeatingNote', label: 'Тёплый пол — комментарий' },
  { id: 'washerLocationNote', label: 'Стиральная машина — комментарий' },
  { id: 'details', label: 'Важные детали' },
  {
    id: 'existingItems',
    label:
      'Уже купленные и переезжающие вещи (ссылки, если нет ссылки — фото и размеры)',
  },
];

const ROOM_TITLES: Record<string, string> = {
  kitchen: 'Кухня',
  kitchen_living: 'Кухня-гостиная',
  hallway: 'Прихожая',
  bedroom: 'Спальня',
  bathroom: 'Санузел',
  wardrobe: 'Гардеробная',
  kids: 'Детская',
  loggia: 'Лоджия',
};

export const BRIEF_VALUE_LABELS: Record<string, Record<string, string>> = {
  likedColors: {
    ivory: 'Слоновая кость',
    sand: 'Песок',
    taupe: 'Тауп',
    clay: 'Глина',
    terracotta: 'Терракота',
    blush: 'Пыльная роза',
    burgundy: 'Бордо',
    sage: 'Шалфей',
    olive: 'Олива',
    forest: 'Лес',
    dustyBlue: 'Пыльный синий',
    navy: 'Navy',
    graphite: 'Графит',
    charcoal: 'Уголь',
    mustard: 'Горчица',
    cream: 'Крем',
    metal: 'Металл',
  },
  likedStyles: {
    scandi: 'Скандинавский',
    minimal: 'Минимализм',
    japandi: 'Джапанди',
    classic: 'Современная классика',
    classical: 'Классический',
    provence: 'Прованс',
    loft: 'Лофт',
    mediterranean: 'Средиземноморский',
    eclectic: 'Эклектика',
  },
  objectType: {
    apartment: 'Квартира',
    house: 'Дом',
    office: 'Офис',
    commercial: 'Коммерческое помещение',
    townhouse: 'Таунхаус',
  },
  commercialType: {
    office: 'Офис',
    retail: 'Магазин / шоурум',
    cafe: 'Кафе / ресторан',
    clinic: 'Клиника',
    salon: 'Салон / студия',
    coworking: 'Коворкинг',
    other: 'Другое',
  },
  kitchenLayout: {
    kitchen: 'Кухня',
    kitchen_living: 'Кухня-гостиная',
  },
  householdKind: {
    alone: 'Живу один / одна',
    couple: 'Пара',
    family: 'Семья',
    generations: 'Несколько поколений',
  },
  kids: {
    none: 'Без детей',
    toddler: 'Малыш',
    preschool: 'Дошкольник',
    school: 'Школьник',
    teen: 'Подросток',
  },
  pets: {
    none: 'Нет',
    cat: 'Кошка',
    dog: 'Собака',
    other: 'Другое',
  },
  routine: {
    morningsHome: 'Утро дома',
    workFromHome: 'Работаю из дома',
    cookOften: 'Часто готовлю',
    guestsOften: 'Часто гости',
    eveningsHome: 'Вечера дома',
    rarelyHome: 'Редко бываю дома',
  },
  hobbies: {
    reading: 'Чтение',
    cinema: 'Кино',
    sport: 'Спорт',
    cooking: 'Готовка',
    plants: 'Растения',
    music: 'Музыка',
    guests: 'Приём гостей',
    boardgames: 'Настолки',
    yoga: 'Йога',
    collecting: 'Коллекции',
  },
  interests: {
    bigKitchen: 'Большая кухня',
    homeOffice: 'Домашний офис',
    wardrobe: 'Гардеробная',
    cinema: 'Кинозал',
    sport: 'Спорт дома',
    pets: 'Зона для питомцев',
    guests: 'Гостевая',
    library: 'Библиотека',
  },
  disliked: {
    bright: 'Яркие цвета',
    coldGrey: 'Холодный серый',
    goldStucco: 'Золото и лепнина',
    loft: 'Лофт / бетон',
    classic: 'Классика',
    gloss: 'Глянец',
    darkWalls: 'Тёмные стены',
    country: 'Кантри',
    hightech: 'Хай-тек',
  },
  budget: {
    upto2: 'До 2 млн',
    '2_4': '2–4 млн',
    '4_7': '4–7 млн',
    '7_12': '7–12 млн',
    from12: 'От 12 млн',
    undecided: 'Пока не решили',
  },
  replan: {
    full: 'Полная перепланировка',
    partial: 'Частично',
    keep: 'Стены оставляем',
  },
  // Conditioner and warm floor are picked per room; old answers keep their labels.
  floorHeating: {
    all: 'Везде',
    wet: 'В мокрых зонах',
    no: 'Не нужен',
    later: 'Решим позже',
    ...ROOM_TITLES,
    none: 'Не нужен',
  },
  washerLocation: {
    bathroom: 'В ванной',
    kitchen: 'На кухне',
    laundry: 'Постирочная',
    unknown: 'Пока не знаем',
  },
  split: {
    living: 'Гостиная',
    bedrooms: 'Спальни',
    all: 'Во всех комнатах',
    no: 'Не нужен',
    ...ROOM_TITLES,
    none: 'Не нужен',
  },
  gadgetOutlets: {
    yes: 'Да, заложить',
    no: 'Не нужно',
    later: 'Решим позже',
    robot: 'Робот-пылесос',
    humidifier: 'Увлажнитель',
    bedside: 'Зарядки у кровати',
    none: 'Нет',
  },
  radiators: {
    replace: 'Меняем всё',
    keep: 'Оставляем',
    later: 'Решим позже',
    radiators: 'Радиаторы',
    windows: 'Окна',
    sills: 'Подоконники',
    entranceDoor: 'Входная дверь',
    doors: 'Межкомнатные двери',
    none: 'Ничего не меняем',
  },
};

export function formatBriefValue(fieldId: string, raw?: string): string {
  if (!raw?.trim()) return '';
  const map = BRIEF_VALUE_LABELS[fieldId];
  if (!map) return raw.trim();
  return raw
    .split(',')
    .map((part) => part.trim())
    .filter(Boolean)
    .map((id) => map[id] ?? id)
    .join(', ');
}

/** Same questions as the app (apps/mobile/.../brief_questionnaire.dart). */
export const BRIEF_ROOM_SECTIONS: BriefRoomSection[] = [
  {
    id: 'kitchen',
    title: 'Кухня',
    fields: [
      {
        id: 'lighting',
        label: 'Какое освещение предусмотреть?',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'finishes',
        label: 'Предпочтения по отделке',
        groups: [
          {
            key: 'floor',
            label: 'Пол',
          },
          {
            key: 'walls',
            label: 'Стены',
          },
          {
            key: 'apron',
            label: 'Фартук',
          },
        ],
      },
      {
        id: 'hood',
        label: 'Вытяжка',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'diningTable',
        label: 'Обеденный стол',
        groups: [
          {
            key: '',
          },
          {
            key: 'seats',
            label: 'Мест',
          },
        ],
      },
      {
        id: 'island',
        label: 'Стол-остров',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'dishwasher',
        label: 'Посудомойка',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'cooktop',
        label: 'Варочная панель',
        groups: [
          {
            key: '',
          },
          {
            key: 'type',
            label: 'Тип',
          },
        ],
      },
      {
        id: 'oven',
        label: 'Духовой шкаф',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'fridge',
        label: 'Холодильник',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'other',
        label: 'Что ещё необходимо учесть?',
      },
    ],
  },
  {
    id: 'kitchen_living',
    title: 'Кухня-гостиная',
    fields: [
      {
        id: 'lighting',
        label: 'Какое освещение предусмотреть?',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'finishes',
        label: 'Предпочтения по отделке',
        groups: [
          {
            key: 'floor',
            label: 'Пол',
          },
          {
            key: 'walls',
            label: 'Стены',
          },
          {
            key: 'apron',
            label: 'Фартук',
          },
        ],
      },
      {
        id: 'doorFromHall',
        label: 'Дверь из прихожей',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'sofa',
        label: 'Диван',
        groups: [
          {
            key: '',
          },
          {
            key: 'size',
            label: 'Размер',
          },
        ],
      },
      {
        id: 'extraFurniture',
        label: 'Кресла, столик, рабочее место, камин',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'shelves',
        label: 'Стеллаж / открытые полки',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'hood',
        label: 'Вытяжка',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'diningTable',
        label: 'Обеденный стол',
        groups: [
          {
            key: '',
          },
          {
            key: 'seats',
            label: 'Мест',
          },
        ],
      },
      {
        id: 'island',
        label: 'Стол-остров',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'dishwasher',
        label: 'Посудомойка',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'cooktop',
        label: 'Варочная панель',
        groups: [
          {
            key: '',
          },
          {
            key: 'type',
            label: 'Тип',
          },
        ],
      },
      {
        id: 'oven',
        label: 'Духовой шкаф',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'fridge',
        label: 'Холодильник',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'tv',
        label: 'ТВ',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'curtains',
        label: 'Шторы',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'other',
        label: 'Что ещё необходимо учесть?',
      },
    ],
  },
  {
    id: 'hallway',
    title: 'Прихожая',
    fields: [
      {
        id: 'finishes',
        label: 'Предпочтения по отделке',
        groups: [
          {
            key: 'floor',
            label: 'Пол',
          },
          {
            key: 'walls',
            label: 'Стены',
          },
        ],
      },
      {
        id: 'lighting',
        label: 'Какое освещение предусмотреть?',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'storage',
        label: 'Хранение',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'other',
        label: 'Что ещё необходимо учесть?',
      },
    ],
  },
  {
    id: 'bedroom',
    title: 'Спальня',
    fields: [
      {
        id: 'finishes',
        label: 'Предпочтения по отделке',
        groups: [
          {
            key: 'floor',
            label: 'Пол',
          },
          {
            key: 'walls',
            label: 'Стены',
          },
        ],
      },
      {
        id: 'lighting',
        label: 'Какое освещение предусмотреть?',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'mattress',
        label: 'Размер кровати / матраса',
        groups: [
          {
            key: 'width',
            label: 'Ширина',
          },
          {
            key: 'length',
            label: 'Длина',
          },
        ],
      },
      {
        id: 'shelves',
        label: 'Полки, тумбочки, стеллажи',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'vanity',
        label: 'Туалетный / рабочий стол',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'wardrobe',
        label: 'Хранение',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'curtains',
        label: 'Шторы',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'mirror',
        label: 'Зеркало',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'other',
        label: 'Что ещё необходимо учесть?',
      },
    ],
  },
  {
    id: 'bathroom',
    title: 'Санузел',
    fields: [
      {
        id: 'finishes',
        label: 'Предпочтения по отделке',
        groups: [
          {
            key: 'floor',
            label: 'Пол',
          },
          {
            key: 'walls',
            label: 'Стены',
          },
        ],
      },
      {
        id: 'lighting',
        label: 'Какое освещение предусмотреть?',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'bathOrShower',
        label: 'Ванна или душ',
        groups: [
          {
            key: '',
          },
          {
            key: 'bathSize',
            label: 'Размер ванны',
          },
          {
            key: 'shower',
            label: 'Душ',
          },
        ],
      },
      {
        id: 'screen',
        label: 'Шторка / перегородка',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'toilet',
        label: 'Унитаз',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'sinks',
        label: 'Раковины',
        groups: [
          {
            key: '',
            label: 'Количество',
          },
          {
            key: 'type',
            label: 'Тип',
          },
        ],
      },
      {
        id: 'bidet',
        label: 'Гигиенический душ / биде',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'makeupLight',
        label: 'Подсветка зеркала',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'storage',
        label: 'Хранение',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'towelRail',
        label: 'Полотенцесушитель',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'washerKg',
        label: 'Стиральная машина',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'dryer',
        label: 'Сушильная машина',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'other',
        label: 'Что ещё необходимо учесть?',
      },
    ],
  },
  {
    id: 'wardrobe',
    title: 'Гардеробная',
    fields: [
      {
        id: 'finishes',
        label: 'Предпочтения по отделке',
        groups: [
          {
            key: 'floor',
            label: 'Пол',
          },
          {
            key: 'walls',
            label: 'Стены',
          },
        ],
      },
      {
        id: 'lighting',
        label: 'Какое освещение предусмотреть?',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'system',
        label: 'Система хранения',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'zones',
        label: 'Зоны',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'island',
        label: 'Остров / пуф',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'mirror',
        label: 'Зеркало',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'other',
        label: 'Что ещё необходимо учесть?',
      },
    ],
  },
  {
    id: 'kids',
    title: 'Детская',
    fields: [
      {
        id: 'finishes',
        label: 'Предпочтения по отделке',
        groups: [
          {
            key: 'floor',
            label: 'Пол',
          },
          {
            key: 'walls',
            label: 'Стены',
          },
        ],
      },
      {
        id: 'lighting',
        label: 'Какое освещение предусмотреть?',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'furniture',
        label: 'Мебель',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'kidsItems',
        label: 'Что ещё',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'other',
        label: 'Что ещё необходимо учесть?',
      },
    ],
  },
  {
    id: 'loggia',
    title: 'Лоджия',
    fields: [
      {
        id: 'finishes',
        label: 'Предпочтения по отделке',
        groups: [
          {
            key: 'floor',
            label: 'Пол',
          },
          {
            key: 'walls',
            label: 'Стены',
          },
        ],
      },
      {
        id: 'lighting',
        label: 'Какое освещение предусмотреть?',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'relax',
        label: 'Релакс-зона',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'storage',
        label: 'Хранение',
        groups: [
          {
            key: '',
          },
        ],
      },
      {
        id: 'other',
        label: 'Что ещё необходимо учесть?',
      },
    ],
  },
];

/**
 * A room answer as it reads in the PDF: picked buttons per row, the comment last.
 * Answers typed as free text in the earlier version stay as they are.
 */
export function formatRoomField(
  field: BriefField,
  room: Record<string, unknown> | undefined,
): string {
  const get = (key: string) => {
    const value = room?.[key];
    return typeof value === 'string' ? value.trim() : '';
  };
  if (!field.groups?.length) return get(field.id);
  const lines: string[] = [];
  if (!field.groups.some((g) => g.key === '') && get(field.id)) {
    lines.push(get(field.id));
  }
  for (const group of field.groups) {
    const value = get(group.key ? `${field.id}.${group.key}` : field.id);
    if (value) lines.push(group.label ? `${group.label}: ${value}` : value);
  }
  const note = get(`${field.id}.note`);
  if (note) lines.push(lines.length ? `Комментарий: ${note}` : note);
  return lines.join('\n');
}

export const BRIEF_ATTACHMENTS = [
  'фотографии проектируемого помещения',
  'план БТИ',
  'референсы с комментариями (что именно понравилось на фото)',
  'ссылки на купленные или выбранные товары (если нет ссылки — фото и размеры: ширина, глубина, высота)',
];

export type BriefAnswers = {
  general?: Record<string, string>;
  rooms?: Record<string, { included?: boolean } & Record<string, string>>;
};

export function emptyBriefAnswers(): BriefAnswers {
  return { general: {}, rooms: {} };
}
