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

function SmartAI:useCardThunderSlash(...)
	self:useCardSlash(...)
end

sgs.ai_card_intention.ThunderSlash = sgs.ai_card_intention.Slash

sgs.ai_use_value.ThunderSlash = 4.55
sgs.ai_keep_value.ThunderSlash = 3.66
sgs.ai_use_priority.ThunderSlash = 2.5

function SmartAI:useCardFireSlash(...)
	self:useCardSlash(...)
end

sgs.ai_card_intention.FireSlash = sgs.ai_card_intention.Slash

sgs.ai_use_value.FireSlash = 4.6
sgs.ai_keep_value.FireSlash = 3.63
sgs.ai_use_priority.FireSlash = 2.5

sgs.weapon_range.Fan = 4
sgs.ai_use_priority.Fan = 2.68
sgs.ai_use_priority.Vine = 0.95

sgs.ai_skill_invoke.Fan = function(self, data)
	local use = data:toCardUse()

	for _, target in sgs.qlist(use.to) do
		if self:isFriend(target) then
			if not self:damageIsEffective(target, sgs.DamageStruct_Fire) then return true end
			if target:isChained() and self:isGoodChainTarget(target, nil, nil, nil, use.card) then return true end
			if self:findLeijiTarget(target, 50, self.player) then return false end
			if target:hasArmorEffect("IronArmor") then return true end
		else
			if target:hasArmorEffect("IronArmor") then return false end
			if not self:damageIsEffective(target, sgs.DamageStruct_Fire) then return false end
			if target:isChained() and not self:isGoodChainTarget(target, nil, nil, nil, use.card) then return false end
			if target:isChained() and self:isGoodChainTarget(target, nil, nil, nil, use.card) then return true end
			if target:hasArmorEffect("Vine") then
				return true
			end
		end
	end
	return false
end
sgs.ai_view_as.Fan = function(card, player, card_place)
	local suit = card:getSuitString()
	local number = card:getNumberString()
	local card_id = card:getEffectiveId()
	if sgs.Sanguosha:getCurrentCardUseReason() ~= sgs.CardUseStruct_CARD_USE_REASON_RESPONSE
		and card_place ~= sgs.Player_PlaceSpecial and card:objectName() == "slash" then
		return ("fire_slash:fan[%s:%s]=%d&Fan"):format(suit, number, card_id)
	end
end

local fan_skill = {}
fan_skill.name = "Fan"
table.insert(sgs.ai_skills, fan_skill)
fan_skill.getTurnUseCard = function(self)
	local cards = self.player:getCards("h")
	cards = sgs.QList2Table(cards)
	local slash_card

	for _,card in ipairs(cards)  do
		if card:isKindOf("Slash") and not (card:isKindOf("FireSlash") or card:isKindOf("ThunderSlash")) then
			slash_card = card
			break
		end
	end

	if not slash_card  then return nil end
	local suit = slash_card:getSuitString()
	local number = slash_card:getNumberString()
	local card_id = slash_card:getEffectiveId()
	local card_str = ("fire_slash:Fan[%s:%s]=%d&Fan"):format(suit, number, card_id)
	local fireslash = sgs.Card_Parse(card_str)
	assert(fireslash)

	return fireslash
end

function sgs.ai_weapon_value.Fan(self, enemy,player)
	if enemy and enemy:hasArmorEffect("Vine") then return 6 end
	--if player:hasShownSkills("liegong|liegong_xh") then return 3.1 end
end

