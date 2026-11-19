-- BrainrotNightMarket Catalog: every character the conveyor can sell.
-- Original Indonesian street-food brainrots, priced $50 up to $12,000.
-- Rarity ladder: Common, Rare, Epic, Legendary, Mythic.
-- Income is cash per second while the character sits on a base pad.
-- Mutation multiplies income: Golden x2, Rainbow x5, Diamond x10.
-- The server rolls mutations when a character spawns on the conveyor.

local Catalog = {}

Catalog.RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

Catalog.RARITY_COLOR = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(80, 180, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 180, 40),
	Mythic = Color3.fromRGB(255, 60, 120),
}

-- Mutation roll chances. Golden Hour event triples the Golden chance.
Catalog.MUTATIONS = {
	{ name = "None", chance = 0, mult = 1, star = "" },
	{ name = "Golden", chance = 0.04, mult = 2, star = "★" },
	{ name = "Rainbow", chance = 0.008, mult = 5, star = "★★" },
	{ name = "Diamond", chance = 0.0015, mult = 10, star = "★★★" },
}

Catalog.MUTATION_COLOR = {
	None = Color3.fromRGB(255, 255, 255),
	Golden = Color3.fromRGB(255, 210, 60),
	Rainbow = Color3.fromRGB(120, 220, 255),
	Diamond = Color3.fromRGB(140, 240, 255),
}

