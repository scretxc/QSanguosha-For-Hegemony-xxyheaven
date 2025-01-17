--[[********************************************************************
	Copyright (c) 2013-2015 Mogara

  This file is part of QSanguosha-Hegemony.

  This game is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 3.0
  of the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  General Public License for more details.

  See the LICENSE file for more details.

  Mogara
*********************************************************************]]
--邓艾
sgs.ai_skill_invoke.tuntian = function(self, data)
	if not (self:willShowForAttack() or self:willShowForDefence()) then
		return false
	end
	return true
end

sgs.ai_skill_choice["tuntian"] = function(self, choices)
	return "yes"
end

local jixi_skill = {}
jixi_skill.name = "jixi"
table.insert(sgs.ai_skills, jixi_skill)
jixi_skill.getTurnUseCard = function(self)
	if self.player:getPile("field"):isEmpty()
		or (self.player:getHandcardNum() >= self.player:getHp() + 2
			and self.player:getPile("field"):length() <= self.room:getAlivePlayers():length() / 2 - 1) then
		return
	end
	local can_use = false
	for i = 0, self.player:getPile("field"):length() - 1, 1 do
		local snatch = sgs.Sanguosha:getCard(self.player:getPile("field"):at(i))
		local snatch_str = ("snatch:jixi[%s:%s]=%d&jixi"):format(snatch:getSuitString(), snatch:getNumberString(), self.player:getPile("field"):at(i))
		local jixisnatch = sgs.Card_Parse(snatch_str)
		assert(jixisnatch)

		for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if (self.player:distanceTo(player, 1) <= 1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_DistanceLimit, self.player, jixisnatch))
				and self:trickIsEffective(jixisnatch, player) then

				local suit = snatch:getSuitString()
				local number = snatch:getNumberString()
				local card_id = snatch:getEffectiveId()
				local card_str = ("snatch:jixi[%s:%s]=%d%s"):format(suit, number, card_id, "&jixi")
				local snatch = sgs.Card_Parse(card_str)
				assert(snatch)
				return snatch
			end
		end
	end
end

sgs.ai_view_as.jixi = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if card_place == sgs.Player_PlaceSpecial and player:getPileName(card_id) == "field" then
		return ("snatch:jixi[%s:%s]=%d%s"):format(suit, number, card_id, "&jixi")
	end
end

local getZiliangCard = function(self, target)
	if not (target:getPhase() == sgs.Player_NotActive and self:needKongcheng(target, true)) then
		local ids = sgs.QList2Table(self.player:getPile("field"))
		local cards = {}
		for _, id in ipairs(ids) do table.insert(cards, sgs.Sanguosha:getCard(id)) end
		if target:getPhase() == sgs.Player_NotActive and self:isWeak(target) then
			for _, card in ipairs(cards) do
				if card:isKindOf("Peach") or card:isKindOf("Analeptic") then
					return card:getEffectiveId()
				end
			end
			for _, card in ipairs(cards) do
				if card:isKindOf("Jink") then return card:getEffectiveId() end
			end
			self:sortByKeepValue(cards, true)
			return cards[1]:getEffectiveId()
		else--配合钟会找连弩？
			self:sortByUseValue(cards)
			return cards[1]:getEffectiveId()
		end
	else
		return nil
	end
end

sgs.ai_skill_use["@@ziliang"] = function(self)
	local damage = self.player:getTag("ziliang_aidata"):toDamage()
	local target = damage.to
	local id = getZiliangCard(self, target)
	if id then
		return "@ZiliangCard=" .. tostring(id) .. "&ziliang"
	end
	return "."
end

--曹洪
local function huyuan_validate(self, equip_type, is_handcard)
	local targets = {}
	if is_handcard then targets = self.friends else targets = self.friends_noself end
	if equip_type == "po_bazhen" then
		for _, enemy in ipairs(self.enemies) do
			if self:hasKnownSkill("bazhen", enemy) and not enemy:getArmor() then table.insert(targets, enemy) end
		end
		equip_type = "Armor"
	end
	self:sort(targets, "defense")
	for _, p in ipairs(targets) do
		local has_equip = false
		for _, equip in sgs.qlist(p:getEquips()) do
			if equip:isKindOf(equip_type) then
				has_equip = true
				break
			end
		end
		if not has_equip and not (equip_type == "Armor" and self:hasKnownSkill("bazhen", p) and self:isFriend(p)) then
			--[[
			self:sort(self.enemies, "defense")
			for _, enemy in ipairs(self.enemies) do
				if p:distanceTo(enemy) == 1 and self.player:canDiscard(enemy, "he") then
					enemy:setFlags("AI_HuyuanToChoose")
					return p
				end
			end
			]]
			return p
		end
	end
	return nil
end