function sgs.ai_armor_value.Vine(player, self)
	if self:needKongcheng(player) and player:getHandcardNum() == 1 then
		return player:hasShownSkill("kongcheng") and 5 or 3.8
	end
	if self.player:objectName() == player:objectName() and self.player:hasSkills(sgs.lose_equip_skill) then return 3.8 end
	--if not self:damageIsEffective(player, sgs.DamageStruct_Fire) then return 6 end--建议改为相关技能，否则装备太平会换成藤甲

	local lp = player:getLastAlive()
	while (player:isFriendWith(lp) and lp:objectName() ~= player:objectName()) do
		lp = lp:getLastAlive()--找到队列的上家
	end
	if not self:isFriend(player,lp) and (lp:hasShownSkills("qice|yigui") or getKnownCard(lp, player, "BurningCamps") > 0) then--上家有奇策、役鬼,火烧
		return -3
	end
	if self:needToLoseHp(player) or self:needDamagedEffects(player) then--卖血不上藤甲
		return -2
	end

	local fslash = sgs.cloneCard("fire_slash")
	local tslash = sgs.cloneCard("thunder_slash")
	if player:isChained() and (not self:isGoodChainTarget(player, self.player, nil, nil, fslash) or not self:isGoodChainTarget(player, self.player, nil, nil, tslash)) then return -2 end

	for _, enemy in ipairs(self:getEnemies(player)) do
		if enemy:hasShownSkill("jgbiantian") then return -2 end
		if (enemy:canSlash(player) and enemy:hasWeapon("Fan")) or enemy:hasShownSkills("huoji|midao") then return -2 end
		if getKnownCard(enemy, player, "FireSlash", true) >= 1 or getKnownCard(enemy, player, "FireAttack", true) >= 1 or
			getKnownCard(enemy, player, "Fan") >= 1 then
				return -2
		end
		if not self:isFriend(player,lp) and getKnownCard(enemy, player, "BurningCamps") > 0 then--敌方可能合纵连横火烧
			return -2
		end
	end
	for _, p in sgs.qlist(self.room:getOtherPlayers(player)) do
		if p:hasShownSkill("luanji") and p:getHandcardNum() > 3 then return 4.2 end
	end

	if (#self.enemies < 3 and sgs.turncount > 2) or player:getHp() <= 2 then return 3 end--条件现在是否还适用？
	return 1
end

function SmartAI:shouldUseAnaleptic(target, card_use)
	if self:evaluateKingdom(target) == "unknown" then return false end

	if not IgnoreArmor(self.player, target) then
		if target:hasArmorEffect("SilverLion") then return false end
		if target:hasArmorEffect("Breastplate") and target:getHp() <= 2 then return false end
	end

	for _, p in sgs.qlist(self.room:getAlivePlayers()) do
		if p:hasShownSkill("qianhuan") and not p:getPile("sorcery"):isEmpty() and p:getKingdom() == target:getKingdom() and card_use.to:length() <= 1 then
			return false
		end
	end
	if (HasBuquEffect(target) or HasNiepanEffect(target)) and target:getHp() == 1 then
		return false
	end
	if target:hasShownSkill("gongqing") and self.player:getAttackRange() < 3 then
		return false
	end

	if target:hasShownSkill("xiangle") then
		local basicnum = 0
		for _, acard in sgs.qlist(self.player:getHandcards()) do
			if acard:getTypeId() == sgs.Card_TypeBasic and not acard:isKindOf("Peach") then basicnum = basicnum + 1 end
		end
		if basicnum < 3 then return false end
	end

	if card_use.card then
		if target:hasArmorEffect("PeaceSpell") and card_use.card and card_use.card:isKindOf("NatureSlash") then return false end

		local noresponse = card_use.card:getTag("NoResponse"):toStringList()--新增卡牌无法响应
		if noresponse and (table.contains(noresponse,target:objectName()) or table.contains(noresponse,"_ALL_PLAYERS")) then
			return true
		end
	end

	if self:canLiegong(target, self.player) then
		return true
	end
	if self.player:hasWeapon("Axe") and self.player:getCardCount(true) > 4 then
		return true
	end
	if self.player:hasSkills("wushuang|wushuang_lvlingqi") then
		if getKnownCard(target, self.player, "Jink", true, "he") >= 2 then return false end
		return getCardsNum("Jink", target, self.player) < 2
	end
	if self.player:hasSkills("tieqi|tieqi_xh") then
		return true
	end
	if self.player:hasShownSkill("jianchu") and (target:hasEquip() or target:getCardCount(true) == 1) then
		return true
	end
	if target:getMark("##qianxi+no_suit_red") > 0 and not target:hasShownSkill("qingguo") then
		return true
	end
	if self.player:hasWeapon("DragonPhoenix") and target:getCardCount(true) == 1 then
		return true
	end
	if getKnownCard(target, self.player, "Jink", true, "he") >= 1 and not (self:getOverflow() > 0 and self:getCardsNum("Analeptic") > 1) then return false end
	return self:getCardsNum("Analeptic") > 1 or getCardsNum("Jink", target, self.player) < 1 or sgs.card_lack[target:objectName()]["Jink"] == 1 or self:getOverflow() > 0
end

function SmartAI:useCardAnaleptic(card, use)
	if not self.player:hasEquip(card) and not self:hasLoseHandcardEffective() and not self:isWeak()
		and sgs.Analeptic_IsAvailable(self.player, card) then
		use.card = card
	end
end

function SmartAI:searchForAnaleptic(use, enemy, slash)
	if not self.toUse then return nil end
	if not use.to then return nil end

	local analeptic = self:getCard("Analeptic")
	if not analeptic then return nil end

	local analepticAvail = 1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_Residue, self.player, analeptic)
	local slashAvail = 0

	for _, card in ipairs(self.toUse) do
		if analepticAvail == 1 and card:getEffectiveId() ~= slash:getEffectiveId() and card:isKindOf("Slash") then return nil end
		if card:isKindOf("Slash") then slashAvail = slashAvail + 1 end
	end

	if analepticAvail > 1 and analepticAvail < slashAvail then return nil end
	if not sgs.Analeptic_IsAvailable(self.player) then return nil end

	local cards = self.player:getHandcards()
	cards = sgs.QList2Table(cards)
	self:fillSkillCards(cards)
	local allcards = self.player:getCards("he")
	allcards = sgs.QList2Table(allcards)

	local card_str = self:getCardId("Analeptic")
	if card_str then return sgs.Card_Parse(card_str) end

	for _, anal in ipairs(cards) do
		if (anal:getClassName() == "Analeptic") and anal:getEffectiveId() ~= slash:getEffectiveId() then
			return anal
		end
	end
