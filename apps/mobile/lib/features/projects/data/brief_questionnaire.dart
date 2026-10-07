import 'dart:convert';

class BriefField {
  const BriefField({required this.id, required this.label, this.lines = 3});

  final String id;
  final String label;
  final int lines;
}

class BriefRoomSection {
  const BriefRoomSection({
    required this.id,
    required this.title,
    required this.fields,
  });

  final String id;
  final String title;
  final List<BriefField> fields;

  String get imageAsset {
    if (id == 'kitchen') return 'assets/brief/rooms/kitchen_living.jpg';
    if (id == 'wardrobe') return 'assets/brief/rooms/hallway.jpg';
    return 'assets/brief/rooms/$id.jpg';
  }
}

class BriefChoice {
  const BriefChoice({required this.id, required this.label});

  final String id;
  final String label;
}

class BriefColorSwatch {
  const BriefColorSwatch({
    required this.id,
    required this.label,
    required this.hex,
  });

  final String id;
  final String label;
  final int hex;
}

class BriefVisualOption {
  const BriefVisualOption({
    required this.id,
    required this.label,
    required this.asset,
  });

  final String id;
  final String label;
  final String asset;
}

const briefIntro =
    'На основании данной анкеты и приложенных к ней файлов я буду проектировать ваш интерьер. Прошу максимально точно и развернуто описать все пожелания, чтобы результат моей работы обрадовал вас.';

const briefColorSwatches = <BriefColorSwatch>[
  BriefColorSwatch(id: 'ivory', label: 'Слоновая кость', hex: 0xFFF4EFE4),
  BriefColorSwatch(id: 'sand', label: 'Песок', hex: 0xFFE4D4B8),
  BriefColorSwatch(id: 'taupe', label: 'Тауп', hex: 0xFFA89880),
  BriefColorSwatch(id: 'clay', label: 'Глина', hex: 0xFFB07A5C),
  BriefColorSwatch(id: 'terracotta', label: 'Терракота', hex: 0xFFC45C3E),
  BriefColorSwatch(id: 'blush', label: 'Пыльная роза', hex: 0xFFE2B8B0),
  BriefColorSwatch(id: 'burgundy', label: 'Бордо', hex: 0xFF6E3038),
  BriefColorSwatch(id: 'sage', label: 'Шалфей', hex: 0xFF9AAE96),
  BriefColorSwatch(id: 'olive', label: 'Олива', hex: 0xFF7A7A4E),
  BriefColorSwatch(id: 'forest', label: 'Лес', hex: 0xFF3D5344),
  BriefColorSwatch(id: 'dustyBlue', label: 'Пыльный синий', hex: 0xFF7D93A8),
  BriefColorSwatch(id: 'navy', label: 'Navy', hex: 0xFF2C3D55),
  BriefColorSwatch(id: 'graphite', label: 'Графит', hex: 0xFF4A4A4A),
  BriefColorSwatch(id: 'charcoal', label: 'Уголь', hex: 0xFF2A2A2A),
  BriefColorSwatch(id: 'mustard', label: 'Горчица', hex: 0xFFC4A04A),
  BriefColorSwatch(id: 'cream', label: 'Крем', hex: 0xFFFAF6EE),
  BriefColorSwatch(id: 'metal', label: 'Металл', hex: 0xFF8A9098),
];

const briefStyleOptions = <BriefVisualOption>[
  BriefVisualOption(
    id: 'scandi',
    label: 'Скандинавский',
    asset: 'assets/brief/styles/scandi.jpg',
  ),
  BriefVisualOption(
    id: 'minimal',
    label: 'Минимализм',
    asset: 'assets/brief/styles/minimal.jpg',
  ),
  BriefVisualOption(
    id: 'japandi',
    label: 'Джапанди',
    asset: 'assets/brief/styles/japandi.jpg',
  ),
  BriefVisualOption(
    id: 'classic',
    label: 'Современная классика',
    asset: 'assets/brief/styles/classic.jpg',
  ),
  BriefVisualOption(
    id: 'classical',
    label: 'Классический',
    asset: 'assets/brief/styles/classic.jpg',
  ),
  BriefVisualOption(
    id: 'travans',
    label: 'Траванс',
    asset: 'assets/brief/styles/classic.jpg',
  ),
  BriefVisualOption(
    id: 'provence',
    label: 'Прованс',
    asset: 'assets/brief/styles/mediterranean.jpg',
  ),
  BriefVisualOption(
    id: 'loft',
    label: 'Лофт',
    asset: 'assets/brief/styles/loft.jpg',
  ),
  BriefVisualOption(
    id: 'mediterranean',
    label: 'Средиземноморский',
    asset: 'assets/brief/styles/mediterranean.jpg',
  ),
  BriefVisualOption(
    id: 'eclectic',
    label: 'Эклектика',
    asset: 'assets/brief/styles/eclectic.jpg',
  ),
];