-- id, display name, rarity, price, income per second, body colour, face mood.
Catalog.CHARACTERS = {
	{ id = "tahu_gejrot", name = "Tahu Gejrot", rarity = "Common", price = 50, income = 1, color = Color3.fromRGB(255, 220, 130), mood = "yum" },
	{ id = "nasi_goreng", name = "Nasi Goreng Gila", rarity = "Common", price = 100, income = 2, color = Color3.fromRGB(255, 170, 60), mood = "wild" },
	{ id = "bakso_beranak", name = "Bakso Beranak", rarity = "Common", price = 150, income = 3, color = Color3.fromRGB(190, 130, 80), mood = "happy" },
	{ id = "krupuk_terbang", name = "Krupuk Terbang", rarity = "Common", price = 200, income = 4, color = Color3.fromRGB(255, 240, 200), mood = "fly" },
	{ id = "es_teh_manis", name = "Es Teh Manis", rarity = "Common", price = 250, income = 5, color = Color3.fromRGB(200, 120, 60), mood = "cool" },
	{ id = "mie_ayam", name = "Mie Ayam Sakti", rarity = "Common", price = 300, income = 6, color = Color3.fromRGB(255, 200, 90), mood = "slurp" },
	{ id = "sate_madura", name = "Sate Madura", rarity = "Rare", price = 400, income = 9, color = Color3.fromRGB(160, 90, 40), mood = "fire" },
	{ id = "rendang_raksasa", name = "Rendang Raksasa", rarity = "Rare", price = 500, income = 12, color = Color3.fromRGB(120, 60, 20), mood = "big" },
	{ id = "gado_gado", name = "Gado-Gado Galak", rarity = "Rare", price = 650, income = 15, color = Color3.fromRGB(120, 200, 80), mood = "angry" },
	{ id = "soto_lamongan", name = "Soto Lamongan", rarity = "Rare", price = 800, income = 18, color = Color3.fromRGB(255, 220, 120), mood = "warm" },
	{ id = "pecel_lele", name = "Pecel Lele Terbang", rarity = "Rare", price = 950, income = 22, color = Color3.fromRGB(90, 110, 140), mood = "fly" },
	{ id = "ayam_geprek", name = "Ayam Geprek Petir", rarity = "Rare", price = 1100, income = 26, color = Color3.fromRGB(255, 120, 60), mood = "zap" },
	{ id = "nasi_padang", name = "Nasi Padang Gunung", rarity = "Epic", price = 1300, income = 32, color = Color3.fromRGB(255, 190, 80), mood = "big" },
	{ id = "martabak", name = "Martabak Manis Raksasa", rarity = "Epic", price = 1600, income = 40, color = Color3.fromRGB(140, 90, 50), mood = "sweet" },
	{ id = "rawon_hitam", name = "Rawon Hitam Misterius", rarity = "Epic", price = 1900, income = 48, color = Color3.fromRGB(40, 40, 40), mood = "mystery" },
	{ id = "gudeg_jogja", name = "Gudeg Jogja Emas", rarity = "Epic", price = 2200, income = 56, color = Color3.fromRGB(255, 210, 90), mood = "royal" },
	{ id = "sate_padang", name = "Sate Padang Panas", rarity = "Epic", price = 2500, income = 65, color = Color3.fromRGB(200, 60, 30), mood = "fire" },
	{ id = "lontong_balap", name = "Lontong Balap", rarity = "Epic", price = 2800, income = 73, color = Color3.fromRGB(240, 240, 220), mood = "fast" },
	{ id = "durian_king", name = "Durian Musang King", rarity = "Legendary", price = 3200, income = 90, color = Color3.fromRGB(140, 180, 60), mood = "spiky" },
	{ id = "kopi_luwak", name = "Kopi Luwak Sakti", rarity = "Legendary", price = 3600, income = 105, color = Color3.fromRGB(80, 50, 30), mood = "wise" },
	{ id = "sate_klathak", name = "Sate Klathak Api", rarity = "Legendary", price = 4000, income = 120, color = Color3.fromRGB(255, 90, 30), mood = "fire" },
	{ id = "nasi_liwet", name = "Nasi Liwet Solo", rarity = "Legendary", price = 4400, income = 135, color = Color3.fromRGB(250, 230, 180), mood = "calm" },
	{ id = "bakpia_pathok", name = "Bakpia Pathok", rarity = "Legendary", price = 4800, income = 150, color = Color3.fromRGB(200, 150, 90), mood = "happy" },
	{ id = "cendol_dawet", name = "Cendol Dawet Ajaib", rarity = "Legendary", price = 5200, income = 170, color = Color3.fromRGB(90, 200, 120), mood = "magic" },
	{ id = "garuda_tumpeng", name = "Garuda Nasi Tumpeng", rarity = "Mythic", price = 6000, income = 220, color = Color3.fromRGB(255, 200, 60), mood = "royal" },
	{ id = "komodo_sambal", name = "Komodo Sambal Iblis", rarity = "Mythic", price = 7000, income = 280, color = Color3.fromRGB(200, 40, 40), mood = "angry" },
	{ id = "barong_ketoprak", name = "Barong Ketoprak", rarity = "Mythic", price = 8000, income = 350, color = Color3.fromRGB(255, 80, 80), mood = "wild" },
	{ id = "semar_escampur", name = "Semar Es Campur", rarity = "Mythic", price = 9000, income = 430, color = Color3.fromRGB(120, 200, 255), mood = "cool" },
	{ id = "raksasa_rendang", name = "Raksasa Rendang Emas", rarity = "Mythic", price = 10000, income = 550, color = Color3.fromRGB(255, 180, 40), mood = "big" },
	{ id = "dewi_sri", name = "Dewi Sri Padi", rarity = "Mythic", price = 12000, income = 700, color = Color3.fromRGB(255, 240, 160), mood = "royal" },
}

function Catalog.find(id)
	for _, c in ipairs(Catalog.CHARACTERS) do
		if c.id == id then
			return c
		end
	end
	return nil
end

function Catalog.cheapOnes()
	local out = {}
	for _, c in ipairs(Catalog.CHARACTERS) do
		if c.price <= 100 then
			table.insert(out, c)
		end
	end
	return out
end

function Catalog.byRarity(rarity)
	local out = {}
	for _, c in ipairs(Catalog.CHARACTERS) do
		if c.rarity == rarity then
			table.insert(out, c)
		end
	end
	return out
end

function Catalog.rollMutation(goldenBoost)
	local roll = math.random()
	local goldenChance = 0.04
	if goldenBoost then
		goldenChance = 0.12
	end
	if roll < 0.0015 then
		return "Diamond"
	elseif roll < 0.0095 then
		return "Rainbow"
	elseif roll < 0.0095 + goldenChance then
		return "Golden"
	end
	return "None"
end

function Catalog.mutationMult(name)
	for _, m in ipairs(Catalog.MUTATIONS) do
		if m.name == name then
			return m.mult
		end
	end
	return 1
end

function Catalog.mutationStar(name)
	for _, m in ipairs(Catalog.MUTATIONS) do
		if m.name == name then
			return m.star
		end
	end
	return ""
end

return Catalog
