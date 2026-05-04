const restaurants = [
  {
    id: "rest_101",
    name: "Biryani Bay",
    area: "Bandra West",
    cuisine: "Biryani",
    rating: 4.6,
    etaMinutes: 28,
    priceForOne: 360,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1633945274405-b6c8069047b0?auto=format&fit=crop&w=900&q=80",
    tags: ["biryani", "late night", "spicy", "family"],
    menu: [
      { id: "item_101", name: "Chicken Dum Biryani", price: 329, type: "non-veg", likes: 941, tags: ["biryani", "spicy", "rice"] },
      { id: "item_102", name: "Paneer Biryani", price: 279, type: "veg", likes: 612, tags: ["biryani", "paneer", "rice"] },
      { id: "item_103", name: "Mutton Shorba", price: 169, type: "non-veg", likes: 344, tags: ["soup", "mutton"] },
      { id: "item_104", name: "Double Ka Meetha", price: 109, type: "veg", likes: 288, tags: ["dessert", "sweet"] }
    ]
  },
  {
    id: "rest_102",
    name: "Tandoori Street",
    area: "Andheri East",
    cuisine: "North Indian",
    rating: 4.4,
    etaMinutes: 34,
    priceForOne: 330,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?auto=format&fit=crop&w=900&q=80",
    tags: ["tandoor", "butter chicken", "meal box", "office"],
    menu: [
      { id: "item_201", name: "Butter Chicken Bowl", price: 349, type: "non-veg", likes: 782, tags: ["chicken", "meal", "north indian"] },
      { id: "item_202", name: "Dal Makhani Meal", price: 249, type: "veg", likes: 551, tags: ["dal", "veg", "meal"] },
      { id: "item_203", name: "Paneer Tikka Roll", price: 229, type: "veg", likes: 498, tags: ["paneer", "roll", "tandoor"] },
      { id: "item_204", name: "Garlic Naan", price: 59, type: "veg", likes: 401, tags: ["bread", "naan"] }
    ]
  },
  {
    id: "rest_103",
    name: "Dosa District",
    area: "Matunga",
    cuisine: "South Indian",
    rating: 4.7,
    etaMinutes: 22,
    priceForOne: 210,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1668236543090-82eba5ee5976?auto=format&fit=crop&w=900&q=80",
    tags: ["dosa", "breakfast", "filter coffee", "quick"],
    menu: [
      { id: "item_301", name: "Ghee Roast Dosa", price: 159, type: "veg", likes: 824, tags: ["dosa", "breakfast", "crispy"] },
      { id: "item_302", name: "Idli Vada Combo", price: 129, type: "veg", likes: 697, tags: ["idli", "vada", "breakfast"] },
      { id: "item_303", name: "Podi Uttapam", price: 149, type: "veg", likes: 442, tags: ["uttapam", "podi"] },
      { id: "item_304", name: "Filter Coffee", price: 79, type: "veg", likes: 530, tags: ["coffee", "drink"] }
    ]
  },
  {
    id: "rest_104",
    name: "Bombay Chaat Co.",
    area: "Dadar",
    cuisine: "Street Food",
    rating: 4.5,
    etaMinutes: 18,
    priceForOne: 160,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1601050690597-df0568f70950?auto=format&fit=crop&w=900&q=80",
    tags: ["chaat", "vada pav", "budget", "snacks"],
    menu: [
      { id: "item_401", name: "Vada Pav Duo", price: 79, type: "veg", likes: 1084, tags: ["vada pav", "budget", "snack"] },
      { id: "item_402", name: "Pav Bhaji", price: 189, type: "veg", likes: 937, tags: ["pav bhaji", "buttery"] },
      { id: "item_403", name: "Dahi Puri", price: 139, type: "veg", likes: 644, tags: ["chaat", "puri"] },
      { id: "item_404", name: "Cheese Sev Puri", price: 149, type: "veg", likes: 512, tags: ["chaat", "cheese"] }
    ]
  },
  {
    id: "rest_105",
    name: "Coastal Curry House",
    area: "Colaba",
    cuisine: "Coastal",
    rating: 4.8,
    etaMinutes: 31,
    priceForOne: 520,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=900&q=80",
    tags: ["seafood", "coastal", "premium", "konkan"],
    menu: [
      { id: "item_501", name: "Prawn Gassi with Rice", price: 489, type: "non-veg", likes: 703, tags: ["seafood", "prawn", "rice"] },
      { id: "item_502", name: "Surmai Fry", price: 549, type: "non-veg", likes: 691, tags: ["fish", "coastal", "fry"] },
      { id: "item_503", name: "Crab Sukka", price: 649, type: "non-veg", likes: 468, tags: ["crab", "seafood"] },
      { id: "item_504", name: "Sol Kadhi", price: 119, type: "veg", likes: 377, tags: ["drink", "kokum"] }
    ]
  },
  {
    id: "rest_106",
    name: "Lower Parel Lunchbox",
    area: "Lower Parel",
    cuisine: "Healthy Bowls",
    rating: 4.3,
    etaMinutes: 25,
    priceForOne: 290,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=900&q=80",
    tags: ["healthy", "office lunch", "quick", "protein"],
    menu: [
      { id: "item_601", name: "Protein Dal Rice Bowl", price: 239, type: "veg", likes: 436, tags: ["healthy", "dal", "meal"] },
      { id: "item_602", name: "Chicken Tikka Salad", price: 299, type: "non-veg", likes: 389, tags: ["healthy", "chicken", "salad"] },
      { id: "item_603", name: "Millet Khichdi Bowl", price: 219, type: "veg", likes: 318, tags: ["millet", "khichdi", "healthy"] },
      { id: "item_604", name: "Coconut Water", price: 69, type: "veg", likes: 251, tags: ["drink", "coconut"] }
    ]
  },
  {
    id: "rest_107",
    name: "Juhu Pizza Works",
    area: "Juhu",
    cuisine: "Pizza",
    rating: 4.4,
    etaMinutes: 29,
    priceForOne: 390,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=900&q=80",
    tags: ["pizza", "cheese", "party", "italian"],
    menu: [
      { id: "item_701", name: "Bombay Masala Pizza", price: 329, type: "veg", likes: 719, tags: ["pizza", "spicy", "cheese"] },
      { id: "item_702", name: "Pepperoni Feast", price: 429, type: "non-veg", likes: 604, tags: ["pizza", "pepperoni"] },
      { id: "item_703", name: "Garlic Cheese Bread", price: 169, type: "veg", likes: 501, tags: ["bread", "cheese"] },
      { id: "item_704", name: "Tiramisu Cup", price: 199, type: "veg", likes: 260, tags: ["dessert"] }
    ]
  },
  {
    id: "rest_108",
    name: "Kurla Kebab Factory",
    area: "Kurla",
    cuisine: "Kebabs",
    rating: 4.5,
    etaMinutes: 32,
    priceForOne: 310,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=900&q=80",
    tags: ["kebab", "mughlai", "late night", "grill"],
    menu: [
      { id: "item_801", name: "Chicken Seekh Kebab", price: 269, type: "non-veg", likes: 812, tags: ["kebab", "chicken", "grill"] },
      { id: "item_802", name: "Mutton Galouti Roll", price: 319, type: "non-veg", likes: 588, tags: ["roll", "mutton", "kebab"] },
      { id: "item_803", name: "Paneer Malai Tikka", price: 249, type: "veg", likes: 402, tags: ["paneer", "tikka"] },
      { id: "item_804", name: "Roomali Roti", price: 49, type: "veg", likes: 220, tags: ["bread"] }
    ]
  },
  {
    id: "rest_109",
    name: "Ghatkopar Gujarati Thali",
    area: "Ghatkopar",
    cuisine: "Gujarati",
    rating: 4.6,
    etaMinutes: 27,
    priceForOne: 260,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1543352634-a1c51d9f1fa7?auto=format&fit=crop&w=900&q=80",
    tags: ["thali", "pure veg", "comfort", "family"],
    menu: [
      { id: "item_901", name: "Mini Gujarati Thali", price: 249, type: "veg", likes: 744, tags: ["thali", "veg", "comfort"] },
      { id: "item_902", name: "Fafda Jalebi Box", price: 149, type: "veg", likes: 611, tags: ["snack", "sweet"] },
      { id: "item_903", name: "Kadhi Khichdi", price: 169, type: "veg", likes: 384, tags: ["khichdi", "comfort"] },
      { id: "item_904", name: "Chaas", price: 49, type: "veg", likes: 286, tags: ["drink"] }
    ]
  },
  {
    id: "rest_110",
    name: "Versova Sushi Bar",
    area: "Versova",
    cuisine: "Asian",
    rating: 4.7,
    etaMinutes: 38,
    priceForOne: 620,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=900&q=80",
    tags: ["sushi", "asian", "premium", "date night"],
    menu: [
      { id: "item_1001", name: "Avocado Maki", price: 349, type: "veg", likes: 388, tags: ["sushi", "veg", "maki"] },
      { id: "item_1002", name: "Salmon Nigiri", price: 589, type: "non-veg", likes: 451, tags: ["sushi", "salmon"] },
      { id: "item_1003", name: "Chicken Katsu Don", price: 429, type: "non-veg", likes: 399, tags: ["rice", "chicken", "asian"] },
      { id: "item_1004", name: "Miso Soup", price: 149, type: "veg", likes: 247, tags: ["soup"] }
    ]
  },
  {
    id: "rest_111",
    name: "Mahim Frankie House",
    area: "Mahim",
    cuisine: "Rolls",
    rating: 4.3,
    etaMinutes: 20,
    priceForOne: 180,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1626700051175-6818013e1d4f?auto=format&fit=crop&w=900&q=80",
    tags: ["frankie", "rolls", "budget", "college"],
    menu: [
      { id: "item_1101", name: "Paneer Schezwan Frankie", price: 139, type: "veg", likes: 660, tags: ["frankie", "paneer", "spicy"] },
      { id: "item_1102", name: "Chicken Mayo Frankie", price: 169, type: "non-veg", likes: 592, tags: ["frankie", "chicken"] },
      { id: "item_1103", name: "Aloo Cheese Roll", price: 119, type: "veg", likes: 476, tags: ["roll", "cheese", "budget"] },
      { id: "item_1104", name: "Masala Lemon Soda", price: 59, type: "veg", likes: 203, tags: ["drink"] }
    ]
  },
  {
    id: "rest_112",
    name: "Borivali Sandwich Studio",
    area: "Borivali",
    cuisine: "Cafe",
    rating: 4.2,
    etaMinutes: 24,
    priceForOne: 190,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?auto=format&fit=crop&w=900&q=80",
    tags: ["sandwich", "cafe", "budget", "quick bites"],
    menu: [
      { id: "item_1201", name: "Bombay Grill Sandwich", price: 149, type: "veg", likes: 802, tags: ["sandwich", "grill", "veg"] },
      { id: "item_1202", name: "Chicken Club Sandwich", price: 229, type: "non-veg", likes: 410, tags: ["sandwich", "chicken"] },
      { id: "item_1203", name: "Cold Coffee", price: 129, type: "veg", likes: 521, tags: ["coffee", "drink"] },
      { id: "item_1204", name: "Peri Peri Fries", price: 119, type: "veg", likes: 458, tags: ["fries", "snack"] }
    ]
  },
  {
    id: "rest_113",
    name: "Powai Wok Express",
    area: "Powai",
    cuisine: "Chinese",
    rating: 4.5,
    etaMinutes: 26,
    priceForOne: 280,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1525755662778-989d0524087e?auto=format&fit=crop&w=900&q=80",
    tags: ["chinese", "wok", "noodles", "office"],
    menu: [
      { id: "item_1301", name: "Hakka Noodles", price: 199, type: "veg", likes: 678, tags: ["noodles", "chinese", "wok"] },
      { id: "item_1302", name: "Chicken Manchurian Rice", price: 289, type: "non-veg", likes: 581, tags: ["rice", "chicken", "chinese"] },
      { id: "item_1303", name: "Chilli Paneer Bowl", price: 249, type: "veg", likes: 496, tags: ["paneer", "spicy"] },
      { id: "item_1304", name: "Honey Noodles", price: 129, type: "veg", likes: 230, tags: ["dessert"] }
    ]
  },
  {
    id: "rest_114",
    name: "Chembur Misal Mandal",
    area: "Chembur",
    cuisine: "Maharashtrian",
    rating: 4.6,
    etaMinutes: 21,
    priceForOne: 170,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1628294896516-344152572ee8?auto=format&fit=crop&w=900&q=80",
    tags: ["misal", "maharashtrian", "spicy", "budget"],
    menu: [
      { id: "item_1401", name: "Kolhapuri Misal Pav", price: 139, type: "veg", likes: 921, tags: ["misal", "spicy", "pav"] },
      { id: "item_1402", name: "Sabudana Vada", price: 99, type: "veg", likes: 440, tags: ["vada", "snack"] },
      { id: "item_1403", name: "Pithla Bhakri", price: 179, type: "veg", likes: 383, tags: ["meal", "maharashtrian"] },
      { id: "item_1404", name: "Kokum Sharbat", price: 69, type: "veg", likes: 265, tags: ["drink", "kokum"] }
    ]
  },
  {
    id: "rest_115",
    name: "Worli Dessert Lab",
    area: "Worli",
    cuisine: "Desserts",
    rating: 4.4,
    etaMinutes: 23,
    priceForOne: 240,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1488477181946-6428a0291777?auto=format&fit=crop&w=900&q=80",
    tags: ["dessert", "cakes", "ice cream", "sweet"],
    menu: [
      { id: "item_1501", name: "Belgian Chocolate Slice", price: 189, type: "veg", likes: 690, tags: ["cake", "chocolate", "dessert"] },
      { id: "item_1502", name: "Mango Cheesecake Jar", price: 229, type: "veg", likes: 532, tags: ["cheesecake", "mango"] },
      { id: "item_1503", name: "Brownie Sundae", price: 249, type: "veg", likes: 581, tags: ["brownie", "ice cream"] },
      { id: "item_1504", name: "Berry Kulfi Cup", price: 149, type: "veg", likes: 300, tags: ["kulfi", "dessert"] }
    ]
  },
  {
    id: "rest_116",
    name: "CST Breakfast Canteen",
    area: "Fort",
    cuisine: "Breakfast",
    rating: 4.1,
    etaMinutes: 16,
    priceForOne: 140,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=900&q=80",
    tags: ["breakfast", "budget", "quick", "tea"],
    menu: [
      { id: "item_1601", name: "Bun Maska Chai", price: 89, type: "veg", likes: 800, tags: ["chai", "breakfast", "budget"] },
      { id: "item_1602", name: "Akuri Pav", price: 149, type: "non-veg", likes: 360, tags: ["egg", "breakfast", "pav"] },
      { id: "item_1603", name: "Poha Upma Combo", price: 119, type: "veg", likes: 421, tags: ["poha", "upma", "breakfast"] },
      { id: "item_1604", name: "Cutting Chai Flask", price: 99, type: "veg", likes: 390, tags: ["chai", "drink"] }
    ]
  },
  {
    id: "rest_117",
    name: "Malad Vegan Bowl Bar",
    area: "Malad",
    cuisine: "Vegan",
    rating: 4.3,
    etaMinutes: 30,
    priceForOne: 310,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=900&q=80",
    tags: ["vegan", "healthy", "salad", "bowls"],
    menu: [
      { id: "item_1701", name: "Tofu Buddha Bowl", price: 299, type: "veg", likes: 420, tags: ["tofu", "vegan", "healthy"] },
      { id: "item_1702", name: "Quinoa Bhel Bowl", price: 249, type: "veg", likes: 377, tags: ["quinoa", "bhel", "healthy"] },
      { id: "item_1703", name: "Hummus Pita Plate", price: 269, type: "veg", likes: 336, tags: ["hummus", "pita", "vegan"] },
      { id: "item_1704", name: "Kombucha", price: 159, type: "veg", likes: 212, tags: ["drink"] }
    ]
  },
  {
    id: "rest_118",
    name: "Navi Mumbai Shawarma Stop",
    area: "Vashi",
    cuisine: "Middle Eastern",
    rating: 4.2,
    etaMinutes: 35,
    priceForOne: 220,
    isOpen: true,
    image: "https://images.unsplash.com/photo-1529006557810-274b9b2fc783?auto=format&fit=crop&w=900&q=80",
    tags: ["shawarma", "wraps", "hummus", "budget"],
    menu: [
      { id: "item_1801", name: "Chicken Shawarma", price: 179, type: "non-veg", likes: 735, tags: ["shawarma", "chicken", "wrap"] },
      { id: "item_1802", name: "Falafel Wrap", price: 159, type: "veg", likes: 479, tags: ["falafel", "wrap", "veg"] },
      { id: "item_1803", name: "Hummus with Pita", price: 199, type: "veg", likes: 318, tags: ["hummus", "pita"] },
      { id: "item_1804", name: "Garlic Toum Fries", price: 129, type: "veg", likes: 267, tags: ["fries", "garlic"] }
    ]
  }
];

module.exports = {
  restaurants
};