const briefObjectOptions = <BriefVisualOption>[
  BriefVisualOption(
    id: 'apartment',
    label: 'Квартира',
    asset: 'assets/brief/objects/apartment.jpg',
  ),
  BriefVisualOption(
    id: 'house',
    label: 'Дом',
    asset: 'assets/brief/objects/house.jpg',
  ),
  BriefVisualOption(
    id: 'office',
    label: 'Офис',
    asset: 'assets/brief/objects/townhouse.jpg',
  ),
  BriefVisualOption(
    id: 'commercial',
    label: 'Коммерческое помещение',
    asset: 'assets/brief/objects/townhouse.jpg',
  ),
];

const briefCommercialTypeChoices = <BriefChoice>[
  BriefChoice(id: 'office', label: 'Офис'),
  BriefChoice(id: 'retail', label: 'Магазин / шоурум'),
  BriefChoice(id: 'cafe', label: 'Кафе / ресторан'),
  BriefChoice(id: 'clinic', label: 'Клиника'),
  BriefChoice(id: 'salon', label: 'Салон / студия'),
  BriefChoice(id: 'coworking', label: 'Коворкинг'),
  BriefChoice(id: 'other', label: 'Другое'),
];

const briefFamilyRoleChoices = <BriefChoice>[
  BriefChoice(id: 'self', label: 'Я'),
  BriefChoice(id: 'partner', label: 'Супруг'),
  BriefChoice(id: 'child', label: 'Ребёнок'),
  BriefChoice(id: 'parent', label: 'Родитель'),
  BriefChoice(id: 'relative', label: 'Родственник'),
  BriefChoice(id: 'other', label: 'Другой'),
];

const briefKitchenLayoutChoices = <BriefChoice>[
  BriefChoice(id: 'kitchen', label: 'Кухня'),
  BriefChoice(id: 'kitchen_living', label: 'Кухня-гостиная'),
];

const briefHouseholdChoices = <BriefChoice>[
  BriefChoice(id: 'alone', label: 'Живу один / одна'),
  BriefChoice(id: 'couple', label: 'Пара'),
  BriefChoice(id: 'family', label: 'Семья'),
  BriefChoice(id: 'generations', label: 'Несколько поколений'),
];

const briefKidsChoices = <BriefChoice>[
  BriefChoice(id: 'none', label: 'Без детей'),
  BriefChoice(id: 'toddler', label: 'Малыш'),
  BriefChoice(id: 'preschool', label: 'Дошкольник'),
  BriefChoice(id: 'school', label: 'Школьник'),
  BriefChoice(id: 'teen', label: 'Подросток'),
];

const briefPetChoices = <BriefChoice>[
  BriefChoice(id: 'none', label: 'Нет'),
  BriefChoice(id: 'cat', label: 'Кошка'),
  BriefChoice(id: 'dog', label: 'Собака'),
  BriefChoice(id: 'other', label: 'Другое'),
];

const briefRoutineChoices = <BriefChoice>[
  BriefChoice(id: 'morningsHome', label: 'Утро дома'),
  BriefChoice(id: 'workFromHome', label: 'Работаю из дома'),
  BriefChoice(id: 'cookOften', label: 'Часто готовлю'),
  BriefChoice(id: 'guestsOften', label: 'Часто гости'),
  BriefChoice(id: 'eveningsHome', label: 'Вечера дома'),
  BriefChoice(id: 'rarelyHome', label: 'Редко бываю дома'),
];

