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

function SmartAI:canAttack(enemy, attacker, nature, card)
	attacker = attacker or self.player
	nature = nature or sgs.DamageStruct_Normal
	local damage = 1
	if nature == sgs.DamageStruct_Fire and not enemy:hasArmorEffect("SilverLion") then
		if enemy:hasArmorEffect("Vine") then damage = damage + 1 end
		if enemy:getMark("@gale") > 0 then damage = damage + 1 end
	end
	if enemy:hasShownSkill("gongqing") and attacker:getAttackRange(true) > 3 then
		damage = damage + 1
	end
	if (attacker:hasShownSkill("congjian") and attacker:getPhase() == sgs.Player_NotActive) or (enemy:hasShownSkill("congjian") and enemy:getPhase() == sgs.Player_NotActive) then
		damage = damage + 1
	end
	if card and card:isKindOf("Slash") then
		if card:hasFlag("drank") then
			damage = damage + 1
		elseif attacker:getMark("drank") > 0 then
			damage = damage + attacker:getMark("drank")
		end
	end
	local jiaren_zidan = sgs.findPlayerByShownSkillName("jgchiying")
	local jgchiying = (jiaren_zidan and jiaren_zidan:isFriendWith(enemy))
	if (enemy:hasArmorEffect("SilverLion") and not IgnoreArmor(attacker, enemy)) or jgchiying or (enemy:hasShownSkill("gongqing") and attacker:getAttackRange(true) < 3) then
		damage = 1
	end
	if #self.enemies == 1 then return true end
	if (self:needToLoseHp(enemy, attacker, false, true) and #self.enemies > 1) or not sgs.isGoodTarget(enemy, self.enemies, self) then return false end
	if self:needDamagedEffects(enemy, attacker) and damage <= 1 then return false end
	if self:objectiveLevel(enemy) <= 2 or self:cantbeHurt(enemy, self.player, damage) or not self:damageIsEffective(enemy, nature, attacker, card) then return false end
	if nature ~= sgs.DamageStruct_Normal and enemy:isChained() and not self:isGoodChainTarget(enemy, self.player, nature) then return false end
	return true
end


function sgs.isGoodHp(player, observer)
	observer = observer or sgs.recorder.player
	local goodHp = player:getHp() > 1 or getCardsNum("Peach", player, observer) >= 1 or getCardsNum("Analeptic", player, observer) >= 1
					or HasBuquEffect(player) or HasNiepanEffect(player)
	if goodHp then
		return goodHp
	else
		local n = 0
		for _, friend in ipairs(sgs.recorder:getFriends(player)) do
			if Global_room:getCurrent():hasShownSkill("wansha") and player:objectName() ~= friend:objectName() then continue end
			n = n + getCardsNum("Peach", friend, observer)
		end
		return n > 0
	end
	return false
end

function sgs.isGoodTarget(player, targets, self, isSlash)
	if not self then Global_room:writeToConsole(debug.traceback()) end
	-- self = self or sgs.ais[player:objectName()]
	local arr = { "jieming", "yiji", "fangzhu" }--其他卖血技能？
	local m_skill = false
	local attacker = Global_room:getCurrent()

	if targets and type(targets)=="table" then
		if #targets == 1 then return true end
		local foundtarget = false
		for i = 1, #targets, 1 do
			if sgs.isGoodTarget(targets[i], nil, self) and not self:cantbeHurt(targets[i]) then
				foundtarget = true
				break
			end
		end
		if not foundtarget then return true end
	end

	for _, masochism in ipairs(arr) do
		if player:hasShownSkill(masochism) then
			if masochism == "jieming" and self and self:getJiemingDrawNum(player) < 2 then m_skill = false
			elseif masochism == "yiji" and self and not self:findFriendsByType(sgs.Friend_Draw, player) then m_skill = false
			else
				m_skill = true
				break
			end
		end
	end

	if isSlash and self and (self:hasCrossbowEffect() or self:getCardsNum("Crossbow") > 0) and self:getCardsNum("Slash") > player:getHp() then
		return true
	end

	if isSlash and self and self.player:hasWeapon("Crossbow") and player:hasShownSkills(sgs.throw_crossbow_skill) then
		return false
	end

	if m_skill and sgs.isGoodHp(player, self and self.player) and not self.player:hasSkills("tieqi|tieqi_xh|yinbing") then
		return false
	else
		return true
	end
end

function sgs.getDefenseSlash(player, self)
	if not player or not self then Global_room:writeToConsole(debug.traceback()) return 0 end
	local attacker = self.player
	local unknownJink = getCardsNum("Jink", player, attacker)
	local defense = unknownJink

	local knownJink = getKnownCard(player, attacker, "Jink", true, "he")

	if sgs.card_lack[player:objectName()]["Jink"] == 1 and knownJink == 0 then defense = 0 end

	defense = defense + knownJink * 1.2

	if self:canLiegong(player, attacker) then
		defense = 0
	end

	local niaoxiang_BA = false
	if attacker:hasSkill("niaoxiang") and not attacker:inFormationRalation(player) then--(2.3.2)
		niaoxiang_BA = true
	else
		local jiangqin = sgs.findPlayerByShownSkillName("niaoxiang")
		if jiangqin then
			if attacker:inSiegeRelation(jiangqin, player) then
				niaoxiang_BA = true
			end
		end
	end
	
	local need_double_jink = attacker:hasShownSkills("wushuang|wushuang_lvlingqi") or niaoxiang_BA
	if need_double_jink and knownJink < 2 and unknownJink < 1.5 then
		defense = 0
	end

	if attacker:hasShownSkill("jianchu") and (player:hasEquip() or player:getCardCount(true) == 1) then
		defense = 0
	end

	local jink = sgs.cloneCard("jink")
	if player:isCardLimited(jink, sgs.Card_MethodUse) then defense = 0 end

	if player:getMark("##qianxi+no_suit_red") > 0 then
		if player:hasShownSkill("qingguo") then
			defense = defense - 0.5
		else
			defense = 0
		end
	elseif player:getMark("##qianxi+no_suit_black") > 0 then
		if player:hasShownSkill("qingguo") then
			defense = defense - 1
		end
	end

	if player:getMark("##boyan") > 0 or player:getMark("command4_effect") > 0 then
		defense = 0
	end

	if attacker:hasWeapon("DragonPhoenix") or attacker:hasSkills("tieqi|tieqi_xh") then
		if player:getCardCount(true) <= 1 then
			defense = 0
		elseif player:getCardCount(true) <= 3 then
			defense = defense - 1
		end
	end

	if attacker:hasWeapon("Axe") and attacker:getCardCount(true) > 4 then
		defense = 0
	end

	defense = defense + math.min(player:getHp() * 0.45, 10)
	if sgs.isAnjiang(player) then defense = defense - 1 end

	local hasEightDiagram = false

	if player:hasArmorEffect("EightDiagram") and not IgnoreArmor(attacker, player) then
		hasEightDiagram = true
	end

	if hasEightDiagram then
		defense = defense + (self:hasCrossbowEffect(attacker) and 4 or 1.5)
		if player:hasShownSkills("qingguo+tiandu") then defense = defense + 10
		elseif player:hasShownSkills("tiandu|zhuwei") then defense = defense + 1 end
		if player:hasShownSkill("leiji") then defense = defense + 0.6 end
		if player:hasShownSkills("hongyan|guicai|huanshi") then defense = defense + 0.5 end
	end
	if player:hasArmorEffect("RenwangShield") and not IgnoreArmor(attacker, player) and player:hasShownSkill("jiang") then
		defense = defense + 1.6
	end

	if player:hasShownSkill("tuntian") and player:hasShownSkill("jixi") and unknownJink >= 1 and not attacker:hasSkills("tieqi|tieqi_xh") then
		defense = defense + 1.5
	end

	if not attacker:hasSkills("tieqi|tieqi_xh|yinbing") then
		for _, masochism in ipairs(sgs.masochism_skill:split("|")) do
			if player:hasShownSkill(masochism) and sgs.isGoodHp(player, self.player) then
				defense = defense + 1
			end
		end
		if player:hasShownSkill("fudi") and player:getHandcardNum() > 1 and attacker:getHp() + 1 >= player:getHp() then
			defense = defense + 1
		end
	end

	if not sgs.isGoodTarget(player, nil, self) then defense = defense + 10 end

	if player:hasShownSkill("rende") and player:getHp() > 2 then defense = defense + 1 end
	if player:hasShownSkill("kuanggu") and player:getHp() > 1 then defense = defense + 0.2 end
	if player:hasShownSkill("zaiqi") and player:getHp() > 1 then defense = defense + 0.35 end

	if player:getHp() <= 2 then defense = defense - 0.4 end

	local playernum = Global_room:alivePlayerCount()
	if (player:getSeat()-attacker:getSeat()) % playernum >= playernum-2 and playernum>3 and player:getHandcardNum()<=2 and player:getHp()<=2 then
		defense = defense - 0.4
	end

	if player:hasShownSkill("tianxiang") then defense = defense + player:getHandcardNum() * 0.8 end
	local isInPile = function()
		for _,pile in sgs.list(player:getPileNames())do
			if pile:startsWith("&") or pile == "wooden_ox" then
				if not player:getPile(pile):isEmpty() then
					return false
				end
			end
		end
		return true
	end
	if player:isKongcheng() and player:getHandPile():isEmpty() and not player:hasShownSkills("kongcheng") then
		if player:getHp() <= 1 then defense = defense - 2.5 end
		if player:getHp() == 2 then defense = defense - 1.5 end
		if not hasEightDiagram then defense = defense - 2 end
	end

	local has_fire_slash
	local cards = sgs.QList2Table(attacker:getHandcards())
	for i = 1, #cards, 1 do
		if (attacker:hasWeapon("Fan") and cards[i]:objectName() == "slash" and not cards[i]:isKindOf("ThunderSlash")) or cards[i]:isKindOf("FireSlash")  then
			has_fire_slash = true
			break
		end
	end

	if player:hasArmorEffect("Vine") and not IgnoreArmor(attacker, player) and has_fire_slash then
		defense = defense - 0.6
	end

	if player:hasTreasure("JadeSeal") then defense = defense - 0.4 end

	if player:isLord() then defense = defense - 0.5 end
	if player:getRole() == "careerist" and player:getActualGeneral1():getKingdom() == "careerist" then
		defense = defense - 0.5
	end

	if not player:faceUp() then defense = defense - 0.35 end

	if player:containsTrick("indulgence") then defense = defense - 0.25 end
	if player:containsTrick("supply_shortage") then defense = defense - 0.15 end

	if not hasEightDiagram then
--[[--这一部分用处？？控制集火？
		if player:hasShownSkill("jijiu") then
			defense = defense - 3
		elseif sgs.hasNullSkill("jijiu", player) then
			defense = defense - 4
		end
		if player:hasShownSkill("dimeng") then
			defense = defense - 2.5
		elseif sgs.hasNullSkill("dimeng", player) then
			defense = defense - 3.5
		end
		if player:hasShownSkill("guzheng") and knownJink == 0 then
			defense = defense - 2.5
		elseif sgs.hasNullSkill("guzheng", player) and knownJink == 0 then
			defense = defense - 3.5
		end
		if player:hasShownSkill("qiaobian") then
			defense = defense - 2.4
		elseif sgs.hasNullSkill("qiaobian", player) then
			defense = defense - 3.4
		end
		if player:hasShownSkill("jieyin") then
			defense = defense - 2.3
		elseif sgs.hasNullSkill("jieyin", player) then
			defense = defense - 3.3
		end
		if player:hasShownSkill("lijian") then
			defense = defense - 2.2
		elseif sgs.hasNullSkill("lijian", player) then
			defense = defense - 3.2
		end
]]

		local priority = sgs.priority_skill:split("|")
		for _, skill in ipairs(priority) do
			if player:hasShownSkill(skill) then
				defense = defense - 0.6
			elseif sgs.hasNullSkill(skill, player) then
				defense = defense - 1
			end
		end

		local masochism = sgs.masochism_skill:split("|")
		for _, skill in ipairs(masochism) do
			if sgs.hasNullSkill(skill, player) then
				defense = defense - 1
			end
		end
	end
	return defense
end

function SmartAI:slashProhibit(card, enemy, from)
	card = card or sgs.cloneCard("slash", sgs.Card_NoSuit, 0)
	from = from or self.player
	if enemy:isRemoved() then return true end

	local nature = sgs.Slash_Natures[card:getClassName()]
	for _, askill in sgs.qlist(enemy:getVisibleSkillList(true)) do
		if enemy:hasShownSkill(askill:objectName()) then
			local filter = sgs.ai_slash_prohibit[askill:objectName()]
			if filter and type(filter) == "function" and filter(self, from, enemy, card) then return true end
		end
	end

	if self:isFriend(enemy, from) then
		if (card:isKindOf("FireSlash") or from:hasWeapon("Fan")) and enemy:hasArmorEffect("Vine")
			and not (enemy:isChained() and self:isGoodChainTarget(enemy, from, nil, nil, card)) then return true end
		if enemy:isChained() and card:isKindOf("NatureSlash") and self:slashIsEffective(card, enemy, from)
			and not self:isGoodChainTarget(enemy, from, nature, nil, card) then return true end
		if getCardsNum("Jink",enemy, from) == 0 and enemy:getHp() < 2 and self:slashIsEffective(card, enemy, from) then return true end
	else
		if card:isKindOf("NatureSlash") and enemy:isChained() and not self:isGoodChainTarget(enemy, from, nature, nil, card) and self:slashIsEffective(card, enemy, from) then
			return true
		end
	end

	return not self:slashIsEffective(card, enemy, from) -- @todo: param of slashIsEffective
end

function SmartAI:canLiuli(daqiao, another)
	if not daqiao:hasShownSkill("liuli") then return false end
	if type(another) == "table" then
		if #another == 0 then return false end
		for _, target in ipairs(another) do
			if target:getHp() < 3 and self:canLiuli(daqiao, target) then return true end
		end
		return false
	end

	if not self:needToLoseHp(another, self.player, true) or not self:needDamagedEffects(another, self.player, true) then return false end
	if another:hasShownSkill("xiangle") then return false end
	local n = daqiao:getHandcardNum()
	if n > 0 and (daqiao:distanceTo(another) <= daqiao:getAttackRange()) then return true
	elseif daqiao:getWeapon() and daqiao:getOffensiveHorse() and (daqiao:distanceTo(another) <= daqiao:getAttackRange()) then return true
	elseif daqiao:getWeapon() or daqiao:getOffensiveHorse() then return daqiao:distanceTo(another) <= 1
	else return false end
end

function SmartAI:slashIsEffective(slash, to, from, ignore_armor)
	if not slash or not to then self.room:writeToConsole(debug.traceback()) return end
	from = from or self.player
	if to:hasShownSkill("kongcheng") and to:isKongcheng() then return false end
	if to:isRemoved() then return false end

	local nature = sgs.Slash_Natures[slash:getClassName()]
	local damage = {}
	damage.from = from
	damage.to = to
	damage.card = slash
	damage.nature = nature
	damage.damage = 1
	if not from:hasShownAllGenerals() and to:hasShownSkill("mingshi") then
		local dummy_use = { to = sgs.SPlayerList() }
		dummy_use.to:append(to)
		local analeptic = self:searchForAnaleptic(dummy_use, to, slash)
		if analeptic and self:shouldUseAnaleptic(to, dummy_use) and analeptic:getEffectiveId() ~= slash:getEffectiveId() then
			damage.damage = damage.damage + 1
		end
	end
	if not self:damageIsEffective_(damage) then return false end

	if to:hasSkill("jgyizhong") and not to:getArmor() and slash:isBlack() then
		if (from:hasWeapon("DragonPhoenix") or from:hasWeapon("DoubleSword") and (from:isMale() and to:isFemale() or from:isFemale() or to:isMale()))
			and (to:getCardCount(true) == 1 or #self:getEnemies(from) == 1) then
		else
			return false
		end
	end

	if not ignore_armor and  to:hasArmorEffect("IronArmor") and slash:isKindOf("FireSlash") then return false end

	if not (ignore_armor or IgnoreArmor(from, to)) then
		if to:hasArmorEffect("RenwangShield") and slash:isBlack() then
			if (from:hasWeapon("DragonPhoenix") or from:hasWeapon("DoubleSword") and (from:isMale() and to:isFemale() or from:isFemale() or to:isMale()))
				and (to:getCardCount(true) == 1 or #self:getEnemies(from) == 1) then
			elseif from:hasShownSkill("jianchu") or (from:hasShownSkill("kuangfu") and not from:hasFlag("kuangfuUsed")) then--需要配合单独判断弃防具
				return true
			else
				return false
			end
		end

		if to:hasArmorEffect("Vine") and not slash:isKindOf("NatureSlash") then
			if (from:hasWeapon("DragonPhoenix") or from:hasWeapon("DoubleSword") and (from:isMale() and to:isFemale() or from:isFemale() or to:isMale()))
				and (to:getCardCount(true) == 1 or #self:getEnemies(from) == 1) then
			elseif from:hasShownSkill("jianchu") or (from:hasShownSkill("kuangfu") and not from:hasFlag("kuangfuUsed")) then
				return true
			else
				local skill_name = slash:getSkillName() or ""
				local can_convert = false
				local skill = sgs.Sanguosha:getSkill(skill_name)
				if not skill or skill:inherits("FilterSkill") then
					can_convert = true
				end
				if not can_convert or not from:hasWeapon("Fan") then return false end
			end
		end
	end

	if slash:isKindOf("ThunderSlash") then
		local f_slash = self:getCard("FireSlash")
		if f_slash and self:hasHeavySlashDamage(from, f_slash, to, true) > self:hasHeavySlashDamage(from, slash, to, true)
			and (not to:isChained() or self:isGoodChainTarget(to, from, sgs.DamageStruct_Fire, nil, f_slash)) then
			return self:slashProhibit(f_slash, to, from)
		end
	elseif slash:isKindOf("FireSlash") then
		local t_slash = self:getCard("ThunderSlash")
		if t_slash and self:hasHeavySlashDamage(from, t_slash, to, true) > self:hasHeavySlashDamage(from, slash, to, true)
			and (not to:isChained() or self:isGoodChainTarget(to, from, sgs.DamageStruct_Thunder, nil, t_slash)) then
			return self:slashProhibit(t_slash, to, from)
		end
	end

	return true
end

function SmartAI:slashIsAvailable(player, slash) -- @todo: param of slashIsAvailable
	player = player or self.player
	if slash and not slash:isKindOf("Slash") then
		self.room:writeToConsole("出错的是 " .. slash:objectName() .. slash:toString() .. " clssname = " .. slash:getClassName())
		self.room:writeToConsole(debug.traceback())
	end
	slash = slash or sgs.cloneCard("slash")
	return slash:isAvailable(player)
end

function SmartAI:findWeaponToUse(enemy)
	local weaponvalue = {}
	local hasweapon
	for _, c in sgs.qlist(self.player:getHandcards()) do
		if c:isKindOf("Weapon") then
			local dummy_use = { isDummy = true, to = sgs.SPlayerList() }
			self:useEquipCard(c, dummy_use)
			if dummy_use.card then
				weaponvalue[c] = self:evaluateWeapon(c, self.player, enemy)
				hasweapon = true
			end
		end
	end
	if not hasweapon then return end
	if self.player:getWeapon() then weaponvalue[self.player:getWeapon()] = self:evaluateWeapon(self.player:getWeapon(), self.player, enemy) end
	local max_value, max_card = -1000, nil
	for c, v in pairs(weaponvalue) do
		if v > max_value then
			max_card = c
			max_value = v
		end
	end
	if self.player:getWeapon() and self.player:getWeapon():getEffectiveId() == max_card:getEffectiveId() then return false end
	return max_card
end

function SmartAI:isPriorFriendOfSlash(friend, card, source)
	source = source or self.player
	local huatuo = sgs.findPlayerByShownSkillName("jijiu")
	if source:hasSkill("zhiman") then
		local promo = self:findPlayerToDiscard("ej", false, sgs.Card_MethodGet, nil, true)
		if table.contains(promo, friend) then
			return true
		end
	end
	if not self:hasHeavySlashDamage(source, card, friend)
		and ((self:findLeijiTarget(friend, 50, source) and not source:hasShownSkill("wushuang"))
		or (friend:hasShownSkill("jieming") and source:hasShownSkill("rende") and huatuo and self:isFriend(huatuo, source))) then
		return true
	end
	if card:isKindOf("NatureSlash") and friend:isChained() and self:isGoodChainTarget(friend, source, nil, nil, card) then return true end
	return
end


function SmartAI:useCardSlash(card, use)
	if card:getClassName() == "AocaiCard" then
		card = sgs.cloneCard("slash")
	end
	if card:getClassName() == "MiewuCard" then
		local userstring = card:toString()
		userstring = (userstring:split(":"))[3]
		local slash = sgs.cloneCard(userstring)
		slash:addSubcard(card:getSubcards():first())
		card = slash
	end
	if use.to then
	elseif not use.to and not use.isDummy then
		local name = self.player:getActualGeneral1Name() .. "/" .. self.player:getActualGeneral2Name()
		Global_room:writeToConsole(name .."->使用杀无use.to:"..tostring(card:toString()))
	end
	if not use.isDummy and not self:slashIsAvailable(self.player, card) then return end
	if self.player:hasSkill("xiaoji") and sgs.Sanguosha:getCard(card:getEffectiveId()) and sgs.Sanguosha:getCard(card:getEffectiveId()):isKindOf("EquipCard")
		and self.room:getCardPlace(card:getEffectiveId()) == sgs.Player_PlaceHand then return end
	local cards = self.player:getCards("he")
	cards = sgs.QList2Table(cards)
	local no_distance = sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_DistanceLimit, self.player, card) > 50
						or self.player:hasFlag("slashNoDistanceLimit") or self:hasWenjiBuff(card)
	local slash_tgnum = 1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_ExtraTarget, self.player, card)
	local rangefix = 0
	if card:isVirtualCard() then
		if self.player:getWeapon() and card:getSubcards():contains(self.player:getWeapon():getEffectiveId()) then
			if self.player:getWeapon():getClassName() ~= "Weapon" then
				rangefix = sgs.weapon_range[self.player:getWeapon():getClassName()] - self.player:getAttackRange(false)
			end
		end
		if self.player:getOffensiveHorse() and card:getSubcards():contains(self.player:getOffensiveHorse():getEffectiveId()) then
			rangefix = rangefix + 1
		end
	end

	local function canAppendTarget(target)
		if self.player:hasSkill("paoxiao") then--咆哮屯杀
			local enough_pxslash = false
			if self:getCardsNum("Slash") > 0 then
			  local yongjue_slash = 0
			  if self.player:getMark("GlobalPlayCardUsedTimes") == 0 then
				for _, p in ipairs(self.friends) do
					if p:hasShownSkill("yongjue") and self.player:isFriendWith(p) then--self.player:getSlashCount() == 0
					yongjue_slash = 1
					break
					end
				end
			  end
			  if yongjue_slash + self.player:getSlashCount() + self:getCardsNum("Slash") >= 2 then
				enough_pxslash = true
			  end
			end
			if not enough_pxslash and self:getOverflow() <= 0 and not (target:getHp() == 1 and self:isWeak(target))
			and not (self.player:hasSkill("jili") and self.player:getCardUsedTimes(".") + self.player:getCardRespondedTimes(".") + 1 == self.player:getAttackRange()) then
				self.room:writeToConsole("咆哮屯杀")
				return false
			end
		end
		local targets = sgs.PlayerList()
		if use.to and not use.to:isEmpty() then
			if use.to:contains(target) then return false end
			for _, to in sgs.qlist(use.to) do
				targets:append(to)
			end
		end
		return card:targetFilter(targets, target, self.player)
	end

	for _, friend in ipairs(self.friends_noself) do
		if self:isPriorFriendOfSlash(friend, card) and not self:slashProhibit(card, friend) then
			if (not use.current_targets or not table.contains(use.current_targets, friend:objectName()))
				and (self.player:canSlash(friend, card, not no_distance, rangefix)
				or (use.isDummy and (self.player:distanceTo(friend, rangefix) <= self.predictedRange)))
				and self:slashIsEffective(card, friend) then
				use.card = card
				if use.to and canAppendTarget(friend) then
					use.to:append(friend)
				end
				if not use.to or slash_tgnum <= use.to:length() then
					return
				end
			end
		end
	end

	local targets = {}
	local forbidden = {}
	self:sort(self.enemies, "defenseSlash")
	for _, enemy in ipairs(self.enemies) do
		if not self:slashProhibit(card, enemy) and sgs.isGoodTarget(enemy, self.enemies, self, true) then
			if not self:needDamagedEffects(enemy, self.player, true) then
				table.insert(targets, enemy)
			else
				table.insert(forbidden, enemy)
			end
		end
	end
	if #targets == 0 and #forbidden > 0 then targets = forbidden end
	local canSlashTargets = {}

	for _, target in ipairs(targets) do
		local canliuli = false
		for _, friend in ipairs(self.friends_noself) do
			if self:canLiuli(target, friend) and self:slashIsEffective(card, friend) and #targets > 1 and friend:getHp() < 3 then canliuli = true end
		end
		if (not use.current_targets or not table.contains(use.current_targets, target:objectName()))
			and (self.player:canSlash(target, card, not no_distance, rangefix)
				or (use.isDummy and self.predictedRange and self.player:distanceTo(target, rangefix) <= self.predictedRange))
			and self:objectiveLevel(target) > 3
			and not canliuli then
		--[[旧克己
			and not (not self:isWeak(target) and #self.enemies > 1 and #self.friends > 1 and self.player:hasSkill("keji")
			and self:getOverflow() > 0 and not self:hasCrossbowEffect()) ]]

			if target:getHp() > 1 and target:hasShownSkill("jianxiong") and self.player:hasWeapon("Spear") and card:getSkillName() == "Spear" then
				local ids, isGood = card:getSubcards(), true
				for _, id in sgs.qlist(ids) do
					local c = sgs.Sanguosha:getCard(id)
					if isCard("Peach", c, target) or isCard("Analeptic", c, target) then isGood = false break end
				end
				if not isGood then continue end
			end

			-- fill the card use struct
			local usecard = card
			if not use.to or use.to:isEmpty() then
				if self.player:hasWeapon("Spear") and card:getSkillName() == "Spear" then
				elseif self.player:hasWeapon("Crossbow") and self:getCardsNum("Slash") > 0 then
				elseif not use.isDummy then
					local weapon = self:findWeaponToUse(target)
					if weapon then
						use.card = weapon
						return
					end
				end

				if target:isChained() and self:isGoodChainTarget(target, nil, nil, nil, card) and not use.card then
					if self:hasCrossbowEffect() and card:isKindOf("NatureSlash") then
						for _, slash in ipairs(self:getCards("Slash")) do
							if not slash:isKindOf("NatureSlash") and self:slashIsEffective(slash, target)
								and not self:slashProhibit(slash, target) then
								usecard = slash
								break
							end
						end
					elseif not card:isKindOf("NatureSlash") then
						local slash = self:getCard("NatureSlash")
						if slash and self:slashIsEffective(slash, target) and not self:slashProhibit(slash, target) then usecard = slash end
					end
				end
				local godsalvation = self:getCard("GodSalvation")
				if not use.isDummy and godsalvation and godsalvation:getId() ~= card:getId() and self:willUseGodSalvation(godsalvation) and
					(not target:isWounded() or not self:trickIsEffective(godsalvation, target, self.player)) then
					use.card = godsalvation
					return
				end
			end

			use.card = use.card or usecard
			if not use.isDummy and canAppendTarget(target) then--酒和技能配合处理？
				local analeptic = self:searchForAnaleptic(use, target, use.card or usecard)
				if analeptic and self:shouldUseAnaleptic(target, use) and analeptic:getEffectiveId() ~= card:getEffectiveId() then
					use.card = analeptic
					if use.to then use.to = sgs.SPlayerList() end
					return
				end
			end

			if self.player:hasSkill("duanbing") or (self.player:hasSkills("kuanggu|kuanggu_xh") and self:hasCrossbowEffect()) then--需要额外筛选目标的技能，但是酒怎么处理？
				table.insert(canSlashTargets, target)
				continue
			end

			if use.to and canAppendTarget(target) then
				use.to:append(target)
			end
			if not use.to or slash_tgnum <= use.to:length() then
				return
			end
		end
	end

	if self.player:hasSkill("duanbing") and #canSlashTargets > 0 then
		for _, target in ipairs(canSlashTargets) do
			if self.player:distanceTo(target) > 1 then--短兵先选远的目标
				if use.to and canAppendTarget(target) then
					use.to:append(target)
				end
				if not use.to or slash_tgnum <= use.to:length() then
					return
				end
			end
		end
		for _, target in ipairs(canSlashTargets) do
			if use.to and canAppendTarget(target) then
				use.to:append(target)
			end
			if not use.to or slash_tgnum <= use.to:length() then
				return
			end
		end
	end

	if self.player:hasSkills("kuanggu|kuanggu_xh") and self:hasCrossbowEffect() and #canSlashTargets > 0 then
		for _, target in ipairs(canSlashTargets) do
			if self.player:distanceTo(target) < 2 then--狂骨先选距离1的目标，残血回复的情况？
				if use.to and canAppendTarget(target) then
					use.to:append(target)
				end
				if not use.to or slash_tgnum <= use.to:length() then
					return
				end
			end
		end
		for _, target in ipairs(canSlashTargets) do
			if use.to and canAppendTarget(target) then
				use.to:append(target)
			end
			if not use.to or slash_tgnum <= use.to:length() then
				return
			end
		end
	end

	for _, friend in ipairs(self.friends_noself) do
		if (not use.current_targets or not table.contains(use.current_targets, friend:objectName()))
			and not self:slashProhibit(card, friend) and not self:hasHeavySlashDamage(self.player, card, friend)
			and (self:needDamagedEffects(friend, self.player) or self:needToLoseHp(friend, self.player, true, true))
			and (self.player:canSlash(friend, card, not no_distance, rangefix)
				or (use.isDummy and self.predictedRange and self.player:distanceTo(friend, rangefix) <= self.predictedRange)) then
			use.card = card
			if use.to and canAppendTarget(friend) then use.to:append(friend) end
			if not use.to or slash_tgnum <= use.to:length() then
				return
			end
		end
	end
	if use.to and use.to:isEmpty() then
		use.card = nil
	end
end

sgs.ai_skill_use.slash = function(self, prompt)
	local parsedPrompt = prompt:split(":")
	local callback = sgs.ai_skill_cardask[parsedPrompt[1]] -- for askForUseSlashTo

	local ret = nil

	if type(callback) == "function" then
		local slash
		local target
		if self.player:hasFlag("slashTargetFixToOne")then
			--sgs.ai_skill_cardask["@wushuang-slash-1"] = function(self, data, pattern, target)
			--sgs.ai_skill_cardask["@tiaoxin-slash"] = function(self, data, pattern, target)
			--sgs.ai_skill_cardask["collateral-slash"] = function(self, data, pattern, target2, target, prompt)
			--sgs.ai_skill_cardask["@luanwu-slash"] = function(self)--唯一目标的乱武杀
			for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
				if player:hasFlag("SlashAssignee") then target = player break end
			end
			local target2 = nil
			if #parsedPrompt >= 3 then target2 = self.room:findPlayerbyobjectName(parsedPrompt[3]) end
			if not target then return "." end
			ret = callback(self, nil, nil, target, target2, prompt)
		else
			ret = callback(self, nil, nil, nil, nil, prompt)
		end
		if ret == nil or ret == "." then return "." end
		--唯一目标的乱武杀返回(use_card:toString()->target)
		slash = sgs.Card_Parse(ret)
		assert(slash)

		local characters = ret:split("->")
		local vitims = {}
		if #characters > 1 then vitims = characters[2]:split("+") end
		if #vitims == 0 then
			local no_distance = sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_DistanceLimit, self.player, slash) > 50 or self.player:hasFlag("slashNoDistanceLimit")
			local targets = {}
			local use = { to = sgs.SPlayerList() }
			if self.player:canSlash(target, slash, not no_distance) then use.to:append(target) else return "." end

			self:useCardSlash(slash, use)
			for _, p in sgs.qlist(use.to) do table.insert(targets, p:objectName()) end
			if table.contains(targets, target:objectName()) then ret = ret .. "->" .. table.concat(targets, "+") end
		end
	end
	local useslash, target
	local slashes = self:getCards("Slash")
	self:sortByUseValue(slashes)
	self:sort(self.enemies, "defenseSlash")
	for _, slash in ipairs(slashes) do
		local no_distance = sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_DistanceLimit, self.player, slash) > 50 or self.player:hasFlag("slashNoDistanceLimit")
		for _, friend in ipairs(self.friends_noself) do
			if not self:hasHeavySlashDamage(self.player, slash, friend)
				and self.player:canSlash(friend, slash, not no_distance) and not self:slashProhibit(slash, friend)
				and self:slashIsEffective(slash, friend)
				and (self:findLeijiTarget(friend, 50, self.player) or (friend:hasShownSkill("jieming") and self.player:hasSkill("rende")))
				and not (self.player:hasFlag("slashTargetFix") and not friend:hasFlag("SlashAssignee")) then

				useslash = slash
				target = friend
				break
			end
		end
	end
	if not useslash then
		for _, slash in ipairs(slashes) do
			local no_distance = sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_DistanceLimit, self.player, slash) > 50 or self.player:hasFlag("slashNoDistanceLimit") or self:hasWenjiBuff(slash)
			for _, enemy in ipairs(self.enemies) do
				if self.player:canSlash(enemy, slash, not no_distance) and not self:slashProhibit(slash, enemy)
					and self:slashIsEffective(slash, enemy) and sgs.isGoodTarget(enemy, self.enemies, self)
					and not (self.player:hasFlag("slashTargetFix") and not enemy:hasFlag("SlashAssignee")) then

					useslash = slash
					target = enemy
					break
				end
			end
		end
	end
	if useslash and target then
		local targets = {}
		local use = { to = sgs.SPlayerList() }
		use.to:append(target)

		self:useCardSlash(useslash, use)
		for _, p in sgs.qlist(use.to) do table.insert(targets, p:objectName()) end
		if table.contains(targets, target:objectName()) then return useslash:toString() .. "->" .. table.concat(targets, "+") end
	end
	return "."