end

sgs.dynamic_value.benefit.Analeptic = true

sgs.ai_use_value.Analeptic = 6.2
sgs.ai_keep_value.Analeptic = 4.1
sgs.ai_use_priority.Analeptic = 3.0

local function handcard_subtract_hp(a, b)
	local diff1 = a:getHandcardNum() - a:getHp()
	local diff2 = b:getHandcardNum() - b:getHp()

	return diff1 < diff2
end

function SmartAI:useCardSupplyShortage(card, use)
	local enemies = self:exclude(self.enemies, card)

	local zhanghe = sgs.findPlayerByShownSkillName("qiaobian")
	local zhanghe_seat = zhanghe and zhanghe:faceUp() and not zhanghe:isKongcheng() and not self:isFriend(zhanghe) and zhanghe:getSeat() or 0

	if #enemies == 0 then return end

	local getvalue = function(enemy)
		if card:isBlack() and enemy:hasShownSkill("weimu") then return -100 end
		if enemy:containsTrick("supply_shortage") or enemy:containsTrick("YanxiaoCard") then return -100 end
		if enemy:hasShownSkill("qiaobian") and not enemy:containsTrick("supply_shortage") and not enemy:containsTrick("indulgence") then return -100 end
		if zhanghe_seat > 0 and (self:playerGetRound(zhanghe) <= self:playerGetRound(enemy) and self:enemiesContainsTrick() <= 1 or not enemy:faceUp()) then
			return - 100 end

		local value = 0 - enemy:getHandcardNum()

		if enemy:hasShownSkills(sgs.priority_skill) then
		  value = value + 3
		end
		if enemy:hasShownSkills(sgs.cardneed_skill) then
			value = value + 5
		end
		--[[if enemy:hasShownSkills(sgs.drawcard_skill) or (enemy:hasShownSkill("zaiqi") and enemy:getLostHp() > 2) then
			value = value + 5
		end]]
		if self:isWeak(enemy) then value = value + 5 end
		if enemy:isLord() then value = value + 1 end
		if enemy:getRole() == "careerist" and enemy:getActualGeneral1():getKingdom() == "careerist" then
			value = value + 3
		end

		if self:objectiveLevel(enemy) < 3 then value = value - 10 end
		if not enemy:faceUp() then value = value - 10 end
		if enemy:hasShownSkills("shensu") then value = value - enemy:getHandcardNum() end
		if enemy:hasShownSkills("guanxing|"..sgs.wizard_skill) then value = value - 5 end
		if not sgs.isGoodTarget(enemy, self.enemies, self) then value = value - 1 end
		if self:needKongcheng(enemy) then value = value - 1 end
		return value
	end

	local cmp = function(a,b)
		return getvalue(a) > getvalue(b)
	end

	table.sort(enemies, cmp)

	local target = enemies[1]
	if getvalue(target) > -100 then
		use.card = card
		if use.to then use.to:append(target) end
		return
	end
end

sgs.ai_use_value.SupplyShortage = 6.5
sgs.ai_keep_value.SupplyShortage = 3.48
sgs.ai_use_priority.SupplyShortage = 0.5
sgs.ai_card_intention.SupplyShortage = 120

sgs.dynamic_value.control_usecard.SupplyShortage = true

function SmartAI:getChainedFriends(player)
	player = player or self.player
	local chainedFriends = {}
	for _, friend in ipairs(self:getFriends(player)) do
		if friend:isChained() then
			table.insert(chainedFriends, friend)
		end
	end
	return chainedFriends
end

function SmartAI:getChainedEnemies(player)
	player = player or self.player
	local chainedEnemies = {}
	for _, enemy in ipairs(self:getEnemies(player)) do
		if enemy:isChained() then
			table.insert(chainedEnemies,enemy)
		end
	end
	return chainedEnemies
end

function SmartAI:isGoodChainPartner(player)
	player = player or self.player
	if HasBuquEffect(player) or HasNiepanEffect(player) or self:needToLoseHp(player) or self:needDamagedEffects(player) then
		return true
	end
	return false
end