sgs.ai_skill_use["@@huyuan"] = function(self, prompt)
	if self:findPlayerToDiscard("ej") then
		if self:needToThrowArmor() and not self.player:hasArmorEffect("PeaceSpell") then
			local player = huyuan_validate(self, "po_bazhen", false)
			if player then return "@HuyuanCard=" .. self.player:getArmor():getEffectiveId() .. "->" .. player:objectName() end
		end

		local eq, friend = self:getCardNeedPlayer(sgs.QList2Table(self.player:getCards("he")))
		if eq and eq:getTypeId() == sgs.Card_TypeEquip and friend then return
			"@HuyuanCard=" .. eq:getEffectiveId() .. "->" .. friend:objectName()
		end

		local cards = self.player:getHandcards()--先给手牌中的装备
		cards = sgs.QList2Table(cards)
		self:sortByKeepValue(cards)
		for _, card in ipairs(cards) do
			if card:isKindOf("SilverLion") or card:isKindOf("Vine") then
				local player = huyuan_validate(self, "po_bazhen", true)
				if player then return "@HuyuanCard=" .. card:getEffectiveId() .. "->" .. player:objectName() end
			end
			if card:isKindOf("Armor") then
				local player = huyuan_validate(self, "Armor", true)
				if player then return "@HuyuanCard=" .. card:getEffectiveId() .. "->" .. player:objectName() end
			end
		end
		for _, card in ipairs(cards) do
			if card:isKindOf("DefensiveHorse") then
				local player = huyuan_validate(self, "DefensiveHorse", true)
				if player then return "@HuyuanCard=" .. card:getEffectiveId() .. "->" .. player:objectName() end
			end
		end
		for _, card in ipairs(cards) do
			if card:isKindOf("OffensiveHorse") then
				local player = huyuan_validate(self, "OffensiveHorse", true)
				if player then return "@HuyuanCard=" .. card:getEffectiveId() .. "->" .. player:objectName() end
			end
		end
		for _, card in ipairs(cards) do
			if card:isKindOf("Weapon") then
				local player = huyuan_validate(self, "Weapon", true)
				if player then return "@HuyuanCard=" .. card:getEffectiveId() .. "->" .. player:objectName() end
			end
		end

		if self.player:getOffensiveHorse() then
			local player = huyuan_validate(self, "OffensiveHorse", false)
			if player then return "@HuyuanCard=" .. self.player:getOffensiveHorse():getEffectiveId() .. "->" .. player:objectName() end
		end
		if self.player:getWeapon() then
			local player = huyuan_validate(self, "Weapon", false)
			if player then return "@HuyuanCard=" .. self.player:getWeapon():getEffectiveId() .. "->" .. player:objectName() end
		end
		if self.player:getArmor() and self.player:getLostHp() <= 1 and self.player:getHandcardNum() >= 3 then
			local player = huyuan_validate(self, "Armor", false)
			if player then return "@HuyuanCard=" .. self.player:getArmor():getEffectiveId() .. "->" .. player:objectName() end
		end
	else
		local c, friend = self:getCardNeedPlayer()
		if c and friend then return "@HuyuanCard=" .. c:getEffectiveId() .. "->" .. friend:objectName() end
	end
end

sgs.ai_skill_playerchosen.huyuan = function(self, targets)
--[[
	targets = sgs.QList2Table(targets)
	for _, p in ipairs(targets) do
		if p:hasFlag("AI_HuyuanToChoose") then
			p:setFlags("-AI_HuyuanToChoose")
			return p
		end
	end
]]
	return self:findPlayerToDiscard("ej", false, sgs.Card_MethodDiscard, targets)
end

sgs.ai_card_intention.HuyuanCard = function(self, card, from, to)
	if self:hasKnownSkill("bazhen", to[1]) then
		if sgs.Sanguosha:getCard(card:getEffectiveId()):isKindOf("Armor") then
			sgs.updateIntention(from, to[1], 10)
			return
		end
	end
	sgs.updateIntention(from, to[1], -50)
end

sgs.ai_cardneed.huyuan = sgs.ai_cardneed.equip

sgs.huyuan_keep_value = {
	Peach = 6,
	Jink = 5.1,
	EquipCard = 4.8
}

--姜维
function SmartAI:isTiaoxinTarget(enemy)
	if not enemy then self.room:writeToConsole(debug.traceback()) return end
	if getCardsNum("Slash", enemy, self.player) < 1 and self.player:getHp() > 1 and not self:canHit(self.player, enemy)
		and not (enemy:hasWeapon("DoubleSword") and self.player:getGender() ~= enemy:getGender())
		then return true end
	if sgs.card_lack[enemy:objectName()]["Slash"] == 1
		or self:needLeiji(self.player, enemy)
		or self:needDamagedEffects(self.player, enemy, true)
		or self:needToLoseHp(self.player, enemy, true, true)
		then return true end
	if self.player:hasSkill("xiangle") and (enemy:getHandcardNum() < 2 or getKnownCard(enemy, self.player, "BasicCard") < 2
												and enemy:getHandcardNum() - getKnownNum(enemy, self.player) < 2) then return true end
	return false
