import '../../domain/models/meal_item.dart';

class RecipeData {
  final String id;
  final String name;
  final String nameHi;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final List<MealIngredient> ingredients;
  final List<String> instructions;
  final List<String> instructionsHi;
  final List<String> substitutions;

  const RecipeData({
    required this.id,
    required this.name,
    required this.nameHi,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    this.servings = 1,
    required this.ingredients,
    required this.instructions,
    required this.instructionsHi,
    required this.substitutions,
  });
}

class WeeklyMenuEntry {
  final String id;
  final int dayOfWeek; // 1 = Monday ... 7 = Sunday
  final String mealType; // breakfast, lunch, dinner
  final String title;
  final String titleHi;
  final String recipeId;

  const WeeklyMenuEntry({
    required this.id,
    required this.dayOfWeek,
    required this.mealType,
    required this.title,
    required this.titleHi,
    required this.recipeId,
  });
}

class WeeklyMenuData {
  // 15 Distinct Local Vegetarian Recipes
  static final Map<String, RecipeData> recipes = {
    'masala_oats': const RecipeData(
      id: 'masala_oats',
      name: 'Masala Oats',
      nameHi: 'मसाला ओट्स',
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Rolled / Quick Oats', quantity: '40 g (1/2 cup)'),
        MealIngredient(name: 'Mixed veggies (carrots, peas, beans, capsicum)', quantity: '1/2 cup finely chopped'),
        MealIngredient(name: 'Onion', quantity: '1 small (chopped)'),
        MealIngredient(name: 'Tomato', quantity: '1 small (chopped)'),
        MealIngredient(name: 'Green chili', quantity: '1 (finely chopped)'),
        MealIngredient(name: 'Cumin seeds (jeera)', quantity: '1/2 tsp'),
        MealIngredient(name: 'Turmeric powder', quantity: '1/4 tsp'),
        MealIngredient(name: 'Garam masala', quantity: '1/4 tsp'),
        MealIngredient(name: 'Mustard oil or Ghee', quantity: '1 tsp'),
        MealIngredient(name: 'Water', quantity: '1.5 cups'),
        MealIngredient(name: 'Fresh coriander & salt', quantity: 'To taste & garnish'),
      ],
      instructions: [
        'Heat 1 tsp oil/ghee in a pan and splutter cumin seeds.',
        'Add green chili and chopped onion; sauté for 1-2 minutes until translucent.',
        'Add chopped tomato and cook until soft.',
        'Stir in mixed vegetables, turmeric, garam masala, and salt. Cook for 2 minutes.',
        'Pour 1.5 cups of water and bring to a gentle boil.',
        'Add oats, lower the heat, and simmer for 4-5 minutes until oats are soft and creamy.',
        'Garnish with fresh coriander and serve warm.',
      ],
      instructionsHi: [
        'पैन में 1 चम्मच तेल/घी गरम करें और जीरा चटकाएं।',
        'हरी मिर्च और प्याज डालकर 1-2 मिनट तक भूनें।',
        'टमाटर डालकर नरम होने तक पकाएं।',
        'कटी सब्जियां, हल्दी, गरम मसाला और नमक डालकर 2 मिनट चलाएं।',
        '1.5 कप पानी डालें और उबाल आने दें।',
        'ओट्स डालें और धीमी आंच पर 4-5 मिनट तक गाढ़ा होने तक पकाएं।',
        'ताजा धनिया डालकर गरमा-गरम परोसें।',
      ],
      substitutions: [
        'Steel-cut oats can be used (increase cook time to 15-20 min).',
        'Add 2 tbsp grated paneer or tofu for extra morning protein.',
      ],
    ),