end

sgs.ai_skill_playerchosen.slash_extra_targets = function(self, targets)
	local slash = sgs.cloneCard("slash")
	targets = sgs.QList2Table(targets)
	self:sort(targets, "defenseSlash")
	--当前杀不一定有效,需要额外data(短兵,方天杀太平,藤甲等)
	for _, target in ipairs(targets) do
		if self:isEnemy(target) and not self:slashProhibit(slash, target) and sgs.isGoodTarget(target, targets, self) and self:slashIsEffective(slash, target) then
			return target
		end
	end
	for _, target in ipairs(targets) do
		if self:isFriend(target) and self:slashIsEffective(slash, target) and (self:needToLoseHp(target, self.player, true, true)
			or self:needDamagedEffects(target, self.player, true) or self:needLeiji(target, self.player)) then
			return target
		end
	end
	return nil
end

sgs.ai_skill_playerchosen.zero_card_as_slash = function(self, targets)
	local slash = sgs.cloneCard("slash")
	local targetlist = sgs.QList2Table(targets)
	local arrBestHp, canAvoidSlash, forbidden = {}, {}, {}
	self:sort(targetlist, "defenseSlash")

	for _, target in ipairs(targetlist) do
		if self:isEnemy(target) and not self:slashProhibit(slash ,target) and sgs.isGoodTarget(target, targetlist, self) then
			if self:slashIsEffective(slash, target) then
				if self:needDamagedEffects(target, self.player, true) or self:needLeiji(target, self.player) then
					table.insert(forbidden, target)
				elseif self:needToLoseHp(target, self.player, true, true) then
					table.insert(arrBestHp, target)
				else
					return target
				end
			else
				table.insert(canAvoidSlash, target)
			end
		end
	end
	for i=#targetlist, 1, -1 do
		local target = targetlist[i]
		if not self:slashProhibit(slash, target) then
			if self:slashIsEffective(slash, target) then
				if self:isFriend(target) and (self:needToLoseHp(target, self.player, true, true)
					or self:needDamagedEffects(target, self.player, true) or self:needLeiji(target, self.player)) then
						return target
				end
			else
				table.insert(canAvoidSlash, target)
			end
		end
	end

	if #canAvoidSlash > 0 then return canAvoidSlash[1] end
	if #arrBestHp > 0 then return arrBestHp[1] end

	self:sort(targetlist, "defenseSlash", true)
	for _, target in ipairs(targetlist) do
		if target:objectName() ~= self.player:objectName() and not self:isFriend(target) and not table.contains(forbidden, target) then
			return target
		end
	end

	return targetlist[1]
end

sgs.ai_card_intention.Slash = function(self, card, from, tos)
	for _, to in ipairs(tos) do
		local value = 80
		sgs.updateIntention(from, to, value)
	end
end

sgs.ai_skill_cardask["slash-jink"] = function(self, data, pattern, target)
	local isdummy = type(data) == "number"
	local function getJink()
		local cards = self:getCards("Jink")
		self:sortByKeepValue(cards)
		for _, card in ipairs(cards) do
			if self.room:isJinkEffected(self.player, card) then return card:toString() end
		end
		return not isdummy and "."
	end
	if self:isFriend(self.player, target) and target:hasSkill("zhiman") and not self.player:hasSkill("leiji") then return "." end
	local slash
	--被杀出闪,杀的data类型为QVariant
	--global_room:writeToConsole(type(data))
	if type(data) == "QVariant" or type(data) == "userdata" then
		local effect = data:toSlashEffect()
		slash = effect.slash
	else
		slash = sgs.cloneCard("slash")
	end

	local cards = sgs.QList2Table(self.player:getHandcards())
	if self:findLeijiTarget(self.player, 50, target) then return getJink() end--火杀太平要术
	if not self:slashIsEffective(slash, self.player, target) then return "." end
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end
	if not target then return getJink() end
	if not self:hasHeavySlashDamage(target, slash, self.player) and self:needDamagedEffects(self.player, target, slash) then return "." end
	if slash:isKindOf("NatureSlash") and self.player:isChained() and self:isGoodChainTarget(self.player, target, nil, nil, slash) then return "." end
	if self:isFriend(target) then
		if self:findLeijiTarget(self.player, 50, target) then return getJink() end
		if target:hasShownSkill("jieyin") and not self.player:isWounded() and self.player:isMale() and not self.player:hasSkill("leiji") then return "." end
		if target:hasShownSkill("rende") and self.player:hasSkill("jieming") then return "." end
		--队友的三尖刀
		if target:hasWeapon("Triblade") and target:getHandcardNum() >= 2 then
			local Triblade_targets = sgs.SPlayerList()
			for _, enemy in ipairs(self.enemies) do
				if self.player:distanceTo(enemy) == 1 and self:canAttack(enemy,target) then Triblade_targets:append(enemy) end
			end
			if not Triblade_targets:isEmpty() then return "." end
		end
	else
		if self:hasHeavySlashDamage(target, slash) then return getJink() end
		if self.player:hasSkill("jijiu") and self:getCardsNum("Peach") > 0 and self.player:getHp() <= 1
			and self.player:hasSkills(sgs.masochism_skill) and not (target:hasWeapon("IceSword") or target:hasShownSkills("chuanxin|lieren")) then return "." end	
		if self.player:getHandcardNum() == 1 and self:needKongcheng() then return getJink() end
		if not self:hasLoseHandcardEffective() and not self.player:isKongcheng() then return getJink() end
		--[[if target:hasShownSkill("mengjin") then
			if self:doNotDiscard(self.player, "he", true) then return getJink() end
			if self.player:getCardCount(true) == 1 and not self.player:getArmor() then return getJink() end
			if self.player:hasSkills("jijiu|qingnang") and self.player:getCardCount(true) > 1 then return "." end
			if (self:getCardsNum("Peach") > 0 or (self:getCardsNum("Analeptic") > 0 and self:isWeak()))
				and not self.player:hasSkill("tuntian") and not self:willSkipPlayPhase() then
				return "."
			end
		end]]
		if target:hasWeapon("Axe") then
			if target:hasShownSkills(sgs.lose_equip_skill) and target:getEquips():length() > 1 and target:getCardCount(true) > 2 then return not isdummy and "." end
			if target:getHandcardNum() - target:getHp() > 2 and not self:isWeak() and self:getOverflow() <= 0 then return not isdummy and "." end
		end
	end
	return getJink()
end

sgs.dynamic_value.damage_card.Slash = true

sgs.ai_use_value.Slash = 4.5
sgs.ai_keep_value.Slash = 3.6
sgs.ai_use_priority.Slash = 2.6

