import 'dart:convert';

class BriefField {
  const BriefField({
    required this.id,
    required this.label,
    this.lines = 3,
    this.groups = const [],
  });

  final String id;
  final String label;
  final int lines;

  /// Answer buttons; empty — the question is answered with text only.
  final List<BriefChoiceGroup> groups;
}

/// A row of answer buttons under a room question. Picked labels are stored as text
/// («Паркет; Ламинат»), so the PDF and the staff see them without a lookup table.
class BriefChoiceGroup {
  const BriefChoiceGroup(this.options, {this.key = '', this.label, this.multi = false});

  final List<String> options;

  /// '' — stored under the field id itself, otherwise under «fieldId.key».
  final String key;
  final String? label;
  final bool multi;
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
    this.url,
  });

  final String id;
  final String label;
  final String asset;

  /// A render from the studio portfolio; the bundled [asset] stays as the fallback.
  final String? url;
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
  BriefChoice(id: 'pet', label: 'Питомец'),
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

const briefWasherChoices = <BriefChoice>[
  BriefChoice(id: 'bathroom', label: 'В ванной'),
  BriefChoice(id: 'kitchen', label: 'На кухне'),
  BriefChoice(id: 'laundry', label: 'Постирочная'),
  BriefChoice(id: 'unknown', label: 'Пока не знаем'),
];

const briefGadgetChoices = <BriefChoice>[
  BriefChoice(id: 'robot', label: 'Робот-пылесос'),
  BriefChoice(id: 'humidifier', label: 'Увлажнитель'),
  BriefChoice(id: 'bedside', label: 'Зарядки у кровати'),
  BriefChoice(id: 'none', label: 'Нет'),
];

/// «Что меняем» — each item on its own (radiators, windows, sills, doors).
const briefRadiatorChoices = <BriefChoice>[
  BriefChoice(id: 'radiators', label: 'Радиаторы'),
  BriefChoice(id: 'windows', label: 'Окна'),
  BriefChoice(id: 'sills', label: 'Подоконники'),
  BriefChoice(id: 'entranceDoor', label: 'Входная дверь'),
  BriefChoice(id: 'doors', label: 'Межкомнатные двери'),
  BriefChoice(id: 'none', label: 'Ничего не меняем'),
  BriefChoice(id: 'later', label: 'Решим позже'),
];

/// Conditioner and warm floor are asked per room the client picked; this closes the list.
const briefNoneChoice = BriefChoice(id: 'none', label: 'Не нужен');

/// Answers from the earlier version of the questionnaire, so old briefs still read well.
const _legacyLabels = <String, Map<String, String>>{
  'floorHeating': {'all': 'Везде', 'wet': 'В мокрых зонах', 'no': 'Не нужен', 'later': 'Решим позже'},
  'split': {'living': 'Гостиная', 'bedrooms': 'Спальни', 'all': 'Во всех комнатах', 'no': 'Не нужен'},
  'gadgetOutlets': {'yes': 'Да, заложить', 'no': 'Не нужно', 'later': 'Решим позже'},
  'radiators': {'replace': 'Меняем всё', 'keep': 'Оставляем'},
};