end

local tiaoxin_skill = {}
tiaoxin_skill.name = "tiaoxin"
table.insert(sgs.ai_skills, tiaoxin_skill)
tiaoxin_skill.getTurnUseCard = function(self)
	if not self:willShowForAttack() then
		return
	end
	if self.player:hasUsed("TiaoxinCard") then return end
	return sgs.Card_Parse("@TiaoxinCard=.&tiaoxin")
end

sgs.ai_skill_use_func.TiaoxinCard = function(TXCard, use, self)
	local targets = {}
	for _, enemy in ipairs(self.enemies) do
		if enemy:inMyAttackRange(self.player) and not self:doNotDiscard(enemy) and self:isTiaoxinTarget(enemy) then
			table.insert(targets, enemy)
		end
	end

	if #targets == 0 then return end

	sgs.ai_use_priority.TiaoxinCard = 8
	if not self.player:getArmor() and not self.player:isKongcheng() then
		for _, card in sgs.qlist(self.player:getCards("h")) do
			if card:isKindOf("Armor") and self:evaluateArmor(card) > 3 then
				sgs.ai_use_priority.TiaoxinCard = 5.9
				break
			end
		end
	end

	if use.to then
		self:sort(targets, "defenseSlash")
		use.to:append(targets[1])
	end
	use.card = TXCard
end

sgs.ai_skill_cardask["@tiaoxin-slash"] = function(self, data, pattern, target)
	if target then
		local cards = self:getCards("Slash")
		local theslash
		self:sortByUseValue(cards)
		for _, slash in ipairs(cards) do
			if self:isFriend(target) and self:slashIsEffective(slash, target) then
				if self:needLeiji(target, self.player) then return slash:toString() end
				if self:needDamagedEffects(target, self.player) then return slash:toString() end
				if self:needToLoseHp(target, self.player, nil, true) then return slash:toString() end
			end
			if not self:isFriend(target) and self:slashIsEffective(slash, target)
				and not self:needDamagedEffects(target, self.player, true) and not self:needLeiji(target, self.player) then
					return slash:toString()
			end
		end
		for _, slash in ipairs(cards) do
			if not self:isFriend(target) then
				if not self:needLeiji(target, self.player) and not self:needDamagedEffects(target, self.player, true) then return slash:toString() end
				if not self:slashIsEffective(slash, target) then return slash:toString() end
			end
		end
	end
	return "."
end

sgs.ai_card_intention.TiaoxinCard = 80
sgs.ai_use_priority.TiaoxinCard = 4

--蒋琬＆费祎
sgs.ai_skill_invoke.shoucheng = function(self, data)
	local target = data:toPlayer()
	if target and self:isFriend(target) and not self:needKongcheng(target, true) then
		return true
	end
	return false
end

sgs.ai_skill_playerchosen.shoucheng = function(self, targets)
	local result = {}
	for _, target in sgs.qlist(targets) do
		if target and self:isFriend(target) and not self:needKongcheng(target, true) then
			table.insert(result, target)
		end
	end
	return result
end

sgs.ai_skill_invoke.shengxi = function(self, data)
	if not self:willShowForDefence() and (self:needKongcheng() and self.player:getHp() < 3 ) then
		return false
	end
--[[
		if self:getOverflow() >= 0 then
		local erzhang = sgs.findPlayerByShownSkillName("guzheng")
		if erzhang and self:isEnemy(erzhang) then return false end
	end
]]--现在是结束阶段发动
	return true
end

--蒋钦
local shangyi_skill = {}
shangyi_skill.name = "shangyi"
table.insert(sgs.ai_skills, shangyi_skill)
shangyi_skill.getTurnUseCard = function(self)
	if self.player:hasUsed("ShangyiCard") then return end
	if self.player:isKongcheng() then return end
	if not self:willShowForAttack() then return end
	local card_str = ("@ShangyiCard=.&shangyi")
	local shangyi_card = sgs.Card_Parse(card_str)
	assert(shangyi_card)
	return shangyi_card
end

sgs.ai_skill_use_func.ShangyiCard = function(card, use, self)
	self:sort(self.enemies, "handcard")
	self.shangyi = nil
	for index = #self.enemies, 1, -1 do
		if not self.enemies[index]:isKongcheng() and self:objectiveLevel(self.enemies[index]) > 0 then
			use.card = card
			self.shangyi = "handcards"
			if use.to then
				use.to:append(self.enemies[index])
			end
			return
		end
	end
	if self.player:hasSkill("shangyi") then
		for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if sgs.ai_explicit[p:objectName()] == "unknown" then
				use.card = card
				self.shangyi = "hidden_general"
				if use.to then
					use.to:append(p)
				end
				return
			end
		end
	end
end