function SmartAI:canHit(to, from, conservative)
	from = from or self.room:getCurrent()
	to = to or self.player
	local jink = sgs.cloneCard("jink")
	if to:isCardLimited(jink, sgs.Card_MethodUse) then return true end
	--[[
	if from:hasShownSkill("xiaoni") then 
		local cant_response = false
		local friends = self:getFriendsNoself(from)
		self:sort(friends, "handcard")
		for _, friend in ipairs(friends) do
			if not from:isFriendWith(friend) then continue end
			if friend:getHandcardNum() > from:getHandcardNum() then 
				cant_response = false
				break
			else cant_response = true end
		end
		return cant_response
	end
	--]]
	if from:hasFlag("cblongnu") then return true end
	
	if not self:isFriend(to, from) then
		if self:canLiegong(to, from) then return true end
		if from:hasWeapon("Axe") and from:getCardCount(true) > 2 then return true end
		if from:hasShownSkill("jianchu") and to:hasEquip() then return true end
		--[[
		if from:hasShownSkill("mengjin") and not self:hasHeavySlashDamage(from, nil, to) and not self:needLeiji(to, from) then
			if self:doNotDiscard(to, "he", true) then
			elseif to:getCardCount(true) == 1 and not to:getArmor() then
			elseif self:willSkipPlayPhase() then
			elseif (getCardsNum("Peach", to, from) > 0 or getCardsNum("Analeptic", to, from) > 0) then return true
			elseif not self:isWeak(to) and to:getArmor() and not self:needToThrowArmor() then return true
			elseif not self:isWeak(to) and to:getDefensiveHorse() then return true
			end
		end
		]]--技能修改
	end

	local hasHeart, hasRed, hasBlack, hasNotHand
	if to:objectName() == self.player:objectName() then
		for _, card in ipairs(self:getCards("Jink")) do
			if card:getSuit() == sgs.Card_Heart then hasHeart = true end
			if card:isRed() then hasRed = true end
			if card:isBlack() then hasBlack = true end
			if self.room:getCardPlace(card:getEffectiveId()) ~= sgs.Player_PlaceHand then hasNotHand = true end
		end
	end
	if to:getMark("##qianxi+no_suit_red") > 0 and not hasBlack then return true end
	if to:getMark("##qianxi+no_suit_black") > 0 and not hasRed then return true end
	if to:getMark("##boyan") > 0 and not hasNotHand then return true end
	if not conservative and self:hasHeavySlashDamage(from, nil, to) then conservative = true end
	if not conservative and self:hasEightDiagramEffect(to) and not IgnoreArmor(from, to) then return false end
	local need_double_jink = from and from:hasShownSkill("wushuang")
	if to:objectName() == self.player:objectName() then
		if self:getCardsNum("Jink") == 0 then return true end--别用getCardsNum("Jink", to, from),from未必知道你没有闪,但是你自己知道
		if need_double_jink and getCardsNum("Jink", to, from) < 2 then return true end
	end
	if getCardsNum("Jink", to, from) == 0 then return true end
	if need_double_jink and getCardsNum("Jink", to, from) < 2 then return true end
	return false
end

function SmartAI:useCardPeach(card, use)
	if not self.player:canRecover() then return end

	local mustusepeach = false
	local peaches = 0
	local cards = sgs.QList2Table(self.player:getHandcards())

	for _, c in ipairs(cards) do
		if isCard("Peach", c, self.player) then peaches = peaches + 1 end
	end

	if self.player:hasSkill("rende") and self:findFriendsByType(sgs.Friend_Draw) then return end

	if not use.isDummy then
		if self.player:hasArmorEffect("SilverLion") then
		for _, card in sgs.qlist(self.player:getHandcards()) do
			if card:isKindOf("Armor") and self:evaluateArmor(card) > 0 then
				use.card = card
				return
			end
		end
		end

		local SilverLion, OtherArmor
		for _, card in sgs.qlist(self.player:getHandcards()) do
			if card:isKindOf("SilverLion") then
				SilverLion = card
			elseif card:isKindOf("Armor") and not card:isKindOf("SilverLion") and self:evaluateArmor(card) > 0 then
				OtherArmor = true
			end
		end
		if SilverLion and OtherArmor then
			use.card = SilverLion
			return
		end
	end

	if self.player:getHandcardNum() < 3 then
		for _, enemy in ipairs(self.enemies) do
			if enemy:hasShownSkills(sgs.drawpeach_skill) or getCardsNum("Dismantlement", enemy, self.player) >= 1
				or enemy:hasShownSkill("jixi") and enemy:getPile("field"):length() >0 and enemy:distanceTo(self.player) == 1
				or enemy:hasShownSkill("qixi") and getKnownCard(enemy, self.player, "black", nil, "he") >= 1
				or getCardsNum("Snatch", enemy, self.player) >= 1 and enemy:distanceTo(self.player) == 1
				or (enemy:hasShownSkills("tiaoxin|baolie") and (self.player:inMyAttackRange(enemy) and self:getCardsNum("Slash") < 1 or not self.player:canSlash(enemy)))
				or enemy:hasShownSkill("chuli")--旋略怎么考虑呢？
			then
				mustusepeach = true
				break
			end
		end
	end

	local maxCards = self:getOverflow(self.player, true)
	local overflow = self:getOverflow() > 0
	if self.player:hasSkill("buqu") and self.player:getHp() < 1 and maxCards == 0 then
		use.card = card
		return
	end
	if not mustusepeach and not overflow then
		local lvlingqi = sgs.findPlayerByShownSkillName("shenwei")
		if lvlingqi and lvlingqi:isAlive() and self.player:isFriendWith(lvlingqi) 
			and self.player:getHp() <= lvlingqi:getHp() and self.player:getHp() + 1 > lvlingqi:getHp() then
			return
		elseif self.player:hasSkill("hunshang") then
			return
		elseif self.player:hasShownSkill("shangshi") and self.player:getMaxHp() > 2 and self:findFriendsByType(sgs.Friend_Draw) 
			and self.player:getHp() + 1 < self.player:getMaxHp() then
			return
		elseif self.player:hasSkill("yinghun_sunjian") and self.player:getHp() + 1 < self.player:getMaxHp() then
			return
		end
	end

	if mustusepeach or peaches > maxCards or self.player:getHp() == 1 then
		use.card = card
		return
	end

	if not overflow and #self.friends_noself > 0 then
		return
	end

	local useJieyinCard
	if self.player:hasSkill("jieyin") and not self.player:hasUsed("JieyinCard") and overflow and self.player:getPhase() == sgs.Player_Play then
		self:sort(self.friends, "hp")
		for _, friend in ipairs(self.friends) do
			if friend:isWounded() and friend:isMale() then useJieyinCard = true end
		end
	end
--(吃桃避免弃牌,为主留桃或做主自己吃,保持受伤状态)优先级调整为(保持受伤状态,为主留桃或做主自己吃,吃桃避免弃牌)即优先考虑留桃
	if self:needToLoseHp(self.player, nil, nil, nil, true) then return end
	
	local lord = self.player:getLord()
	if lord and lord:getHp() <= 2 and self:isWeak(lord) then
		if self.player:isLord() then use.card = card end
		return
	end

	if overflow then
		self:sortByKeepValue(cards)
		local handcardNum = self.player:getHandcardNum() - (useJieyinCard and 2 or 0)
		local discardNum = handcardNum - maxCards
		if discardNum > 0 then
			for i, c in ipairs(cards) do
				if c:getEffectiveId() == card:getEffectiveId() then
					use.card = card
					return
				end
				if i >= discardNum then break end
			end
		end
	end

	self:sort(self.friends, "hp")
	if self.friends[1]:objectName() == self.player:objectName() or self.player:getHp() < 2 then
		use.card = card
		return
	end

	if #self.friends > 1 and ((not HasBuquEffect(self.friends[2]) and self.friends[2]:getHp() < 3 and self:getOverflow() < 2)
								or (not HasBuquEffect(self.friends[1]) and self.friends[1]:getHp() < 2 and peaches <= 1 and self:getOverflow() < 3)) then
		return
	end

	use.card = card
end

sgs.ai_card_intention.Peach = function(self, card, from, tos)
	for _, to in ipairs(tos) do
		sgs.updateIntention(from, to, -120)
	end
end

sgs.ai_use_value.Peach = 7
sgs.ai_keep_value.Peach = 7
sgs.ai_use_priority.Peach = 0.9

sgs.ai_use_value.Jink = 8.9
sgs.ai_keep_value.Jink = 5.2

sgs.dynamic_value.benefit.Peach = true

sgs.ai_keep_value.Weapon = 2.05
sgs.ai_keep_value.Armor = 2.06
sgs.ai_keep_value.Treasure = 2.08
sgs.ai_keep_value.Horse = 2.04

sgs.weapon_range.Weapon = 1
sgs.weapon_range.Crossbow = 1
sgs.weapon_range.DoubleSword = 2
sgs.weapon_range.QinggangSword = 2
sgs.weapon_range.IceSword = 2
sgs.weapon_range.GudingBlade = 2
sgs.weapon_range.Axe = 3
sgs.weapon_range.Blade = 3
sgs.weapon_range.Spear = 3
sgs.weapon_range.Halberd = 4
sgs.weapon_range.KylinBow = 5
sgs.weapon_range.SixSwords = 2
sgs.weapon_range.DragonPhoenix = 2
sgs.weapon_range.Triblade = 3

--[[SmartAI:evaluateWeapon里单独有连弩的
function sgs.ai_slash_weaponfilter.Crossbow(self, to, player)
	return player:distanceTo(to) <= math.max(sgs.weapon_range.Crossbow, player:getAttackRange())
		and sgs.card_lack[to:objectName()]["Jink"] == 1 or getCardsNum("Jink", to, self.player) == 0
end

function sgs.ai_weapon_value.Crossbow(self, enemy, player)
	if player:hasShownSkill("paoxiao") then return 0 end
	if player:getActualGeneral1():getKingdom() == "careerist" then return 6 end
	local v = 0.5
	v = v + getCardsNum("Slash", player)*0.5
	return v
end
]]

sgs.ai_skill_invoke.DoubleSword = function(self, data)
	return not self:needKongcheng(self.player, true)
end

function sgs.ai_slash_weaponfilter.DoubleSword(self, to, player)
	return player:distanceTo(to) <= math.max(sgs.weapon_range.DoubleSword, player:getAttackRange()) and player:getGender() ~= to:getGender()
end

function sgs.ai_weapon_value.DoubleSword(self, enemy, player)
	if enemy and enemy:isMale() ~= player:isMale() then return 4 end
end

function SmartAI:getExpectedJinkNum(use)
	local jink_list = use.from:getTag("Jink_" .. use.card:toString()):toStringList()
	local index, jink_num = 1, 1
	for _, p in sgs.qlist(use.to) do
		if p:objectName() == self.player:objectName() then
			local n = tonumber(jink_list[index])
			if n == 0 then return 0
			elseif n > jink_num then jink_num = n end
		end
		index = index + 1
	end
	return jink_num
end

sgs.ai_skill_cardask["double-sword-card"] = function(self, data, pattern, target)
	if self.player:isKongcheng() then return "." end
	local use = data:toCardUse()
	local jink_num = self:getExpectedJinkNum(use)
	if jink_num > 1 and self:getCardsNum("Jink") == jink_num then return "." end

	if self:needKongcheng(self.player, true) and self.player:getHandcardNum() <= 2 then
		if self.player:getHandcardNum() == 1 then
			local card = self.player:getHandcards():first()
			return (jink_num > 0 and isCard("Jink", card, self.player)) and "." or ("$" .. card:getEffectiveId())
		end
		if self.player:getHandcardNum() == 2 then
			local first = self.player:getHandcards():first()
			local last = self.player:getHandcards():last()
			local jink = isCard("Jink", first, self.player) and first or (isCard("Jink", last, self.player) and last)
			if jink then
				return first:getEffectiveId() == jink:getEffectiveId() and ("$"..last:getEffectiveId()) or ("$"..first:getEffectiveId())
			end
		end
	end
	if target and self:isFriend(target) then return "." end
	if target and self:needKongcheng(target, true) then return "." end
	local cards = self.player:getHandcards()
	for _, card in sgs.qlist(cards) do
		if (card:isKindOf("Slash") and self:getCardsNum("Slash") > 1)
			or (card:isKindOf("Jink") and self:getCardsNum("Jink") > 2)
			or card:isKindOf("Disaster")
			or (card:isKindOf("EquipCard") and not self.player:hasSkills(sgs.lose_equip_skill))
			or (not self.player:hasSkill("jizhi") and (card:isKindOf("Collateral") or card:isKindOf("GodSalvation")
			or card:isKindOf("FireAttack") or card:isKindOf("IronChain") or card:isKindOf("AmazingGrace"))) then
			return "$" .. card:getEffectiveId()
		end
	end
	return "."
end

function sgs.ai_weapon_value.QinggangSword(self, enemy)
	if enemy and enemy:getArmor() and enemy:hasArmorEffect(enemy:getArmor():objectName()) then return 3 end
end

function sgs.ai_slash_weaponfilter.QinggangSword(self, enemy, player)
	if player:distanceTo(enemy) > math.max(sgs.weapon_range.QinggangSword, player:getAttackRange()) then return end
	if enemy:getArmor() and enemy:hasArmorEffect(enemy:getArmor():objectName())
		and (sgs.card_lack[enemy:objectName()]["Jink"] == 1 or getCardsNum("Jink", enemy, self.player) < 1) then
		return true
	end
end

sgs.ai_skill_invoke.IceSword = function(self, data)
	local damage = data:toDamage()
	local target = damage.to
	if self:isFriend(target) then
		if self:needDamagedEffects(target, self.players, true) or self:needToLoseHp(target, self.player, true) then return false
		elseif target:isChained() and self:isGoodChainTarget(target, self.player, nil, nil, damage.card) then return false
		elseif self:isWeak(target) or damage.damage > 1 then return true
		elseif target:getLostHp() < 1 then return false end
		return true
	else
		if target:hasShownSkill("tianxiang") and self.player:getMark("GlobalBattleRoyalMode") > 0 and self:cantbeHurt(target) then return true end
		if target:hasArmorEffect("PeaceSpell") and damage.nature ~= sgs.DamageStruct_Normal then return true end
		if self:isWeak(target) then return false end
		if damage.damage > 1 or self:hasHeavySlashDamage(self.player, damage.card, target) then return false end
		if target:hasShownSkill("lirang") and #self:getFriendsNoself(target) > 0 then return false end
		if target:getArmor() and self:evaluateArmor(target:getArmor(), target) > 3 and not (target:hasArmorEffect("SilverLion") and target:isWounded()) then return true end
		if self.player:hasSkill("tieqi") or self:canLiegong(target, self.player) then return false end
		if target:hasShownSkill("tuntian") and target:getPhase() == sgs.Player_NotActive then return false end
		if target:hasShownSkills(sgs.need_kongcheng) then return false end
		if target:getCardCount(true)<4 and target:getCardCount(true)>1 then return true end
		return false
	end
end

function sgs.ai_slash_weaponfilter.IceSword(self, to, player)
	return player:distanceTo(to) <= math.max(sgs.weapon_range.IceSword, player:getAttackRange())
		and to:hasShownSkill("tianxiang") and player:getMark("GlobalBattleRoyalMode") > 0
end

function sgs.ai_weapon_value.IceSword(self, enemy, player)
	if enemy and player:getMark("GlobalBattleRoyalMode") > 0 and enemy:hasShownSkill("tianxiang") then return 10 end
end

function sgs.ai_slash_weaponfilter.GudingBlade(self, to)
	return to:isKongcheng() and not to:hasArmorEffect("SilverLion")
end

function sgs.ai_weapon_value.GudingBlade(self, enemy)
	if not enemy then return end
	local value = 2
	if enemy:getHandcardNum() < 1 and not enemy:hasArmorEffect("SilverLion") then value = 4 end
	return value
end

function SmartAI:needToThrowAll(player)
	player = player or self.player
	if player:getPhase() == sgs.Player_NotActive or player:getPhase() == sgs.Player_Finish then return false end
	local erzhang = sgs.findPlayerByShownSkillName("guzheng")
	if erzhang and self:isFriend(erzhang, player) then return false end

	self.yongsi_discard = nil
	local index = 0

	local kingdom_num = 0
	local kingdoms = {}
	for _, ap in sgs.qlist(self.room:getAlivePlayers()) do
		if not kingdoms[ap:getKingdom()] then
			kingdoms[ap:getKingdom()] = true
			kingdom_num = kingdom_num + 1
		end
	end

	local cards = self.player:getCards("he")
	local Discards = {}
	for _, card in sgs.qlist(cards) do
		local shouldDiscard = true
		if card:isKindOf("Axe") then shouldDiscard = false end
		if isCard("Peach", card, player) or isCard("Slash", card, player) then
			local dummy_use = { isDummy = true }
			self:useBasicCard(card, dummy_use)
			if dummy_use.card then shouldDiscard = false end
		end
		if card:getTypeId() == sgs.Card_TypeTrick then
			local dummy_use = { isDummy = true }
			self:useTrickCard(card, dummy_use)
			if dummy_use.card then shouldDiscard = false end
		end
		if shouldDiscard then
			if #Discards < 2 then table.insert(Discards, card:getId()) end
			index = index + 1
		end
	end

	if #Discards == 2 and index < kingdom_num then
		self.yongsi_discard = Discards
		return true
	end
	return false
end

