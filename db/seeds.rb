regions = [
  { name: "青森", meat: "鶏・豚", seasoning: "味噌", feature: "いももち入り、家庭差あり" },
  { name: "岩手", meat: "鶏", seasoning: "醤油", feature: "醤油が基本、味噌派もあり" },
  { name: "秋田", meat: "鶏・豚", seasoning: "醤油", feature: "根菜・きのこ多め、家庭ごとに差あり" },
  { name: "宮城", meat: "豚", seasoning: "味噌", feature: "家庭では定番、川原芋煮は少ない" },
  { name: "山形", meat: "牛", seasoning: "醤油", feature: "川原の大鍋文化、芋煮会で有名" },
  { name: "福島", meat: "豚", seasoning: "醤油・味噌", feature: "地域で味付けが分かれ、家庭的に親しまれる" }
]

regions.each do |attributes|
  region = Region.find_or_initialize_by(name: attributes[:name])
  region.update!(attributes)
end