function SmartAI:isGoodChainTarget(who, source, nature, damagecount, card)
	if not who then self.room:writeToConsole(debug.traceback()) return end
	if not who:isChained() then return not self:isFriend(who) end
	local damageStruct = {}
	damageStruct.to = who
	damageStruct.from = source or self.player
	damageStruct.nature = nature or sgs.DamageStruct_Fire
	damageStruct.damage = damagecount or 1
	damageStruct.card = card
	return self:isGoodChainTarget_(damageStruct)
end

function SmartAI:isGoodChainTarget_(damageStruct)
	local to = damageStruct.to
	if not to then self.room:writeToConsole(debug.traceback()) return end
	if not to:isChained() then return not self:isFriend(to) end
	local from = damageStruct.from or self.player
	local nature = damageStruct.nature or sgs.DamageStruct_Fire
	local damage = damageStruct.damage or 1
	local card = damageStruct.card

	if card and card:isKindOf("Slash") then
		if from:hasSkill("yinbing") then return end
		nature = sgs.Slash_Natures[card:getClassName()]
		damage = self:hasHeavySlashDamage(from, card, to, true)
	end
	if nature == sgs.DamageStruct_Fire then
		if to:getMark("@gale") > 0 then damage = damage + 1 end
	end

	if not self:damageIsEffective_(damageStruct) then return end
	if card and card:isKindOf("TrickCard") and not self:trickIsEffective(card, to, self.player) then return end

	if nature == sgs.DamageStruct_Fire and from:hasSkill("xinghuo") then
		damage = damage + 1
	end

	local jiaren_zidan = sgs.findPlayerByShownSkillName("jgchiying")
	if jiaren_zidan and jiaren_zidan:isFriendWith(to) then
		damage = 1
	end

	if nature == sgs.DamageStruct_Fire then
		if to:hasArmorEffect("Vine") then damage = damage + 1 end
	end

	if to:hasArmorEffect("SilverLion") then damage = 1 end

	local punish
	local kills, the_enemy = 0, nil
	local good, bad, F_count, E_count = 0, 0, 0, 0
	local peach_num = self.player:objectName() == from:objectName() and self:getCardsNum("Peach") or getCardsNum("Peach", from, self.player)

	local function getChainedPlayerValue(target, dmg)
		local newvalue = 0
		if self:isGoodChainPartner(target) then newvalue = newvalue + (self:isFriend(target) and 1 or -1) end
		if self:isWeak(target) then newvalue = newvalue + (self:isFriend(target) and -1 or 1) end
		if dmg and nature == sgs.DamageStruct_Fire then
			if target:hasArmorEffect("Vine") then dmg = dmg + 1 end
			if target:getMark("@gale") > 0 then dmg = dmg + 1 end
		end
		if self:cantbeHurt(target, from, damage) then newvalue = newvalue - 100 end
		if damage + (dmg or 0) >= target:getHp() then
			if self:isFriend(target) or self:isFriend(from) then newvalue = newvalue - self:getReward(to) end
			if self:isFriend(from) and self:isFriend(target) and not punish and getCardsNum("Peach", from, self.player) + getCardsNum("Peach", target, self.player) == 0 then
				punish = true
				newvalue = newvalue - from:getCardCount(true)
			end
			if self:isEnemy(target) then kills = kills + 1 end
			if target:objectName() == self.player:objectName() and #self.friends_noself == 0 and peach_num < damage + (dmg or 0) then newvalue = newvalue - 100 end
		else
			if self:isEnemy(target) and self:isFriend(from) and from:getHandcardNum() < 2 and target:hasShownSkills("ganglie") and from:getHp() == 1
				and self:damageIsEffective(from, nil, target) and peach_num < 1 then newvalue = newvalue - 100 end
		end

		if target:hasArmorEffect("SilverLion") then return newvalue + (self:isFriend(target) and 1 or -1) end
		return newvalue - damage * 2 - (dmg and dmg * 2 or 0)
	end

	local value = getChainedPlayerValue(to)
	if self:isFriend(to) then
		good = value
		F_count = F_count + 1
	elseif self:isEnemy(to) then
		bad = value
		E_count = E_count + 1
	end

	if nature == sgs.DamageStruct_Normal then return good > bad end

	if card and card:isKindOf("FireAttack") and from:objectName() == to:objectName() then good = good - 1 end

	for _, player in sgs.qlist(self.room:getAllPlayers()) do
		local newDamageStruct = damageStruct
		newDamageStruct.to = player
		if nature == sgs.DamageStruct_Fire and player:hasArmorEffect("Vine") then newDamageStruct.damage = newDamageStruct.damage + 1 end
		if player:objectName() ~= to:objectName() and player:isChained() and self:damageIsEffective_(newDamageStruct)
			and not (card and card:isKindOf("FireAttack") and not self:trickIsEffective(card, to, self.player)) then
			local getvalue = getChainedPlayerValue(player, 0)
			if kills == #self.enemies and sgs.getDefenseSlash(player, self) < 2 then
				if card and from:objectName() == self.room:getCurrent():objectName() and from:getPhase() == sgs.Player_Play then
					self.room:setCardFlag(card, "AIGlobal_KillOff") end
				return true
			end
			if self:isFriend(player) then
				good = good + getvalue
				F_count = F_count + 1
			else
				bad = bad + getvalue
				E_count = E_count + 1
				the_enemy = player
			end
		end
	end

	if card and F_count == 1 and E_count == 1 and the_enemy and the_enemy:isKongcheng() and the_enemy:getHp() == 1 then
		for _, c in ipairs(self:getCards("Slash")) do
			if not c:isKindOf("NatureSlash") and not self:slashProhibit(c, the_enemy, from) then return end--空返回？
		end
	end

	if F_count > 0 and E_count <= 0 then return end

	--预备造成传导伤害时(例如属性杀敌友敌,依次结算会坑队友)
	local current_str = ""
	local current_message = ""
	local friend_chained = false
	for _,p in sgs.qlist(to:getAliveSiblings()) do
		if not p:isChained() then continue end
		if from:isFriendWith(p) then friend_chained = true break end
	end
	if from and friend_chained then
		current_str = sgs.Sanguosha:translate(from:getActualGeneral1Name()).."/"..sgs.Sanguosha:translate(from:getActualGeneral2Name())
		current_message = from:getSeat()
		if card then
			current_message = current_message..":"..tostring(card:getEffectiveId())
		end
		if not card or not self.chained_message or self.chained_message ~= current_message then
			repetitive = false
			self.chained_message = current_message
		end
	else
		self.chained_message = nil
	end
	local target_str = sgs.Sanguosha:translate(to:getActualGeneral1Name()).."/"..sgs.Sanguosha:translate(to:getActualGeneral2Name()).."("..sgs.Sanguosha:translate(string.format("SEAT(%s)",to:getSeat()))..")"
	if card then
		target_str = target_str .. ":" .. card:objectName()
	end
	local repetitive = true
	local current_damage = self.room:getTag("CurrentDamageStruct"):toDamage()
	if current_damage and current_damage.to then--伤害结算过程中的判断
		if (to:objectName() ~= current_damage.to:objectName())
			or (nature ~= current_damage.nature or damage ~= current_damage.damage) then
			repetitive = false
		else
			if from and current_damage.from and from:objectName() == current_damage.from:objectName() then
			else repetitive = false end
			if card and current_damage.card and card:getEffectiveId() == current_damage.card:getEffectiveId() then
			else repetitive = false end
		end
	end
	
	
	if good > bad and to:isChained() then
		if card and self:isFriend(to) and from and sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_ExtraTarget, from, card) > 0 then
			for _,p in sgs.qlist(to:getAliveSiblings()) do
				if not p:isChained() or self:isFriend(p) then continue end
				if self:playerGetRound(p) > self:playerGetRound(to) then continue end--只考虑之前的敌人
				local newDamageStruct = damageStruct
				newDamageStruct.to = p
				if not self:damageIsEffective_(newDamageStruct) then continue end
				local skip_str = sgs.Sanguosha:translate(string.format("SEAT(%s)",p:getSeat()))
				if card:isKindOf("Slash") and from:canSlash(p, card) and not self:slashProhibit(card, p, from) and card:targetFilter(sgs.PlayerList(), p, from) then
					Global_room:writeToConsole(current_str..":攻击:"..target_str..":跳过:"..skip_str)
					return false
				elseif card:isKindOf("TrickCard") and self:trickIsEffective(card, to, self.player) then
					Global_room:writeToConsole(current_str..":攻击:"..target_str..":跳过:"..skip_str)
					return false
				end
			end
		end
		current_str = current_str..":连环传导有利:"
		if friend_chained and not repetitive then
			Global_room:writeToConsole(current_str..target_str)
		end
	end

	return good > bad