const briefHobbyChoices = <BriefChoice>[
  BriefChoice(id: 'reading', label: 'Чтение'),
  BriefChoice(id: 'cinema', label: 'Кино'),
  BriefChoice(id: 'sport', label: 'Спорт'),
  BriefChoice(id: 'cooking', label: 'Готовка'),
  BriefChoice(id: 'plants', label: 'Растения'),
  BriefChoice(id: 'music', label: 'Музыка'),
  BriefChoice(id: 'guests', label: 'Приём гостей'),
  BriefChoice(id: 'boardgames', label: 'Настолки'),
  BriefChoice(id: 'yoga', label: 'Йога'),
  BriefChoice(id: 'collecting', label: 'Коллекции'),
];

const briefInterestChoices = <BriefChoice>[
  BriefChoice(id: 'bigKitchen', label: 'Большая кухня'),
  BriefChoice(id: 'homeOffice', label: 'Домашний офис'),
  BriefChoice(id: 'wardrobe', label: 'Гардеробная'),
  BriefChoice(id: 'cinema', label: 'Кинозал'),
  BriefChoice(id: 'sport', label: 'Спорт дома'),
  BriefChoice(id: 'pets', label: 'Зона для питомцев'),
  BriefChoice(id: 'guests', label: 'Гостевая'),
  BriefChoice(id: 'library', label: 'Библиотека'),
];

const briefDislikeChoices = <BriefChoice>[
  BriefChoice(id: 'bright', label: 'Яркие цвета'),
  BriefChoice(id: 'coldGrey', label: 'Холодный серый'),
  BriefChoice(id: 'goldStucco', label: 'Золото и лепнина'),
  BriefChoice(id: 'loft', label: 'Лофт / бетон'),
  BriefChoice(id: 'classic', label: 'Классика'),
  BriefChoice(id: 'gloss', label: 'Глянец'),
  BriefChoice(id: 'darkWalls', label: 'Тёмные стены'),
  BriefChoice(id: 'country', label: 'Кантри'),
  BriefChoice(id: 'hightech', label: 'Хай-тек'),
];

const briefBudgetChoices = <BriefChoice>[
  BriefChoice(id: 'upto2', label: 'До 2 млн'),
  BriefChoice(id: '2_4', label: '2–4 млн'),
  BriefChoice(id: '4_7', label: '4–7 млн'),
  BriefChoice(id: '7_12', label: '7–12 млн'),
  BriefChoice(id: 'from12', label: 'От 12 млн'),
  BriefChoice(id: 'undecided', label: 'Пока не решили'),
];

const briefReplanChoices = <BriefChoice>[
  BriefChoice(id: 'full', label: 'Полная перепланировка'),
  BriefChoice(id: 'partial', label: 'Частично'),
  BriefChoice(id: 'keep', label: 'Стены оставляем'),
];

const briefFloorHeatingChoices = <BriefChoice>[
  BriefChoice(id: 'all', label: 'Везде'),
  BriefChoice(id: 'wet', label: 'В мокрых зонах'),
  BriefChoice(id: 'no', label: 'Не нужен'),
  BriefChoice(id: 'later', label: 'Решим позже'),
];

const briefWasherChoices = <BriefChoice>[
  BriefChoice(id: 'bathroom', label: 'В ванной'),
  BriefChoice(id: 'kitchen', label: 'На кухне'),
  BriefChoice(id: 'laundry', label: 'Постирочная'),
  BriefChoice(id: 'unknown', label: 'Пока не знаем'),
];

const briefSplitChoices = <BriefChoice>[
  BriefChoice(id: 'living', label: 'Гостиная'),
  BriefChoice(id: 'bedrooms', label: 'Спальни'),
  BriefChoice(id: 'all', label: 'Во всех комнатах'),
  BriefChoice(id: 'no', label: 'Не нужен'),
];

const briefGadgetChoices = <BriefChoice>[
  BriefChoice(id: 'yes', label: 'Да, заложить'),
  BriefChoice(id: 'no', label: 'Не нужно'),
  BriefChoice(id: 'later', label: 'Решим позже'),
];