sgs.ai_skill_choice.shangyi = function(self, choices)
	return self.shangyi
end

sgs.ai_choicemade_filter.skillChoice.shangyi = function(self, from, promptlist)
	local choice = promptlist[#promptlist]
	if choice ~= "handcards" then
		for _, to in sgs.qlist(self.room:getOtherPlayers(from)) do
			if to:hasFlag("shangyiTarget") then
				to:setMark(("KnownBoth_%s_%s"):format(from:objectName(), to:objectName()), 1)
				from:setTag("KnownBoth_" .. to:objectName(), sgs.QVariant(to:getActualGeneral1Name() .. "+" .. to:getActualGeneral2Name()))
				break
			end
		end
	end
end

sgs.ai_use_value.ShangyiCard = 4
sgs.ai_use_priority.ShangyiCard = 9
sgs.ai_card_intention.ShangyiCard = 50

--徐盛
sgs.ai_skill_invoke.yicheng = function(self, data)
	--local friend = data:toPlayer()
	if not self:willShowForDefence() and not self:willShowForAttack() then
		return false
	end
	return true
end

sgs.ai_skill_discard.yicheng = function(self, discard_num, min_num, optional, include_equip)
	if self.player:hasSkill("hongyan") then
		return self:askForDiscard("dummyreason", discard_num, min_num, false, true)
	end

	local unpreferedCards = {}
	local cards = sgs.QList2Table(self.player:getHandcards())

	--没有data无法判定杀伤害的类型,为了避免火杀只能直接弃藤甲
	if self:needToThrowArmor() or (self.player:getArmor() and self.player:hasArmorEffect("Vine")) then
		table.insert(unpreferedCards, self.player:getArmor():getId())
	end

	if self:getCardsNum("Slash") > 1 then
		self:sortByKeepValue(cards)
		for _, card in ipairs(cards) do
			if card:isKindOf("Slash") then table.insert(unpreferedCards, card:getId()) end
		end
		table.remove(unpreferedCards, 1)
	end

	local num = self:getCardsNum("Jink") - 1
	if self.player:getArmor() then num = num + 1 end
	if num > 0 then
		for _, card in ipairs(cards) do
			if card:isKindOf("Jink") and num > 0 then
				table.insert(unpreferedCards, card:getId())
				num = num - 1
			end
		end
	end
	for _, card in ipairs(cards) do
		if (card:isKindOf("Weapon") and self.player:getHandcardNum() < 3) or card:isKindOf("OffensiveHorse")
			or self:getSameEquip(card, self.player) or card:isKindOf("AmazingGrace") or card:isKindOf("Lightning") then
			table.insert(unpreferedCards, card:getId())
		end
	end

	if self.player:getWeapon() and self.player:getHandcardNum() < 3 then
		table.insert(unpreferedCards, self.player:getWeapon():getId())
	end

	if self.player:getOffensiveHorse() and self.player:getWeapon() then
		table.insert(unpreferedCards, self.player:getOffensiveHorse():getId())
	end

	for index = #unpreferedCards, 1, -1 do
		if not self.player:isJilei(sgs.Sanguosha:getCard(unpreferedCards[index])) then return { unpreferedCards[index] } end
	end

	return self:askForDiscard("dummyreason", discard_num, min_num, false, true)
end

sgs.ai_skill_choice.yicheng = "yes"

--于吉
sgs.ai_skill_invoke.qianhuan = function(self, data)
	if not (self:willShowForAttack() or self:willShowForDefence() or self:willShowForMasochism() ) then
		return false
	end
	return true
end

sgs.ai_skill_cardask["@qianhuan-put"] = function(self, data, pattern, target, target2)

	local function qianhuan_CanPut(card)
		local sorcery_ids = self.player:getPile("sorcery")
		local suits = {"heart", "diamond", "spade", "club"}
		for _,id in sgs.qlist(sorcery_ids) do
			table.removeOne(suits, sgs.Sanguosha:getCard(id):getSuitString())
		end
		for _,suit in ipairs(suits) do
			if card:getSuitString() == suit then
				return true
			end
		end
		return false
	end

	local cards = self.player:getCards("he")
	cards=sgs.QList2Table(cards)
	self:sortByKeepValue(cards)
	if self.player:hasTreasure("WoodenOx") and not self.player:getPile("wooden_ox"):isEmpty() then
		local WoodenOx = sgs.Sanguosha:getCard(self.player:getTreasure():getEffectiveId())
		if self:getKeepValue(WoodenOx) > sgs.ai_keep_value.Peach then
			table.removeOne(cards, WoodenOx)
		end
	end
	local shicai_peach = false
	if self.player:hasShownSkill("shicai") then--恃才弃手牌
		local damage = self.player:getTag("qianhuan_data"):toDamage()
		if damage and damage.to and damage.to:objectName() == self.player:objectName() and damage.damage > 1 then
			shicai_peach = true
		end
	end
	for _,card in ipairs(cards) do
		if qianhuan_CanPut(card) and (shicai_peach or (not isCard("Peach", card, self.player))) then
			return card:toString()
		end
	end
	return "."
end

local invoke_qianhuan = function(self, use)
	if (use.from and self:isFriend(use.from)) then return false end
	if use.to:isEmpty() then return false end
	if use.card:isKindOf("Peach") or use.card:isKindOf("Analeptic") then return false end
	if use.card:isKindOf("KnownBoth") then return end
	local to = use.to:first()
	if use.card:isKindOf("Lightning") and self:getFinalRetrial(to, "Lightning") ~= 2 then return end
	if use.card:isKindOf("Slash") and not self:slashIsEffective(use.card, to, use.from) then return end
	if use.card:isKindOf("TrickCard") and not self:trickIsEffective(use.card, to, use.from) then return end
	if self.player:getPile("sorcery"):length() == 1 then
		if use.card:isKindOf("Slash") then
			local hcard = to:getHandcardNum()
			if self:isWeak(to) or self:hasHeavySlashDamage(use.from, use.card) or to:hasFlag("QianxiTarget") then
				return true
			elseif (use.from:hasWeapon("Triblade") and use.from:getCardCount(true) > 1) then
				for _, aplayer in sgs.qlist(self.room:getOtherPlayers(to)) do
					if to:distanceTo(aplayer) == 1 and self:isFriend(aplayer) then
						return true	
					end
				end
			elseif (use.from:hasWeapon("axe") and use.from:getCardCount(true) > 2) 
				or (use.from:hasShownSkill("liegong") and (hcard >= use.from:getHp() or hcard <= use.from:getAttackRange()))
				or getCardsNum("Jink", to, self.player) == 0 then
				return true	
			else
				local niaoxiang_BA = false
				local jiangqin = sgs.findPlayerByShownSkillName("niaoxiang")
				if jiangqin then
					if jiangqin:inSiegeRelation(jiangqin, to) then
						niaoxiang_BA = true
					end
				end
				local need_double_jink = use.from:hasShownSkill("wushuang") or niaoxiang_BA
				if need_double_jink and getCardsNum("Jink", to, self.player) < 2 then
					return true	
				end
			end
			return false
		end
		if use.card:isKindOf("Duel") or use.card:isKindOf("BurningCamps")
			or use.card:isKindOf("ArcheryAttack")  or use.card:isKindOf("SavageAssault")
			or (use.card:isKindOf("FireAttack") and to:getHp() == 1)
			or (use.card:isKindOf("Drowning") and to:getEquips():length() > 1) then
			return true
		end
		if (use.card:isKindOf("Indulgence") and self:getOverflow(to) > 1)
		or (use.card:isKindOf("SupplyShortage") and to:getHandcardNum() < 2) then--乐、兵
			return true
		end
		if (use.card:isKindOf("Snatch") or use.card:isKindOf("Dismantlement")) then--拆顺暂时不处理
			return false
		end
		--self.room:writeToConsole("invoke_qianhuan ? " .. use.card:getClassName())
		return false
	end
	if to and to:objectName() == self.player:objectName() then
		return not (use.from and (use.from:objectName() == to:objectName()
									or (use.card:isKindOf("Slash") and self:isPriorFriendOfSlash(self.player, use.card, use.from))))
	else
		return not (use.from and use.from:objectName() == to:objectName())
	end
end
sgs.ai_skill_use["@@qianhuan"] = function(self)
	local use = self.player:getTag("qianhuan_data"):toCardUse()
	local invoke = invoke_qianhuan(self, use)
	if invoke then
		return "@QianhuanCard=" .. self.player:getPile("sorcery"):first()
	end
	return "."
end

--何太后
local function will_discard_zhendu(self)
	local current = self.room:getCurrent()
	local need_damage = self:needDamagedEffects(current, self.player) or self:needToLoseHp(current, self.player)
	local analeptic = sgs.cloneCard("Analeptic")
	if current:isCardLimited(analeptic, sgs.Card_MethodUse) then return -1 end--司敌禁止？
	if self:isFriend(current) and not self.player:hasSkill("congjian") and not current:hasSkill("congjian") then
		if current:getMark("drank") > 0 and not need_damage then return -1 end
		if (getKnownCard(current, self.player, "Slash") > 0 or (getCardsNum("Slash", current, self.player) >= 1 and current:getHandcardNum() >= 2))
			and (not self:damageIsEffective(current, nil, self.player) or current:getHp() > 2 or (getCardsNum("Peach", current, self.player) > 1 and not self:isWeak(current))) then
			local slash = sgs.cloneCard("slash")
			local trend = 3
			if current:hasWeapon("Axe") then trend = trend - 1
			elseif self:hasKnownSkill(sgs.force_slash_skill, current) then trend = trend - 0.4 end
			for _, enemy in ipairs(self.enemies) do
				if ((enemy:getHp() < 3 and enemy:getHandcardNum() < 3) or (enemy:getHandcardNum() < 2)) and current:canSlash(enemy) and not self:slashProhibit(slash, enemy, current)
					and self:slashIsEffective(slash, enemy, current) and sgs.isGoodTarget(enemy, self.enemies, self, true) then
					return trend
				end
			end
		end
		if need_damage then return 3 end
	elseif self:isEnemy(current) or self:isWeak(current) then
		if not self:damageIsEffective(current, nil, self.player)then return -1 end
		if self.player:hasSkill("congjian") and not current:hasArmorEffect("SilverLion")  then--张绣配合，无白银狮子
			if current:getHp() <= 2 then
				return 1
			elseif self.player:getMark("GlobalBattleRoyalMode") > 0 then--鏖战
				return 2.5
			elseif current:getHandcardNum() < 4 then--出牌阶段手牌小于4
				return 3.5
			else--手牌较多时
				return 5.3
			end
		end
		if current:getHp() == 1 then return 1 end
		if need_damage or current:getHandcardNum() > 2 then return -1 end
		if getKnownCard(current, self.player, "Slash") == 0 and getCardsNum("Slash", current, self.player) < 0.5 then return 3.5 end
		return 5.9
	end
	return -1
end

sgs.ai_skill_discard.zhendu = function(self)
	local discard_trend = will_discard_zhendu(self)
	if discard_trend <= 0 then return {} end
	if self.player:getHandcardNum() + math.random(1, 100) / 100 >= discard_trend then
		local cards = sgs.QList2Table(self.player:getHandcards())
		self:sortByKeepValue(cards)
		for _, card in ipairs(cards) do
			if not self:isValuableCard(card, self.player) then return {card:getEffectiveId()} end
		end
	end
	return {}
end

function sgs.ai_cardneed.zhendu(to, card, self)
	return to:isKongcheng() and not self:needKongcheng(to)
end

sgs.ai_skill_invoke.qiluan = true

--君·刘备
sgs.ai_skill_invoke.jizhao = function(self, data)
	if self.player:getMark("command5_effect") > 0 then
		return false
	end
	if not self.player:canRecover() then return false end
	local dying = data:toDying()
	local need_peaches = 1 - dying.who:getHp()
	local self_recovers = (self:getCardsNum("Peach") + self:getCardsNum("Analeptic"))
	if need_peaches > self_recovers then return true end
	local value = math.max(self.player:getMaxHp() - self.player:getHandcardNum(), 0)
	local shouyue_value = 0
	if self.player:hasLordSkill("shouyue") then
		local fazheng = sgs.findPlayerByShownSkillName("xuanhuo")
		if fazheng and self.player:isFriendWith(fazheng) then
			for _, friend in ipairs(self:getFriendsNoself(fazheng)) do
				if self.player:isFriendWith(friend) then
					shouyue_value = shouyue_value + 2
				elseif self:isFriendWith(friend) and not friend:hasShownAllGenerals() then
					shouyue_value = shouyue_value + 1
				elseif not friend:hasShownOneGeneral() then
					shouyue_value = shouyue_value + 0.5
				end
			end
			if shouyue_value ~= 0 then
				shouyue_value = math.max(3, shouyue_value)
			end
		else
			for _, friend in ipairs(self.friends) do
				if friend:hasShownOneGeneral() and self.player:isFriendWith(friend) then
					if friend:hasShownSkills("wusheng|paoxiao|longdan|tieqi|liegong") then
						shouyue_value = shouyue_value + 2
					elseif not friend:hasShownAllGenerals() then--期待队友的暗置武将牌
						shouyue_value = shouyue_value + 1
					end
				elseif self:isFriendWith(friend) and not friend:hasShownAllGenerals() then
					shouyue_value = shouyue_value + 1
				elseif not friend:hasShownOneGeneral() then
					shouyue_value = shouyue_value + 0.5
				end
			end
		end
		value = value - shouyue_value
	end
	
	local peach_marks = (self.player:getMark("@companion") + self.player:getMark("@careerist"))
	if self_recovers - peach_marks <= need_peaches then
		value = value + 2*(need_peaches - self_recovers + peach_marks)
	end
	return value > 0
end

sgs.ai_skill_invoke.zhangwu = true

--飞龙夺凤
sgs.weapon_range.DragonPhoenix = 2
sgs.ai_use_priority.DragonPhoenix = 2.400
function sgs.ai_weapon_value.DragonPhoenix(self, enemy, player)
	local lord_liubei = sgs.findPlayerByShownSkillName("zhangwu")
	if lord_liubei and player:getWeapon() and not player:hasShownSkills(sgs.lose_equip_skill) then
		return -10
	end
	if enemy and enemy:getHp() <= 2 and enemy:getHandcardNum() <= 2 then--效果修改
		--(sgs.card_lack[enemy:objectName()]["Jink"] == 1 or getCardsNum("Jink", enemy, self.player) == 0)
		return 4.5
	end
	if player:hasShownSkills("paoxiao|paoxiao_xh|suzhi|xiongnve|kuangcai") or (player:hasShownSkill("baolie") and player:getHp() < 3) then
		return 3.5
	end
	return 2.5
end

function sgs.ai_slash_weaponfilter.DragonPhoenix(self, to, player)
	if player:distanceTo(to) > math.max(sgs.weapon_range.DragonPhoenix, player:getAttackRange()) then return end
--[[
	return getCardsNum("Peach", to, self.player) + getCardsNum("Jink", to, self.player) < 1
		and (sgs.card_lack[to:objectName()]["Jink"] == 1 or getCardsNum("Jink", to, self.player) == 0)
]]
	return to:getHandcardNum() <= 2 or sgs.card_lack[to:objectName()]["Jink"] == 1 or getCardsNum("Jink", to, self.player) < 1
end

--[[新飞龙夺凤技能修改
sgs.ai_skill_invoke.DragonPhoenix = function(self, data)
	if data:toString() == "revive" then return true end
	local death = data:toDeath()
	if death.who then return true
	else
		local to = data:toPlayer()
		if self:doNotDiscard(to, "he", true, 1, "DragonPhoenix") then
			return self:isFriend(to)
		else
			return self:isEnemy(to)
		end
		return not self.player:isFriendWith(to)
	end
	return true
end

sgs.ai_skill_choice.DragonPhoenix_revive = function(self)
	return "yes"
end

sgs.ai_skill_choice.DragonPhoenix = function(self, choices, data)
	local kingdom = data:toString()
	local choices_pri = {}
	choices_t = string.split(choices, "+")
	local max_hp = self.player:getMaxHp()
	local e_num = self.room:getAlivePlayers():length() - self.player:getPlayerNumWithSameKingdom("AI", kingdom)
	
	if (kingdom == "wei") then
		if (string.find(choices, "guojia")) then
			table.insert(choices_pri,"guojia") end
		if (string.find(choices, "xunyu")) then
			table.insert(choices_pri,"xunyu") end
		if (string.find(choices, "lidian")) then
			table.insert(choices_pri,"lidian") end
		if (string.find(choices, "zhanghe")) then
			table.insert(choices_pri,"zhanghe") end
		if (string.find(choices, "caopi")) then
			table.insert(choices_pri,"caopi") end
		if (string.find(choices, "zhangliao")) and e_num > 1 then
			table.insert(choices_pri,"zhangliao") end

		table.removeOne(choices_t, "caohong")
		table.removeOne(choices_t, "zangba")
		table.removeOne(choices_t, "xuchu")
		table.removeOne(choices_t, "dianwei")
		table.removeOne(choices_t, "caoren")

	elseif (kingdom == "shu") then
		if (string.find(choices, "mifuren")) then
			table.insert(choices_pri,"mifuren") end
		if (string.find(choices, "pangtong")) then
			table.insert(choices_pri,"pangtong") end
		if (string.find(choices, "lord_liubei")) then
			table.insert(choices_pri,"lord_liubei") end
		if (string.find(choices, "liushan")) then
			table.insert(choices_pri, "liushan") end
		if (string.find(choices, "jiangwanfeiyi")) then
			table.insert(choices_pri, "jiangwanfeiyi") end
		if (string.find(choices, "wolong")) then
			table.insert(choices_pri, "wolong") end
		if (string.find(choices, "menghuo")) and max_hp > 4 then
			table.insert(choices_pri, "menghuo") end
			
		table.removeOne(choices_t, "guanyu")
		table.removeOne(choices_t, "zhangfei")
		table.removeOne(choices_t, "weiyan")
		table.removeOne(choices_t, "zhurong")
		table.removeOne(choices_t, "madai")

	elseif (kingdom == "wu") then
		if (string.find(choices, "zhoutai")) then
			table.insert(choices_pri, "zhoutai") end
		if (string.find(choices, "lusu")) then
			table.insert(choices_pri, "lusu") end
		if (string.find(choices, "taishici")) then
			table.insert(choices_pri, "taishici") end
		if (string.find(choices, "sunjian")) and max_hp >= 4 then
			table.insert(choices_pri, "sunjian") end
		if (string.find(choices, "sunshangxiang")) then
			table.insert(choices_pri, "sunshangxiang") end
		if (string.find(choices, "sunquan")) and max_hp >= 4 then
			table.insert(choices_pri, "sunquan") end
			
		table.removeOne(choices_t, "sunce")
		table.removeOne(choices_t, "chenwudongxi")
		table.removeOne(choices_t, "luxun")
		table.removeOne(choices_t, "huanggai")

	elseif (kingdom == "qun") then
		if (string.find(choices, "yuji")) then
			table.insert(choices_pri,"yuji") end
		if (string.find(choices, "caiwenji")) then
			table.insert(choices_pri,"caiwenji") end
		if (string.find(choices, "mateng")) then
			table.insert(choices_pri,"mateng") end
		if (string.find(choices, "kongrong")) then
			table.insert(choices_pri,"kongrong") end
		if (string.find(choices, "lord_zhangjiao")) then
			table.insert(choices_pri,"lord_zhangjiao") end
		if (string.find(choices, "huatuo")) then
			table.insert(choices_pri,"huatuo") end

		table.removeOne(choices_t, "dongzhuo")
		table.removeOne(choices_t, "tianfeng")
		table.removeOne(choices_t, "zhangjiao")

	end
	
	if #choices_t == 0 then choices_t = string.split(choices, "+") end
	
	if #choices_pri > 0 then
		return choices_pri[math.random(1, #choices_pri)]
	end
	
	local secondly
	local masochisms = sgs.masochism_skill:split("|")
	local cardneeds = sgs.cardneed_skill:split("|")
	
	for _,name in ipairs(choices_t) do
		local general = sgs.Sanguosha:getGeneral(name)
		for _,skill in sgs.qlist(general:getVisibleSkillList()) do
			if table.contains(masochisms, skill) then
				if general:getMaxHpHead() == 3 then
					return name
				else
					secondly = name
				end
			end
		end
	end
	if secondly then return secondly end
	for _,name in ipairs(choices_t) do
		local general = sgs.Sanguosha:getGeneral(name)
		for _,skill in sgs.qlist(general:getVisibleSkillList()) do
			if table.contains(cardneeds, skill) then
				if general:getMaxHpHead() == 3 then
					return name
				else
					secondly = name
				end
			end
		end
	end
	if secondly then return secondly end
	return choices_t[math.random(1, #choices_t)]
end
--]]

sgs.ai_skill_invoke.DragonPhoenix = function(self, data)
	local target = data:toPlayer()
	if self:doNotDiscard(target, "he", true, 1, "DragonPhoenix") then
		return (self:isFriend(target) or target:getHp() <= 0)
	else
		return self:isEnemy(target)
	end
	return not self.player:isFriendWith(target)
end

sgs.ai_skill_discard.DragonPhoenix = function(self, discard_num, min_num, optional, include_equip)
	local to_discard = sgs.QList2Table(self.player:getCards("he"))

	if #to_discard == 1 then
		return {to_discard[1]:getEffectiveId()}
	end

	local aux_func = function(card)
		local place = self.room:getCardPlace(card:getEffectiveId())
		if place == sgs.Player_PlaceEquip then
			local few_hnum = self.player:getHandcardNum() < discard_num + 2 and not self:needKongcheng()
			if card:isKindOf("Weapon") then
				return few_hnum and 0 or 2
			elseif card:isKindOf("OffensiveHorse") then
				return few_hnum and 0 or 1
			elseif card:isKindOf("DefensiveHorse") then return 3
			elseif card:isKindOf("Armor") then
				if self.player:getHp() == 1 and card:isKindOf("Breastplate") then
					return 99
				end
				return self:needToThrowArmor() and -2 or 4
			elseif card:isKindOf("Treasure") then
				if card:isKindOf("WoodenOx") then
					if self.player:getPile("wooden_ox"):isEmpty() then
						return few_hnum and 0 or 2
					else
						return 6
					end
				end
				return few_hnum and 1 or 4
			else return 0
			end
		else
			if self.player:getMark("##qianxi+no_suit_red") > 0 and card:isRed() and not card:isKindOf("Peach") then return 0 end
			if self.player:getMark("##qianxi+no_suit_black") > 0 and card:isBlack() then return 0 end
			if self:isWeak() then return 5 else return 0 end
		end
	end

	local compare_func = function(card1, card2)
		local card1_aux = aux_func(card1)
		local card2_aux = aux_func(card2)
		if card1_aux ~= card2_aux then return card1_aux < card2_aux end
		return self:getKeepValue(card1) < self:getKeepValue(card2)
	end

	table.sort(to_discard, compare_func)

	if #to_discard == 2 then
		if self.player:getHp() <= 1 and to_discard[1]:isKindOf("Jink") and not self.player:isJilei(to_discard[2])
		and (to_discard[2]:isKindOf("Peach") or to_discard[2]:isKindOf("Analeptic")) then
			return to_discard[2]:getEffectiveId()
		end
	end

	for _, card in ipairs(to_discard) do
		if not self.player:isJilei(card) then return {card:getEffectiveId()} end
	end
end

--[[默认的就好
sgs.ai_skill_cardchosen.DragonPhoenix = function(self, who, flags, method, disable_list)
	local cards = who:getCards(flags)
	local length = cards:length()
	local index = math.random(0, length)
	local card = cards:at(index)
	return card:getId()
end
]]