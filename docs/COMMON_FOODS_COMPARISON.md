# Common foods compared with the original GoHard catalog

Generated from `app/assets/data/common-foods.json` (version 1) and the original app's `FoodSeedData.cs`
(GoHardAPI revision 27ac638, 76 definitions, supplied as `legacy-food-catalog-reference.json`). The original values
had no source IDs or citations; they are shown only for comparison and are not used anywhere in the app.

**Summary.** 76 original names; 75 are covered by a traceable USDA FoodData Central record and
1 is not: Protein Bar. The catalog has 74 foods.
Every item is the record exactly as the rebuild API returns it from USDA (source `usda`, the FDC ID, the record's
own values, basis and portions); the everyday name, preparation label, category, aliases and starting portion are
GoHard's labels around it. Where the original row and the record differ, the record is what the app uses.

Why some rows differ noticeably:
- **Ground beef 90%**: the record is the cooked (broiled) patty; the original 176 kcal matches raw.
- **Tofu**: the record is firm tofu; the original 76 kcal matches regular.
- **Whey protein**: the closest generic record is "Protein powder, whey based"; the original was a branded-style estimate.
- **Almonds, walnuts**: Foundation/SR Legacy records were chosen over FNDDS ones, whose energy ran 8–12% above the others.
- **Drinks** (milk, juice, coconut water): values stay per 100 g with the record's gram portions ("1 cup = 244 g");
  no gram-to-millilitre density was assumed, so "1 cup" is offered only where the record states its weight.
- **Starting portion**: a count portion only where the record states one ("1 egg = 50 g"); otherwise 100 g.