const briefRadiatorChoices = <BriefChoice>[
  BriefChoice(id: 'replace', label: 'Меняем всё'),
  BriefChoice(id: 'keep', label: 'Оставляем'),
  BriefChoice(id: 'later', label: 'Решим позже'),
];

const briefDefaultRoomsByObject = <String, List<String>>{
  'apartment': ['hallway', 'kitchen_living', 'bedroom', 'bathroom', 'loggia'],
  'house': ['hallway', 'kitchen_living', 'bedroom', 'bathroom', 'kids'],
  'office': ['hallway', 'kitchen_living', 'bathroom'],
  'commercial': ['hallway', 'kitchen_living', 'bathroom'],
  'townhouse': [
    'hallway',
    'kitchen_living',
    'bedroom',
    'bathroom',
    'kids',
    'loggia',
  ],
};

const briefGeneralFields = <BriefField>[
  BriefField(
    id: 'address',
    label: 'Адрес (город, ЖК, улица, дом, квартира)',
    lines: 2,
  ),
  BriefField(id: 'phone', label: 'Контактный телефон', lines: 1),
  BriefField(id: 'email', label: 'Электронная почта', lines: 1),
  BriefField(id: 'objectType', label: 'Тип объекта', lines: 1),
  BriefField(id: 'floors', label: 'Количество этажей', lines: 1),
  BriefField(id: 'area', label: 'Площадь, м²', lines: 1),
  BriefField(id: 'commercialType', label: 'Тип коммерческого объекта', lines: 1),
  BriefField(id: 'householdKind', label: 'Кто будет жить', lines: 1),
  BriefField(id: 'householdMembers', label: 'Состав семьи'),
  BriefField(id: 'household', label: 'Состав проживающих (имена и возраст)'),
  BriefField(id: 'kids', label: 'Дети', lines: 1),
  BriefField(id: 'pets', label: 'Домашние животные', lines: 1),
  BriefField(id: 'routine', label: 'Распорядок дня', lines: 2),
  BriefField(id: 'routineNote', label: 'Уточнение к распорядку', lines: 2),
  BriefField(id: 'hobbies', label: 'Хобби', lines: 2),
  BriefField(id: 'hobbiesNote', label: 'Уточнение к хобби', lines: 2),
  BriefField(
    id: 'interests',
    label: 'Что обязательно должно быть дома',
    lines: 2,
  ),
  BriefField(id: 'interestsNote', label: 'Уточнение к увлечениям', lines: 2),
  BriefField(id: 'likedColors', label: 'Цвета, которые нравятся', lines: 1),
  BriefField(id: 'likedStyles', label: 'Стили, которые нравятся', lines: 1),
  BriefField(id: 'likedStylesCustom', label: 'Свой стиль', lines: 1),
  BriefField(id: 'disliked', label: 'Что категорически не нравится', lines: 2),
  BriefField(id: 'budget', label: 'Бюджет на ремонт', lines: 1),
  BriefField(
    id: 'replan',
    label: 'Перепланировка: стены оставляем или двигаем?',
    lines: 2,
  ),
  BriefField(id: 'zones', label: 'Комнаты и зоны в помещении'),
  BriefField(
    id: 'split',
    label: 'Где разместить сплит-систему (кондиционеры)?',
  ),
  BriefField(
    id: 'gadgetOutlets',
    label: 'Розетки под гаджеты (робот-пылесос, увлажнитель и т.д.)',
  ),
  BriefField(
    id: 'radiators',
    label: 'Новые радиаторы, подоконники, двери, окна',
  ),
  BriefField(id: 'floorHeating', label: 'Тёплый пол', lines: 1),
  BriefField(
    id: 'washerLocation',
    label: 'Где планируется стиральная машина?',
    lines: 2,
  ),
  BriefField(id: 'details', label: 'Важные детали'),
  BriefField(
    id: 'existingItems',
    label:
        'Уже купленные и переезжающие вещи (ссылки, если нет ссылки — фото и размеры)',
    lines: 4,
  ),
];

const _lighting = BriefField(
  id: 'lighting',
  label: 'Какое освещение предусмотреть?',
);
const _other = BriefField(id: 'other', label: 'Что еще необходимо учесть?');