const briefDefaultRoomsByObject = <String, List<String>>{
  'apartment': ['hallway', 'kitchen_living', 'bedroom', 'bathroom', 'loggia'],
  'house': ['hallway', 'kitchen_living', 'bedroom', 'bathroom', 'kids'],
  'office': ['hallway', 'kitchen', 'bathroom'],
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

const _officeHiddenRooms = {'bedroom', 'kitchen_living'};

List<BriefRoomSection> briefRoomsForObject(String? objectType) {
  if (objectType != 'office') return briefRoomSections;
  return [
    for (final section in briefRoomSections)
      if (!_officeHiddenRooms.contains(section.id)) section,
  ];
}

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
  BriefField(id: 'dislikedNote', label: 'Комментарий', lines: 3),
  BriefField(id: 'budget', label: 'Бюджет на ремонт', lines: 1),
  BriefField(
    id: 'replan',
    label: 'Перепланировка: стены оставляем или двигаем?',
    lines: 2,
  ),
  BriefField(id: 'zones', label: 'Комнаты и зоны в помещении'),
  BriefField(
    id: 'split',
    label: 'Кондиционер',
  ),
  BriefField(
    id: 'gadgetOutlets',
    label: 'Розетки под гаджеты (робот-пылесос, увлажнитель и т.д.)',
  ),
  BriefField(
    id: 'radiators',
    label: 'Что меняем',
  ),
  BriefField(id: 'floorHeating', label: 'Тёплый пол', lines: 1),
  BriefField(
    id: 'washerLocation',
    label: 'Где планируется стиральная машина?',
    lines: 2,
  ),
  BriefField(id: 'replanNote', label: 'Перепланировка — комментарий', lines: 2),
  BriefField(id: 'radiatorsNote', label: 'Что меняем — комментарий', lines: 2),
  BriefField(id: 'splitNote', label: 'Кондиционер — комментарий', lines: 2),
  BriefField(id: 'gadgetOutletsNote', label: 'Розетки — комментарий', lines: 2),
  BriefField(id: 'floorHeatingNote', label: 'Тёплый пол — комментарий', lines: 2),
  BriefField(id: 'washerLocationNote', label: 'Стиральная машина — комментарий', lines: 2),
  BriefField(id: 'details', label: 'Важные детали'),
  BriefField(
    id: 'existingItems',
    label:
        'Уже купленные и переезжающие вещи (ссылки, если нет ссылки — фото и размеры)',
    lines: 4,
  ),
];

const _floor = BriefChoiceGroup(
  ['Паркет / инженерная доска', 'Ламинат', 'Кварцвинил', 'Керамогранит', 'Микроцемент', 'Ковролин', 'Решит дизайнер'],
  key: 'floor',
  label: 'Пол',
  multi: true,
);
const _walls = BriefChoiceGroup(
  ['Покраска', 'Обои', 'Декоративная штукатурка', 'Стеновые панели / рейки', 'Плитка', 'Молдинги', 'Решит дизайнер'],
  key: 'walls',
  label: 'Стены',
  multi: true,
);
const _apron = BriefChoiceGroup(
  ['Плитка', 'Керамогранит крупного формата', 'Камень (как столешница)', 'Стекло', 'Решит дизайнер'],
  key: 'apron',
  label: 'Фартук',
);
const _finishes = BriefField(
  id: 'finishes',
  label: 'Предпочтения по отделке',
  groups: [_floor, _walls],
);
const _kitchenFinishes = BriefField(
  id: 'finishes',
  label: 'Предпочтения по отделке',
  groups: [_floor, _walls, _apron],
);
const _lighting = BriefField(
  id: 'lighting',
  label: 'Какое освещение предусмотреть?',
  groups: [
    BriefChoiceGroup(
      ['Люстра', 'Точечные светильники', 'Трековые', 'Подсветка (скрытая, LED)', 'Бра', 'Торшер', 'Настольные лампы', 'Решит дизайнер'],
      multi: true,
    ),
  ],
);
const _other = BriefField(id: 'other', label: 'Что ещё необходимо учесть?');

