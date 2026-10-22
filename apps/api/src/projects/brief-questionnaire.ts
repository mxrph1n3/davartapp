export type BriefField = {
  id: string;
  label: string;
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
  { id: 'split', label: 'Где разместить сплит-систему (кондиционеры)?' },
  {
    id: 'gadgetOutlets',
    label: 'Розетки под гаджеты (робот-пылесос, увлажнитель и т.д.)',
  },
  { id: 'radiators', label: 'Новые радиаторы, подоконники, двери, окна' },
  { id: 'floorHeating', label: 'Тёплый пол' },
  { id: 'washerLocation', label: 'Где планируется стиральная машина?' },
  { id: 'details', label: 'Важные детали' },
  {
    id: 'existingItems',
    label:
      'Уже купленные и переезжающие вещи (ссылки, если нет ссылки — фото и размеры)',
  },
];

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
  floorHeating: {
    all: 'Везде',
    wet: 'В мокрых зонах',
    no: 'Не нужен',
    later: 'Решим позже',
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
  },
  gadgetOutlets: {
    yes: 'Да, заложить',
    no: 'Не нужно',
    later: 'Решим позже',
  },
  radiators: {
    replace: 'Меняем всё',
    keep: 'Оставляем',
    later: 'Решим позже',
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

const finishes = (extra = ''): BriefField => ({
  id: 'finishes',
  label: `Предпочтения по отделке (пол, стены${extra})?`,
});

const lighting: BriefField = {
  id: 'lighting',
  label: 'Какое освещение предусмотреть?',
};

const other: BriefField = {
  id: 'other',
  label: 'Что еще необходимо учесть?',
};

export const BRIEF_ROOM_SECTIONS: BriefRoomSection[] = [
  {
    id: 'kitchen',
    title: 'Кухня',
    fields: [
      lighting,
      finishes(', фартук'),
      {
        id: 'hood',
        label: 'Вытяжка встроенная в кухню или отдельностоящая?',
      },
      {
        id: 'diningTable',
        label: 'Есть ли предпочтения по форме обеденного стола и по материалу?',
      },
      { id: 'island', label: 'Нужен ли стол-остров?' },
      {
        id: 'dishwasher',
        label: 'Нужна ли посудомойка? Какого размера?',
      },
      { id: 'cooktop', label: 'На сколько конфорок варочная панель?' },
      {
        id: 'oven',
        label:
          'Нужен ли духовой шкаф? Рассматриваете ли вариант духовка 2в1 (с функцией свч), или нужна отдельная микроволновка?',
      },
      {
        id: 'fridge',
        label: 'Холодильник встроенный или отдельностоящий?',
      },
      other,
    ],
  },
  {
    id: 'kitchen_living',
    title: 'Кухня-гостиная',
    fields: [
      lighting,
      finishes(', фартук'),
      { id: 'doorFromHall', label: 'Нужна ли дверь из прихожей?' },
      {
        id: 'sofa',
        label:
          'Нужен ли диван (прямой, угловой, большой, маленький, раскладной, мягкий, жесткий)?',
      },
      {
        id: 'extraFurniture',
        label: 'Нужны ли кресла, журнальный столик, рабочее место, камин и тд?',
      },
      { id: 'shelves', label: 'Нужен ли стеллаж или открытые полки?' },
      {
        id: 'hood',
        label: 'Вытяжка встроенная в кухню или отдельностоящая?',
      },
      {
        id: 'diningTable',
        label:
          'Есть ли предпочтения по форме обеденного стола и по материалу? Должен ли он раскладываться? На какое количество персон в разложенном и сложенном видах?',
      },
      { id: 'island', label: 'Нужен ли стол-остров?' },
      { id: 'dishwasher', label: 'Нужна ли посудомойка? Какого размера?' },
      { id: 'cooktop', label: 'На сколько конфорок варочная панель?' },
      {
        id: 'oven',
        label:
          'Нужен ли духовой шкаф? Рассматриваете ли вариант духовка 2в1 (с функцией свч), или нужна отдельная микроволновка?',
      },
      {
        id: 'fridge',
        label: 'Холодильник встроенный или отдельностоящий?',
      },
      { id: 'tv', label: 'Нужен ли тв?' },
      { id: 'curtains', label: 'Нужны ли шторы, римские шторы и тд?' },
      other,
    ],
  },
  {
    id: 'hallway',
    title: 'Прихожая',
    fields: [
      finishes(),
      lighting,
      {
        id: 'storage',
        label:
          'Нужны ли открытые вешалки, пуф, шкаф, полочки для ключей и перчаток, зеркало в полный рост, зеркало для макияжа?',
      },
      other,
    ],
  },
  {
    id: 'bedroom',
    title: 'Спальня',
    fields: [
      finishes(),
      lighting,
      { id: 'mattress', label: 'Размер матраса на кровать?' },
      {
        id: 'shelves',
        label: 'Нужны ли полочки, прикроватные тумбочки или стеллажи?',
      },
      {
        id: 'vanity',
        label: 'Нужен ли туалетный столик для макияжа или рабочий стол?',
      },
      {
        id: 'wardrobe',
        label: 'Нужен ли комод, шкаф, гардеробная? Каких размеров?',
      },
      { id: 'curtains', label: 'Нужны ли шторы, римские шторы?' },
      { id: 'mirror', label: 'Нужно ли зеркало?' },
      other,
    ],
  },
  {
    id: 'bathroom',
    title: 'Санузел',
    fields: [
      finishes(),
      lighting,
      { id: 'bathOrShower', label: 'Ванна или душ? Размеры?' },
      {
        id: 'screen',
        label: 'Шторка для ванны или стеклянная перегородка?',
      },
      {
        id: 'toilet',
        label: 'Унитаз обычный или подвесной со скрытой инсталляцией?',
      },
      { id: 'sinks', label: 'Количество раковин?' },
      { id: 'bidet', label: 'Нужен ли гигиенический душ или биде?' },
      {
        id: 'makeupLight',
        label: 'Нужно ли к зеркалу освещение для макияжа или бьюти-процедур?',
      },
      { id: 'storage', label: 'Какие нужны места для хранения?' },
      {
        id: 'towelRail',
        label:
          'Какой полотенцесушитель предпочитаете: электрический или водяной?',
      },
      { id: 'washerKg', label: 'На сколько кг стиральная машина?' },
      { id: 'dryer', label: 'Нужна ли сушильная машина?' },
      other,
    ],
  },
  {
    id: 'wardrobe',
    title: 'Гардеробная',
    fields: [
      finishes(),
      lighting,
      {
        id: 'system',
        label: 'Какая система хранения нужна: корпусная, встроенная, открытая?',
      },
      {
        id: 'zones',
        label: 'Какие зоны нужны: одежда, обувь, сумки, бельё?',
      },
      { id: 'island', label: 'Нужен ли остров / пуф в гардеробной?' },
      { id: 'mirror', label: 'Нужно ли зеркало?' },
      other,
    ],
  },
  {
    id: 'kids',
    title: 'Детская',
    fields: [
      finishes(),
      lighting,
      {
        id: 'furniture',
        label:
          'Нужны ли рабочее место, шкаф, комод, кровать или диван (и размер матраса), тумбочка прикроватная, стеллажи, полки, шторы, ковер и тд?',
      },
      {
        id: 'kidsItems',
        label:
          'Нужны ли детские предметы (вигвам, бизи-борд, бассейн с шариками, шведская стенка, столик со стульчиком, ночник и тд)?',
      },
      other,
    ],
  },
  {
    id: 'loggia',
    title: 'Лоджия',
    fields: [
      finishes(),
      lighting,
      {
        id: 'relax',
        label: 'Нужна ли релакс-зона с креслом и столиком?',
      },
      { id: 'storage', label: 'Нужно ли место для хранения (шкаф)?' },
      other,
    ],
  },
];

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