const briefRoomSections = <BriefRoomSection>[
  BriefRoomSection(
    id: 'kitchen',
    title: 'Кухня',
    fields: [
      _lighting,
      BriefField(
        id: 'finishes',
        label: 'Предпочтения по отделке (пол, стены, фартук)?',
      ),
      BriefField(
        id: 'hood',
        label: 'Вытяжка встроенная в кухню или отдельностоящая?',
      ),
      BriefField(
        id: 'diningTable',
        label:
            'Есть ли предпочтения по форме обеденного стола и по материалу?',
        lines: 4,
      ),
      BriefField(id: 'island', label: 'Нужен ли стол-остров?'),
      BriefField(
        id: 'dishwasher',
        label: 'Нужна ли посудомойка? Какого размера?',
      ),
      BriefField(id: 'cooktop', label: 'На сколько конфорок варочная панель?'),
      BriefField(
        id: 'oven',
        label:
            'Нужен ли духовой шкаф? Рассматриваете ли вариант духовка 2в1 (с функцией свч), или нужна отдельная микроволновка?',
      ),
      BriefField(
        id: 'fridge',
        label: 'Холодильник встроенный или отдельностоящий?',
      ),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'kitchen_living',
    title: 'Кухня-гостиная',
    fields: [
      _lighting,
      BriefField(
        id: 'finishes',
        label: 'Предпочтения по отделке (пол, стены, фартук)?',
      ),
      BriefField(id: 'doorFromHall', label: 'Нужна ли дверь из прихожей?'),
      BriefField(
        id: 'sofa',
        label:
            'Нужен ли диван (прямой, угловой, большой, маленький, раскладной, мягкий, жесткий)?',
      ),
      BriefField(
        id: 'extraFurniture',
        label: 'Нужны ли кресла, журнальный столик, рабочее место, камин и тд?',
      ),
      BriefField(id: 'shelves', label: 'Нужен ли стеллаж или открытые полки?'),
      BriefField(
        id: 'hood',
        label: 'Вытяжка встроенная в кухню или отдельностоящая?',
      ),
      BriefField(
        id: 'diningTable',
        label:
            'Есть ли предпочтения по форме обеденного стола и по материалу? Должен ли он раскладываться? На какое количество персон в разложенном и сложенном видах?',
        lines: 4,
      ),
      BriefField(id: 'island', label: 'Нужен ли стол-остров?'),
      BriefField(
        id: 'dishwasher',
        label: 'Нужна ли посудомойка? Какого размера?',
      ),
      BriefField(id: 'cooktop', label: 'На сколько конфорок варочная панель?'),
      BriefField(
        id: 'oven',
        label:
            'Нужен ли духовой шкаф? Рассматриваете ли вариант духовка 2в1 (с функцией свч), или нужна отдельная микроволновка?',
      ),
      BriefField(
        id: 'fridge',
        label: 'Холодильник встроенный или отдельностоящий?',
      ),
      BriefField(id: 'tv', label: 'Нужен ли тв?'),
      BriefField(id: 'curtains', label: 'Нужны ли шторы, римские шторы и тд?'),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'hallway',
    title: 'Прихожая',
    fields: [
      BriefField(
        id: 'finishes',
        label: 'Предпочтения по отделке (пол, стены)?',
      ),
      _lighting,
      BriefField(
        id: 'storage',
        label:
            'Нужны ли открытые вешалки, пуф, шкаф, полочки для ключей и перчаток, зеркало в полный рост, зеркало для макияжа?',
      ),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'bedroom',
    title: 'Спальня',
    fields: [
      BriefField(
        id: 'finishes',
        label: 'Предпочтения по отделке (пол, стены)?',
      ),
      _lighting,
      BriefField(id: 'mattress', label: 'Размер матраса на кровать?'),
      BriefField(
        id: 'shelves',
        label: 'Нужны ли полочки, прикроватные тумбочки или стеллажи?',
      ),
      BriefField(
        id: 'vanity',
        label: 'Нужен ли туалетный столик для макияжа или рабочий стол?',
      ),
      BriefField(
        id: 'wardrobe',
        label: 'Нужен ли комод, шкаф, гардеробная? Каких размеров?',
      ),
      BriefField(id: 'curtains', label: 'Нужны ли шторы, римские шторы?'),
      BriefField(id: 'mirror', label: 'Нужно ли зеркало?'),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'bathroom',
    title: 'Санузел',
    fields: [
      BriefField(
        id: 'finishes',
        label: 'Предпочтения по отделке (пол, стены)?',
      ),
      _lighting,
      BriefField(id: 'bathOrShower', label: 'Ванна или душ? Размеры?'),
      BriefField(
        id: 'screen',
        label: 'Шторка для ванны или стеклянная перегородка?',
      ),
      BriefField(
        id: 'toilet',
        label: 'Унитаз обычный или подвесной со скрытой инсталляцией?',
      ),
      BriefField(id: 'sinks', label: 'Количество раковин?', lines: 1),
      BriefField(id: 'bidet', label: 'Нужен ли гигиенический душ или биде?'),
      BriefField(
        id: 'makeupLight',
        label: 'Нужно ли к зеркалу освещение для макияжа или бьюти-процедур?',
      ),
      BriefField(id: 'storage', label: 'Какие нужны места для хранения?'),
      BriefField(
        id: 'towelRail',
        label:
            'Какой полотенцесушитель предпочитаете: электрический или водяной?',
      ),
      BriefField(
        id: 'washerKg',
        label: 'На сколько кг стиральная машина?',
        lines: 1,
      ),
      BriefField(id: 'dryer', label: 'Нужна ли сушильная машина?'),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'wardrobe',
    title: 'Гардеробная',
    fields: [
      BriefField(
        id: 'finishes',
        label: 'Предпочтения по отделке (пол, стены)?',
      ),
      _lighting,
      BriefField(
        id: 'system',
        label: 'Какая система хранения нужна: корпусная, встроенная, открытая?',
      ),
      BriefField(
        id: 'zones',
        label: 'Какие зоны нужны: одежда, обувь, сумки, бельё?',
      ),
      BriefField(id: 'island', label: 'Нужен ли остров / пуф в гардеробной?'),
      BriefField(id: 'mirror', label: 'Нужно ли зеркало?'),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'kids',
    title: 'Детская',
    fields: [
      BriefField(
        id: 'finishes',
        label: 'Предпочтения по отделке (пол, стены)?',
      ),
      _lighting,
      BriefField(
        id: 'furniture',
        label:
            'Нужны ли рабочее место, шкаф, комод, кровать или диван (и размер матраса), тумбочка прикроватная, стеллажи, полки, шторы, ковер и тд?',
      ),
      BriefField(
        id: 'kidsItems',
        label:
            'Нужны ли детские предметы (вигвам, бизи-борд, бассейн с шариками, шведская стенка, столик со стульчиком, ночник и тд)?',
      ),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'loggia',
    title: 'Лоджия',
    fields: [
      BriefField(
        id: 'finishes',
        label: 'Предпочтения по отделке (пол, стены)?',
      ),
      _lighting,
      BriefField(
        id: 'relax',
        label: 'Нужна ли релакс-зона с креслом и столиком?',
      ),
      BriefField(id: 'storage', label: 'Нужно ли место для хранения (шкаф)?'),
      _other,
    ],
  ),
];

const briefAttachments = [
  'фотографии проектируемого помещения',
  'план БТИ',
  'референсы с комментариями (что именно понравилось на фото)',
  'ссылки на купленные или выбранные товары (если нет ссылки — фото и размеры: ширина, глубина, высота)',
];

final briefValueLabels = <String, Map<String, String>>{
  'likedColors': {for (final item in briefColorSwatches) item.id: item.label},
  'likedStyles': {for (final item in briefStyleOptions) item.id: item.label},
  'objectType': {for (final item in briefObjectOptions) item.id: item.label},
  'commercialType': {
    for (final item in briefCommercialTypeChoices) item.id: item.label
  },
  'kitchenLayout': {
    for (final item in briefKitchenLayoutChoices) item.id: item.label
  },
  'householdKind': {for (final item in briefHouseholdChoices) item.id: item.label},
  'familyRole': {for (final item in briefFamilyRoleChoices) item.id: item.label},
  'kids': {for (final item in briefKidsChoices) item.id: item.label},
  'pets': {for (final item in briefPetChoices) item.id: item.label},
  'routine': {for (final item in briefRoutineChoices) item.id: item.label},
  'hobbies': {for (final item in briefHobbyChoices) item.id: item.label},
  'interests': {for (final item in briefInterestChoices) item.id: item.label},
  'disliked': {for (final item in briefDislikeChoices) item.id: item.label},
  'budget': {for (final item in briefBudgetChoices) item.id: item.label},
  'replan': {for (final item in briefReplanChoices) item.id: item.label},
  'floorHeating': {for (final item in briefFloorHeatingChoices) item.id: item.label},
  'washerLocation': {for (final item in briefWasherChoices) item.id: item.label},
  'split': {for (final item in briefSplitChoices) item.id: item.label},
  'gadgetOutlets': {for (final item in briefGadgetChoices) item.id: item.label},
  'radiators': {for (final item in briefRadiatorChoices) item.id: item.label},
};

List<String> briefSelectedIds(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  return raw
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

String briefJoinIds(Iterable<String> ids) => ids.join(',');

String briefToggleId(String? raw, String id, {int? max}) {
  final selected = briefSelectedIds(raw);
  if (selected.contains(id)) {
    selected.remove(id);
  } else {
    if (max != null && selected.length >= max) {
      selected.removeAt(0);
    }
    selected.add(id);
  }
  return briefJoinIds(selected);
}

String briefToggleExclusiveNone(String? raw, String id, {required String noneId}) {
  if (id == noneId) {
    return raw == noneId ? '' : noneId;
  }
  final selected = briefSelectedIds(raw).where((item) => item != noneId).toList();
  if (selected.contains(id)) {
    selected.remove(id);
  } else {
    selected.add(id);
  }
  return briefJoinIds(selected);
}

String briefDisplayValue(String fieldId, String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final map = briefValueLabels[fieldId];
  if (map == null) return raw.trim();
  return briefSelectedIds(raw).map((id) => map[id] ?? id).join(', ');
}

class BriefFamilyMember {
  const BriefFamilyMember({
    this.role = '',
    this.age = '',
    this.customRole = '',
    this.name = '',
  });

  final String role;
  final String age;
  final String customRole;
  final String name;

  String get roleLabel {
    if (role == 'other' && customRole.trim().isNotEmpty) {
      return customRole.trim();
    }
    return briefValueLabels['familyRole']?[role] ??
        (customRole.trim().isNotEmpty ? customRole.trim() : role);
  }

  Map<String, String> toJson() => {
        'role': role,
        'age': age,
        if (name.isNotEmpty) 'name': name,
        if (customRole.isNotEmpty) 'customRole': customRole,
      };

  factory BriefFamilyMember.fromJson(Map<String, dynamic> json) {
    return BriefFamilyMember(
      role: (json['role'] as String?) ?? '',
      age: (json['age'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      customRole: (json['customRole'] as String?) ?? '',
    );
  }

  BriefFamilyMember copyWith({
    String? role,
    String? age,
    String? customRole,
    String? name,
  }) {
    return BriefFamilyMember(
      role: role ?? this.role,
      age: age ?? this.age,
      customRole: customRole ?? this.customRole,
      name: name ?? this.name,
    );
  }
}

List<BriefFamilyMember> briefParseFamilyMembers(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map(
          (item) => BriefFamilyMember.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  } catch (_) {
    return const [];
  }
}

String briefEncodeFamilyMembers(List<BriefFamilyMember> members) {
  return jsonEncode(members.map((m) => m.toJson()).toList());
}

String briefFamilyMembersSummary(List<BriefFamilyMember> members) {
  return members
      .where(
        (m) =>
            m.role.isNotEmpty || m.customRole.isNotEmpty || m.age.isNotEmpty,
      )
      .map((m) {
        final who = m.name.trim().isNotEmpty
            ? m.name.trim()
            : (m.roleLabel.isEmpty ? 'Участник' : m.roleLabel);
        final age = m.age.trim();
        return age.isEmpty ? who : '$who, $age';
      })
      .join('; ');
}