sgs.ai_skill_cardask["@Axe"] = function(self, data, pattern, target)
	if target and self:isFriend(target) then return "." end
	local effect = data:toSlashEffect()
	local allcards = self.player:getCards("he")
	allcards = sgs.QList2Table(allcards)
	if self:hasHeavySlashDamage(self.player, effect.slash, target)
	  or (#allcards - 3 >= self.player:getHp())
	  or (self.player:hasSkills("kuanggu|kuanggu_xh") and self.player:isWounded() and self.player:distanceTo(effect.to) == 1)
	  or (effect.to:getHp() == 1 and not effect.to:hasShownSkill("buqu"))
	  or (self:needKongcheng() and self.player:getHandcardNum() > 0)
	  or (self.player:hasSkills(sgs.lose_equip_skill) and self.player:getEquips():length() > 1 and self.player:getHandcardNum() < 2)
	then

		local hcards = {}
		for _, c in sgs.qlist(self.player:getHandcards()) do
			if not (isCard("Slash", c, self.player) and self:hasCrossbowEffect())
				and (not isCard("Peach", c, self.player) or target:getHp() == 1 and self:isWeak(target)) then
				table.insert(hcards, c)
			end
		end
		if self.player:getPhase() <= sgs.Player_Play then
			self:sortByUseValue(hcards, true)
		else
			self:sortByKeepValue(hcards)
		end
		local cards = {}
		local hand, armor, def, off = false, false, false, false
		if self:needToThrowArmor() then
			table.insert(cards, self.player:getArmor():getEffectiveId())
			armor = true
		end
		if (self.player:hasSkills(sgs.need_kongcheng) or not self:hasLoseHandcardEffective()) and self.player:getHandcardNum() > 0 then
			hand = true
			for _, card in ipairs(hcards) do
				table.insert(cards, card:getEffectiveId())
				if #cards == 2 then break end
			end
		end
		if #cards < 2 and self.player:hasSkills(sgs.lose_equip_skill) then
			if #cards < 2 and self.player:getOffensiveHorse() then
				off = true
				table.insert(cards, self.player:getOffensiveHorse():getEffectiveId())
			end
			if #cards < 2 and self.player:getDefensiveHorse() then
				def = true
				table.insert(cards, self.player:getDefensiveHorse():getEffectiveId())
			end
			if #cards < 2 and not armor and self.player:getArmor() then
				armor = true
				table.insert(cards, self.player:getArmor():getEffectiveId())
			end
		end

		if #cards < 2 and not hand  and self.player:getHandcardNum() > 2 then
			hand = true
			for _, card in ipairs(hcards) do
				table.insert(cards, card:getEffectiveId())
				if #cards == 2 then break end
			end
		end

		if #cards < 2 and not off and self.player:getOffensiveHorse() then
			off = true
			table.insert(cards, self.player:getOffensiveHorse():getEffectiveId())
		end
		if #cards < 2 and not hand and self.player:getHandcardNum() > 0 then
			hand = true
			for _, card in ipairs(hcards) do
				table.insert(cards, card:getEffectiveId())
				if #cards == 2 then break end
			end
		end
		if #cards < 2 and not armor and self.player:getArmor() then
			armor = true
			table.insert(cards, self.player:getArmor():getEffectiveId())
		end
		if #cards < 2 and not def and self.player:getDefensiveHorse() then
			def = true
			table.insert(cards, self.player:getDefensiveHorse():getEffectiveId())
		end

		if #cards == 2 then
			local num = 0
			for _, id in ipairs(cards) do
				if self.player:hasEquip(sgs.Sanguosha:getCard(id)) then num = num + 1 end
			end
			local eff = self:damageIsEffective(effect.to, effect.nature, self.player)
			if not eff then return "." end
			return "$" .. table.concat(cards, "+")
		end
	end
end

function sgs.ai_slash_weaponfilter.Axe(self, to, player)
	return player:distanceTo(to) <= math.max(sgs.weapon_range.Axe, player:getAttackRange()) and self:getOverflow(player) > 0
end

function sgs.ai_weapon_value.Axe(self, enemy, player)
	if player:hasShownSkills("luoyi|suzhi") and not player:hasShownSkills(sgs.force_slash_skill) then return 6 end
	if enemy and player:getMark("GlobalBattleRoyalMode") > 0 then return 3 end
	local v = 1
	if getCardsNum("Analeptic", player) > 0 then
		v = v + 1
	end
	if player:getPhase() == sgs.Player_Play then
		if player:hasShownSkill("fengshix") and player:getHandcardNum() > 3
		and player:getHandcardNum() > enemy:getHandcardNum() then
			v = v + 1
		end
	end
	if enemy and not player:hasShownSkills(sgs.force_slash_skill) then
		if self:getOverflow(player) > 0 then
			v = v + 1
		end
		if enemy:getHp() < 3  then
			v = v + 3 - enemy:getHp()
		end
	end
	return v
end

function sgs.ai_cardsview.Spear(self, class_name, player, cards)
	if class_name == "Slash" then
		if not cards then
			cards = {}
			for _, c in sgs.qlist(player:getHandcards()) do
				if sgs.cardIsVisible(c, player, self.player) and c:isKindOf("Slash") then
				else
					table.insert(cards, c)
				end
			end
			for _, id in sgs.qlist(player:getHandPile()) do
				local c = sgs.Sanguosha:getCard(id)
				if sgs.cardIsVisible(c, player, self.player) and c:isKindOf("Slash") then
				else
					table.insert(cards, c)
				end
			end
		end
		if #cards < 2 then return {} end

		sgs.ais[player:objectName()]:sortByKeepValue(cards)

		local newcards = {}
		for _, card in ipairs(cards) do
			if not self.room:getCardOwner(card:getEffectiveId())
				or self.room:getCardOwner(card:getEffectiveId()):objectName() ~= player:objectName()
				or self.room:getCardPlace(card:getEffectiveId()) ~= sgs.Player_PlaceHand then continue end
			if not isCard("Peach", card, player) and not (isCard("ExNihilo", card, player) and player:getPhase() == sgs.Player_Play) then
				table.insert(newcards, card)
			end
		end
		if #newcards < 2 then return {} end

		local card_str = {}
		for i = 1, #newcards, 2 do
			if i + 1 > #newcards then break end
			local id1 = newcards[i]:getEffectiveId()
			local id2 = newcards[i + 1]:getEffectiveId()
			local str = ("slash:%s[%s:%s]=%d+%d&"):format("Spear", "to_be_decided", 0, id1, id2)
			table.insert(card_str , str)
		end
		return card_str
	end
end

local function turnUse_spear(self, inclusive, skill_name)
	if self.player:hasSkills("wusheng|wusheng_xh") then
		local cards = self.player:getCards("he")
		cards = sgs.QList2Table(cards)
		for _, id in sgs.qlist(self.player:getHandPile()) do
			table.insert(cards, sgs.Sanguosha:getCard(id))
		end
		for _, acard in ipairs(cards) do
			if isCard("Slash", acard, self.player) then return end
		end
	end

	local cards = self.player:getCards("h")
	cards = sgs.QList2Table(cards)
	self:sortByUseValue(cards)
	local newcards = {}
	for _, card in ipairs(cards) do
		if not isCard("Slash", card, self.player) and not isCard("Peach", card, self.player) and not isCard("AllianceFeast", card, self.player)
		and not ((isCard("ExNihilo", card, self.player) or isCard("BefriendAttacking", card, self.player)) and self.player:getPhase() == sgs.Player_Play)
		and not ((isCard("ThreatenEmperor", card, self.player)) and card:isAvailable(self.player)) then
			table.insert(newcards, card)
		end
	end
	if #cards <= self.player:getHp() - 1 and self.player:getHp() <= 4 and not self:hasHeavySlashDamage(self.player)
		and not self.player:hasSkills("kongcheng|paoxiao") then return end
	if #newcards < 2 then return end

	local card_id1 = newcards[1]:getEffectiveId()
	local card_id2 = newcards[2]:getEffectiveId()

	if newcards[1]:isBlack() and newcards[2]:isBlack() then
		local black_slash = sgs.cloneCard("slash", sgs.Card_NoSuitBlack)
		local nosuit_slash = sgs.cloneCard("slash")

		self:sort(self.enemies, "defenseSlash")
		for _, enemy in ipairs(self.enemies) do
			if self.player:canSlash(enemy) and not self:slashProhibit(nosuit_slash, enemy) and self:slashIsEffective(nosuit_slash, enemy)
				and self:canAttack(enemy) and self:slashProhibit(black_slash, enemy) and self:isWeak(enemy) then
				local redcards, blackcards = {}, {}
				for _, acard in ipairs(newcards) do
					if acard:isBlack() then table.insert(blackcards, acard) else table.insert(redcards, acard) end
				end
				if #redcards == 0 then break end

				local redcard, othercard

				self:sortByUseValue(blackcards, true)
				self:sortByUseValue(redcards, true)
				redcard = redcards[1]

				othercard = #blackcards > 0 and blackcards[1] or redcards[2]
				if redcard and othercard then
					card_id1 = redcard:getEffectiveId()
					card_id2 = othercard:getEffectiveId()
					break
				end
			end
		end
	end

	local card_str = ("slash:%s[%s:%s]=%d+%d&%s"):format(skill_name, "to_be_decided", 0, card_id1, card_id2, skill_name)
	local slash = sgs.Card_Parse(card_str)
	assert(slash)
	return slash
end

local Spear_skill = {}
Spear_skill.name = "Spear"
table.insert(sgs.ai_skills, Spear_skill)
Spear_skill.getTurnUseCard = function(self, inclusive)
	return turnUse_spear(self, inclusive, "Spear")
end

function sgs.ai_weapon_value.Spear(self, enemy, player)
	if player:hasShownSkills("paoxiao|paoxiao_xh|xiongnve|kuangcai") or (player:hasShownSkill("baolie") and player:getHp() < 3) then
		return math.min(2, player:getHandcardNum() /2)
	end
	if enemy and getCardsNum("Slash", player, self.player) == 0 then
		if self:getOverflow(player) > 0 then return 2
		elseif player:getHandcardNum() > 2 then return 1
		end
	end
	return 0
end

function sgs.ai_slash_weaponfilter.Fan(self, to, player)
	return player:distanceTo(to) <= math.max(sgs.weapon_range.Fan, player:getAttackRange())
		and (sgs.card_lack[to:objectName()]["Jink"] == 1 or getCardsNum("Jink", to, self.player) < 1)
		and to:hasArmorEffect("Vine")
end

sgs.ai_skill_invoke.KylinBow = function(self, data)
	local damage = data:toDamage()
	if damage.from:hasShownSkill("kuangfu") and damage.to:getCards("e"):length() == 1 then return false end
	if damage.to:hasShownSkills(sgs.lose_equip_skill) then
		return self:isFriend(damage.to)
	end
	return self:isEnemy(damage.to)
end

function sgs.ai_slash_weaponfilter.KylinBow(self, to, player)
	return player:distanceTo(to) <= math.max(sgs.weapon_range.KylinBow, player:getAttackRange())
		and (sgs.card_lack[to:objectName()]["Jink"] == 1 or getCardsNum("Jink", to, self.player) < 1)
		and (to:getDefensiveHorse() or to:getOffensiveHorse())
end

function sgs.ai_weapon_value.KylinBow(self, enemy,player)
	--if player:hasShownSkills("liegong|liegong_xh") then return 3.5 end
	if enemy and (enemy:getOffensiveHorse() or enemy:getDefensiveHorse()) then return 1.5 end
end

sgs.ai_skill_invoke.EightDiagram = function(self, data)
	local jink = sgs.cloneCard("jink")
	if self:needDamagedEffects(self.player, nil, true) or self:needToLoseHp(self.player, nil, true, true) then return false end
	--先考虑天妒八卦再考虑闪无效
	if self.player:hasSkill("tiandu") then
		if self.player:hasSkill("yiji") and not self:isWeak() and self:findFriendsByType(sgs.Friend_Draw, self.player) then
			return false
		else return true end
	end
	if not self.room:isJinkEffected(self.player, jink) then return false end
	if self:getCardsNum("Jink") == 0 then return true end
	local zhangjiao = sgs.findPlayerByShownSkillName("guidao")
	if zhangjiao and self:isEnemy(zhangjiao) then
		if getKnownCard(zhangjiao, self.player, "black", false, "he") > 1 then return false end
		if self:getCardsNum("Jink") > 1 and getKnownCard(zhangjiao, self.player, "black", false, "he") > 0 then return false end
		if zhangjiao:getHandcardNum() - getKnownNum(zhangjiao, self.player) >= 3 then return false end
	end
	return true
end

function sgs.ai_armor_value.EightDiagram(player, self)
	if player:hasShownSkill("bazhen") then return 0 end
	local haswizard = self:hasKnownSkills(sgs.wizard_harm_skill, self:getEnemies(player))
	if haswizard then
		return 2
	end
	if player:hasShownSkills("tiandu|leiji|zhuwei") then
		return 6
	end
	for _, p in sgs.qlist(self.room:getOtherPlayers(player)) do
		if p:hasShownSkill("luanji") then
			return 4.1
		end
	end
	return 4
end

function sgs.ai_armor_value.RenwangShield(player, self)
	if player:hasShownSkill("bazhen") then return 0 end
	if player:hasShownSkill("jiang") then return 6 end
	if player:hasShownSkill("leiji") and getKnownCard(player, self.player, "Jink", true) > 1 and player:hasShownSkill("guidao")
		and getKnownCard(player, self.player, "black", false, "he") > 0 then
			return 0
	end
	return 4
end

function sgs.ai_armor_value.SilverLion(player, self)
	if self:hasWizard(self:getEnemies(player), true) then
		for _, p in sgs.qlist(self.room:getAlivePlayers()) do
			if p:containsTrick("lightning") then return 5 end
		end
	end
	if self.player:objectName() == player:objectName() and self.player:isWounded() and not self.player:getArmor() then return 9 end
	if self.player:objectName() == player:objectName() and self.player:isWounded() and self:getCardsNum("Armor", "h") >= 2 and not self.player:hasArmorEffect("SilverLion") then return 8 end
	if player:hasShownSkill("shicai") then return 5 end
	if player:hasShownSkill("gongqing") then
		for _, enemy in ipairs(self:getEnemies(player)) do
			if enemy:getAttackRange() > 3 then
				return 3.5
			end
		end
	end
	return 1
end


sgs.ai_use_priority.Blade = 2.688
sgs.ai_use_priority.IceSword = 2.685
-- sgs.ai_use_priority.Fan = 2.68
sgs.ai_use_priority.KylinBow = 2.675
--sgs.ai_use_priority.Triblade = 2.673
sgs.ai_use_priority.DoubleSword = 2.67
sgs.ai_use_priority.GudingBlade = 2.665
sgs.ai_use_priority.Spear = 2.66
sgs.ai_use_priority.QinggangSword = 2.655
sgs.ai_use_priority.Halberd = 2.65
sgs.ai_use_priority.Axe = 2.645
sgs.ai_use_priority.Crossbow = 2.63

sgs.ai_use_priority.SilverLion = 1.0
-- sgs.ai_use_priority.Vine = 0.95
-- sgs.ai_use_priority.Breastplate = 0.9
sgs.ai_use_priority.RenwangShield = 0.85
--sgs.ai_use_priority.IronArmor = 0.82
sgs.ai_use_priority.EightDiagram = 0.8

sgs.ai_use_priority.DefensiveHorse = 2.75
sgs.ai_use_priority.OffensiveHorse = 2.72

function SmartAI:useCardArcheryAttack(card, use)
	if self:getAoeValue(card) > 0 then
		use.card = card
	end
end

function SmartAI:useCardSavageAssault(card, use)
	if self:getAoeValue(card) > 0 then
		use.card = card
	end
end

sgs.dynamic_value.damage_card.ArcheryAttack = true
sgs.dynamic_value.damage_card.SavageAssault = true

sgs.ai_use_value.ArcheryAttack = 3.8
sgs.ai_use_priority.ArcheryAttack = 3.5
sgs.ai_keep_value.ArcheryAttack = 3.35
sgs.ai_use_value.SavageAssault = 3.9
sgs.ai_use_priority.SavageAssault = 3.5
sgs.ai_keep_value.SavageAssault = 3.34

sgs.ai_nullification.ArcheryAttack = function(self, card, from, to, positive, keep)
	local targets = sgs.SPlayerList()
	local players = self.room:getTag("targets" .. card:toString()):toList()
	for _, q in sgs.qlist(players) do
		targets:append(q:toPlayer())
	end

	if positive then
		if self:isFriend(to) then
			if keep then
				for _, p in sgs.qlist(targets) do
					if self:isFriend(p) and self:aoeIsEffective(card, p, from)
						and not self:hasEightDiagramEffect(p) and self:needDamagedEffects(p, from) and self:isWeak(p)
						and getKnownCard(p, self.player, "Jink", true, "he") == 0 then
						keep = false
					end
				end
			end
			if keep then return false end

			local heg_null_card = self:getCard("HegNullification") or (self.room:getTag("NullifyingTimes"):toInt() > 0 and self.room:getTag("NullificatonType"):toBool())
			if heg_null_card and self:aoeIsEffective(card, to, from) then
				targets:removeOne(to)
				for _, p in sgs.qlist(targets) do
					if to:isFriendWith(p) and self:aoeIsEffective(card, p, from) then return true, false end
				end
			end

			if not self:isFriendWith(to) and not self:isWeak(to) then
				return
			elseif not self:aoeIsEffective(card, to, from) then
				return
			elseif self:needDamagedEffects(to, from) then
				return
			elseif to:objectName() == self.player:objectName() and self:canAvoidAOE(card) then
				return
			elseif (getKnownCard(to, self.player, "Jink", true, "he") >= 1 or self:hasEightDiagramEffect(to)) and to:getHp() > 1 then
				return
			elseif not self.player:isFriendWith(to) and self:playerGetRound(to) < self:playerGetRound(self.player) and self:isWeak() then
				return
			else
				return true, true
			end
		end
	else
		if not self:isFriend(from) or not(self:isEnemy(to) and from:isFriendWith(to)) then return false end
		if keep then
			for _, p in sgs.qlist(targets) do
				if self:isEnemy(p) and self:aoeIsEffective(card, p, from)
					and not self:hasEightDiagramEffect(p) and self:needDamagedEffects(p, from) and self:isWeak(p)
					and getKnownCard(p, self.player, "Jink", true, "he") == 0 then
					keep = false
				end
			end
		end
		if keep or not self:isEnemy(to) then return false end
		local nulltype = self.room:getTag("NullificatonType"):toBool()
		if nulltype then
			targets:removeOne(to)
			local num = 0
			local weak
			for _, p in sgs.qlist(targets) do
				if to:isFriendWith(p) and self:aoeIsEffective(card, p, from) then
					num = num + 1
				end
				if self:isWeak(to) or self:isWeak(p) then
					weak = true
				end
			end
			return num > 1 or weak, true
		else
			if self:isWeak(to) then return true, true end
		end
	end
	return
end

sgs.ai_nullification.SavageAssault = function(self, card, from, to, positive, keep)
	local targets = sgs.SPlayerList()
	local players = self.room:getTag("targets" .. card:toString()):toList()
	for _, q in sgs.qlist(players) do
		targets:append(q:toPlayer())
	end
	local menghuo = sgs.findPlayerByShownSkillName("huoshou")
	if positive then
		if self:isFriend(to) then
			local zhurong = sgs.findPlayerByShownSkillName("juxiang")
			if menghuo then targets:removeOne(menghuo) end
			if zhurong then targets:removeOne(zhurong) end

			if keep then
				for _, p in sgs.qlist(targets) do
					if self:isFriend(p) and self:aoeIsEffective(card, p, menghuo or from)
						and self:needDamagedEffects(p, menghuo or from) and self:isWeak(p)
						and getKnownCard(p, self.player, "Slash", true, "he") == 0 then
						keep = false
					end
				end
			end
			if keep then return false end

			local heg_null_card = self:getCard("HegNullification") or (self.room:getTag("NullifyingTimes"):toInt() > 0 and self.room:getTag("NullificatonType"):toBool())
			if heg_null_card and self:aoeIsEffective(card, to, menghuo or from) then
				targets:removeOne(to)
				for _, p in sgs.qlist(targets) do
					if to:isFriendWith(p) and self:aoeIsEffective(card, p, menghuo or from) then return true, false end
				end
			end

			if not self:isFriendWith(to) and not self:isWeak(to) then
				return
			elseif not self:aoeIsEffective(card, to, menghuo or from) then
				return
			elseif self:needDamagedEffects(to, menghuo or from) then
				return
			elseif to:objectName() == self.player:objectName() and self:canAvoidAOE(card) then
				return
			elseif getKnownCard(to, self.player, "Slash", true, "he") >= 1 and to:getHp() > 1 then
				return
			elseif not self.player:isFriendWith(to) and self:playerGetRound(to) < self:playerGetRound(self.player) and self:isWeak() then
				return
			else
				return true, true
			end
		end
	else
		if not self:isFriend(from) or not(self:isEnemy(to) and from:isFriendWith(to)) then return false end
		if keep then
			for _, p in sgs.qlist(targets) do
				if self:isEnemy(p) and self:aoeIsEffective(card, p, menghuo or from)
					and self:needDamagedEffects(p, menghuo or from) and self:isWeak(p)
					and getKnownCard(p, self.player, "Slash", true, "he") == 0 then
					keep = false
				end
			end
		end
		if keep or not self:isEnemy(to) then return false end
		local nulltype = self.room:getTag("NullificatonType"):toBool()
		if nulltype then
			targets:removeOne(to)
			local num = 0
			local weak
			for _, p in sgs.qlist(targets) do
				if to:isFriendWith(p) and self:aoeIsEffective(card, p, menghuo or from) then
					num = num + 1
				end
				if self:isWeak(to) or self:isWeak(p) then
					weak = true
				end
			end
			return num > 1 or weak, true
		else
			if self:isWeak(to) then return true, true end
		end
	end
	return
end

sgs.ai_skill_cardask.aoe = function(self, data, pattern, target, name)
	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end
	local aoe
	if type(data) == "QVariant" or type(data) == "userdata" then aoe = data:toCardEffect().card else aoe = sgs.cloneCard(name) end
	assert(aoe ~= nil)
	local menghuo = sgs.findPlayerByShownSkillName("huoshou")
	local attacker = target
	if aoe:isKindOf("ArcheryAttack") then
		if not self.player:hasSkill("leiji") and self:isFriend(self.player, target) and target:hasSkill("zhiman") then return "." end
	elseif aoe:isKindOf("SavageAssault") then
		if not menghuo and self:isFriend(self.player, target) and target:hasSkill("zhiman") then return "." end
		if menghuo and menghuo:hasShownSkill("zhiman") and self:isFriend(self.player, menghuo) then return "." end
	end
	if menghuo and aoe:isKindOf("SavageAssault") then attacker = menghuo end

	if not self:damageIsEffective(nil, nil, attacker) then return "." end
	if self:needDamagedEffects(self.player, attacker) or self:needToLoseHp(self.player, attacker) then return "." end

	if (self.player:hasSkill("jianxiong") or (self.player:hasSkill("qiuan") and self.player:getPile("letter"):isEmpty()))--新增孟达
	and (self.player:getHp() > 1 or self:getAllPeachNum() > 0)
	and not self:willSkipPlayPhase() then
		if not self:needKongcheng(self.player, true) and self:getAoeValue(aoe) > 0 then
			return "."
		end
		if sgs.ai_AOE_data then
			local damagecard = sgs.ai_AOE_data:toCardUse().card
--[[
			if damagecard:getSkillName() == "qice" and damagecard:subcardsLength() > 2 then
				self.get_AOE_subcard = true
				return "."
			end
			if damagecard:getSkillName() == "luanji" then
				self.get_AOE_subcard = true
				return "."
			end
]]
			if damagecard:subcardsLength() > 0 then
				local usevalue, keepvalue = 0,0
				for _, id in sgs.qlist(damagecard:getSubcards()) do
					local card = sgs.Sanguosha:getCard(id)
					if isCard("Peach", card, self.player) then
						self.get_AOE_subcard = true
						return "."
					end
					usevalue = self:getUseValue(card) + usevalue
				end
				if usevalue > sgs.ai_use_value.Slash * 2 then
					self.get_AOE_subcard = true
					return "."
				end
			end
		end
	end
end

sgs.ai_skill_cardask["savage-assault-slash"] = function(self, data, pattern, target)
	return sgs.ai_skill_cardask.aoe(self, data, pattern, target, "savage_assault")
end

sgs.ai_skill_cardask["archery-attack-jink"] = function(self, data, pattern, target)
	return sgs.ai_skill_cardask.aoe(self, data, pattern, target, "archery_attack")
end

sgs.ai_keep_value.Nullification = 3.8
sgs.ai_use_value.Nullification = 5.5

function SmartAI:useCardAmazingGrace(card, use)
	local value = 1
	if not self:trickIsEffective(card, self.player, self.player) then value = 0 end--防止灭吴帷幕黑五谷
	local suf, coeff = 0.8, 0.8
	local xuyou = sgs.findPlayerByShownSkillName("chenglve")
	local aoedraw = xuyou and self.player:isFriendWith(xuyou)
	if (self:needKongcheng() and self.player:getHandcardNum() == 1) or self.player:hasSkill("jizhi") or aoedraw then
		suf = 0.6
		coeff = 0.6
	end
	for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		local index = 0
		if self:trickIsEffective(card, player, self.player) then
			if self:isFriend(player) then index = 1 elseif self:isEnemy(player) then index = -1 end
		end
		value = value + index * suf
		if value < 0 then return end
		suf = suf * coeff
	end
	use.card = card
end

sgs.ai_use_value.AmazingGrace = 2
sgs.ai_keep_value.AmazingGrace = -1
sgs.ai_use_priority.AmazingGrace = 1.2
sgs.dynamic_value.benefit.AmazingGrace = true

function SmartAI:willUseGodSalvation(card)
	if not card then self.room:writeToConsole(debug.traceback()) return false end
	local good, bad = 0, 0
	local wounded_friend = 0
	local wounded_enemy = 0

	local noresponse = false
	local noresponselist = card:getTag("NoResponse"):toStringList()--新增卡牌无法响应
	if noresponselist and table.contains(noresponselist,"_ALL_PLAYERS") then
		noresponse = true
	end

	local xuyou = sgs.findPlayerByShownSkillName("chenglve")
	local aoedraw = xuyou and self.player:isFriendWith(xuyou)
	if self.player:hasSkill("jizhi") or aoedraw then good = good + 6 end
	if (self.player:hasSkill("kongcheng") and self.player:getHandcardNum() == 1) or not self:hasLoseHandcardEffective() then good = good + 5 end

	for _, friend in ipairs(self.friends) do
		if noresponselist and table.contains(noresponselist,friend:objectName()) then
			noresponse = true
		end
		if not noresponse then
			good = good + 10 * getCardsNum("Nullification", friend, self.player)
		end
		if self:trickIsEffective(card, friend, self.player) then
			if friend:canRecover() then
				wounded_friend = wounded_friend + 1
				good = good + 10
				if friend:isLord() then good = good + 10 / math.max(friend:getHp(), 1) end
				if friend:hasShownSkills(sgs.masochism_skill) then
					good = good + 5
				end
				if friend:getHp() <= 1 and self:isWeak(friend) then
					good = good + 5
					if friend:isLord() then good = good + 10 end
				else
					if friend:isLord() then good = good + 5 end
				end
				if self:needToLoseHp(friend, nil, nil, true, true) then good = good - 3 end
			end
		end
	end

	for _, enemy in ipairs(self.enemies) do
		if noresponselist and table.contains(noresponselist,enemy:objectName()) then
			noresponse = true
		end
		if not noresponse then
			bad = bad + 10 * getCardsNum("Nullification", enemy, self.player)
		end
		if self:trickIsEffective(card, enemy, self.player) then
			if enemy:canRecover() then
				wounded_enemy = wounded_enemy + 1
				bad = bad + 10
				if enemy:isLord() then
					bad = bad + 10 / math.max(enemy:getHp(), 1)
				end
				if enemy:hasShownSkills(sgs.masochism_skill) then
					bad = bad + 5
				end
				if enemy:getHp() <= 1 and self:isWeak(enemy) then
					bad = bad + 5
					if enemy:isLord() then bad = bad + 10 end
				else
					if enemy:isLord() then bad = bad + 5 end
				end
				if self:needToLoseHp(enemy, nil, nil, true, true) then bad = bad - 3 end
			end
		end
	end
	return good - bad > 5 and wounded_friend > 0
end

function SmartAI:useCardGodSalvation(card, use)
	if self:willUseGodSalvation(card) then
		use.card = card
	end
end

sgs.ai_use_value.GodSalvation = 2
sgs.ai_use_priority.GodSalvation = 1.1
sgs.ai_keep_value.GodSalvation = 3.30
sgs.dynamic_value.benefit.GodSalvation = true
sgs.ai_card_intention.GodSalvation = function(self, card, from, tos)
	local can, first
	for _, to in ipairs(tos) do
		if to:isWounded() and not first then
			first = to
			can = true
		elseif first and to:isWounded() and not self:isFriend(first, to) then
			can = false
			break
		end
	end
	if can then
		sgs.updateIntention(from, first, -10)
	end
end

function SmartAI:useCardDuel(duel, use)

	local enemies = self:exclude(self.enemies, duel)
	local friends = self:exclude(self.friends_noself, duel)
	duel:setFlags("AI_Using")
	local n1 = self:getCardsNum("Slash")
	
	duel:setFlags("-AI_Using")
	if self.player:hasSkills("wushuang|wushuang_lvlingqi") then n1 = n1 * 2 end
	local huatuo = sgs.findPlayerByShownSkillName("jijiu")
	local targets = {}

	local canUseDuelTo=function(target)
		return self:trickIsEffective(duel, target) and self:damageIsEffective(target,sgs.DamageStruct_Normal)
	end

	for _, friend in ipairs(friends) do
		if not canUseDuelTo(friend) then continue end
		if friend:hasSkill("jieming") and self.player:hasSkill("rende") and (huatuo and self:isFriend(huatuo)) then
			table.insert(targets, friend)
		end
		if self.player:hasSkill("zhiman") and (self.player:canGetCard(friend, "j") or ((friend:hasShownSkills(sgs.lose_equip_skill) or self:needToThrowArmor(friend)) and self.player:canGetCard(friend, "e"))) then
			table.insert(targets, friend)
		end
	end

	for _, enemy in ipairs(enemies) do
		if self.player:hasFlag("duelTo_" .. enemy:objectName()) and canUseDuelTo(enemy) then
			table.insert(targets, enemy)
		end
	end

	local cmp = function(a, b)
		local v1 = getCardsNum("Slash", a, self.player) + a:getHp()
		local v2 = getCardsNum("Slash", b, self.player) + b:getHp()

		if self:needDamagedEffects(a, self.player) then v1 = v1 + 20 end
		if self:needDamagedEffects(b, self.player) then v2 = v2 + 20 end

		if not self:isWeak(a) and a:hasSkill("jianxiong") then v1 = v1 + 10 end
		if not self:isWeak(b) and b:hasSkill("jianxiong") then v2 = v2 + 10 end

		if self:needToLoseHp(a) then v1 = v1 + 5 end
		if self:needToLoseHp(b) then v2 = v2 + 5 end

		if a:hasShownSkills(sgs.masochism_skill) then v1 = v1 + 5 end
		if b:hasShownSkills(sgs.masochism_skill) then v2 = v2 + 5 end

		if not self:isWeak(a) and a:hasSkill("jiang") then v1 = v1 + 5 end
		if not self:isWeak(b) and b:hasSkill("jiang") then v2 = v2 + 5 end

		if v1 == v2 then return sgs.getDefenseSlash(a, self) < sgs.getDefenseSlash(b, self) end

		return v1 < v2
	end

	table.sort(enemies, cmp)

	local noresponse = false
	local noresponselist = duel:getTag("NoResponse"):toStringList()--新增卡牌无法响应
	if noresponselist and table.contains(noresponselist,"_ALL_PLAYERS") then
		noresponse = true
	end

	for _, enemy in ipairs(enemies) do
		local useduel
		local n2 = getCardsNum("Slash", enemy, self.player)--ai经常对明天兵决斗？
		if enemy:hasSkills("wushuang|wushuang_lvlingqi") then n2 = n2 * 2 end
		if sgs.card_lack[enemy:objectName()]["Slash"] == 1 then n2 = 0 end
		if noresponselist and table.contains(noresponselist,enemy:objectName()) then
			noresponse = true
		end
		useduel = n1 >= n2 or self:needToLoseHp(self.player, nil, nil, true) or noresponse
					or self:needDamagedEffects(self.player, enemy) or (n2 < 1 and sgs.isGoodHp(self.player, self.player))
					or ((self.player:hasSkill("jianxiong") or self.player:hasFlag("shuangxiong")) and sgs.isGoodHp(self.player, self.player)
						and n1 + self.player:getHp() >= n2 and self:isWeak(enemy))

		if self:objectiveLevel(enemy) > 3 and canUseDuelTo(enemy) and not self:cantbeHurt(enemy) and useduel and sgs.isGoodTarget(enemy, enemies, self) then
			if not table.contains(targets, enemy) then table.insert(targets, enemy) end
		end
	end

	if #targets > 0 then

		local godsalvation = self:getCard("GodSalvation")
		if godsalvation and godsalvation:getId() ~= duel:getId() and self:willUseGodSalvation(godsalvation) then
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

		local targets_num = 1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_ExtraTarget, self.player, duel)
		if use.isDummy and use.xiechan then targets_num = 100 end
		local enemySlash = 0
		local setFlag = false

		use.card = duel

		for i = 1, #targets, 1 do
			local n2 = getCardsNum("Slash", targets[i], self.player)
			if sgs.card_lack[targets[i]:objectName()]["Slash"] == 1 then n2 = 0 end
			if self:isEnemy(targets[i]) then enemySlash = enemySlash + n2 end

			if use.to then
				if i == 1 then
					use.to:append(targets[i])
				end
				if not setFlag and self.player:getPhase() == sgs.Player_Play and self:isEnemy(targets[i]) then
					self.player:setFlags("duelTo" .. targets[i]:objectName())
					setFlag = true
				end
				if use.to:length() == targets_num then return end
			end
		end
	end