const _kitchenFields = <BriefField>[
  BriefField(
    id: 'hood',
    label: 'Вытяжка',
    groups: [
      BriefChoiceGroup(['Встроенная', 'Островная', 'Наклонная настенная', 'Купольная', 'Встроенная в варочную панель', 'Решит дизайнер']),
    ],
  ),
  BriefField(
    id: 'diningTable',
    label: 'Обеденный стол',
    groups: [
      BriefChoiceGroup(['Круглый', 'Прямоугольный', 'Раздвижной', 'Барная стойка', 'Не нужен']),
      BriefChoiceGroup(['2', '4', '6', '8', '10+'], key: 'seats', label: 'Мест'),
    ],
  ),
  BriefField(
    id: 'island',
    label: 'Стол-остров',
    groups: [
      BriefChoiceGroup(['Да', 'Нет', 'Если поместится']),
    ],
  ),
  BriefField(
    id: 'dishwasher',
    label: 'Посудомойка',
    groups: [
      BriefChoiceGroup(['45 см', '60 см', 'Не нужна']),
    ],
  ),
  BriefField(
    id: 'cooktop',
    label: 'Варочная панель',
    groups: [
      BriefChoiceGroup(['2 конфорки', '4 конфорки', '5 конфорок']),
      BriefChoiceGroup(['Индукция', 'Газ', 'Домино (комбинированная)'], key: 'type', label: 'Тип'),
    ],
  ),
  BriefField(
    id: 'oven',
    label: 'Духовой шкаф',
    groups: [
      BriefChoiceGroup(['Духовой шкаф', 'Компактный с СВЧ', 'Пароварка', 'Не нужен'], multi: true),
    ],
  ),
  BriefField(
    id: 'fridge',
    label: 'Холодильник',
    groups: [
      BriefChoiceGroup(['Встроенный', 'Отдельностоящий', 'Side-by-side (двухдверный)', 'Встроенный + винный шкаф']),
    ],
  ),
];

const _livingCurtains = BriefField(
  id: 'curtains',
  label: 'Шторы',
  groups: [
    BriefChoiceGroup(['Портьеры', 'Тюль', 'Римские шторы', 'Рулонные', 'Жалюзи', 'Не нужны'], multi: true),
  ],
);