end

function SmartAI:useCardIronChain(card, use)
	local needTarget = (card:getSkillName() == "guhuo" or card:getSkillName() == "nosguhuo" or card:getSkillName() == "qice" 
		or card:getSkillName() == "yigui" or card:getSkillName() == "miewu" or card:getSkillName() == "tiandian" or card:getSkillName() == "xuanyan")
	if not needTarget then
		if self.player:isLocked(card) then return end
		if #self.enemies == 1 and #self:getChainedFriends() <= 1 then return end
	end
	use.card = card
	local friendtargets, friendtargets2 = {}, {}
	local enemytargets = {}
	local danlaoenemies = {}
	self:sort(self.friends, "defense")
	for _, friend in ipairs(self.friends) do
		if friend:isChained() and not self:isGoodChainPartner(friend) and self:trickIsEffective(card, friend, self.player) then
			if friend:containsTrick("lightning") then
				table.insert(friendtargets, friend)
			elseif not friend:hasShownSkill("fenming") then
				table.insert(friendtargets2, friend)
			end
		end
	end
	table.insertTable(friendtargets, friendtargets2)
	self:sort(self.enemies, "defense")
	for _, enemy in ipairs(self.enemies) do
		if not enemy:isChained()
			and self:trickIsEffective(card, enemy, self.player) and self:objectiveLevel(enemy) > 3
			and not self:needDamagedEffects(enemy) and not self:needToLoseHp(enemy) and sgs.isGoodTarget(enemy, self.enemies, self) then
			if not enemy:hasShownSkill("danlao") then
				table.insert(enemytargets, enemy)
			elseif self:isWeak(enemy) then
				table.insert(danlaoenemies, enemy)
			end
		end
	end

	local chainSelf = self:trickIsEffective(card, self.player, self.player) and not self.player:isChained()
						and (not self.player:hasSkill("duanxie") or self.player:hasUsed("DuanxieCard"))
						and (self:needToLoseHp(self.player, nil, nil, true) or self:needDamagedEffects(self.player))
						and (self:getCardId("FireSlash") or self:getCardId("ThunderSlash")
							or (self:getCardId("Slash") and self.player:hasWeapon("Fan"))
							or (self:getCardId("FireAttack") and self.player:getHandcardNum() > 2))

	local targets_num = 2 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_ExtraTarget, self.player, card)

	if #friendtargets > 1 then
		if use.to then
			for _, friend in ipairs(friendtargets) do
				use.to:append(friend)
				if use.to:length() == targets_num then return end
			end
		end
	elseif #friendtargets == 1 then
		if #enemytargets > 0 then
			if use.to then
				use.to:append(friendtargets[1])
				for _, enemy in ipairs(enemytargets) do
					use.to:append(enemy)
					if use.to:length() == targets_num then return end
				end
			end
		elseif chainSelf then
			if use.to then use.to:append(friendtargets[1]) end
			if use.to then use.to:append(self.player) end
		end
	elseif #enemytargets > 1 then
		if use.to then
			for _, enemy in ipairs(enemytargets) do
				use.to:append(enemy)
				if use.to:length() == targets_num then return end
			end
		end
	elseif #enemytargets == 1 then
		if chainSelf then
			if use.to then use.to:append(enemytargets[1]) end
			if use.to then use.to:append(self.player) end
		end
	end
	if use.to and use.to:length() == 0 and #danlaoenemies > 0 then
		use.to:append(danlaoenemies[1])
	end
	if use.to then assert(use.to:length() < targets_num + 1) end
	if (not use.to or use.to:isEmpty())
	and (needTarget or self.player:isCardLimited(card, sgs.Card_MethodRecast) or not card:canRecast()) then
		use.card = nil
	end