end

sgs.ai_card_intention.Duel = function(self, card, from, tos)
	if string.find(card:getSkillName(), "lijian") then return end
	sgs.updateIntentions(from, tos, 80)
end

sgs.ai_use_value.Duel = 3.7
sgs.ai_use_priority.Duel = 2.9
sgs.ai_keep_value.Duel = 3.42

sgs.dynamic_value.damage_card.Duel = true

sgs.ai_skill_cardask["duel-slash"] = function(self, data, pattern, target)
	if self:isFriend(self.player, target) and target:hasSkill("zhiman") then return "." end
	if self.player:getPhase()==sgs.Player_Play then return self:getCardId("Slash") end

	if sgs.ai_skill_cardask.nullfilter(self, data, pattern, target) then return "." end

	if self:cantbeHurt(target) then return "." end

	if self:isFriend(target) and target:hasSkill("rende") and self.player:hasSkill("jieming") then return "." end
	if self:isEnemy(target) and not self:isWeak() and self:needDamagedEffects(self.player, target) then return "." end

	if self:isFriend(target) then
		if self:needDamagedEffects(self.player, target) or self:needToLoseHp(self.player, target) then return "." end
		if self:needDamagedEffects(target, self.player) or self:needToLoseHp(target, self.player) then
			return self:getCardId("Slash")
		else
			return "."
		end
	end

	local saveforcaopi = false
	local caopi = sgs.findPlayerByShownSkillName("xingshang")
	if caopi and self:isFriend(caopi) then
		saveforcaopi = true
	end

	if (not self:isFriend(target) and self:getCardsNum("Slash") >= getCardsNum("Slash", target, self.player))
	or (self:isWeak() and self:getAllPeachNum() < 1 and (not saveforcaopi and self.player:getHp() == 1)
		and (not self:isFriendWith(target) or (target:getHp() >= 2 and self.player:getHp() == 1))) then
		return self:getCardId("Slash")
	else return "." end

end

function SmartAI:useCardExNihilo(card, use)
	use.card = card
end

sgs.ai_card_intention.ExNihilo = -80

sgs.ai_keep_value.ExNihilo = 3.88
sgs.ai_use_value.ExNihilo = 8.9
sgs.ai_use_priority.ExNihilo = 9.3

sgs.dynamic_value.benefit.ExNihilo = true

function SmartAI:getDangerousCard(who)
	local weapon = who:getWeapon()
	local armor = who:getArmor()
	local treasure = who:getTreasure()
--有优先顺序
	if weapon and (weapon:isKindOf("Crossbow") or weapon:isKindOf("GudingBlade")) and self:isEnemy(who) then
		for _, friend in ipairs(self.friends) do
			if weapon:isKindOf("Crossbow") and who:distanceTo(friend) <= 1 and getCardsNum("Slash", who, self.player) > 0 then
				return weapon:getEffectiveId()
			end
			if weapon:isKindOf("GudingBlade") and who:inMyAttackRange(friend) and friend:isKongcheng() and not friend:hasShownSkill("kongcheng") and getCardsNum("Slash", who) > 0 then
				return weapon:getEffectiveId()
			end
		end
	end
	if weapon and weapon:isKindOf("Axe") and who:hasShownSkills("luoyi|suzhi") then
		return weapon:getEffectiveId()
	end

	if treasure and treasure:isKindOf("JadeSeal") then
		return treasure:getEffectiveId()
	end
	if treasure and treasure:isKindOf("LuminousPearl") and who:hasShownSkills(sgs.lose_equip_skill .. "|zhiheng|lirang") then
		return treasure:getEffectiveId()
	end
	if treasure and treasure:isKindOf("WoodenOx") and who:getPile("wooden_ox"):length() > 1 then
		return treasure:getEffectiveId()
	end

	if weapon and weapon:isKindOf("Halberd") and who:hasShownSkills(sgs.force_slash_skill .. "|paoxiao|paoxiao_xh|baolie|xiongnve|kuangcai") then
		return weapon:getEffectiveId()
	end
	if weapon and weapon:isKindOf("Spear") and who:hasShownSkills("paoxiao|paoxiao_xh|baolie|xiongnve|kuangcai") and who:getHandcardNum() >= 1 then
		return weapon:getEffectiveId()
	end
	if weapon and weapon:isKindOf("DragonPhoenix") and who:hasShownSkills("paoxiao|paoxiao_xh|baolie|suzhi|xiongnve|kuangcai") then
		return weapon:getEffectiveId()
	end

	if armor and armor:isKindOf("EightDiagram") and who:hasShownSkills(sgs.wizard_skill) then
		return armor:getEffectiveId()
	end
	if armor and armor:isKindOf("RenwangShield") and who:hasShownSkill("jiang") then
		return armor:getEffectiveId()
	end
	if armor and armor:isKindOf("PeaceSpell") and self.player:getPlayerNumWithSameKingdom("AI", who:getKingdom()) > 2
	and not sgs.findPlayerByShownSkillName("wendao") then
		return armor:getEffectiveId()
	end

	--[[if weapon and who:hasShownSkill("liegong") and sgs.weapon_range[weapon:getClassName()] >= 3 then
		return weapon:getEffectiveId()
	end]]

	if weapon and self:isEnemy(who) then
		for _, friend in ipairs(self.friends) do
			if who:distanceTo(friend) < who:getAttackRange(false) and self:isWeak(friend) and not self:doNotDiscard(who, "e", true) then return weapon:getEffectiveId() end
		end
	end
end

function SmartAI:getValuableCard(who)
	local weapon = who:getWeapon()
	local armor = who:getArmor()
	local offhorse = who:getOffensiveHorse()
	local defhorse = who:getDefensiveHorse()
	local treasure = who:getTreasure()
	self:sort(self.friends, "hp")
	local friend
	if #self.friends > 0 then friend = self.friends[1] end
	if friend and self:isWeak(friend) and who:distanceTo(friend) <= who:getAttackRange(false) and not self:doNotDiscard(who, "e", true) then
		if weapon and (who:distanceTo(friend) > 1) then
			return weapon:getEffectiveId()
		end
		if offhorse and who:distanceTo(friend) > 1 then
			return offhorse:getEffectiveId()
		end
	end

	if treasure and not self:doNotDiscard(who, "e") then
		return treasure:getEffectiveId()
	end

	if defhorse and not self:doNotDiscard(who, "e")
		and not (self.player:hasWeapon("KylinBow") and self.player:canSlash(who) and self:slashIsEffective(sgs.cloneCard("slash"), who, self.player)
				and (getCardsNum("Jink", who, self.player) < 1 or sgs.card_lack[who:objectName()].Jink == 1 )) then
		return defhorse:getEffectiveId()
	end

	if armor and self:evaluateArmor(armor, who) > 3  and not self:needToThrowArmor(who)  and not self:doNotDiscard(who, "e")
	and (not armor:isKindOf("PeaceSpell") or not sgs.findPlayerByShownSkillName("wendao")) then
		return armor:getEffectiveId()
	end

	if offhorse and who:hasShownSkills("kuanggu|duanbing|qianxi") then
		return offhorse:getEffectiveId()
	end

	local equips = sgs.QList2Table(who:getEquips())
	for _,equip in ipairs(equips) do
		if who:hasShownSkill("guose") and equip:getSuit() == sgs.Card_Diamond then  return equip:getEffectiveId() end
		if who:hasShownSkills("qixi|duanliang|guidao") and equip:isBlack() then  return equip:getEffectiveId() end
		if who:hasShownSkills("wusheng|jijiu") and equip:isRed() then  return equip:getEffectiveId() end
		if who:hasShownSkills(sgs.need_equip_skill) and not who:hasShownSkills(sgs.lose_equip_skill) then return equip:getEffectiveId() end
	end

	if armor and not self:needToThrowArmor(who) and not self:doNotDiscard(who, "e")
	and (not armor:isKindOf("PeaceSpell") or not sgs.findPlayerByShownSkillName("wendao")) then
		return armor:getEffectiveId()
	end

	if offhorse and who:getHandcardNum() > 1 then
		if not self:doNotDiscard(who, "e", true) then
			for _,f in ipairs(self.friends) do
				if who:distanceTo(f) == who:getAttackRange() and who:getAttackRange() > 1 then
					return offhorse:getEffectiveId()
				end
			end
		end
	end

	if weapon and who:getHandcardNum() > 1 then
		if not self:doNotDiscard(who, "e", true) then
			for _,f in ipairs(self.friends) do
				if (who:distanceTo(f) <= who:getAttackRange()) and (who:distanceTo(f) > 1) then
					return weapon:getEffectiveId()
				end
			end
		end
	end
end