const briefRoomSections = <BriefRoomSection>[
  BriefRoomSection(
    id: 'kitchen',
    title: 'Кухня',
    fields: [_lighting, _kitchenFinishes, ..._kitchenFields, _other],
  ),
  BriefRoomSection(
    id: 'kitchen_living',
    title: 'Кухня-гостиная',
    fields: [
      _lighting,
      _kitchenFinishes,
      BriefField(
        id: 'doorFromHall',
        label: 'Дверь из прихожей',
        groups: [
          BriefChoiceGroup(['Нужна', 'Не нужна', 'Раздвижная', 'Скрытая']),
        ],
      ),
      BriefField(
        id: 'sofa',
        label: 'Диван',
        groups: [
          BriefChoiceGroup(['Прямой', 'Угловой', 'Модульный', 'П-образный', 'Диван-кровать', 'Не нужен']),
          BriefChoiceGroup(
            ['Небольшой (до 2 м)', 'Средний (2–2,5 м)', 'Большой (от 2,5 м)'],
            key: 'size',
            label: 'Размер',
          ),
        ],
      ),
      BriefField(
        id: 'extraFurniture',
        label: 'Кресла, столик, рабочее место, камин',
        groups: [
          BriefChoiceGroup(['Кресла', 'Журнальный столик', 'Рабочее место', 'Биокамин', 'Электрокамин', 'Ничего'], multi: true),
        ],
      ),
      BriefField(
        id: 'shelves',
        label: 'Стеллаж / открытые полки',
        groups: [
          BriefChoiceGroup(['Стеллаж', 'Открытые полки', 'Закрытые шкафы', 'Не нужно']),
        ],
      ),
      ..._kitchenFields,
      BriefField(
        id: 'tv',
        label: 'ТВ',
        groups: [
          BriefChoiceGroup(['Нужен, на стене', 'Нужен, на тумбе', 'Проектор', 'Не нужен']),
        ],
      ),
      _livingCurtains,
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'hallway',
    title: 'Прихожая',
    fields: [
      _finishes,
      _lighting,
      BriefField(
        id: 'storage',
        label: 'Хранение',
        groups: [
          BriefChoiceGroup(
            ['Шкаф-купе', 'Распашной шкаф', 'Открытая вешалка', 'Обувница', 'Банкетка / пуф', 'Зеркало в полный рост', 'Ключница'],
            multi: true,
          ),
        ],
      ),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'bedroom',
    title: 'Спальня',
    fields: [
      _finishes,
      _lighting,
      BriefField(
        id: 'mattress',
        label: 'Размер кровати / матраса',
        groups: [
          BriefChoiceGroup(['140 см', '160 см', '180 см', '200 см'], key: 'width', label: 'Ширина'),
          BriefChoiceGroup(['190 см', '200 см', '210 см'], key: 'length', label: 'Длина'),
        ],
      ),
      BriefField(
        id: 'shelves',
        label: 'Полки, тумбочки, стеллажи',
        groups: [
          BriefChoiceGroup(['Прикроватные тумбы', 'Подвесные полки', 'Стеллаж', 'Не нужны'], multi: true),
        ],
      ),
      BriefField(
        id: 'vanity',
        label: 'Туалетный / рабочий стол',
        groups: [
          BriefChoiceGroup(['Туалетный столик', 'Рабочий стол', 'Не нужно'], multi: true),
        ],
      ),
      BriefField(
        id: 'wardrobe',
        label: 'Хранение',
        groups: [
          BriefChoiceGroup(['Комод', 'Шкаф', 'Гардеробная', 'Кровать с ящиками'], multi: true),
        ],
      ),
      BriefField(
        id: 'curtains',
        label: 'Шторы',
        groups: [
          BriefChoiceGroup(['Блэкаут', 'Тюль', 'Римские', 'Рулонные', 'Не нужны'], multi: true),
        ],
      ),
      BriefField(
        id: 'mirror',
        label: 'Зеркало',
        groups: [
          BriefChoiceGroup(['Настенное', 'В полный рост', 'В дверце шкафа', 'Не нужно']),
        ],
      ),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'bathroom',
    title: 'Санузел',
    fields: [
      _finishes,
      _lighting,
      BriefField(
        id: 'bathOrShower',
        label: 'Ванна или душ',
        groups: [
          BriefChoiceGroup(['Ванна', 'Душ', 'Ванна и душ', 'Отдельностоящая ванна']),
          BriefChoiceGroup(['150 см', '170 см', '180 см'], key: 'bathSize', label: 'Размер ванны'),
          BriefChoiceGroup(['Поддон', 'Трап в полу'], key: 'shower', label: 'Душ'),
        ],
      ),
      BriefField(
        id: 'screen',
        label: 'Шторка / перегородка',
        groups: [
          BriefChoiceGroup(['Стеклянная перегородка', 'Шторка', 'Не нужна']),
        ],
      ),
      BriefField(
        id: 'toilet',
        label: 'Унитаз',
        groups: [
          BriefChoiceGroup(['Подвесной с инсталляцией', 'Напольный', 'Приставной']),
        ],
      ),
      BriefField(
        id: 'sinks',
        label: 'Раковины',
        groups: [
          BriefChoiceGroup(['1', '2'], label: 'Количество'),
          BriefChoiceGroup(['Накладная', 'Встроенная', 'На тумбе', 'Подвесная'], key: 'type', label: 'Тип'),
        ],
      ),
      BriefField(
        id: 'bidet',
        label: 'Гигиенический душ / биде',
        groups: [
          BriefChoiceGroup(['Гигиенический душ', 'Биде', 'Не нужно']),
        ],
      ),
      BriefField(
        id: 'makeupLight',
        label: 'Подсветка зеркала',
        groups: [
          BriefChoiceGroup(['Нужна', 'Не нужна']),
        ],
      ),
      BriefField(
        id: 'storage',
        label: 'Хранение',
        groups: [
          BriefChoiceGroup(['Тумба под раковиной', 'Пенал', 'Шкаф над инсталляцией', 'Ниша', 'Открытые полки'], multi: true),
        ],
      ),
      BriefField(
        id: 'towelRail',
        label: 'Полотенцесушитель',
        groups: [
          BriefChoiceGroup(['Водяной', 'Электрический', 'Не нужен']),
        ],
      ),
      BriefField(
        id: 'washerKg',
        label: 'Стиральная машина',
        groups: [
          BriefChoiceGroup(['6 кг', '7–8 кг', '9 кг и больше', 'Не здесь']),
        ],
      ),
      BriefField(
        id: 'dryer',
        label: 'Сушильная машина',
        groups: [
          BriefChoiceGroup(['Нужна, в колонну со стиральной', 'Нужна, рядом', 'Не нужна']),
        ],
      ),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'wardrobe',
    title: 'Гардеробная',
    fields: [
      _finishes,
      _lighting,
      BriefField(
        id: 'system',
        label: 'Система хранения',
        groups: [
          BriefChoiceGroup(['Корпусная', 'Встроенная', 'Открытая (на стойках)', 'Решит дизайнер']),
        ],
      ),
      BriefField(
        id: 'zones',
        label: 'Зоны',
        groups: [
          BriefChoiceGroup(
            ['Одежда на штангах', 'Полки', 'Обувь', 'Сумки', 'Бельё (ящики)', 'Гладильная доска', 'Пылесос'],
            multi: true,
          ),
        ],
      ),
      BriefField(
        id: 'island',
        label: 'Остров / пуф',
        groups: [
          BriefChoiceGroup(['Остров с ящиками', 'Пуф', 'Не нужно']),
        ],
      ),
      BriefField(
        id: 'mirror',
        label: 'Зеркало',
        groups: [
          BriefChoiceGroup(['В полный рост', 'Не нужно']),
        ],
      ),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'kids',
    title: 'Детская',
    fields: [
      _finishes,
      _lighting,
      BriefField(
        id: 'furniture',
        label: 'Мебель',
        groups: [
          BriefChoiceGroup(
            ['Кровать', 'Двухъярусная кровать', 'Кровать-чердак', 'Рабочий стол', 'Шкаф', 'Стеллаж для игрушек'],
            multi: true,
          ),
        ],
      ),
      BriefField(
        id: 'kidsItems',
        label: 'Что ещё',
        groups: [
          BriefChoiceGroup(['Шведская стенка', 'Игровая зона', 'Место для творчества', 'Мягкий пол / ковёр'], multi: true),
        ],
      ),
      _other,
    ],
  ),
  BriefRoomSection(
    id: 'loggia',
    title: 'Лоджия',
    fields: [
      _finishes,
      _lighting,
      BriefField(
        id: 'relax',
        label: 'Релакс-зона',
        groups: [
          BriefChoiceGroup(['Кресло и столик', 'Рабочее место', 'Зона для цветов', 'Не нужна']),
        ],
      ),
      BriefField(
        id: 'storage',
        label: 'Хранение',
        groups: [
          BriefChoiceGroup(['Шкаф', 'Открытые полки', 'Не нужно']),
        ],
      ),
      _other,
    ],
  ),
];

String briefGroupKey(BriefField field, BriefChoiceGroup group) =>
    group.key.isEmpty ? field.id : '${field.id}.${group.key}';

String briefNoteKey(BriefField field) => '${field.id}.note';

const _labelSeparator = '; ';

List<String> briefLabelParts(String? raw) => [
      for (final part in (raw ?? '').split(';'))
        if (part.trim().isNotEmpty) part.trim(),
    ];

/// «Не нужен», «Ничего», «Решит дизайнер»… — picking one clears the rest of the row.
bool _isExclusiveLabel(String label) =>
    RegExp(r'^(Не нуж|Не здесь|Ничего|Нет$|Решит дизайнер|Решим позже)').hasMatch(label);

/// Toggles [label] in a stored row; text typed in the old free-form version stays.
String briefToggleLabel(String? raw, BriefChoiceGroup group, String label) {
  final parts = briefLabelParts(raw);
  final free = [for (final p in parts) if (!group.options.contains(p)) p];
  var picked = [for (final p in parts) if (group.options.contains(p)) p];
  if (picked.contains(label)) {
    picked.remove(label);
  } else if (!group.multi || _isExclusiveLabel(label)) {
    picked = [label];
  } else {
    picked
      ..removeWhere(_isExclusiveLabel)
      ..add(label);
  }
  return [...free, ...picked].join(_labelSeparator);
}

/// The answer as it reads in the brief: one line per row, the comment last.
String briefRoomFieldValue(BriefField field, Map<String, String> fields) {
  if (field.groups.isEmpty) return (fields[field.id] ?? '').trim();
  final lines = <String>[];
  if (!field.groups.any((g) => g.key.isEmpty)) {
    final legacy = (fields[field.id] ?? '').trim();
    if (legacy.isNotEmpty) lines.add(legacy);
  }
  for (final group in field.groups) {
    final value = (fields[briefGroupKey(field, group)] ?? '').trim();
    if (value.isEmpty) continue;
    lines.add(group.label == null ? value : '${group.label}: $value');
  }
  final note = (fields[briefNoteKey(field)] ?? '').trim();
  if (note.isNotEmpty) lines.add(lines.isEmpty ? note : 'Комментарий: $note');
  return lines.join('\n');
}

/// Portfolio style for each questionnaire style (pictures of rooms in the client's style).
const briefPortfolioStyle = <String, String>{
  'scandi': 'skandinavskij',
  'minimal': 'minimalizm',
  'classic': 'sovr-klassika',
  'classical': 'neoklassika',
  'provence': 'provans',
  'loft': 'loft',
};

/// Questionnaire room → rooms as named under portfolio renders, best match first.
const briefPortfolioRooms = <String, List<String>>{
  'kitchen': ['Кухня', 'Кухня-гостиная'],
  'kitchen_living': ['Кухня-гостиная', 'Гостиная', 'Кухня'],
  'hallway': ['Прихожая', 'Коридор', 'Холл'],
  'bedroom': ['Спальня', 'Гостевая'],
  'bathroom': ['Санузел', 'Ванная'],
  'wardrobe': ['Гардеробная'],
  'kids': ['Детская'],
  'loggia': ['Лоджия'],
};

const briefAttachments = [
  'фотографии проектируемого помещения',
  'план БТИ',
  'референсы с комментариями (что именно понравилось на фото)',
  'ссылки на купленные или выбранные товары (если нет ссылки — фото и размеры: ширина, глубина, высота)',
];

final briefValueLabels = <String, Map<String, String>>{
  'likedColors': {for (final item in briefColorSwatches) item.id: item.label},
  'likedStyles': {
    for (final item in briefStyleOptions) item.id: item.label,
  },
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
  'floorHeating': {..._legacyLabels['floorHeating']!, ..._roomLabels},
  'washerLocation': {for (final item in briefWasherChoices) item.id: item.label},
  'split': {..._legacyLabels['split']!, ..._roomLabels},
  'gadgetOutlets': {
    ..._legacyLabels['gadgetOutlets']!,
    for (final item in briefGadgetChoices) item.id: item.label,
  },
  'radiators': {
    ..._legacyLabels['radiators']!,
    for (final item in briefRadiatorChoices) item.id: item.label,
  },
};

final _roomLabels = <String, String>{
  for (final section in briefRoomSections) section.id: section.title,
  briefNoneChoice.id: briefNoneChoice.label,
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
  // «Решим позже» also stands alone, like «Нет».
  bool alone(String item) => item == noneId || item == 'later';
  if (alone(id)) {
    return raw == id ? '' : id;
  }
  final selected = briefSelectedIds(raw).where((item) => !alone(item)).toList();
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
  return briefSelectedIds(raw)
      .where((id) => id != 'travans')
      .map((id) => map[id] ?? id)
      .where((label) => label != 'travans')
      .join(', ');
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
        final bits = <String>[
          if (m.roleLabel.isNotEmpty) m.roleLabel,
          if (m.name.trim().isNotEmpty) m.name.trim(),
        ];
        final who = bits.isEmpty ? 'Участник' : bits.join(', ');
        final age = m.age.trim();
        return age.isEmpty ? who : '$who, $age';
      })
      .join('; ');
}