end

sgs.ai_card_intention.IronChain = function(self, card, from, tos)
	for _, to in ipairs(tos) do
		if not to:isChained() then
			sgs.updateIntention(from, to,60)
		else
			sgs.updateIntention(from, to, -60)
		end
	end
end

sgs.ai_use_value.IronChain = 5.4
sgs.ai_keep_value.IronChain = 3.32
sgs.ai_use_priority.IronChain = 8.5

sgs.ai_skill_cardask["@fire-attack"] = function(self, data, pattern, target)
	local cards = sgs.QList2Table(self.player:getHandcards())
	local convert = { [".S"] = "spade", [".D"] = "diamond", [".H"] = "heart", [".C"] = "club"}
	local card

	if self.fireattack_onlyview then
		self.fireattack_onlyview = nil
		Global_room:writeToConsole("火攻只看手牌")
		return "."
	end

	if self.player:isFriendWith(target) and not (self:needToLoseHp(target) or self:needDamagedEffects(target)) then
		if not (target:isChained() and self:isGoodChainTarget(target)) then
			--暗置队友在火攻过程中明置时
			Global_room:writeToConsole("火攻队友不弃牌")
			return "."
		end
	end
	self:sortByUseValue(cards, true)

	for _, acard in ipairs(cards) do
		if acard:getSuitString() == convert[pattern] then
			if not isCard("Peach", acard, self.player) then
				card = acard
				break
			else
				local needKeepPeach = true
				if (self:isWeak(target) and not self:isWeak()) or target:getHp() == 1
						or self:isGoodChainTarget(target) or target:hasArmorEffect("Vine") then
					needKeepPeach = false
				end
				if self.player:getHp() == 1 and self:getCardsNum("Peach") + self:getCardsNum("Analeptic") < 2 then
					needKeepPeach = true
				end
				if not needKeepPeach then
					card = acard
					break
				end
			end
		end
	end
	if not card then
		self.player:setTag("AI_FireAttack_NoSuit", sgs.QVariant(convert[pattern]))
		Global_room:writeToConsole("火攻失败记录花色")
	end
	return card and card:getId() or "."