| Original name | Catalog food · preparation | Category | USDA record (FDC ID, data type) | Starts at | Original row | Record, same amount |
|---|---|---|---|---|---|---|
| Chicken Breast | Chicken breast · Baked or roasted · skinless | Proteins | [2705956](https://fdc.nal.usda.gov/food-details/2705956/nutrients) Survey (FNDDS) | 1 medium breast = 120 g | 100 g: 165 kcal, 31 g | 161 kcal, 30.2 g |
| Eggs | Eggs · Whole · raw | Proteins | [2707152](https://fdc.nal.usda.gov/food-details/2707152/nutrients) Survey (FNDDS) | 1 egg = 50 g | 50 g: 78 kcal, 6 g | 71.5 kcal, 6.2 g |
| Salmon | Salmon · Atlantic, farmed · cooked | Proteins | [175168](https://fdc.nal.usda.gov/food-details/175168/nutrients) SR Legacy | 100 g | 100 g: 208 kcal, 20 g | 206 kcal, 22.1 g |
| Ground Beef (90% lean) | Ground beef 90% lean · Patty · broiled | Proteins | [174031](https://fdc.nal.usda.gov/food-details/174031/nutrients) SR Legacy | 100 g | 100 g: 176 kcal, 26 g | 217 kcal, 26.1 g |
| Greek Yogurt | Greek yogurt · Plain · nonfat | Proteins | [2705424](https://fdc.nal.usda.gov/food-details/2705424/nutrients) Survey (FNDDS) | 1 cup = 245 g | 170 g: 100 kcal, 17 g | 100.3 kcal, 17.5 g |
| Tofu | Tofu · Firm · raw | Proteins | [172475](https://fdc.nal.usda.gov/food-details/172475/nutrients) SR Legacy | 100 g | 100 g: 76 kcal, 8 g | 144 kcal, 17.3 g |
| Tuna (canned in water) | Tuna · Light · canned in water, drained | Proteins | [334194](https://fdc.nal.usda.gov/food-details/334194/nutrients) Foundation | 100 g | 85 g: 73 kcal, 17 g | 76.5 kcal, 16.2 g |
| Turkey Breast | Turkey breast · Roasted · meat only | Proteins | [171496](https://fdc.nal.usda.gov/food-details/171496/nutrients) SR Legacy | 100 g | 100 g: 135 kcal, 30 g | 147 kcal, 30.1 g |
| Shrimp | Shrimp · Cooked | Proteins | [175180](https://fdc.nal.usda.gov/food-details/175180/nutrients) SR Legacy | 100 g | 100 g: 99 kcal, 24 g | 99 kcal, 24 g |
| Cottage Cheese (Low-fat) | Cottage cheese · Low-fat · 1% milkfat | Proteins | [173417](https://fdc.nal.usda.gov/food-details/173417/nutrients) SR Legacy | 100 g | 113 g: 81 kcal, 14 g | 81.4 kcal, 14 g |
| Pork Tenderloin | Pork tenderloin · Roasted · lean only | Proteins | [168250](https://fdc.nal.usda.gov/food-details/168250/nutrients) SR Legacy | 100 g | 100 g: 143 kcal, 26 g | 143 kcal, 26.2 g |
| Egg Whites | Egg whites · Whites only · raw | Proteins | [2707168](https://fdc.nal.usda.gov/food-details/2707168/nutrients) Survey (FNDDS) | 1 egg white = 33 g | 100 g: 52 kcal, 11 g | 52 kcal, 10.7 g |
| Tempeh | Tempeh · Fermented soybean | Proteins | [174272](https://fdc.nal.usda.gov/food-details/174272/nutrients) SR Legacy | 100 g | 100 g: 192 kcal, 20 g | 192 kcal, 20.3 g |
| Cod | Cod · Atlantic · cooked | Proteins | [171956](https://fdc.nal.usda.gov/food-details/171956/nutrients) SR Legacy | 100 g | 100 g: 82 kcal, 18 g | 105 kcal, 22.8 g |
| Whey Protein Powder | Whey protein powder · Whey based · dry powder | Proteins | [173180](https://fdc.nal.usda.gov/food-details/173180/nutrients) SR Legacy | 100 g | 30 g: 120 kcal, 24 g | 105.6 kcal, 23.4 g |
| Brown Rice | Brown rice · Cooked · no added fat | Carbohydrates | [2708414](https://fdc.nal.usda.gov/food-details/2708414/nutrients) Survey (FNDDS) | 1 cup, cooked = 195 g | 195 g: 248 kcal, 5.5 g | 239.9 kcal, 4.7 g |
| Oatmeal | Oats · Dry · uncooked | Carbohydrates | [2708489](https://fdc.nal.usda.gov/food-details/2708489/nutrients) Survey (FNDDS) | 100 g | 40 g: 150 kcal, 5 g | 151.6 kcal, 5.3 g |
| Sweet Potato | Sweet potato · Baked · no added fat | Carbohydrates | [2709699](https://fdc.nal.usda.gov/food-details/2709699/nutrients) Survey (FNDDS) | 1 medium = 150 g | 150 g: 129 kcal, 2.4 g | 123 kcal, 2.5 g |
| Quinoa | Quinoa · Cooked · no added fat | Carbohydrates | [2708400](https://fdc.nal.usda.gov/food-details/2708400/nutrients) Survey (FNDDS) | 1 cup, cooked = 170 g | 185 g: 222 kcal, 8 g | 222 kcal, 8.1 g |
| Whole Wheat Bread | Whole wheat bread · Sliced loaf | Carbohydrates | [2707709](https://fdc.nal.usda.gov/food-details/2707709/nutrients) Survey (FNDDS) | 1 medium or regular slice = 36 g | 43 g: 110 kcal, 5 g | 109.2 kcal, 5.3 g |
| White Rice | White rice · Cooked · no added fat | Carbohydrates | [2708408](https://fdc.nal.usda.gov/food-details/2708408/nutrients) Survey (FNDDS) | 1 cup, cooked = 158 g | 158 g: 206 kcal, 4.3 g | 203.8 kcal, 4.2 g |
| Whole Wheat Pasta | Whole wheat pasta · Whole grain · cooked | Carbohydrates | [2708358](https://fdc.nal.usda.gov/food-details/2708358/nutrients) Survey (FNDDS) | 1 cup, cooked = 140 g | 140 g: 174 kcal, 7.5 g | 207.2 kcal, 8.3 g |
| Potato | Potato · Baked · with skin | Carbohydrates | [2709524](https://fdc.nal.usda.gov/food-details/2709524/nutrients) Survey (FNDDS) | 1 medium = 285 g | 173 g: 161 kcal, 4.3 g | 160.9 kcal, 4.3 g |
| Black Beans | Black beans · Cooked from dried · no added fat | Carbohydrates | [2707361](https://fdc.nal.usda.gov/food-details/2707361/nutrients) Survey (FNDDS) | 1 cup = 180 g | 172 g: 227 kcal, 15 g | 225.3 kcal, 15.2 g |
| Chickpeas | Chickpeas · Cooked from dried · no added fat | Carbohydrates | [2707416](https://fdc.nal.usda.gov/food-details/2707416/nutrients) Survey (FNDDS) | 1 cup = 180 g | 164 g: 269 kcal, 15 g | 267.3 kcal, 14.4 g |
| Lentils | Lentils · Cooked from dried · no added fat | Carbohydrates | [2707425](https://fdc.nal.usda.gov/food-details/2707425/nutrients) Survey (FNDDS) | 1 cup = 180 g | 198 g: 230 kcal, 18 g | 227.7 kcal, 17.8 g |
| Banana | Banana · Raw | Carbohydrates | [2709224](https://fdc.nal.usda.gov/food-details/2709224/nutrients) Survey (FNDDS) | 1 banana = 126 g | 118 g: 105 kcal, 1.3 g | 114.5 kcal, 0.9 g |
| Corn Tortilla | Corn tortilla · Corn | Carbohydrates | [2707823](https://fdc.nal.usda.gov/food-details/2707823/nutrients) Survey (FNDDS) | 1 medium = 28 g | 26 g: 52 kcal, 1.4 g | 56.7 kcal, 1.5 g |
| Bagel | Bagel · Regular | Carbohydrates | [2707684](https://fdc.nal.usda.gov/food-details/2707684/nutrients) Survey (FNDDS) | 1 regular = 105 g | 98 g: 277 kcal, 11 g | 258.7 kcal, 10.3 g |
| English Muffin | English muffin · Whole wheat | Carbohydrates | [2707741](https://fdc.nal.usda.gov/food-details/2707741/nutrients) Survey (FNDDS) | 1 muffin = 58 g | 57 g: 134 kcal, 5 g | 127.1 kcal, 5 g |
| Broccoli | Broccoli · Raw | Vegetables | [2709643](https://fdc.nal.usda.gov/food-details/2709643/nutrients) Survey (FNDDS) | 1 cup = 90 g | 91 g: 31 kcal, 2.5 g | 35.5 kcal, 2.3 g |
| Spinach | Spinach · Raw | Vegetables | [2709614](https://fdc.nal.usda.gov/food-details/2709614/nutrients) Survey (FNDDS) | 1 cup = 25 g | 30 g: 7 kcal, 0.9 g | 8.1 kcal, 0.9 g |
| Kale | Kale · Raw | Vegetables | [2709599](https://fdc.nal.usda.gov/food-details/2709599/nutrients) Survey (FNDDS) | 1 cup = 25 g | 67 g: 33 kcal, 2.2 g | 28.8 kcal, 2 g |
| Bell Pepper | Bell pepper · Red · raw | Vegetables | [2709801](https://fdc.nal.usda.gov/food-details/2709801/nutrients) Survey (FNDDS) | 1 regular = 120 g | 119 g: 31 kcal, 1 g | 36.9 kcal, 1.1 g |
| Carrots | Carrots · Raw | Vegetables | [2709660](https://fdc.nal.usda.gov/food-details/2709660/nutrients) Survey (FNDDS) | 1 regular carrot = 60 g | 61 g: 25 kcal, 0.6 g | 26.8 kcal, 0.5 g |
| Cucumber | Cucumber · Raw | Vegetables | [2709784](https://fdc.nal.usda.gov/food-details/2709784/nutrients) Survey (FNDDS) | 1 cup = 120 g | 104 g: 16 kcal, 0.7 g | 16.6 kcal, 0.6 g |
| Tomato | Tomato · Raw | Vegetables | [2709719](https://fdc.nal.usda.gov/food-details/2709719/nutrients) Survey (FNDDS) | 1 whole = 125 g | 123 g: 22 kcal, 1.1 g | 24.6 kcal, 1 g |
| Asparagus | Asparagus · Cooked · no added fat | Vegetables | [2709834](https://fdc.nal.usda.gov/food-details/2709834/nutrients) Survey (FNDDS) | 1 cup = 180 g | 134 g: 27 kcal, 3 g | 28.1 kcal, 3.2 g |
| Zucchini | Zucchini · Raw · with skin | Vegetables | [169291](https://fdc.nal.usda.gov/food-details/169291/nutrients) SR Legacy | 100 g | 124 g: 21 kcal, 1.5 g | 21.1 kcal, 1.5 g |
| Cauliflower | Cauliflower · Raw | Vegetables | [2709777](https://fdc.nal.usda.gov/food-details/2709777/nutrients) Survey (FNDDS) | 1 cup = 110 g | 107 g: 27 kcal, 2 g | 26.8 kcal, 2.1 g |
| Green Beans | Green beans · Cooked · no added fat | Vegetables | [2709852](https://fdc.nal.usda.gov/food-details/2709852/nutrients) Survey (FNDDS) | 1 cup = 140 g | 100 g: 31 kcal, 1.8 g | 42 kcal, 2.1 g |
| Brussels Sprouts | Brussels sprouts · Cooked · no added fat | Vegetables | [2709881](https://fdc.nal.usda.gov/food-details/2709881/nutrients) Survey (FNDDS) | 1 cup = 155 g | 88 g: 38 kcal, 3 g | 39.6 kcal, 3.1 g |
| Apple | Apple · Raw | Fruits | [2709215](https://fdc.nal.usda.gov/food-details/2709215/nutrients) Survey (FNDDS) | 1 medium = 200 g | 182 g: 95 kcal, 0.5 g | 111 kcal, 0.3 g |
| Blueberries | Blueberries · Raw | Fruits | [2709275](https://fdc.nal.usda.gov/food-details/2709275/nutrients) Survey (FNDDS) | 1 cup = 150 g | 148 g: 84 kcal, 1.1 g | 94.7 kcal, 1 g |
| Orange | Orange · Raw | Fruits | [2709171](https://fdc.nal.usda.gov/food-details/2709171/nutrients) Survey (FNDDS) | 1 fruit = 154 g | 131 g: 62 kcal, 1.2 g | 65.5 kcal, 1.2 g |
| Avocado | Avocado · Raw | Fruits | [2709223](https://fdc.nal.usda.gov/food-details/2709223/nutrients) Survey (FNDDS) | 1 fruit = 150 g | 150 g: 240 kcal, 3 g | 240 kcal, 3 g |
| Strawberries | Strawberries · Raw | Fruits | [2709283](https://fdc.nal.usda.gov/food-details/2709283/nutrients) Survey (FNDDS) | 1 cup = 150 g | 152 g: 49 kcal, 1 g | 54.7 kcal, 1 g |
| Grapes | Grapes · Raw | Fruits | [2709237](https://fdc.nal.usda.gov/food-details/2709237/nutrients) Survey (FNDDS) | 1 cup = 150 g | 151 g: 104 kcal, 1.1 g | 125.3 kcal, 1.4 g |
| Mango | Mango · Raw | Fruits | [2709242](https://fdc.nal.usda.gov/food-details/2709242/nutrients) Survey (FNDDS) | 1 cup = 165 g | 165 g: 99 kcal, 1.4 g | 99 kcal, 1.4 g |
| Pineapple | Pineapple · Raw | Fruits | [2709260](https://fdc.nal.usda.gov/food-details/2709260/nutrients) Survey (FNDDS) | 1 cup = 165 g | 165 g: 82 kcal, 0.9 g | 99 kcal, 0.8 g |
| Milk (2%) | Milk 2% · Reduced fat | Dairy | [2705386](https://fdc.nal.usda.gov/food-details/2705386/nutrients) Survey (FNDDS) | 1 cup = 244 g | 244 ml: 122 kcal, 8 g | not comparable (units differ) |
| Cheddar Cheese | Cheddar cheese · Regular | Dairy | [2705709](https://fdc.nal.usda.gov/food-details/2705709/nutrients) Survey (FNDDS) | 1 slice = 21 g | 28 g: 113 kcal, 7 g | 114.5 kcal, 6.5 g |
| Almond Milk (Unsweetened) | Almond milk · Unsweetened | Dairy | [2705409](https://fdc.nal.usda.gov/food-details/2705409/nutrients) Survey (FNDDS) | 1 cup = 244 g | 240 ml: 30 kcal, 1 g | not comparable (units differ) |
| Mozzarella Cheese | Mozzarella · Part skim | Dairy | [2705723](https://fdc.nal.usda.gov/food-details/2705723/nutrients) Survey (FNDDS) | 1 slice = 21 g | 28 g: 85 kcal, 6 g | 82.9 kcal, 6.6 g |
| Skim Milk | Skim milk · Fat free | Dairy | [2705388](https://fdc.nal.usda.gov/food-details/2705388/nutrients) Survey (FNDDS) | 1 cup = 244 g | 244 ml: 83 kcal, 8 g | not comparable (units differ) |
| Parmesan Cheese | Parmesan · Dry grated | Dairy | [2705728](https://fdc.nal.usda.gov/food-details/2705728/nutrients) Survey (FNDDS) | 1 tablespoon = 6.2 g | 28 g: 111 kcal, 10 g | 115.4 kcal, 8.4 g |
| Butter | Butter · Stick | Dairy | [2710155](https://fdc.nal.usda.gov/food-details/2710155/nutrients) Survey (FNDDS) | 1 tablespoon = 14 g | 14 g: 102 kcal, 0.1 g | 104 kcal, 0.1 g |
| Cream Cheese | Cream cheese · Regular · plain | Dairy | [2705760](https://fdc.nal.usda.gov/food-details/2705760/nutrients) Survey (FNDDS) | 1 tablespoon = 15 g | 28 g: 99 kcal, 1.7 g | 96 kcal, 1.6 g |
| Olive Oil | Olive oil · Oil | Fats & Oils | [2710186](https://fdc.nal.usda.gov/food-details/2710186/nutrients) Survey (FNDDS) | 1 tablespoon = 14 g | 14 ml: 119 kcal, 0 g | not comparable (units differ) |
| Almonds | Almonds · Whole · raw | Fats & Oils | [2346393](https://fdc.nal.usda.gov/food-details/2346393/nutrients) Foundation | 100 g | 28 g: 164 kcal, 6 g | 163.5 kcal, 6 g |
| Peanut Butter | Peanut butter · Regular | Fats & Oils | [2707537](https://fdc.nal.usda.gov/food-details/2707537/nutrients) Survey (FNDDS) | 1 tablespoon = 16 g | 32 g: 188 kcal, 8 g | 191.4 kcal, 7.1 g |
| Chia Seeds | Chia seeds · Seeds | Fats & Oils | [2707590](https://fdc.nal.usda.gov/food-details/2707590/nutrients) Survey (FNDDS) | 100 g | 28 g: 138 kcal, 4.7 g | 136.1 kcal, 4.6 g |
| Walnuts | Walnuts · English walnuts | Fats & Oils | [170187](https://fdc.nal.usda.gov/food-details/170187/nutrients) SR Legacy | 100 g | 28 g: 185 kcal, 4.3 g | 183.1 kcal, 4.3 g |
| Coconut Oil | Coconut oil · Oil | Fats & Oils | [2710182](https://fdc.nal.usda.gov/food-details/2710182/nutrients) Survey (FNDDS) | 1 tablespoon = 14 g | 14 ml: 121 kcal, 0 g | not comparable (units differ) |
| Hummus | Hummus · Plain | Snacks | [2707402](https://fdc.nal.usda.gov/food-details/2707402/nutrients) Survey (FNDDS) | 1 tablespoon = 15 g | 30 g: 52 kcal, 2 g | 72.9 kcal, 2.2 g |
| Dark Chocolate (70%) | Dark chocolate · 70–85% cacao | Snacks | [170273](https://fdc.nal.usda.gov/food-details/170273/nutrients) SR Legacy | 100 g | 28 g: 170 kcal, 2 g | 167.4 kcal, 2.2 g |
| Rice Cakes | Rice cakes · Brown rice · plain, unsalted | Snacks | [170250](https://fdc.nal.usda.gov/food-details/170250/nutrients) SR Legacy | 100 g | 9 g: 35 kcal, 0.7 g | 34.8 kcal, 0.7 g |
| Trail Mix | Trail mix · Regular | Snacks | [167561](https://fdc.nal.usda.gov/food-details/167561/nutrients) SR Legacy | 100 g | 40 g: 173 kcal, 5 g | 184.8 kcal, 5.5 g |
| Beef Jerky | Beef jerky · Chopped and formed | Snacks | [167536](https://fdc.nal.usda.gov/food-details/167536/nutrients) SR Legacy | 100 g | 28 g: 116 kcal, 9.4 g | 114.8 kcal, 9.3 g |
| Popcorn (Air-popped) | Popcorn · Air-popped · no butter | Snacks | [2708219](https://fdc.nal.usda.gov/food-details/2708219/nutrients) Survey (FNDDS) | 1 cup, popped = 8 g | 8 g: 31 kcal, 1 g | 30.8 kcal, 1 g |
| String Cheese | Mozzarella · Part skim | Dairy (was Snacks) | [2705723](https://fdc.nal.usda.gov/food-details/2705723/nutrients) Survey (FNDDS) | 1 slice = 21 g | 28 g: 80 kcal, 7 g | 82.9 kcal, 6.6 g |
| Coffee (Black) | Coffee · Brewed | Beverages | [2710375](https://fdc.nal.usda.gov/food-details/2710375/nutrients) Survey (FNDDS) | 1 cup (8 fl oz) = 240 g | 240 ml: 2 kcal, 0.3 g | not comparable (units differ) |
| Green Tea | Green tea · Hot · brewed from leaf | Beverages | [2710490](https://fdc.nal.usda.gov/food-details/2710490/nutrients) Survey (FNDDS) | 1 cup = 240 g | 245 ml: 2 kcal, 0 g | not comparable (units differ) |
| Orange Juice | Orange juice · 100% · freshly squeezed | Beverages | [2709187](https://fdc.nal.usda.gov/food-details/2709187/nutrients) Survey (FNDDS) | 100 g | 240 ml: 112 kcal, 2 g | not comparable (units differ) |
| Coconut Water | Coconut water · Unsweetened | Beverages | [2707572](https://fdc.nal.usda.gov/food-details/2707572/nutrients) Survey (FNDDS) | 100 g | 240 ml: 46 kcal, 1.7 g | not comparable (units differ) |

Rebuild: `node scripts/build-common-foods.mjs --cache <dir> [--offline]`; spec: `scripts/common-foods.spec.json`.