    'besan_cheela': const RecipeData(
      id: 'besan_cheela',
      name: 'Besan Cheela',
      nameHi: 'बेसन चीला',
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Besan (Gram flour)', quantity: '60 g (1/2 cup)'),
        MealIngredient(name: 'Onion', quantity: '2 tbsp (finely chopped)'),
        MealIngredient(name: 'Tomato', quantity: '2 tbsp (finely chopped)'),
        MealIngredient(name: 'Green chili & ginger', quantity: '1/2 tsp (chopped)'),
        MealIngredient(name: 'Ajwain (Carom seeds)', quantity: '1/4 tsp (crushed)'),
        MealIngredient(name: 'Turmeric powder', quantity: '1/4 tsp'),
        MealIngredient(name: 'Salt', quantity: 'To taste'),
        MealIngredient(name: 'Water', quantity: '~1/3 to 1/2 cup'),
        MealIngredient(name: 'Cooking oil', quantity: '1 tsp'),
      ],
      instructions: [
        'In a bowl, mix besan, ajwain, turmeric, and salt.',
        'Gradually whisk in water to make a smooth, pourable lump-free batter.',
        'Fold in chopped onion, tomato, green chili, ginger, and coriander.',
        'Heat a flat tawa on medium heat and lightly grease with oil.',
        'Pour a ladleful of batter and spread into a round disc.',
        'Drizzle a few drops of oil on edges; cook for 2 minutes until golden crisp.',
        'Flip carefully and cook the other side for 1-2 minutes.',
        'Serve hot with homemade mint-coriander chutney.',
      ],
      instructionsHi: [
        'कटोरी में बेसन, अजवाइन, हल्दी और नमक मिलाएं।',
        'पानी डालकर गांठ-रहित चिकना घोल तैयार करें।',
        'बारीक कटा प्याज, टमाटर, हरी मिर्च, अदरक और धनिया मिलाएं।',
        'तवे पर हल्का तेल लगाकर गरम करें।',
        'घोल डालकर गोल चीला फैलाएं।',
        'किनारों पर थोड़ा तेल डालकर 2 मिनट सुनहरा होने तक सेकें।',
        'पलटकर दूसरी तरफ भी 1-2 मिनट पकाएं।',
        'पुदीने-धनिया की चटनी के साथ परोसें।',
      ],
      substitutions: [
        'Add finely shredded spinach or grated carrots for extra dietary fiber.',
      ],
    ),

    'oats_dalia_upma': const RecipeData(
      id: 'oats_dalia_upma',
      name: 'Oats Dalia Upma',
      nameHi: 'ओट्स दलिया उपमा',
      prepTimeMinutes: 5,
      cookTimeMinutes: 15,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Broken wheat (Dalia) & Oats mix', quantity: '1/2 cup (equal parts)'),
        MealIngredient(name: 'Mustard seeds (Rai)', quantity: '1/2 tsp'),
        MealIngredient(name: 'Curry leaves', quantity: '6-8 leaves'),
        MealIngredient(name: 'Onion', quantity: '1 small (chopped)'),
        MealIngredient(name: 'Mixed veggies (carrots, peas, beans)', quantity: '1/2 cup'),
        MealIngredient(name: 'Green chili', quantity: '1 (slit)'),
        MealIngredient(name: 'Turmeric & salt', quantity: 'To taste'),
        MealIngredient(name: 'Oil or Ghee', quantity: '1 tsp'),
        MealIngredient(name: 'Water', quantity: '1.5 cups'),
        MealIngredient(name: 'Lemon juice', quantity: '1 tsp'),
      ],
      instructions: [
        'Dry roast the dalia in a pan on medium flame for 3-4 minutes until fragrant. Set aside.',
        'Heat 1 tsp oil/ghee in the pan. Splutter mustard seeds and curry leaves.',
        'Add chopped onion and green chili; sauté until translucent.',
        'Add mixed vegetables, turmeric, and salt. Cook for 2 minutes.',
        'Pour 1.5 cups of water and bring to a boil.',
        'Add roasted dalia and oats. Stir thoroughly to prevent lumps.',
        'Cover and simmer on low heat for 8-10 minutes until water is absorbed and grains are tender.',
        'Turn off heat, squeeze fresh lemon juice, rest covered for 2 minutes, and serve.',
      ],
      instructionsHi: [
        'दलिया को धीमी आंच पर 3-4 मिनट सूखा भूनकर अलग रख लें।',
        'पैन में 1 चम्मच तेल/घी गरम करें, राई और कढ़ी पत्ता चटकाएं।',
        'प्याज और हरी मिर्च डालकर हल्का भूनें।',
        'सब्जियां, हल्दी और नमक डालकर 2 मिनट पकाएं।',
        '1.5 कप पानी डालकर उबालें।',
        'भुना दलिया और ओट्स डालकर अच्छी तरह मिलाएं।',
        'ढककर धीमी आंच पर 8-10 मिनट तक पकने दें।',
        'नींबू का रस डालकर 2 मिनट ढककर रखें, फिर परोसें।',
      ],
      substitutions: [
        'Substitute dalia with semolina (sooji) or quinoa if preferred.',
      ],
    ),

    'moong_dal_cheela': const RecipeData(
      id: 'moong_dal_cheela',
      name: 'Moong Dal Cheela (ready powder se)',
      nameHi: 'मूंग दाल चीला (रेडी पाउडर से)',
      prepTimeMinutes: 4,
      cookTimeMinutes: 8,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Instant Moong Dal Flour / Powder', quantity: '60 g (1/2 cup)'),
        MealIngredient(name: 'Grated ginger', quantity: '1/2 tsp'),
        MealIngredient(name: 'Green chili', quantity: '1 (finely chopped)'),
        MealIngredient(name: 'Hing (Asafoetida)', quantity: '1 pinch'),
        MealIngredient(name: 'Jeera (Cumin powder)', quantity: '1/4 tsp'),
        MealIngredient(name: 'Fresh coriander', quantity: '1 tbsp chopped'),
        MealIngredient(name: 'Salt', quantity: 'To taste'),
        MealIngredient(name: 'Water', quantity: '~1/2 cup'),
        MealIngredient(name: 'Oil', quantity: '1 tsp for cooking'),
      ],
      instructions: [
        'In a bowl, mix instant moong dal powder, hing, cumin powder, ginger, chili, and salt.',
        'Gradually add water and whisk into a smooth pancake batter. Let it rest for 5 minutes.',
        'Heat a tawa on medium heat and grease lightly with oil.',
        'Pour a ladle of batter and spread evenly in circular motion.',
        'Drizzle drops of oil along edges and cook for 2 minutes until crisp and golden.',
        'Flip and cook the second side for 1 minute.',
        'Fold and serve hot with fresh curd or green chutney.',
      ],
      instructionsHi: [
        'कटोरी में मूंग दाल पाउडर, हींग, जीरा पाउडर, अदरक, मिर्च और नमक मिलाएं।',
        'पानी डालकर चीले का चिकना घोल बनाएं और 5 मिनट ढककर रखें।',
        'तवे को गरम करके हल्का तेल लगाएं।',
        'घोल डालकर गोल चीला फैलाएं।',
        'किनारों पर थोड़ा तेल डालकर 2 मिनट कुरकुरा होने तक सेकें।',
        'पलटकर 1 मिनट और सेकें।',
        'दही या हरी चटनी के साथ गरमा-गरम परोसें।',
      ],
      substitutions: [
        'Stuff with 2 tbsp of crumbled low-fat paneer for higher protein.',
      ],
    ),

    'roti_moong_dal_salad': const RecipeData(
      id: 'roti_moong_dal_salad',
      name: '2 Roti + Moong Dal + Salad',
      nameHi: '2 रोटी + मूंग दाल + सलाद',
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Whole wheat flour (Atta)', quantity: 'For 2 medium rotis'),
        MealIngredient(name: 'Yellow split moong dal', quantity: '1/3 cup (washed)'),
        MealIngredient(name: 'Tomato', quantity: '1 medium (chopped)'),
        MealIngredient(name: 'Turmeric powder', quantity: '1/4 tsp'),
        MealIngredient(name: 'Cumin seeds', quantity: '1/2 tsp'),
        MealIngredient(name: 'Ghee', quantity: '1 tsp for tadka'),
        MealIngredient(name: 'Salt & water', quantity: 'To taste & 1 cup water'),
        MealIngredient(name: 'Kheera (Cucumber) / Salad', quantity: '1 sliced cucumber with lemon wedge'),
      ],
      instructions: [
        'Cook washed moong dal with 1 cup water, turmeric, chopped tomato, and salt in pressure cooker for 2 whistles (or pot for 15 min).',
        'Heat 1 tsp ghee in a ladle, splutter cumin seeds and a pinch of hing; pour tadka over cooked dal.',
        'Knead atta with water and roll out 2 rotis. Cook on hot tawa until puffed and cooked through.',
        'Slice fresh cucumber, squeeze lemon juice, and sprinkle rock salt.',
        'Serve hot dal with 2 fresh whole wheat rotis and crunchy salad.',
      ],
      instructionsHi: [
        'मूंग दाल को 1 कप पानी, हल्दी, टमाटर और नमक के साथ कुकर में 2 सीटी आने तक पकाएं।',
        'तड़का पैन में 1 चम्मच घी गरम करें, जीरा और हींग चटकाकर दाल में तड़का लगाएं।',
        'आटा गूंथकर 2 रोटियां बेलें और तवे पर अच्छी तरह फुलाएं।',
        'खीरा काटकर नींबू और सेंधा नमक डालें।',
        'गरम दाल, 2 रोटियां और ताजे सलाद का आनंद लें।',
      ],
      substitutions: [
        'Yellow moong dal can be swapped with split green chilka moong for extra fiber.',
      ],
    ),

    'roti_mix_veg_salad': const RecipeData(
      id: 'roti_mix_veg_salad',
      name: '2 Roti + Mix Veg Sabzi + Salad',
      nameHi: '2 रोटी + मिक्स वेज सब्जी + सलाद',
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Mixed veggies (carrots, beans, peas, capsicum)', quantity: '1.5 cups chopped'),
        MealIngredient(name: 'Onion & Tomato', quantity: '1 each (chopped)'),
        MealIngredient(name: 'Ginger-garlic paste', quantity: '1 tsp'),
        MealIngredient(name: 'Cumin seeds & dry spices (turmeric, coriander, jeera)', quantity: '1/4 tsp each'),
        MealIngredient(name: 'Cooking oil', quantity: '1 tsp'),
        MealIngredient(name: 'Atta', quantity: 'For 2 medium rotis'),
        MealIngredient(name: 'Fresh Salad', quantity: 'Sliced cucumber, tomato, onion'),
      ],
      instructions: [
        'Heat oil in a pan, add cumin seeds, chopped onion, and ginger-garlic paste; sauté until golden.',
        'Add tomato, turmeric, coriander powder, cumin powder, and salt. Cook until tomatoes soften.',
        'Add mixed vegetables and 2 tbsp water. Cover and cook on low flame for 10-12 minutes until tender.',
        'Roll and puff 2 whole wheat rotis on a hot tawa.',
        'Serve dry mix veg sabzi with 2 warm rotis and fresh salad.',
      ],
      instructionsHi: [
        'पैन में तेल गरम करें, जीरा, प्याज और अदरक-लहसुन पेस्ट डालकर भूनें।',
        'टमाटर, हल्दी, धनिया पाउडर, जीरा पाउडर और नमक डालकर टमाटर गलने तक पकाएं।',
        'मिक्स सब्जियां और 2 चम्मच पानी डालें। ढककर धीमी आंच पर 10-12 मिनट पकाएं।',
        'तवे पर 2 गेहूं की रोटियां सेकें।',
        'सब्जी, रोटियां और ताजे सलाद के साथ परोसें।',
      ],
      substitutions: [
        'Toss in 30g paneer cubes or tofu cubes to boost vegetarian protein.',
      ],
    ),

    'brown_rice_kala_chana': const RecipeData(
      id: 'brown_rice_kala_chana',
      name: 'Brown Rice + Kala Chana Curry',
      nameHi: 'ब्राउन राइस + काला चना करी',
      prepTimeMinutes: 10,
      cookTimeMinutes: 25,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Brown rice', quantity: '1/3 cup (soaked 30 mins)'),
        MealIngredient(name: 'Black chickpeas (Kala chana)', quantity: '1/3 cup (soaked overnight)'),
        MealIngredient(name: 'Onion & Tomato', quantity: '1 small each (chopped)'),
        MealIngredient(name: 'Ginger-garlic paste', quantity: '1 tsp'),
        MealIngredient(name: 'Bay leaf & cumin seeds', quantity: '1 leaf, 1/2 tsp seeds'),
        MealIngredient(name: 'Garam masala, coriander, turmeric', quantity: '1/2 tsp each'),
        MealIngredient(name: 'Mustard oil', quantity: '1 tsp'),
        MealIngredient(name: 'Salt & water', quantity: 'To taste'),
      ],
      instructions: [
        'Pressure cook soaked kala chana with 1.5 cups water and salt for 5-6 whistles until soft.',
        'Cook brown rice with 2.5 parts water until fluffy and tender (approx. 20-25 mins).',
        'Heat oil in a pan; add bay leaf, cumin, and onion. Sauté until golden.',
        'Add ginger-garlic paste, tomato, and dry spices; cook until aromatic.',
        'Add boiled kala chana with cooking broth. Simmer on medium heat for 10 minutes.',
        'Serve 1 katori brown rice with hot protein-packed kala chana curry.',
      ],
      instructionsHi: [
        'भीगे काले चने को 1.5 कप पानी और नमक के साथ कुकर में 5-6 सीटी आने तक उबालें।',
        'ब्राउन राइस को पानी में 20-25 मिनट तक नरम होने तक पकाएं।',
        'पैन में तेल गरम करें, तेजपत्ता, जीरा और प्याज सुनहरा होने तक भूनें।',
        'अदरक-लहसुन, टमाटर और सूखे मसाले डालकर अच्छी तरह भूनें।',
        'उबले चने पानी सहित डालें और 10 मिनट धीमी आंच पर उबलने दें।',
        'गर्म ब्राउन राइस के साथ पौष्टिक काला चना करी परोसें।',
      ],
      substitutions: [
        'Soaked white chickpeas (kabuli chana) or rajma can be used as alternatives.',
      ],
    ),

    'roti_palak_sabzi_salad': const RecipeData(
      id: 'roti_palak_sabzi_salad',
      name: '2 Roti + Palak Sabzi + Salad',
      nameHi: '2 रोटी + पालक सब्जी + सलाद',
      prepTimeMinutes: 8,
      cookTimeMinutes: 12,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Fresh Spinach (Palak)', quantity: '2 cups washed & chopped'),
        MealIngredient(name: 'Garlic cloves', quantity: '4-5 (finely sliced)'),
        MealIngredient(name: 'Cumin seeds', quantity: '1/2 tsp'),
        MealIngredient(name: 'Turmeric & red chili', quantity: '1/4 tsp each'),
        MealIngredient(name: 'Mustard oil', quantity: '1 tsp'),
        MealIngredient(name: 'Atta', quantity: 'For 2 medium rotis'),
        MealIngredient(name: 'Fresh Salad', quantity: 'Cucumber and radish slices'),
      ],
      instructions: [
        'Heat 1 tsp mustard oil in a pan. Add cumin seeds and sliced garlic; sauté until golden fragrant.',
        'Add turmeric and chopped spinach. Spinach will reduce rapidly in volume.',
        'Cook uncovered on medium flame for 4-5 minutes until excess moisture evaporates.',
        'Season with salt at the end to keep vibrant green color.',
        'Make 2 fresh whole wheat rotis on tawa.',
        'Serve flavorful lasooni palak sabzi with rotis and crisp salad.',
      ],
      instructionsHi: [
        'पैन में 1 चम्मच सरसों तेल गरम करें, जीरा और बारीक लहसुन सुनहरा होने तक भूनें।',
        'हल्दी और कटा पालक डालें।',
        'मध्यम आंच पर बिना ढके 4-5 मिनट तक पानी सूखने तक पकाएं।',
        'अंत में स्वादानुसार नमक मिलाएं।',
        'तवे पर 2 गेहूं की रोटियां सेकें।',
        'लहसुनी पालक सब्जी को 2 रोटियों और ताजे सलाद के साथ परोसें।',
      ],
      substitutions: [
        'Add diced boiled potato (aloo palak) or sweet corn for varied texture.',
      ],
    ),

    'kala_chana_chaat': const RecipeData(
      id: 'kala_chana_chaat',
      name: 'Kala Chana Chaat (uble chane + veggies)',
      nameHi: 'काला चना चाट (उबले चने + सब्जियां)',
      prepTimeMinutes: 10,
      cookTimeMinutes: 5,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Boiled black chickpeas (Kala chana)', quantity: '1 cup tender & drained'),
        MealIngredient(name: 'Cucumber', quantity: '1/2 cup diced'),
        MealIngredient(name: 'Tomato', quantity: '1/2 cup diced'),
        MealIngredient(name: 'Onion', quantity: '1/4 cup finely chopped'),
        MealIngredient(name: 'Green chili & coriander', quantity: '1 tbsp chopped'),
        MealIngredient(name: 'Roasted cumin powder (Bhuna jeera)', quantity: '1/2 tsp'),
        MealIngredient(name: 'Chaat masala & black salt', quantity: '1/2 tsp each'),
        MealIngredient(name: 'Fresh lemon juice', quantity: '1.5 tbsp'),
      ],
      instructions: [
        'In a mixing bowl, place warm or room-temperature boiled kala chana.',
        'Toss in diced cucumber, tomato, onion, green chili, and coriander.',
        'Season with roasted cumin powder, chaat masala, and black salt.',
        'Drizzle fresh lemon juice and toss thoroughly until uniformly coated.',
        'Enjoy immediately as a high-fiber, high-protein refreshing meal.',
      ],
      instructionsHi: [
        'बाउल में उबले हुए काले चने लें।',
        'कटा खीरा, टमाटर, प्याज, हरी मिर्च और हरा धनिया मिलाएं।',
        'भुना जीरा पाउडर, चाट मसाला और काला नमक डालें।',
        'ताजा नींबू का रस निचोड़ें और अच्छी तरह मिलाएं।',
        'स्वादिष्ट और प्रोटीन से भरपूर चाट तुरंत परोसें।',
      ],
      substitutions: [
        'Add sprouted moong or roasted peanuts for extra crunch and nutrients.',
      ],
    ),

    'brown_rice_moong_dal_mix_veg': const RecipeData(
      id: 'brown_rice_moong_dal_mix_veg',
      name: 'Brown Rice + Moong Dal + Mix Veg',
      nameHi: 'ब्राउन राइस + मूंग दाल + मिक्स वेज',
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Brown rice', quantity: '1/3 cup'),
        MealIngredient(name: 'Yellow split moong dal', quantity: '1/3 cup'),
        MealIngredient(name: 'Mixed veggies (carrots, beans, peas)', quantity: '1/2 cup'),
        MealIngredient(name: 'Cumin seeds & turmeric', quantity: '1/2 tsp each'),
        MealIngredient(name: 'Ghee & salt', quantity: '1 tsp ghee, salt to taste'),
      ],
      instructions: [
        'Cook brown rice in 2.5 parts water until soft and tender.',
        'Cook moong dal with turmeric, salt, and water. Temper with cumin seeds in 1 tsp ghee.',
        'Lightly sauté mixed vegetables in 1/2 tsp oil with a pinch of cumin and salt until crisp-tender.',
        'Serve brown rice with comforting yellow dal and sautéed vegetables.',
      ],
      instructionsHi: [
        'ब्राउन राइस को पानी में नरम होने तक पकाएं।',
        'मूंग दाल को हल्दी और नमक के साथ पकाएं और 1 चम्मच घी में जीरे का तड़का लगाएं।',
        'सब्जियों को थोड़े तेल और जीरे में हल्का भूनें।',
        'ब्राउन राइस, दाल और मिक्स वेज को एक साथ परोसें।',
      ],
      substitutions: [
        'White rice or millets (foxtail or barnyard) can substitute brown rice.',
      ],
    ),

    'soya_chunks_sabzi_roti': const RecipeData(
      id: 'soya_chunks_sabzi_roti',
      name: 'Soya Chunks ki Sabzi + 1 Roti',
      nameHi: 'सोया चंक्स की सब्जी + 1 रोटी',
      prepTimeMinutes: 10,
      cookTimeMinutes: 15,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Soya chunks (Nutrela)', quantity: '35 g (1 cup dry)'),
        MealIngredient(name: 'Onion', quantity: '1 medium (chopped)'),
        MealIngredient(name: 'Tomato', quantity: '1 medium (chopped or pureed)'),
        MealIngredient(name: 'Ginger-garlic paste', quantity: '1 tsp'),
        MealIngredient(name: 'Cumin seeds', quantity: '1/2 tsp'),
        MealIngredient(name: 'Spices (turmeric, coriander, garam masala)', quantity: '1/2 tsp each'),
        MealIngredient(name: 'Cooking oil', quantity: '1 tsp'),
        MealIngredient(name: 'Atta', quantity: 'For 1 roti (or side salad)'),
        MealIngredient(name: 'Water & salt', quantity: '1 cup for gravy, salt to taste'),
      ],
      instructions: [
        'Boil soya chunks in salted water for 8-10 minutes. Rinse with cold water and squeeze out excess water completely.',
        'Heat 1 tsp oil in a pan; sauté squeezed soya chunks for 2 minutes and set aside.',
        'In the same pan, splutter cumin seeds and sauté chopped onion and ginger-garlic paste until golden.',
        'Add tomato and spices; cook until oil begins to separate.',
        'Add soya chunks and 1 cup water. Simmer on low-medium flame for 7-8 minutes so chunks absorb gravy.',
        'Make 1 whole wheat roti (or serve with salad). Serve warm.',
      ],
      instructionsHi: [
        'सोया चंक्स को नमक के पानी में 8-10 मिनट उबालें, ठंडा करके पानी पूरी तरह निचोड़ लें।',
        'पैन में 1 चम्मच तेल में चंक्स को 2 मिनट भूनकर निकाल लें।',
        'उसी पैन में जीरा, प्याज और अदरक-लहसुन पेस्ट को सुनहरा होने तक भूनें।',
        'टमाटर और सूखे मसाले डालकर अच्छी तरह पकाएं।',
        'सोया चंक्स और 1 कप पानी डालकर 7-8 मिनट धीमी आंच पर पकाएं ताकि मसाला चंक्स में समा जाए।',
        '1 ताजी रोटी या सलाद के साथ गरम परोसें।',
      ],
      substitutions: [
        'Paneer cubes or pressed tofu can be cooked in the same aromatic gravy.',
      ],
    ),

    'paneer_bhurji_salad': const RecipeData(
      id: 'paneer_bhurji_salad',
      name: 'Paneer Bhurji + Salad (No Roti)',
      nameHi: 'पनीर भुर्जी + सलाद (बिना रोटी)',
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Fresh Paneer', quantity: '100 g (crumbled)'),
        MealIngredient(name: 'Onion', quantity: '1 small (finely chopped)'),
        MealIngredient(name: 'Tomato', quantity: '1 small (finely chopped)'),
        MealIngredient(name: 'Capsicum', quantity: '2 tbsp (finely chopped)'),
        MealIngredient(name: 'Green chili & ginger', quantity: '1/2 tsp (chopped)'),
        MealIngredient(name: 'Cumin seeds', quantity: '1/2 tsp'),
        MealIngredient(name: 'Turmeric & Pav bhaji / Garam masala', quantity: '1/4 tsp each'),
        MealIngredient(name: 'Ghee or butter', quantity: '1 tsp'),
        MealIngredient(name: 'Salad', quantity: 'Sliced cucumber, carrot, and lemon'),
      ],
      instructions: [
        'Heat 1 tsp ghee/butter in a pan and splutter cumin seeds.',
        'Add chopped ginger, green chili, and onion; sauté until light golden.',
        'Add capsicum and tomato; cook for 2 minutes until softened.',
        'Add turmeric, pav bhaji masala, and salt.',
        'Fold in fresh crumbled paneer and toss gently on medium heat for 2-3 minutes (avoid overcooking).',
        'Garnish with coriander leaves.',
        'Serve with a generous portion of crisp cucumber and carrot salad for a light, high-protein meal.',
      ],
      instructionsHi: [
        'पैन में 1 चम्मच घी/मक्खन गरम करें और जीरा चटकाएं।',
        'अदरक, हरी मिर्च और प्याज डालकर हल्का सुनहरा होने तक भूनें।',
        'शिमला मिर्च और टमाटर डालकर 2 मिनट पकाएं।',
        'हल्दी, मसाला और नमक डालें।',
        'मैश किया हुआ पनीर डालें और मध्यम आंच पर 2-3 मिनट हल्के हाथ से चलाएं।',
        'हरा धनिया डालकर गार्निश करें।',
        'खीरा-गाजर सलाद के साथ बिना रोटी के पौष्टिक भोजन का आनंद लें।',
      ],
      substitutions: [
        'Firm crumbled tofu can be substituted for a 100% plant-based option.',
      ],
    ),

    'soya_chunks_dry_roti': const RecipeData(
      id: 'soya_chunks_dry_roti',
      name: 'Soya Chunks Dry + 1 Roti',
      nameHi: 'सोया चंक्स ड्राई + 1 रोटी',
      prepTimeMinutes: 8,
      cookTimeMinutes: 12,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Soya chunks', quantity: '35 g (boiled and squeezed)'),
        MealIngredient(name: 'Onion & Capsicum', quantity: '1/2 cup diced stir-fry style'),
        MealIngredient(name: 'Ginger-garlic paste', quantity: '1 tsp'),
        MealIngredient(name: 'Mustard seeds & curry leaves', quantity: '1/2 tsp seeds, 5 leaves'),
        MealIngredient(name: 'Black pepper & cumin powder', quantity: '1/2 tsp each'),
        MealIngredient(name: 'Chaat masala & salt', quantity: 'To taste'),
        MealIngredient(name: 'Cooking oil', quantity: '1 tsp'),
        MealIngredient(name: 'Atta', quantity: 'For 1 whole wheat roti'),
      ],
      instructions: [
        'Boil, firmly squeeze, and halve the soya chunks.',
        'Heat 1 tsp oil in a pan or wok. Add mustard seeds and curry leaves until crackling.',
        'Add ginger-garlic paste, diced onion, and capsicum; stir-fry on high heat for 2 minutes.',
        'Add soya chunks, black pepper, cumin powder, chaat masala, and salt.',
        'Toss on high flame for 3-4 minutes until soya chunks are roasted and aromatic.',
        'Serve hot with 1 whole wheat roti.',
      ],
      instructionsHi: [
        'सोया चंक्स को उबालकर पानी निचोड़ लें और दो हिस्सों में काट लें।',
        'कड़ाही में तेल गरम करें, राई और कढ़ी पत्ता चटकाएं।',
        'अदरक-लहसुन पेस्ट, प्याज और शिमला मिर्च डालकर तेज आंच पर 2 मिनट भूनें।',
        'सोया चंक्स, काली मिर्च, जीरा पाउडर, चाट मसाला और नमक डालें।',
        'तेज आंच पर 3-4 मिनट तक अच्छी तरह टॉस करें।',
        '1 ताजी गेहूं की रोटी के साथ परोसें।',
      ],
      substitutions: [
        'Paneer cubes or roasted mushrooms can replace soya chunks.',
      ],
    ),

    'paneer_veggie_stir_fry': const RecipeData(
      id: 'paneer_veggie_stir_fry',
      name: 'Paneer & Veggie Stir-fry',
      nameHi: 'पनीर और वेजी स्टिर-फ्राई',
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Fresh Paneer', quantity: '100 g (cubed)'),
        MealIngredient(name: 'Colorful veggies (bell peppers, carrots, beans, broccoli)', quantity: '1.5 cups chopped'),
        MealIngredient(name: 'Garlic', quantity: '3 cloves (minced)'),
        MealIngredient(name: 'Black pepper', quantity: '1/2 tsp freshly ground'),
        MealIngredient(name: 'Cumin powder & lemon juice', quantity: '1/4 tsp cumin, 1 tsp lemon'),
        MealIngredient(name: 'Olive oil or Ghee', quantity: '1 tsp'),
        MealIngredient(name: 'Salt', quantity: 'To taste'),
      ],
      instructions: [
        'Heat 1 tsp olive oil or ghee in a wide skillet over medium-high flame.',
        'Add minced garlic and sauté for 30 seconds until fragrant.',
        'Add harder vegetables (carrots, beans, broccoli) first; stir-fry for 3 minutes.',
        'Add bell peppers and paneer cubes; sauté for another 3 minutes until paneer edges are golden.',
        'Season with salt, black pepper, and cumin powder.',
        'Squeeze lemon juice, toss well, and serve hot.',
      ],
      instructionsHi: [
        'पैन में 1 चम्मच जैतून तेल या घी गरम करें।',
        'बारीक लहसुन डालकर 30 सेकंड तक भूनें।',
        'गाजर, बीन्स और ब्रोकली डालकर तेज आंच पर 3 मिनट भूनें।',
        'शिमला मिर्च और पनीर के टुकड़े डालकर 3 मिनट और भूनें।',
        'नमक, काली मिर्च और जीरा पाउडर डालें।',
        'नींबू का रस निचोड़ें, टॉस करें और गरमा-गरम परोसें।',
      ],
      substitutions: [
        'Extra firm tofu can be used instead of paneer for a vegan stir-fry.',
      ],
    ),

    'veg_dalia_khichdi': const RecipeData(
      id: 'veg_dalia_khichdi',
      name: 'Veg Dalia Khichdi (one-pot meal)',
      nameHi: 'वेज दलिया खिचड़ी (वन-पॉट मील)',
      prepTimeMinutes: 8,
      cookTimeMinutes: 18,
      servings: 1,
      ingredients: [
        MealIngredient(name: 'Broken wheat (Dalia)', quantity: '1/3 cup'),
        MealIngredient(name: 'Yellow split moong dal', quantity: '2 tbsp (washed)'),
        MealIngredient(name: 'Mixed veggies (peas, carrots, beans, tomato)', quantity: '1/2 cup chopped'),
        MealIngredient(name: 'Cumin seeds & Hing', quantity: '1/2 tsp cumin, 1 pinch hing'),
        MealIngredient(name: 'Turmeric powder', quantity: '1/4 tsp'),
        MealIngredient(name: 'Ghee', quantity: '1 tsp'),
        MealIngredient(name: 'Water & salt', quantity: '2 cups water, salt to taste'),
      ],
      instructions: [
        'Dry roast dalia in pressure cooker or pan for 2-3 minutes until nutty; set aside.',
        'Heat 1 tsp ghee in pressure cooker. Splutter cumin seeds and hing.',
        'Add chopped vegetables, turmeric, and salt; stir for 1 minute.',
        'Add roasted dalia, washed moong dal, and 2 cups of water.',
        'Close lid and cook for 3-4 whistles on medium heat.',
        'Allow steam to release naturally. Stir gently to a porridge-like comforting consistency.',
        'Serve hot with a spoonful of homemade curd.',
      ],
      instructionsHi: [
        'दलिया को 2-3 मिनट सूखा भूनकर अलग रख लें।',
        'कुकर में 1 चम्मच घी गरम करें, जीरा और हींग चटकाएं।',
        'कटी सब्जियां, हल्दी और नमक डालकर 1 मिनट भूनें।',
        'भुना दलिया, धुली मूंग दाल और 2 कप पानी डालें।',
        'कुकर का ढक्कन बंद करके मध्यम आंच पर 3-4 सीटी लगाएं।',
        'भाप निकलने के बाद हल्का चलाएं।',
        'गरम-गरम दलिया खिचड़ी दही के साथ परोसें।',
      ],
      substitutions: [
        'Quinoa or brown rice can be cooked with moong dal in the same one-pot style.',
      ],
    ),
  };

  // 21 Weekly Menu Entries (7 Days * 3 Meals) Exactly matching reference
  static const List<WeeklyMenuEntry> weeklyMenu = [
    // Monday (1)
    WeeklyMenuEntry(
      id: 'mon_breakfast',
      dayOfWeek: 1,
      mealType: 'breakfast',
      title: 'Masala Oats (vegetables ke saath)',
      titleHi: 'मसाला ओट्स (सब्जियों के साथ)',
      recipeId: 'masala_oats',
    ),
    WeeklyMenuEntry(
      id: 'mon_lunch',
      dayOfWeek: 1,
      mealType: 'lunch',
      title: '2 Roti + Moong Dal + Kheera Salad',
      titleHi: '2 रोटी + मूंग दाल + खीरा सलाद',
      recipeId: 'roti_moong_dal_salad',
    ),
    WeeklyMenuEntry(
      id: 'mon_dinner',
      dayOfWeek: 1,
      mealType: 'dinner',
      title: 'Soya Chunks ki Sabzi + 1 Roti',
      titleHi: 'सोया चंक्स की सब्जी + 1 रोटी',
      recipeId: 'soya_chunks_sabzi_roti',
    ),

    // Tuesday (2)
    WeeklyMenuEntry(
      id: 'tue_breakfast',
      dayOfWeek: 2,
      mealType: 'breakfast',
      title: 'Besan Cheela (pyaaz, tamatar daalkar)',
      titleHi: 'बेसन चीला (प्याज, टमाटर डालकर)',
      recipeId: 'besan_cheela',
    ),
    WeeklyMenuEntry(
      id: 'tue_lunch',
      dayOfWeek: 2,
      mealType: 'lunch',
      title: '2 Roti + Mix Veg Sabzi + Salad',
      titleHi: '2 रोटी + मिक्स वेज सब्जी + सलाद',
      recipeId: 'roti_mix_veg_salad',
    ),
    WeeklyMenuEntry(
      id: 'tue_dinner',
      dayOfWeek: 2,
      mealType: 'dinner',
      title: 'Paneer Bhurji + Salad (No Roti)',
      titleHi: 'पनीर भुर्जी + सलाद (बिना रोटी)',
      recipeId: 'paneer_bhurji_salad',
    ),

    // Wednesday (3)
    WeeklyMenuEntry(
      id: 'wed_breakfast',
      dayOfWeek: 3,
      mealType: 'breakfast',
      title: 'Oats Dalia Upma',
      titleHi: 'ओट्स दलिया उपमा',
      recipeId: 'oats_dalia_upma',
    ),
    WeeklyMenuEntry(
      id: 'wed_lunch',
      dayOfWeek: 3,
      mealType: 'lunch',
      title: 'Brown Rice + Kala Chana Curry',
      titleHi: 'ब्राउन राइस + काला चना करी',
      recipeId: 'brown_rice_kala_chana',
    ),
    WeeklyMenuEntry(
      id: 'wed_dinner',
      dayOfWeek: 3,
      mealType: 'dinner',
      title: 'Soya Chunks Dry + 1 Roti',
      titleHi: 'सोया चंक्स ड्राई + 1 रोटी',
      recipeId: 'soya_chunks_dry_roti',
    ),

    // Thursday (4)
    WeeklyMenuEntry(
      id: 'thu_breakfast',
      dayOfWeek: 4,
      mealType: 'breakfast',
      title: 'Moong Dal Cheela (ready powder se)',
      titleHi: 'मूंग दाल चीला (रेडी पाउडर से)',
      recipeId: 'moong_dal_cheela',
    ),
    WeeklyMenuEntry(
      id: 'thu_lunch',
      dayOfWeek: 4,
      mealType: 'lunch',
      title: '2 Roti + Palak Sabzi + Salad',
      titleHi: '2 रोटी + पालक सब्जी + सलाद',
      recipeId: 'roti_palak_sabzi_salad',
    ),
    WeeklyMenuEntry(
      id: 'thu_dinner',
      dayOfWeek: 4,
      mealType: 'dinner',
      title: 'Paneer & Veggie Stir-fry',
      titleHi: 'पनीर और वेजी स्टिर-फ्राई',
      recipeId: 'paneer_veggie_stir_fry',
    ),

    // Friday (5)
    WeeklyMenuEntry(
      id: 'fri_breakfast',
      dayOfWeek: 5,
      mealType: 'breakfast',
      title: 'Masala Oats',
      titleHi: 'मसाला ओट्स',
      recipeId: 'masala_oats',
    ),
    WeeklyMenuEntry(
      id: 'fri_lunch',
      dayOfWeek: 5,
      mealType: 'lunch',
      title: '2 Roti + Moong Dal + Salad',
      titleHi: '2 रोटी + मूंग दाल + सलाद',
      recipeId: 'roti_moong_dal_salad',
    ),
    WeeklyMenuEntry(
      id: 'fri_dinner',
      dayOfWeek: 5,
      mealType: 'dinner',
      title: 'Veg Dalia Khichdi (one-pot meal)',
      titleHi: 'वेज दलिया खिचड़ी (वन-पॉट मील)',
      recipeId: 'veg_dalia_khichdi',
    ),

    // Saturday (6)
    WeeklyMenuEntry(
      id: 'sat_breakfast',
      dayOfWeek: 6,
      mealType: 'breakfast',
      title: 'Besan Cheela',
      titleHi: 'बेसन चीला',
      recipeId: 'besan_cheela',
    ),
    WeeklyMenuEntry(
      id: 'sat_lunch',
      dayOfWeek: 6,
      mealType: 'lunch',
      title: 'Kala Chana Chaat (uble chane + veggies)',
      titleHi: 'काला चना चाट (उबले चने + सब्जियां)',
      recipeId: 'kala_chana_chaat',
    ),
    WeeklyMenuEntry(
      id: 'sat_dinner',
      dayOfWeek: 6,
      mealType: 'dinner',
      title: 'Soya Chunks ki Sabzi + Salad',
      titleHi: 'सोया चंक्स की सब्जी + सलाद',
      recipeId: 'soya_chunks_sabzi_roti',
    ),

    // Sunday (7)
    WeeklyMenuEntry(
      id: 'sun_breakfast',
      dayOfWeek: 7,
      mealType: 'breakfast',
      title: 'Moong Dal Cheela (ready powder se)',
      titleHi: 'मूंग दाल चीला (रेडी पाउडर से)',
      recipeId: 'moong_dal_cheela',
    ),
    WeeklyMenuEntry(
      id: 'sun_lunch',
      dayOfWeek: 7,
      mealType: 'lunch',
      title: 'Brown Rice + Moong Dal + Mix Veg',
      titleHi: 'ब्राउन राइस + मूंग दाल + मिक्स वेज',
      recipeId: 'brown_rice_moong_dal_mix_veg',
    ),
    WeeklyMenuEntry(
      id: 'sun_dinner',
      dayOfWeek: 7,
      mealType: 'dinner',
      title: 'Paneer Bhurji + Salad',
      titleHi: 'पनीर भुर्जी + सलाद',
      recipeId: 'paneer_bhurji_salad',
    ),
  ];

  static RecipeData? getRecipe(String recipeId) => recipes[recipeId];

  static List<MealItem> getMealItemsForDay(int dayOfWeek) {
    final entries = weeklyMenu.where((e) => e.dayOfWeek == dayOfWeek).toList();
    return entries.map((e) {
      final recipe = recipes[e.recipeId]!;
      return MealItem(
        id: e.id,
        dayOfWeek: e.dayOfWeek,
        mealType: e.mealType,
        name: e.title,
        nameHi: e.titleHi,
        prepTimeMinutes: recipe.prepTimeMinutes + recipe.cookTimeMinutes,
        approxCalories: 300,
        approxProteinG: 12.0,
        approxCarbsG: 40.0,
        approxFatG: 7.0,
        approxFiberG: 6.0,
        hostelCategories: const ['mess', 'kettle', 'shared_kitchen', 'full_kitchen'],
        budgetTier: 'low',
        ingredients: recipe.ingredients,
        instructions: recipe.instructions,
        substitutions: recipe.substitutions,
        prepAheadNote: '',
        pcodTip: '',
      );
    }).toList();
  }

  static List<MealItem> getAllMealItems() {
    return weeklyMenu.map((e) {
      final recipe = recipes[e.recipeId]!;
      return MealItem(
        id: e.id,
        dayOfWeek: e.dayOfWeek,
        mealType: e.mealType,
        name: e.title,
        nameHi: e.titleHi,
        prepTimeMinutes: recipe.prepTimeMinutes + recipe.cookTimeMinutes,
        approxCalories: 300,
        approxProteinG: 12.0,
        approxCarbsG: 40.0,
        approxFatG: 7.0,
        approxFiberG: 6.0,
        hostelCategories: const ['mess', 'kettle', 'shared_kitchen', 'full_kitchen'],
        budgetTier: 'low',
        ingredients: recipe.ingredients,
        instructions: recipe.instructions,
        substitutions: recipe.substitutions,
        prepAheadNote: '',
        pcodTip: '',
      );
    }).toList();
  }
}