end

function SmartAI:useCardFireAttack(fire_attack, use)
	local lack = {
		spade = true,
		club = true,
		heart = true,
		diamond = true,
	}

	local can_FireAttack_self = false
	for _, card in sgs.qlist(self.player:getHandcards()) do
		if card:getEffectiveId() ~= fire_attack:getEffectiveId() then
			lack[card:getSuitString()] = false

			if not can_FireAttack_self and (not isCard("Peach", card, self.player) or self:getCardsNum("Peach") >= 3)
			and (not isCard("Analeptic", card, self.player) or self:getCardsNum("Analeptic") >= 2) then
				can_FireAttack_self = true
			end
		end
	end

	if self.player:hasSkill("hongyan") then
		lack.spade = true
	end

	local suitnum = 0
	for suit,islack in pairs(lack) do
		if not islack then suitnum = suitnum + 1  end
	end


	self:sort(self.enemies, "defense")

	local can_fire_attack = function(enemy)
		if self.player:hasFlag("FireAttackFailed_" .. enemy:objectName()) then
			return false
		end
		local known, hassuit = 0, false
		for _, c in sgs.qlist(enemy:getHandcards()) do
			if sgs.cardIsVisible(c, enemy, self.player) then
				known = known + 1
				if not lack[c:getSuitString()] then
					hassuit = true
				end
			end
		end
		if known == enemy:getHandcardNum() and not hassuit then--已知无花色
			return false
		end
		return self:objectiveLevel(enemy) > 3 and not enemy:isKongcheng()
				and self:damageIsEffective(enemy, sgs.DamageStruct_Fire, self.player) and not self:cantbeHurt(enemy, self.player)
				and self:trickIsEffective(fire_attack, enemy)
				and sgs.isGoodTarget(enemy, self.enemies, self)
				and (not (enemy:hasShownSkill("jianxiong") and not self:isWeak(enemy)) and not self:needDamagedEffects(enemy, self.player)
						and not (enemy:isChained() and not self:isGoodChainTarget(enemy, nil, nil, nil, fire_attack)))
	end

	local enemies, targets = {}, {}
	for _, enemy in ipairs(self.enemies) do
		if can_fire_attack(enemy) then
			table.insert(enemies, enemy)
		end
	end

	if can_FireAttack_self and self.player:isChained() and self:isGoodChainTarget(self.player, nil, nil, nil, fire_attack)
		and self.player:getHandcardNum() > 1
		and self:damageIsEffective(self.player, sgs.DamageStruct_Fire, self.player) and not self:cantbeHurt(self.player)
		and self:trickIsEffective(fire_attack, self.player) then

		if HasNiepanEffect(self.player) then
			table.insert(targets, self.player)
		elseif HasBuquEffect(self.player)then
			table.insert(targets, self.player)
		else
			local leastHP = 1
			if self.player:hasArmorEffect("Vine") then leastHP = leastHP + 1 end
			if self.player:hasSkill("enyuan") then leastHP = leastHP + 1 end
			if self.player:hasSkill("congjian") then leastHP = leastHP + 1 end
			if self.player:hasShownSkill("gongqing") and self.player:getAttackRange() > 3 then leastHP = leastHP + 1 end
			if self.player:hasSkill("xinghuo") then leastHP = leastHP + 1 end
			if self.player:getHp() > leastHP then
				table.insert(targets, self.player)
			elseif self:getCardsNum("Peach") + self:getCardsNum("Analeptic") > self.player:getHp() - leastHP then
				table.insert(targets, self.player)
			end
		end
	end

	for _, enemy in ipairs(enemies) do
		if enemy:getHandcardNum() == 1 then
			local handcards = sgs.QList2Table(enemy:getHandcards())
			if sgs.cardIsVisible(handcards[1], enemy, self.player) then
				local suitstring = handcards[1]:getSuitString()
				if not lack[suitstring] and not table.contains(targets, enemy) then
					table.insert(targets, enemy)
				end
			end
		end
	end

	if ((suitnum == 2 and lack.diamond == false) or suitnum <= 1)
		and self:getOverflow() <= ((self.player:hasSkill("jizhi") and not fire_attack:isVirtualCard()) and -2 or 0)
		and #targets == 0 then
			return
	end

	for _, enemy in ipairs(enemies) do
		local damage = 1
		if self.player:hasSkill("xinghuo") then
			damage = damage + 1
		end
		if enemy:hasShownSkill("mingshi") and not self.player:hasShownAllGenerals() then
			damage = damage - 1
		end
		if enemy:getMark("##xiongnve_avoid") > 0 then
			damage = damage - 1
		end
		local gongqing_avoid = false
		if enemy:hasShownSkill("gongqing") then
			if self.player:getAttackRange() < 3 then
				gongqing_avoid = true
			end
			if self.player:getAttackRange() > 3 then
				damage = damage + 1
			end
		end
		if enemy:hasArmorEffect("SilverLion") or gongqing_avoid then
			damage = 1
		end
		if enemy:hasArmorEffect("Vine") then
			damage = damage + 1
		end
		if self:damageIsEffective(enemy, sgs.DamageStruct_Fire, self.player) and damage > 1 then
			if not table.contains(targets, enemy) then table.insert(targets, enemy) end
		end
	end
	for _, enemy in ipairs(enemies) do
		if not table.contains(targets, enemy) then table.insert(targets, enemy) end
	end

	self.fireattack_onlyview = nil
	--if self.player:isLastHandCard(fire_attack) and (self:needKongcheng() or self.player:getMark("@firstshow") + self.player:getMark("@careerist") > 0) then--公孙诸葛带野心标记火攻看牌至空牌
	if self.player:isLastHandCard(fire_attack) and (self:needKongcheng() or self.player:getMark("@firstshow") > 0) then
		self.fireattack_onlyview = true
	end
	if #targets == 0 and self:getOverflow() > 0 then
		self.fireattack_onlyview = true
	end
	if self.fireattack_onlyview then
		if #targets == 0 and #self.enemies > 0 then
			for _,p in ipairs(self.enemies) do
				if p:isKongcheng() or not self:trickIsEffective(fire_attack, p) then continue end--过滤无效角色
				table.insert(targets, p)
				break
			end
		end
		if #targets == 0 then
			for _,p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
				if p:isKongcheng() or not self:trickIsEffective(fire_attack, p) then continue end--过滤无效角色
				table.insert(targets, p)
				break
			end
		end
	end

	if #targets > 0 then
		local godsalvation = self:getCard("GodSalvation")
		if godsalvation and godsalvation:getId() ~= fire_attack:getId() and self:willUseGodSalvation(godsalvation) then
			local use_gs = true
			for _, p in ipairs(targets) do
				if not p:isWounded() or not self:trickIsEffective(godsalvation, p, self.player) then break end
				use_gs = false
			end
			if use_gs then
				use.card = godsalvation
				return
			end
		end

		local targets_num = 1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_ExtraTarget, self.player, fire_attack)
		use.card = fire_attack
		for i = 1, #targets, 1 do
			if use.to then
				use.to:append(targets[i])
				if use.to:length() == targets_num then return end
			end
		end
	end