function SmartAI:useCardSnatchOrDismantlement(card, use)
	local isJixi = card:getSkillName() == "jixi"
	local name = card:objectName()
	local players = self.room:getOtherPlayers(self.player)
	local tricks
	local usecard = false

	local targets = {}
	local targets_num = (1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_ExtraTarget, self.player, card))

	--孙权、吴景取消装备移动判断；使用拆时有顺，先拆第二重要的卡未完成
	local canOperate = function(target, card_id)--注意card_id为字符串的重载
		local wujing = sgs.findPlayerByShownSkillName("fengyang")
		if wujing and wujing:inFormationRalation(target) and not self.player:isFriendWith(target)
		and ((type(card_id) == "number" and self.room:getCardPlace(card_id) == sgs.Player_PlaceEquip) or
			(type(card_id) == "string" and card_id == "e")) then
			return false
		end
		if card:isKindOf("Snatch") then
			if target:hasSkill("jubao") and type(card_id) == "number"
			and target:getTreasure() and target:getTreasure():getEffectiveId() == card_id then
				return false
			end
			return self.player:canGetCard(target, card_id)
		else
			return self.player:canDiscard(target, card_id)
		end
	end

	local addTarget = function(player, cardid)
		if not table.contains(targets, player:objectName())
			and (not use.current_targets or not table.contains(use.current_targets, player:objectName())) then
			if not usecard then
				use.card = card
				usecard = true
			end
			table.insert(targets, player:objectName())
			if usecard and use.to and use.to:length() < targets_num then
				use.to:append(player)
				if not use.isDummy then
					sgs.Sanguosha:getCard(cardid):setFlags("AIGlobal_SDCardChosen_" .. name)
				end
			end
			if #targets == targets_num then return true end
		end
	end

	players = self:exclude(players, card)
	for _, player in ipairs(players) do
		if not player:getJudgingArea():isEmpty() and self:trickIsEffective(card, player)
			and ((player:containsTrick("lightning") and self:getFinalRetrial(player) == 2) or #self.enemies == 0) then
			tricks = player:getCards("j")
			for _, trick in sgs.qlist(tricks) do
				if trick:isKindOf("Lightning") and canOperate(player, trick:getId()) then
					local invoke
					for _, p in ipairs(self.friends) do
						if self:trickIsEffective(trick, p) then
							invoke = true
							break
						end
					end
					if not invoke then continue end
					if addTarget(player, trick:getEffectiveId()) then return end
				end
			end
		end
	end

	local enemies = {}
	if #self.enemies == 0 and self:getOverflow() > 0 then
		enemies = self:exclude(enemies, card)
		self:sort(enemies, "defense", true)
		local temp = {}
		for _, enemy in ipairs(enemies) do
			if self:trickIsEffective(card, enemy) then
				table.insert(temp, enemy)
			end
		end
		enemies = temp
	else
		enemies = self:exclude(self.enemies, card)
		self:sort(enemies, "defense")
		local temp = {}
		for _, enemy in ipairs(enemies) do
			if self:trickIsEffective(card, enemy) then
				table.insert(temp, enemy)
			end
		end
		enemies = temp
	end

	if self:slashIsAvailable() then
		local dummyuse = { isDummy = true, to = sgs.SPlayerList() }
		self:useCardSlash(sgs.cloneCard("slash"), dummyuse)
		if not dummyuse.to:isEmpty() then
			local tos = self:exclude(dummyuse.to, card)
			for _, to in ipairs(tos) do
				if to:getHandcardNum() == 1 and to:getHp() <= 2 and self:hasLoseHandcardEffective(to) and not to:hasSkill("kongcheng")
					and (not self:hasEightDiagramEffect(to) or IgnoreArmor(self.player, to)) then
					if addTarget(to, to:getRandomHandCardId()) then return end
				end
			end
		end
	end

	for _, enemy in ipairs(enemies) do
		if not enemy:isNude() then
			local dangerous = self:getDangerousCard(enemy)
			if dangerous and canOperate(enemy, dangerous) then
				if addTarget(enemy, dangerous) then return end
			end
		end
	end

	self:sort(self.friends_noself, "defense")
	local friends = self:exclude(self.friends_noself, card)
	for _, friend in ipairs(friends) do
		if (friend:containsTrick("indulgence") or friend:containsTrick("supply_shortage")) then
			local cardchosen
			tricks = friend:getJudgingArea()
			for _, trick in sgs.qlist(tricks) do
				if trick:isKindOf("Indulgence") and canOperate(friend, trick:getId()) then
					if friend:getHp() <= friend:getHandcardNum() or friend:isLord() or name == "snatch" then
						cardchosen = trick:getEffectiveId()
						break
					end
				end
				if trick:isKindOf("SupplyShortage") and canOperate(friend, trick:getId()) then
					cardchosen = trick:getEffectiveId()
					break
				end
				if trick:isKindOf("Indulgence") and canOperate(friend, trick:getId()) then
					cardchosen = trick:getEffectiveId()
					break
				end
			end
			if cardchosen then
				if addTarget(friend, cardchosen) then return end
			end
		end
	end

	local hasLion, target
	for _, friend in ipairs(friends) do
		if self:needToThrowArmor(friend) and canOperate(friend, friend:getArmor():getEffectiveId()) then
			hasLion = true
			target = friend
		end
	end

	for _, enemy in ipairs(enemies) do
		if not enemy:isNude() then
			local valuable = self:getValuableCard(enemy)
			if valuable and canOperate(enemy, valuable) then
				if addTarget(enemy, valuable) then return end
			end
		end
	end

	for _, enemy in ipairs(enemies) do
		local cards = sgs.QList2Table(enemy:getHandcards())
		if #cards <= 2 and not enemy:isKongcheng() and not self:doNotDiscard(enemy, "h", true) then
			for _, cc in ipairs(cards) do
				if sgs.cardIsVisible(cc, enemy, self.player) and (cc:isKindOf("Peach") or cc:isKindOf("Analeptic")) then
					if addTarget(enemy, self:getCardRandomly(enemy, "h")) then return end
				end
			end
		end
	end

	for _, enemy in ipairs(enemies) do
		if not enemy:isNude() then
			if enemy:hasShownSkills("jijiu|jieyin") then
				local cardchosen
				local equips = { enemy:getDefensiveHorse(), enemy:getArmor(), enemy:getOffensiveHorse(), enemy:getWeapon(),enemy:getTreasure()}
				for _, equip in ipairs(equips) do
					if equip and (not enemy:hasSkill("jijiu") or equip:isRed()) and canOperate(enemy, equip:getEffectiveId()) then
						cardchosen = equip:getEffectiveId()
						break
					end
				end
				if not cardchosen and not enemy:isKongcheng() and enemy:getHandcardNum() < 3 and self:isWeak(enemy)
					and (not self:needKongcheng(enemy) and enemy:getHandcardNum() == 1)
					and canOperate(enemy, "h") then
					cardchosen = self:getCardRandomly(enemy, "h")
				end
				if not cardchosen and enemy:getDefensiveHorse() and canOperate(enemy, enemy:getDefensiveHorse():getEffectiveId()) then cardchosen = enemy:getDefensiveHorse():getEffectiveId() end
				if not cardchosen and enemy:getArmor() and not self:needToThrowArmor(enemy) and canOperate(enemy, enemy:getArmor():getEffectiveId()) then
					cardchosen = enemy:getArmor():getEffectiveId()
				end

				if cardchosen then
					if addTarget(enemy, cardchosen) then return end
				end
			end
		end
	end

	for _, enemy in ipairs(enemies) do
		if enemy:getArmor() and enemy:getArmor():isKindOf("EightDiagram") and not self:needToThrowArmor(enemy)
			and canOperate(enemy, enemy:getArmor():getEffectiveId()) then
			addTarget(enemy, enemy:getArmor():getEffectiveId())
		end
		if enemy:getTreasure() and (enemy:getPile("wooden_ox"):length() > 1 or enemy:hasTreasure("JadeSeal"))
			and canOperate(enemy, enemy:getTreasure():getEffectiveId()) then
			addTarget(enemy, enemy:getTreasure():getEffectiveId())
		end
	end

	for i = 1, 2 + (isJixi and 3 or 0), 1 do
		for _, enemy in ipairs(enemies) do
			if not enemy:isNude() and not (self:needKongcheng(enemy) and i <= 2) and not self:doNotDiscard(enemy) then
				if (enemy:getHandcardNum() == i and sgs.getDefenseSlash(enemy, self) < 6 + (isJixi and 6 or 0) and enemy:getHp() <= 3 + (isJixi and 2 or 0)) then
					local cardchosen
					if self.player:distanceTo(enemy) == self.player:getAttackRange() + 1 and enemy:getDefensiveHorse() and not self:doNotDiscard(enemy, "e")
						and canOperate(enemy, enemy:getDefensiveHorse():getEffectiveId()) then
						cardchosen = enemy:getDefensiveHorse():getEffectiveId()
					elseif enemy:getArmor() and not self:needToThrowArmor(enemy) and not self:doNotDiscard(enemy, "e")
						and (not enemy:getArmor():isKindOf("PeaceSpell") or not sgs.findPlayerByShownSkillName("wendao"))
						and canOperate(enemy, enemy:getArmor():getEffectiveId())then
						cardchosen = enemy:getArmor():getEffectiveId()
					elseif canOperate(enemy, "h") then
						cardchosen = self:getCardRandomly(enemy, "h")
					end
					if cardchosen then
						if addTarget(enemy, cardchosen) then return end
					end
				end
			end
		end
	end

	if hasLion and canOperate(target, target:getArmor():getEffectiveId()) then
		if addTarget(target, target:getArmor():getEffectiveId()) then return end
	end

	for _, enemy in ipairs(enemies) do
		if not enemy:isKongcheng() and not self:doNotDiscard(enemy, "h")
			and enemy:hasShownSkills(sgs.cardneed_skill) and canOperate(enemy, "h") then
			if addTarget(enemy, self:getCardRandomly(enemy, "h")) then return end
		end
	end

	for _, enemy in ipairs(enemies) do
		if enemy:hasEquip() and not self:doNotDiscard(enemy, "e") then
			local cardchosen
			if enemy:getDefensiveHorse() and canOperate(enemy, enemy:getDefensiveHorse():getEffectiveId()) then
				cardchosen = enemy:getDefensiveHorse():getEffectiveId()
			elseif enemy:getArmor() and not self:needToThrowArmor(enemy)
				and (not enemy:getArmor():isKindOf("PeaceSpell") or not sgs.findPlayerByShownSkillName("wendao"))
				and canOperate(enemy, enemy:getArmor():getEffectiveId()) then
				cardchosen = enemy:getArmor():getEffectiveId()
			elseif enemy:getOffensiveHorse() and canOperate(enemy, enemy:getOffensiveHorse():getEffectiveId()) then
				cardchosen = enemy:getOffensiveHorse():getEffectiveId()
			elseif enemy:getWeapon() and canOperate(enemy, enemy:getWeapon():getEffectiveId()) then
				cardchosen = enemy:getWeapon():getEffectiveId()
			end
			if cardchosen then
				if addTarget(enemy, cardchosen) then return end
			end
		end
	end

	if name == "snatch" or self:getOverflow() > 0 then
		for _, enemy in ipairs(enemies) do
			local equips = enemy:getEquips()
			if not enemy:isNude() and not self:doNotDiscard(enemy, "he") then
				local cardchosen
				if not equips:isEmpty() and not self:doNotDiscard(enemy, "e") then
					cardchosen = self:getCardRandomly(enemy, "e")
				else
					cardchosen = self:getCardRandomly(enemy, "h") end
				if cardchosen then
					if addTarget(enemy, cardchosen) then return end
				end
			end
		end
	end
end

SmartAI.useCardSnatch = SmartAI.useCardSnatchOrDismantlement

sgs.ai_use_value.Snatch = 9
sgs.ai_use_priority.Snatch = 4.3
sgs.ai_keep_value.Snatch = 3.46

sgs.dynamic_value.control_card.Snatch = true

SmartAI.useCardDismantlement = SmartAI.useCardSnatchOrDismantlement

sgs.ai_use_value.Dismantlement = 5.6
sgs.ai_use_priority.Dismantlement = 4.4
sgs.ai_keep_value.Dismantlement = 3.44

sgs.dynamic_value.control_card.Dismantlement = true

sgs.ai_choicemade_filter.cardChosen.snatch = function(self, player, promptlist)
	local from = self.room:findPlayerbyobjectName(promptlist[4])
	local to = self.room:findPlayerbyobjectName(promptlist[5])
	if from and to then
		local id = tonumber(promptlist[3])
		local place = self.room:getCardPlace(id)
		local card = sgs.Sanguosha:getCard(id)
		local intention = 70
		if place == sgs.Player_PlaceDelayedTrick then
			if not card:isKindOf("Disaster") then intention = -intention else intention = 0 end
		elseif place == sgs.Player_PlaceEquip then
			if card:isKindOf("Armor") and self:evaluateArmor(card, to) <= -2 then intention = 0 end
			if card:isKindOf("SilverLion") then
				if to:getLostHp() > 1 then
					if to:hasShownSkills(sgs.use_lion_skill) then
						intention = self:willSkipPlayPhase(to) and -intention or 0
					else
						intention = self:isWeak(to) and -intention or 0
					end
				else
					intention = 0
				end
			elseif to:hasShownSkills(sgs.lose_equip_skill) then
				if self:isWeak(to) and (card:isKindOf("DefensiveHorse") or card:isKindOf("Armor")) then
					intention = math.abs(intention)
				else
					intention = 0
				end
			end
		elseif place == sgs.Player_PlaceHand then
			if self:needKongcheng(to, true) and to:getHandcardNum() == 1 then
				intention = 0
			end
		end
		sgs.updateIntention(from, to, intention)
	end
end

sgs.ai_choicemade_filter.cardChosen.dismantlement = sgs.ai_choicemade_filter.cardChosen.snatch

function SmartAI:useCardCollateral(card, use)
	local fromList = sgs.QList2Table(self.room:getOtherPlayers(self.player))
	local toList = sgs.QList2Table(self.room:getAlivePlayers())

	local cmp = function(a, b)
		local alevel = self:objectiveLevel(a)
		local blevel = self:objectiveLevel(b)

		if alevel ~= blevel then return alevel > blevel end

		local anum = getCardsNum("Slash", a, self.player)
		local bnum = getCardsNum("Slash", b, self.player)

		if anum ~= bnum then return anum < bnum end
		return a:getHandcardNum() < b:getHandcardNum()
	end

	table.sort(fromList, cmp)
	self:sort(toList, "defense")

	local needCrossbow = false
	for _, enemy in ipairs(self.enemies) do
		if self.player:canSlash(enemy) and self:objectiveLevel(enemy) > 3
			and sgs.isGoodTarget(enemy, self.enemies, self) and not self:slashProhibit(nil, enemy) then
			needCrossbow = true
			break
		end
	end

	needCrossbow = needCrossbow and self:getCardsNum("Slash") > 2 and not self.player:hasSkills("paoxiao|kuangcai")

	if needCrossbow then
		for i = #fromList, 1, -1 do
			local friend = fromList[i]
			if friend:getWeapon() and friend:getWeapon():isKindOf("Crossbow") and self:trickIsEffective(card, friend) then
				for _, enemy in ipairs(toList) do
					if friend:canSlash(enemy, nil) and friend:objectName() ~= enemy:objectName() then
						if not use.isDummy then self.room:setPlayerFlag(self.player, "AI_needCrossbow") end
						use.card = card
						if use.to then use.to:append(friend) end
						if use.to then use.to:append(enemy) end
						return
					end
				end
			end
		end
	end

	local n = nil
	local final_enemy = nil
	for _, enemy in ipairs(fromList) do
		if self:trickIsEffective(card, enemy)
			and not enemy:hasShownSkills(sgs.lose_equip_skill)
			and not (enemy:hasSkill("weimu") and card:isBlack())
			and not enemy:hasSkill("tuntian")
			and self:objectiveLevel(enemy) >= 0
			and enemy:getWeapon() then

			for _, enemy2 in ipairs(toList) do
				if enemy:canSlash(enemy2) and self:objectiveLevel(enemy2) > 3 and enemy:objectName() ~= enemy2:objectName() then
					n = 1
					final_enemy = enemy2
					break
				end
			end

			if not n then
				for _, enemy2 in ipairs(toList) do
					if enemy:canSlash(enemy2) and self:objectiveLevel(enemy2) <=3 and self:objectiveLevel(enemy2) >=0 and enemy:objectName() ~= enemy2:objectName() then
						n = 1
						final_enemy = enemy2
						break
					end
				end
			end

			if not n then
				for _, friend in ipairs(toList) do
					if enemy:canSlash(friend) and self:objectiveLevel(friend) < 0 and enemy:objectName() ~= friend:objectName()
							and (self:needToLoseHp(friend, enemy, true, true) or self:needDamagedEffects(friend, enemy, true)) then
						n = 1
						final_enemy = friend
						break
					end
				end
			end

			if not n then
				for _, friend in ipairs(toList) do
					if enemy:canSlash(friend) and self:objectiveLevel(friend) < 0 and enemy:objectName() ~= friend:objectName()
							and (getKnownCard(friend, self.player, "Jink", true, "he") >= 2 or getCardsNum("Slash", enemy, self.player) < 1) then
						n = 1
						final_enemy = friend
						break
					end
				end
			end

			if n then
				use.card = card
				if use.to then use.to:append(enemy) end
				if use.to then use.to:append(final_enemy) end
				return
			end
		end
		n = nil
	end

	for _, friend in ipairs(fromList) do
		if friend:getWeapon() and (getKnownCard(friend, self.player, "Slash", true, "he") > 0 or getCardsNum("Slash", friend, self.player) > 1 and friend:getHandcardNum() >= 4)
			and self:trickIsEffective(card, friend)
			and self:objectiveLevel(friend) < 0 then

			for _, enemy in ipairs(toList) do
				if friend:canSlash(enemy, nil) and self:objectiveLevel(enemy) > 3 and friend:objectName() ~= enemy:objectName()
						and sgs.isGoodTarget(enemy, self.enemies, self) and not self:slashProhibit(nil, enemy) then
					use.card = card
					if use.to then use.to:append(friend) end
					if use.to then use.to:append(enemy) end
					return
				end
			end
		end
	end

	self:sort(toList)

	for _, friend in ipairs(fromList) do
		if friend:getWeapon() and friend:hasShownSkills(sgs.lose_equip_skill)
			and self:trickIsEffective(card, friend)
			and self:objectiveLevel(friend) < 0
			and not (friend:getWeapon():isKindOf("Crossbow") and getCardsNum("Slash", friend, self.player) > 1) then

			for _, enemy in ipairs(toList) do
				if friend:canSlash(enemy, nil) and friend:objectName() ~= enemy:objectName() then
					use.card = card
					if use.to then use.to:append(friend) end
					if use.to then use.to:append(enemy) end
					return
				end
			end
		end
	end
end

sgs.ai_use_value.Collateral = 5.1
sgs.ai_use_priority.Collateral = 2.75
sgs.ai_keep_value.Collateral = 3.36

sgs.ai_card_intention.Collateral = function(self,card, from, tos)
	assert(#tos == 1)
	sgs.ai_collateral = true
end

sgs.dynamic_value.control_card.Collateral = true

sgs.ai_skill_cardask["collateral-slash"] = function(self, data, pattern, target2, target, prompt)
	-- self.player = killer
	-- target = user
	-- target2 = victim

	if self:isFriend(target) and (target:hasFlag("AI_needCrossbow") or
			(getCardsNum("Slash", target, self.player) >= 2 and self.player:getWeapon():isKindOf("Crossbow"))) then
		if target:hasFlag("AI_needCrossbow") then self.room:setPlayerFlag(target, "-AI_needCrossbow") end
		return "."
	end

	local slashes = self:getCards("Slash")
	self:sortByUseValue(slashes)
	local theslash
	if self:isFriend(target2) and self:needLeiji(target2, self.player) then
		for _, slash in ipairs(slashes) do
			if self:slashIsEffective(slash, target2) then
				theslash = slash
				break
			end
		end
	end

	if not theslash and target2 and (self:needDamagedEffects(target2, self.player, true) or self:needToLoseHp(target2, self.player, true)) then
		for _, slash in ipairs(slashes) do
			if self:slashIsEffective(slash, target2) and self:isFriend(target2) then
				theslash = slash
				break
			end
			if not self:slashIsEffective(slash, target2, self.player, true) and self:isEnemy(target2) then
				theslash = slash
				break
			end
		end
		for _, slash in ipairs(slashes) do
			if theslash then break end
			if not self:needDamagedEffects(target2, self.player, true) and self:isEnemy(target2) then
				theslash = slash
				break
			end
		end
	end

	if not theslash and target2 and not self.player:hasSkills(sgs.lose_equip_skill) and self:isEnemy(target2) then
		for _, slash in ipairs(slashes) do
			if self:slashIsEffective(slash, target2) then
				theslash = slash
				break
			end
		end
	end
	if not theslash and target2 and not self.player:hasSkills(sgs.lose_equip_skill) and self:isFriend(target2) then
		for _, slash in ipairs(slashes) do
			if not self:slashIsEffective(slash, target2) then
				theslash = slash
				break
			end
		end
		for _, slash in ipairs(slashes) do
			if theslash then break end
			if (target2:getHp() > 3 or not self:canHit(target2, self.player, self:hasHeavySlashDamage(self.player, slash, target2)))
				and self.player:getHandcardNum() > 1 then
				theslash = slash
				break
			end
			if self:needToLoseHp(target2, self.player) then
				theslash = slash
				break
			end
		end
	end
	if theslash then
		return theslash:toString()
	end
	return "."
end

local function hp_subtract_handcard(a,b)
	local diff1 = a:getHp() - a:getHandcardNum()
	local diff2 = b:getHp() - b:getHandcardNum()

	return diff1 < diff2
end

function SmartAI:enemiesContainsTrick(EnemyCount)
	local trick_all, possible_indul_enemy, possible_ss_enemy = 0, 0, 0
	local indul_num = self:getCardsNum("Indulgence")
	local ss_num = self:getCardsNum("SupplyShortage")
	local enemy_num, temp_enemy = 0, nil

	local zhanghe = sgs.findPlayerByShownSkillName("qiaobian")
	if zhanghe and (not self:isEnemy(zhanghe) or zhanghe:isKongcheng() or not zhanghe:faceUp()) then zhanghe = nil end

	if self.player:hasSkill("guose") then
		for _, acard in sgs.qlist(self.player:getCards("he")) do
			if acard:getSuit() == sgs.Card_Diamond then indul_num = indul_num + 1 end
		end
	end

	if self.player:hasSkill("duanliang") then
		for _, acard in sgs.qlist(self.player:getCards("he")) do
			if acard:isBlack() then ss_num = ss_num + 1 end
		end
	end

	for _, enemy in ipairs(self.enemies) do
		if enemy:containsTrick("indulgence") then
			if not enemy:hasSkill("keji") and   (not zhanghe or self:playerGetRound(enemy) >= self:playerGetRound(zhanghe)) then
				trick_all = trick_all + 1
				if not temp_enemy or temp_enemy:objectName() ~= enemy:objectName() then
					enemy_num = enemy_num + 1
					temp_enemy = enemy
				end
			end
		else
			possible_indul_enemy = possible_indul_enemy + 1
		end
		if self.player:distanceTo(enemy) == 1 or self.player:hasSkill("duanliang") and self.player:distanceTo(enemy) <= 2 then
			if enemy:containsTrick("supply_shortage") then
				if not enemy:hasSkill("shensu") and (not zhanghe or self:playerGetRound(enemy) >= self:playerGetRound(zhanghe)) then
					trick_all = trick_all + 1
					if not temp_enemy or temp_enemy:objectName() ~= enemy:objectName() then
						enemy_num = enemy_num + 1
						temp_enemy = enemy
					end
				end
			else
				possible_ss_enemy = possible_ss_enemy + 1
			end
		end
	end
	indul_num = math.min(possible_indul_enemy, indul_num)
	ss_num = math.min(possible_ss_enemy, ss_num)
	if not EnemyCount then
		return trick_all + indul_num + ss_num
	else
		return enemy_num + indul_num + ss_num
	end
end

function SmartAI:playerGetRound(player, source)
	if not player then return self.room:writeToConsole(debug.traceback()) end
	source = source or self.room:getCurrent()
	if player:objectName() == source:objectName() then return 0 end
	local players_num = self.room:alivePlayerCount()
	local round = (player:getSeat() - source:getSeat()) % players_num
	return round
end

function SmartAI:useCardIndulgence(card, use)
	local enemies = {}

	if #self.enemies == 0 then
		if sgs.turncount <= 1 and sgs.isAnjiang(self.player:getNextAlive()) then
			enemies = self:exclude({self.player:getNextAlive()}, card)
		end
	else
		enemies = self:exclude(self.enemies, card)
	end

	local zhanghe = sgs.findPlayerByShownSkillName("qiaobian")
	local zhanghe_seat = zhanghe and zhanghe:faceUp() and not zhanghe:isKongcheng() and not self:isFriend(zhanghe) and zhanghe:getSeat() or 0

	if #enemies == 0 then return end

	local getvalue = function(enemy)
		if enemy:hasSkills("jgjiguan_qinglong|jgjiguan_baihu|jgjiguan_zhuque|jgjiguan_xuanwu") then return -101 end
		if enemy:hasSkills("jgjiguan_bian|jgjiguan_suanni|jgjiguan_chiwen|jgjiguan_yazi") then return -101 end
		if enemy:hasShownSkill("qianxun") then return -101 end
		if enemy:hasShownSkill("weimu") and card:isBlack() then return -101 end
		if enemy:containsTrick("indulgence") then return -101 end
		if enemy:hasShownSkill("qiaobian") and not enemy:containsTrick("supply_shortage") and not enemy:containsTrick("indulgence") then return -101 end
		if zhanghe_seat > 0 and (self:playerGetRound(zhanghe) <= self:playerGetRound(enemy) and self:enemiesContainsTrick() <= 1 or not enemy:faceUp()) then
			return -101
		end
		if self:willSkipDrawPhase(enemy) and self:getOverflow() <= 0 and enemy:getHandcardNum() + enemy:getMark("@halfmaxhp") < 2
		and enemy:getMark("@firstshow") < 1 and enemy:getMark("@careerist") < 1 then
			return -101
		end

		local value = enemy:getHandcardNum() - enemy:getHp()

		if enemy:hasShownSkills(sgs.priority_skill) then value = value + 5 end
		--if enemy:hasShownSkills("qixi|guose|duanliang|luoshen|jizhi|wansha") then value = value + 5 end
		--if enemy:hasShownSkills("guzheng|duoshi") then value = value + 3 end
		if self:isWeak(enemy) then value = value + 3 end
		if self:getOverflow(enemy) > 1 then value = value + 4 end
		if getKnownCard(enemy, self.player, "Crossbow", false) > 0 then value = value + 4 end
		if enemy:isLord() then value = value + 3 end
		if enemy:getRole() == "careerist" and enemy:getActualGeneral1():getKingdom() == "careerist" then
			value = value + 3
		end

		if self:objectiveLevel(enemy) < 3 then value = value - 10 end
		if self:objectiveLevel(enemy) < 0 then value = value - 10 end--大劣势尽量不乐其他小势力
		if not enemy:faceUp() then value = value - 10 end
		if enemy:hasShownSkills("shensu") then value = value - enemy:getHandcardNum() end
		if enemy:hasShownSkills("keji|lirang|shengxi|xingzhao|tongdu") then value = value - 4 end
		if enemy:hasShownSkills("guanxing|tuxi|tianxiang|"..sgs.wizard_skill) then value = value - 3 end
		if not sgs.isGoodTarget(enemy, self.enemies, self) then value = value - 1 end
		if getKnownCard(enemy, self.player, "Dismantlement", true) > 0 then value = value + 2 end
		value = value + (self.room:alivePlayerCount() - self:playerGetRound(enemy)) / 2
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

sgs.ai_use_value.Indulgence = 7.7
sgs.ai_use_priority.Indulgence = 0.5
sgs.ai_card_intention.Indulgence = 120
sgs.ai_keep_value.Indulgence = 3.5

sgs.dynamic_value.control_usecard.Indulgence = true

function SmartAI:willUseLightning(card)
	if not card then self.room:writeToConsole(debug.traceback()) return false end
	if self.player:containsTrick("lightning") then return end
	if self.player:hasSkill("weimu") and card:isBlack() then
		local shouldUse = true
		for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if self:evaluateKingdom(p) == "unknown" then shouldUse = false break end
			if self:evaluateKingdom(p) == self.player:getKingdom() then shouldUse = false break end
		end
		if shouldUse then return true end
	end
	--if sgs.Sanguosha:isProhibited(self.player, self.player, card) then return end

	local function hasDangerousFriend()
		for _, aplayer in ipairs(self.enemies) do
			if aplayer:hasShownSkills(sgs.wizard_skill.."|hongyan|wendao") and #self.enemies < 3 then return true end
			if aplayer:hasShownSkills("guanxing|yizhi") and self:isFriend(aplayer:getNextAlive()) then return true end
		end
		return false
	end

	if self:getFinalRetrial(self.player) == 2 then
		return
	elseif self:getFinalRetrial(self.player) == 1 then
		return true
	elseif not hasDangerousFriend() then
		if self.player:hasSkills("guanxing+kongcheng") and self.player:isLastHandCard(card) then return true end
		local players = self.room:getAllPlayers()
		players = sgs.QList2Table(players)

		local friends = 0
		local enemies = 0

		for _, player in ipairs(players) do
			if self:objectiveLevel(player) >= 4 and not player:hasSkill("hongyan") and not (player:hasSkill("weimu") and card:isBlack()) then
				enemies = enemies + 1
			elseif self:isFriend(player) and not player:hasSkill("hongyan") and not (player:hasSkill("weimu") and card:isBlack()) then
				friends = friends + 1
			end
		end

		local ratio

		if friends == 0 then ratio = 999
		else ratio = enemies/friends
		end

		if ratio > 1.5 then
			return true
		end
	end
end

function SmartAI:useCardLightning(card, use)
	if self:willUseLightning(card) then
		use.card = card
	end
end

sgs.ai_use_priority.Lightning = 0
sgs.dynamic_value.lucky_chance.Lightning = true
sgs.ai_use_value.Lightning = 0
sgs.ai_keep_value.Lightning = -2

sgs.ai_skill_askforag.amazing_grace = function(self, card_ids)--更新火烧等重要卡牌

	local NextPlayerCanUse, NextPlayerisEnemy
	local NextPlayer = self.player:getNextAlive()
	if not self:willSkipPlayPhase(NextPlayer) then--sgs.turncount > 1 and
		if self:isFriend(NextPlayer) then
			if self:playerGetRound(NextPlayer) > self:playerGetRound(self.player) then
				NextPlayerCanUse = true
			end
		else
			NextPlayerisEnemy = true
		end
	end

	local cards = {}
	local trickcard = {}
	for _, card_id in ipairs(card_ids) do
		local acard = sgs.Sanguosha:getCard(card_id)
		table.insert(cards, acard)
		if acard:isKindOf("TrickCard") then
			table.insert(trickcard , acard)
		end
	end

	local nextfriend_num = 0
	local aplayer = self.player:getNextAlive()
	for i =1, self.player:aliveCount() do
		if self:isFriend(aplayer) then
			aplayer = aplayer:getNextAlive()
			nextfriend_num = nextfriend_num + 1
		else
			break
		end
	end

	local SelfisCurrent
	local CP = self.room:getCurrent()
	if CP:objectName() == self.player:objectName() then SelfisCurrent = true end

---------------
	--考虑自己拿酒让队友拿桃,考虑抢火烧
	local friendneedpeach, peach, analeptic, burningcamps
	local peachnum, jinknum = 0, 0
	if NextPlayerCanUse then
		if self.player:isFriendWith(NextPlayer) and ((self:isWeak(NextPlayer) and CP:hasShownSkill("wansha") and not SelfisCurrent)
			or(NextPlayer:isWounded() and self.player:getLostHp() <= self:getCardsNum("Peach") and not self:willSkipPlayPhase(NextPlayer)))then
			friendneedpeach = true
		elseif (not self.player:isWounded() and NextPlayer:isWounded()) or
			(self.player:getLostHp() < self:getCardsNum("Peach")) or
			(not SelfisCurrent and self:willSkipPlayPhase() and self.player:getHandcardNum() + 2 > self.player:getMaxCards()) then
			friendneedpeach = true
		end
	end
	for _, card in ipairs(cards) do
		if isCard("Peach", card, self.player) then
			peach = card:getEffectiveId()
			peachnum = peachnum + 1
		elseif isCard("Analeptic", card, self.player) then
			analeptic = card:getEffectiveId()
		elseif isCard("BurningCamps", card, self.player) then
			burningcamps = card
		end
		if card:isKindOf("Jink") then jinknum = jinknum + 1 end
	end
	if burningcamps then
		--火烧烧队列优先级可能比单个桃高
		local damage = {}
		damage.nature = sgs.DamageStruct_Fire
		damage.damage = 1
		damage.card = burningcamps
		local positive_value = 0
		if NextPlayerisEnemy and burningcamps:isAvailable(self.player) then
			damage.from = self.player
			local chained_transfer
			local targets = NextPlayer:getFormation()
			for _, target in sgs.qlist(targets) do
				damage.to = target
				if self:trickIsEffective(burningcamps, target, self.player) and self:damageIsEffective_(damage) then
					positive_value = positive_value + 1
					if target:isChained() and self:isGoodChainTarget_(damage) and not chained_transfer then
						positive_value = positive_value + 1
						chained_transfer = true
					end
				end
			end
			if positive_value > 1 then 
				Global_room:writeToConsole("抢高价值火烧:"..tostring(positive_value))
				return burningcamps 
			end
		end
		--预防敌人拿火烧
		local negative_value = 0
		if not NextPlayerCanUse and self.room:alivePlayerCount() > 2 then
			--@todo,取不到剩余五谷目标……
			local remain_targets = {}
			for _, p in sgs.qlist(self.room:getAlivePlayers()) do
				if self:playerGetRound(self.player) >= self:playerGetRound(p) then continue end
				table.insert(remain_targets, p)
			end
			if #remain_targets == #card_ids - 1 then
				self:sort(remain_targets, "round")
				local LastAlivePlayer
				for _, remain_target in ipairs(remain_targets) do
					local burning_target = remain_target:getNextAlive()
					if self:isEnemy(remain_target) and burningcamps:isAvailable(remain_target) and self.player:isFriendWith(burning_target) then
						damage.from = remain_target
						local value = 0
						local chained_transfer
						local targets = burning_target:getFormation()
						for _, target in sgs.qlist(targets) do
							damage.to = target
							if self:trickIsEffective(burningcamps, target, remain_target) and self:damageIsEffective_(damage) then
								value = value + 1
								if self:isWeak(target) then value = value + 1 end
								if target:isChained() and not self:isGoodChainTarget_(damage) and not chained_transfer then
									value = value + 1
									chained_transfer = true
								end
							end
						end
						negative_value = math.max(negative_value, value)
						if negative_value > 1 then 
							Global_room:writeToConsole("预防敌人拿火烧:"..tostring(negative_value))
							return burningcamps 
						end
					elseif self.player:isFriendWith(remain_target) and not self:isWeak(remain_target) then
						Global_room:writeToConsole("火烧放给队友考虑:"..tostring(negative_value))
						break
					end
				end
			end
		end
		--if positive_value + negative_value > 1 then return burningcamps end
	end
	if (not friendneedpeach and peach) or peachnum > 1 then return peach end

	local exnihilo, jink, analeptic, nullification, snatch, dismantlement, befriendattacking
	for _, card in ipairs(cards) do
		if isCard("ExNihilo", card, self.player) then
			if not NextPlayerCanUse or (not self:willSkipPlayPhase() and (self.player:hasSkills("jizhi|zhiheng|rende") or not NextPlayer:hasShownSkills("jizhi|zhiheng|rende"))) then
				exnihilo = card:getEffectiveId()
			end
		elseif isCard("Jink", card, self.player) then
			jink = card:getEffectiveId()
		elseif isCard("Analeptic", card, self.player) then
			analeptic = card:getEffectiveId()
		elseif isCard("Nullification", card, self.player) then
			nullification = card:getEffectiveId()
		elseif isCard("Snatch", card, self.player) then
			snatch = card
		elseif isCard("Dismantlement", card, self.player) then
			dismantlement = card
		elseif isCard("BefriendAttacking", card, self.player) then
			befriendattacking = card
		end
	end

	for _, target in sgs.qlist(self.room:getAlivePlayers()) do
		if self:willSkipPlayPhase(target) or self:willSkipDrawPhase(target) then
			if nullification then return nullification
			elseif self:isFriend(target) and snatch and self:trickIsEffective(snatch, target, self.player) and
				not self:willSkipPlayPhase() and self.player:distanceTo(target) == 1 then
				return snatch:getEffectiveId()
			elseif self:isFriend(target) and dismantlement and self:trickIsEffective(dismantlement, target, self.player) and
				not self:willSkipPlayPhase() and self.player:objectName() ~= target:objectName() then
				return dismantlement:getEffectiveId()
			end
		end
	end

	if SelfisCurrent then
		if exnihilo then return exnihilo end
		if befriendattacking then
			for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
				if p:hasShownOneGeneral() and not self.player:isFriendWith(p) then return befriendattacking end
			end
		end
		if (jink or analeptic) and (self:getCardsNum("Jink") == 0 or (self:isWeak() and self:getOverflow() <= 0)) then
			return jink or analeptic
		end
	else
		local CP = self.room:getCurrent()
		local possible_attack = 0
		for _, enemy in ipairs(self.enemies) do
			if enemy:inMyAttackRange(self.player) and self:playerGetRound(CP, enemy) < self:playerGetRound(CP, self.player) then
				possible_attack = possible_attack + 1
			end
		end
		if possible_attack > self:getCardsNum("Jink") and self:getCardsNum("Jink") <= 2 and sgs.getDefenseSlash(self.player, self) <= 2 then
			if jink or analeptic or exnihilo then return jink or analeptic or exnihilo end
		else
			if exnihilo then return exnihilo end
			if befriendattacking then
				for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
					if p:hasShownOneGeneral() and not self.player:isFriendWith(p) then return befriendattacking end
				end
			end
		end
	end

	if nullification and (self:getCardsNum("Nullification") < 2 or not NextPlayerCanUse) then
		return nullification
	end

	if jinknum == 1 and jink and self:isEnemy(NextPlayer) and (NextPlayer:isKongcheng() or sgs.card_lack[NextPlayer:objectName()]["Jink"] == 1) then
		return jink
	end

	self:sortByUseValue(cards)
	for _, card in ipairs(cards) do
		for _, skill in sgs.qlist(self.player:getVisibleSkillList()) do
			local callback = sgs.ai_cardneed[skill:objectName()]
			if type(callback) == "function" and callback(self.player, card, self) then
				if friendneedpeach and card:getEffectiveId() ~= peach then
					return card:getEffectiveId()
				end
			end
		end
	end

	local eightdiagram, silverlion, vine, renwang, ironarmor, DefHorse, OffHorse, jadeseal
	local weapon, crossbow, halberd, double, qinggang, axe, gudingdao
	for _, card in ipairs(cards) do
		if card:isKindOf("EightDiagram") then eightdiagram = card:getEffectiveId()
		elseif card:isKindOf("SilverLion") then silverlion = card:getEffectiveId()
		elseif card:isKindOf("Vine") then vine = card:getEffectiveId()
		elseif card:isKindOf("RenwangShield") then renwang = card:getEffectiveId()
		elseif card:isKindOf("IronArmor") then ironarmor = card:getEffectiveId()

		elseif card:isKindOf("DefensiveHorse") and not self:getSameEquip(card) then DefHorse = card:getEffectiveId()
		elseif card:isKindOf("OffensiveHorse") and not self:getSameEquip(card) then OffHorse = card:getEffectiveId()

		elseif card:isKindOf("Crossbow") then crossbow = card
		elseif card:isKindOf("DoubleSword") then double = card:getEffectiveId()
		elseif card:isKindOf("QinggangSword") then qinggang = card:getEffectiveId()
		elseif card:isKindOf("Axe") then axe = card:getEffectiveId()
		elseif card:isKindOf("GudingBlade") then gudingdao = card:getEffectiveId()
		elseif card:isKindOf("Halberd") then halberd = card:getEffectiveId()

		elseif card:isKindOf("JadeSeal") then jadeseal = card:getEffectiveId()  end

		if not weapon and card:isKindOf("Weapon") then weapon = card:getEffectiveId() end
	end

	if eightdiagram then
		if not self.player:hasSkill("bazhen") and self.player:hasSkills("tiandu|leiji|hongyan") and not self.player:getArmor() then
			return eightdiagram
		end
		if NextPlayerisEnemy and NextPlayer:hasShownSkills("tiandu|leiji|hongyan") and not NextPlayer:getArmor() then
			return eightdiagram
		end
	end

	if silverlion then
		local lightning, canRetrial
		for _, p in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if p:hasSkill("leiji") and self:isEnemy(p) then
				return silverlion
			end
			if p:containsTrick("lightning") then
				lightning = true
			end
			if p:hasShownSkills("guicai|guidao") and self:isEnemy(p) then
				canRetrial = true
			end
		end
		if lightning and canRetrial then return silverlion end
		if self.player:isChained() then
			for _, friend in ipairs(self.friends) do
				if friend:hasArmorEffect("Vine") and friend:isChained() then
					return silverlion
				end
			end
		end
		if self.player:isWounded() then return silverlion end
	end

	if vine then
		if sgs.ai_armor_value.Vine(self.player, self) > 0 and self.room:alivePlayerCount() <= 3 then
			return vine
		end
	end

	if renwang then
		if sgs.ai_armor_value.RenwangShield(self.player, self) > 0 and self:getCardsNum("Jink") == 0 then return renwang end
	end

	if ironarmor then
		for _, enemy in ipairs(self.enemies) do
			if enemy:hasShownSkill("huoji") then return ironarmor end
			if getCardsNum("FireAttack", enemy, self.player) > 0 then return ironarmor end
			if getCardsNum("FireSlash", enemy, self.player) > 0 then return ironarmor end
			if enemy:getFormation():contains(self.player) and getCardsNum("BurningCamps", enemy, self.player) > 0 then return ironarmor end
		end
	end

	if DefHorse and (not self.player:hasSkill("leiji") or self:getCardsNum("Jink") == 0) then
		local before_num, after_num = 0, 0
		for _, enemy in ipairs(self.enemies) do
			if enemy:canSlash(self.player, nil, true) then
				before_num = before_num + 1
			end
			if enemy:canSlash(self.player, nil, true, 1) then
				after_num = after_num + 1
			end
		end
		if before_num > after_num and (self:isWeak() or self:getCardsNum("Jink") == 0) then return DefHorse end
	end

	if jadeseal then
		for _, friend in ipairs(self.friends) do
			if not (friend:getTreasure() and friend:getPile("wooden_ox"):length() > 1) then return jadeseal end
		end
	end

	if analeptic then
		local slashes = self:getCards("Slash")
		for _, enemy in ipairs(self.enemies) do
			local hit_num = 0
			for _, slash in ipairs(slashes) do
				if self:slashIsEffective(slash, enemy) and self.player:canSlash(enemy, slash) and self:slashIsAvailable() then
					hit_num = hit_num + 1
					if getCardsNum("Jink", enemy, self.player) < 1
						or enemy:isKongcheng()
						or self:canLiegong(enemy, self.player)
						or self.player:hasSkills(sgs.force_slash_skill)
						or (self.player:hasWeapon("Axe") or self:getCardsNum("Axe") > 0) and self.player:getCardCount(true) > 4
						then
						return analeptic
					end
				end
			end
			if self:hasCrossbowEffect(self.player) and hit_num >= 2 then return analeptic end
		end
	end

	if weapon and (self:getCardsNum("Slash") > 0 and self:slashIsAvailable() or not SelfisCurrent) then
		local current_range = (self.player:getWeapon() and sgs.weapon_range[self.player:getWeapon():getClassName()]) or 1
		local nosuit_slash = sgs.cloneCard("slash", sgs.Card_NoSuit, 0)
		local slash = SelfisCurrent and self:getCard("Slash") or nosuit_slash

		self:sort(self.enemies, "defense")

		if crossbow then
			if #self:getCards("Slash") > 1 or self.player:hasSkills("kurou|keji")
				or (self.player:hasSkills("luoshen|guzheng") and not SelfisCurrent and self.room:alivePlayerCount() >= 4) then
				return crossbow:getEffectiveId()
			end
			if self.player:hasSkill("rende") then
				for _, friend in ipairs(self.friends_noself) do
					if getCardsNum("Slash", friend, self.player) > 1 then
						return crossbow:getEffectiveId()
					end
				end
			end
			if self:isEnemy(NextPlayer) then
				local CanSave, huanggai, zhenji
				for _, enemy in ipairs(self.enemies) do
					if enemy:hasShownSkill("jijiu") and getKnownCard(enemy, self.player, "red", nil, "he") > 1 then CanSave = true end
					if enemy:hasShownSkill("kurou") then huanggai = enemy end
					if enemy:hasShownSkill("keji") then return crossbow:getEffectiveId() end
					if enemy:hasShownSkills("luoshen|guzheng") then return crossbow:getEffectiveId() end
				end
				if huanggai then
					if huanggai:getHp() > 2 then return crossbow:getEffectiveId() end
					if CanSave then return crossbow:getEffectiveId() end
				end
				if getCardsNum("Slash", NextPlayer, self.player) >= 3 and NextPlayerisEnemy then return crossbow:getEffectiveId() end
			end
		end

		if halberd then
			if not self.player:hasWeapon("Axe") then
				local halberd_targets = 0
				local range_fix = current_range - 4
				for _, enemy in ipairs(self.enemies) do
					if enemy:hasShownOneGeneral() or enemy:getRole() ~= "careerist" then continue end
					if self.player:canSlash(enemy, slash, true, range_fix) and (self:canHit(enemy, self.player) or self.player:hasSkills(sgs.force_slash_skill .. "|" .."paoxiao|paoxiao_xh|baolie|xiongnve|kuangcai")) then
						halberd_targets = halberd_targets + 1
					end
				end
				local kingdoms = sgs.KingdomsTable
				for _, kingdom in ipairs(kingdoms) do
					for _, enemy in ipairs(self.enemies) do
						if not enemy:hasShownOneGeneral() or enemy:getRole() == "careerist" and enemy:getKingdom() ~= kingdom then continue end
						if self.player:canSlash(enemy, slash, true, range_fix) and (self:canHit(enemy, self.player) or self.player:hasSkills(sgs.force_slash_skill .. "|" .."paoxiao|paoxiao_xh|baolie|xiongnve|kuangcai")) then
							halberd_targets = halberd_targets + 1
							break
						end
					end
				end
				if halberd_targets >= 2 then
					return halberd
				end
			end
		end

		if gudingdao then
			local range_fix = current_range - 2
			for _, enemy in ipairs(self.enemies) do
				if self.player:canSlash(enemy, slash, true, range_fix) and enemy:isKongcheng() and
					(not SelfisCurrent or (self:getCardsNum("Dismantlement") > 0 or (self:getCardsNum("Snatch") > 0 and self.player:distanceTo(enemy) == 1))) then
					return gudingdao
				end
			end
		end

		if axe then
			local range_fix = current_range - 3
			local FFFslash = self:getCard("FireSlash")
			for _, enemy in ipairs(self.enemies) do
				if (enemy:hasArmorEffect("Vine") or enemy:getMark("@gale") > 0) and FFFslash and self:slashIsEffective(FFFslash, enemy) and
					self.player:getCardCount(true) >= 3 and self.player:canSlash(enemy, FFFslash, true, range_fix) then
					return axe
				elseif self:getCardsNum("Analeptic") > 0 and self.player:getCardCount(true) >= 4 and
					self:slashIsEffective(slash, enemy) and self.player:canSlash(enemy, slash, true, range_fix) then
					return axe
				end
			end
		end

		if double then
			local range_fix = current_range - 2
			for _, enemy in ipairs(self.enemies) do
				if self.player:getGender() ~= enemy:getGender() and self.player:canSlash(enemy, nil, true, range_fix) then
					return double
				end
			end
		end

		if qinggang then
			local range_fix = current_range - 2
			for _, enemy in ipairs(self.enemies) do
				if self.player:canSlash(enemy, slash, true, range_fix) and self:slashIsEffective(slash, enemy, self.player, true) then
					return qinggang
				end
			end
		end

	end

	local classNames = { "Snatch", "Dismantlement", "Indulgence", "SupplyShortage", "Collateral", "Duel", "Drowning", "ArcheryAttack", "SavageAssault", "FireAttack",
							"GodSalvation", "Lightning" }
	local className2objectName = { Snatch = "snatch", Dismantlement = "dismantlement", Indulgence = "indulgence", SupplyShortage = "supply_shortage", Collateral = "collateral",
									Duel = "duel", Drowning = "drowning", ArcheryAttack = "archery_attack", SavageAssault = "savage_assault", FireAttack = "fire_attack",
									GodSalvation = "god_salvation", Lightning = "lightning" }
	local new_enemies = {}
	if #self.enemies > 0 then new_enemies = self.enemies
	else
		for _, aplayer in sgs.qlist(self.room:getOtherPlayers(self.player)) do
			if not string.find(self:evaluateKingdom(aplayer), self.player:getKingdom()) then
				table.insert(new_enemies, aplayer)
			end
		end
	end
	if not self:willSkipPlayPhase() or not NextPlayerCanUse then
		for _, className in ipairs(classNames) do
			for _, card in ipairs(cards) do
				if isCard(className, card, self.player) then
					local card_x = className ~= card:getClassName() and sgs.cloneCard(className2objectName[className], card:getSuit(), card:getNumber()) or card
					self.enemies = new_enemies
					local dummy_use = { isDummy = true }
					self:useTrickCard(card_x, dummy_use)
					self:updatePlayers(false)
					if dummy_use.card then return card end
				end
			end
		end
	elseif #trickcard > nextfriend_num + 1 and NextPlayerCanUse then
		for i = #classNames, 1, -1 do
			local className = classNames[i]
			for _, card in ipairs(cards) do
				if isCard(className, card, self.player) then
					local card_x = className ~= card:getClassName() and sgs.cloneCard(className2objectName[className], card:getSuit(), card:getNumber()) or card
					self.enemies = new_enemies
					local dummy_use = { isDummy = true }
					self:useTrickCard(card_x, dummy_use)
					self:updatePlayers(false)
					if dummy_use.card then return card end
				end
			end
		end
	end

	if weapon and not self.player:getWeapon() and self:getCardsNum("Slash") > 0 and (self:slashIsAvailable() or not SelfisCurrent) then
		local inAttackRange
		for _, enemy in ipairs(self.enemies) do
			if self.player:inMyAttackRange(enemy) then
				inAttackRange = true
				break
			end
		end
		if not inAttackRange then return weapon end
	end

	if eightdiagram or silverlion or vine or renwang or ironarmor then
		return renwang or eightdiagram or ironarmor or silverlion or vine
	end

	self:sortByCardNeed(cards, true)
	for _, card in ipairs(cards) do
		if not card:isKindOf("TrickCard") and not card:isKindOf("Peach") then
			return card:getEffectiveId()
		end
	end

	return cards[1]:getEffectiveId()
end


function SmartAI:useCardAwaitExhausted(AwaitExhausted, use)
	if not AwaitExhausted:isAvailable(self.player) then return end
	use.card = AwaitExhausted
end
sgs.ai_use_priority.AwaitExhausted = 2.8
sgs.ai_use_value.AwaitExhausted = 4.9
sgs.ai_keep_value.AwaitExhausted = 3.22

sgs.ai_card_intention.AwaitExhausted = function(self, card, from, tos)
	for _, to in ipairs(tos) do
		sgs.updateIntention(from, to, -50)
	end
end
sgs.ai_nullification.AwaitExhausted = function(self, card, from, to, positive, keep)
	local targets = sgs.SPlayerList()
	local players = self.room:getTag("targets" .. card:toString()):toList()
	for _, q in sgs.qlist(players) do
		targets:append(q:toPlayer())
	end
	if keep then return false end
	if positive then
		local hegnull = self:getCard("HegNullification") or (self.room:getTag("NullifyingTimes"):toInt() > 0 and self.room:getTag("NullificatonType"):toBool())
		if self:isEnemy(to) and targets:length() > 1 and hegnull then
			for _, p in sgs.qlist(targets) do
				if (p:hasShownSkills(sgs.lose_equip_skill) and p:getEquips():length() > 0)
					or (p:getArmor() and self:needToThrowArmor(p)) then
					return true, false
				end
			end
		else
			if self:isEnemy(to) and self:evaluateKingdom(to) ~= "unknown" then
				--if self:getOverflow() > 0 or self:getCardsNum("Nullification") > 1 then return true, true end
				if to:hasShownSkills(sgs.lose_equip_skill) and to:getEquips():length() > 0 then return true, true end
				if to:getArmor() and self:needToThrowArmor(to) then return true, true end
			end
		end
	else
		if self:isFriend(to) and (self:getOverflow() > 0 or self:getCardsNum("Nullification") > 1) then return true, true end
	end
	return
end

function SmartAI:useCardBefriendAttacking(BefriendAttacking, use)
	if not BefriendAttacking:isAvailable(self.player) then return end
	local targets = sgs.PlayerList()
	local players = sgs.QList2Table(self.room:getOtherPlayers(self.player))
	self:sort(players)
	for _, to_select in ipairs(players) do
																						   
		if self:isFriend(to_select) and BefriendAttacking:targetFilter(targets, to_select, self.player) and not targets:contains(to_select)
			and self:trickIsEffective(BefriendAttacking, to_select, self.player) then
			targets:append(to_select)
			if use.to then use.to:append(to_select) end
		end
	end

	if targets:isEmpty() then--破空城
		for _, to_select in ipairs(players) do
			if self:isEnemy(to_select) and self:needKongcheng(to_select)
				and BefriendAttacking:targetFilter(targets, to_select, self.player) and not targets:contains(to_select)
				and self:trickIsEffective(BefriendAttacking, to_select, self.player) then
				targets:append(to_select)
				if use.to then use.to:append(to_select) end
			end
		end
	end
	if targets:isEmpty() then--降低给牌价值
		for _, to_select in ipairs(players) do
																							
			if BefriendAttacking:targetFilter(targets, to_select, self.player) and not targets:contains(to_select)
				and self:trickIsEffective(BefriendAttacking, to_select, self.player) then
				if self:isEnemy(to_select) and to_select:hasShownSkills(sgs.cardneed_skill) then continue end
				targets:append(to_select)
				if use.to then use.to:append(to_select) end
			end
		end
	end
	if targets:isEmpty() then
		for _, to_select in ipairs(players) do
																							
			if BefriendAttacking:targetFilter(targets, to_select, self.player) and not targets:contains(to_select)
				and self:trickIsEffective(BefriendAttacking, to_select, self.player) then
				if self:isEnemy(to_select) and to_select:hasShownSkills("jijiu|tianxiang|kanpo") then continue end
				targets:append(to_select)
				if use.to then use.to:append(to_select) end
			end
		end
	end
	if not targets:isEmpty() then
		use.card = BefriendAttacking
		return
	end
end
sgs.ai_use_priority.BefriendAttacking = 9.28
sgs.ai_use_value.BefriendAttacking = 10
sgs.ai_keep_value.BefriendAttacking = 3.9

sgs.ai_nullification.BefriendAttacking = function(self, card, from, to, positive, keep)
	if keep then return false end
	if positive then
		if not self:isFriend(to) and self:isEnemy(from) and (self:isWeak(from) or from:hasShownSkills(sgs.cardneed_skill)) then
			return true, true
		end
	else
		if self:isFriend(from) then return true, true end
	end
end

function SmartAI:useCardKnownBoth(KnownBoth, use)
	self.knownboth_choice = {}
	if not KnownBoth:isAvailable(self.player) then return false end
	local targets = sgs.PlayerList()
	local total_num = 1 + sgs.Sanguosha:correctCardTarget(sgs.TargetModSkill_ExtraTarget, self.player, KnownBoth)
	for _, player in sgs.qlist(self.room:getOtherPlayers(self.player)) do
		if KnownBoth:targetFilter(targets, player, self.player) and sgs.isAnjiang(player) and not targets:contains(player)
			and player:getMark(("KnownBoth_%s_%s"):format(self.player:objectName(), player:objectName())) == 0 and self:trickIsEffective(KnownBoth, player, self.player) then
			use.card = KnownBoth
			targets:append(player)
			if use.to then use.to:append(player) end
			self.knownboth_choice[player:objectName()] = "head_general"
		end
	end

	if total_num > targets:length() then
		self:sort(self.enemies, "handcard", true)
		for _, enemy in ipairs(self.enemies) do
			if KnownBoth:targetFilter(targets, enemy, self.player) and enemy:getHandcardNum() - self:getKnownNum(enemy, self.player) > 3 and not targets:contains(enemy)
				and self:trickIsEffective(KnownBoth, enemy, self.player) then
				use.card = KnownBoth
				targets:append(enemy)
				if use.to then use.to:append(enemy) end
				self.knownboth_choice[enemy:objectName()] = "handcards"
			end
		end
	end
	if total_num > targets:length() and not targets:isEmpty() then
		self:sort(self.friends_noself, "handcard", true)
		for _, friend in ipairs(self.friends_noself) do
			if self:getKnownNum(friend, self.player) ~= friend:getHandcardNum() and KnownBoth:targetFilter(targets, friend, self.player) and not targets:contains(friend)
				and self:trickIsEffective(KnownBoth, friend, self.player) then
				targets:append(friend)
				if use.to then use.to:append(friend) end
				self.knownboth_choice[friend:objectName()] = "handcards"
			end
		end
	end

	if not use.card then
		--[[targets = sgs.PlayerList()
		local canRecast = KnownBoth:targetsFeasible(targets, self.player)]]
		if not self.player:isCardLimited(KnownBoth, sgs.Card_MethodRecast) and KnownBoth:canRecast() then
			use.card = KnownBoth
			if use.to then use.to = sgs.SPlayerList() end
		end
	end
end
sgs.ai_skill_choice.known_both = function(self, choices, data)
	local target = data:toPlayer()
	if target and self.knownboth_choice and self.knownboth_choice[target:objectName()] then return self.knownboth_choice[target:objectName()] end
	return "handcards"
end
sgs.ai_use_priority.KnownBoth = 9.1
sgs.ai_use_value.KnownBoth = 5
sgs.ai_keep_value.KnownBoth = 3.24
sgs.ai_nullification.KnownBoth = function(self, card, from, to, positive)
	return false
end

sgs.ai_choicemade_filter.skillChoice.known_both = function(self, from, promptlist)
	local choice = promptlist[#promptlist]
	if choice ~= "handcards" then
		for _, to in sgs.qlist(self.room:getOtherPlayers(from)) do
			if to:hasFlag("KnownBothTarget") then
				to:setMark(("KnownBoth_%s_%s"):format(from:objectName(), to:objectName()), 1)
				local names = {}
				if from:getTag("KnownBoth_" .. to:objectName()):toString() ~= "" then
					names = from:getTag("KnownBoth_" .. to:objectName()):toString():split("+")
				else
					if to:hasShownGeneral1() then
						table.insert(names, to:getActualGeneral1Name())
					else
						table.insert(names, "anjiang")
					end
					if to:hasShownGeneral2() then
						table.insert(names, to:getActualGeneral2Name())
					else
						table.insert(names, "anjiang")
					end
				end
				if choice == "head_general" then
					names[1] = to:getActualGeneral1Name()
				else
					names[2] = to:getActualGeneral2Name()
				end
				from:setTag("KnownBoth_" .. to:objectName(), sgs.QVariant(table.concat(names, "+")))
				break
			end
		end
	end
end

sgs.ai_skill_use["@@Triblade"] = function(self, prompt)
	local damage = self.room:getTag("CurrentDamageStruct"):toDamage()
	if type(damage) ~= "DamageStruct" and type(damage) ~= "userdata" then return "." end
	local targets = sgs.SPlayerList()
	for _, p in sgs.qlist(self.room:getOtherPlayers(damage.to)) do
		if damage.to:distanceTo(p) == 1 then targets:append(p) end
	end
	if targets:isEmpty() then return "." end
	local id
	local cards = sgs.QList2Table(self.player:getHandcards())
	self:sortByKeepValue(cards)
	for _, c in ipairs(cards) do
		if not self.player:isCardLimited(c, sgs.Card_MethodDiscard) and not self:isValuableCard(c) then id = c:getEffectiveId() break end
	end
	if not id then return "." end
	for _, target in sgs.qlist(targets) do
		if self:isEnemy(target) and self:damageIsEffective(target, nil, self.player) and not self:needDamagedEffects(target, self.player)
			and not self:needToLoseHp(target, self.player) then
			return "@TribladeSkillCard=" .. id .. "&tribladeskill->" .. target:objectName()
		end
	end
	for _, target in sgs.qlist(targets) do
		if self:isFriend(target) and self:damageIsEffective(target, nil, self.player)
			and (self:needDamagedEffects(target, self.player) or self:needToLoseHp(target, self.player, nil, true)) then
			return "@TribladeSkillCard=" .. id .. "&tribladeskill->" .. target:objectName()
		end
	end
	return "."
end
function sgs.ai_slash_weaponfilter.Triblade(self, to, player)
	if player:distanceTo(to) > math.max(sgs.weapon_range.Triblade, player:getAttackRange()) then return end
	return sgs.card_lack[to:objectName()]["Jink"] == 1 or getCardsNum("Jink", to, self.player) < 1
end
function sgs.ai_weapon_value.Triblade(self, enemy, player)
	if not enemy or #self:getEnemies(player) == 1 then return 1 end
	local v = (self:getOverflow(player) > 0) and 1 or 0
	if self:canHit(enemy, player) and not player:hasWeapon("Axe") then
		v = v + 1
	end
	local Triblade_target = nil
	for _, p in sgs.qlist(self.room:getOtherPlayers(enemy)) do
		if enemy:distanceTo(p) == 1 and self:isEnemy(p, player) and self:canAttack(p) then
			if not Triblade_target then
				Triblade_target = p
			else
				if p:getHp() < Triblade_target:getHp() then
					Triblade_target = p
				end
			end
		end
	end
	if Triblade_target then
		if Triblade_target:getHp() < 3 then
			v = v + 3 - Triblade_target:getHp()
		end
		if player:getHandcardNum() >= 2 then v = v + 1 end
		return math.min(3.8, v)
	end
end

sgs.ai_use_priority.Triblade = 2.673

function sgs.ai_slash_weaponfilter.SixSwords(self, to, player)
	return player:distanceTo(to) <= math.max(sgs.weapon_range.SixSwords, player:getAttackRange())
		and (sgs.card_lack[to:objectName()]["Jink"] == 1 or getCardsNum("Jink", to, self.player) < 1)
end

function sgs.ai_weapon_value.SixSwords(self, enemy, player)
	local v = 0
	for _, p in ipairs(self:getFriendsNoself(player)) do
		if player:isFriendWith(p) then
			v = v + 0.5
		end
	end
	return v
end