end

sgs.ai_cardshow.fire_attack = function(self, requestor)
	local cards = sgs.QList2Table(self.player:getHandcards())
	self:sortByKeepValue(cards)
	if requestor:objectName() == self.player:objectName() then
		self:sortByUseValue(cards, true)
		return cards[1]
	end
	if requestor:hasShownSkill("hongyan") then
		for _, card in ipairs(cards) do
			if card:getSuit() == sgs.Card_Spade then
				return card
			end
		end
	end
	local nosuit = requestor:getTag("AI_FireAttack_NoSuit"):toString()
	if nosuit ~= "" then--来源上一次火攻失败处理，过回合在filterEvent处理
		Global_room:writeToConsole("火攻失败展示")
		requestor:removeTag("AI_FireAttack_NoSuit")
		for _, card in ipairs(cards) do
			if card:getSuitString() == nosuit then
				return card
			end
		end
	end

	local known_cards = {}
	for _, c in sgs.qlist(requestor:getHandcards()) do
		if sgs.cardIsVisible(c, requestor, self.player) then
			table.insert(known_cards, c)
		end
	end
	local priority = { heart = 4, spade = 3, club = 2, diamond = 1 }
	if #known_cards > 0 then--已知花色处理
		for _, c in ipairs(known_cards) do
			priority[c:getSuitString()] = 0
		end
	end

	local index = -1
	local result
	for _, card in ipairs(cards) do
		if priority[card:getSuitString()] > index then
			result = card
			index = priority[card:getSuitString()]
		end
	end

	return result
end

sgs.ai_use_value.FireAttack = 4.8
sgs.ai_keep_value.FireAttack = 3.28
sgs.ai_use_priority.FireAttack = sgs.ai_use_priority.Dismantlement + 0.1
sgs.dynamic_value.damage_card.FireAttack = true
sgs.ai_card_intention.FireAttack = 80
sgs.dynamic_value.damage_card.FireAttack = true