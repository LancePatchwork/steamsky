# Copyright 2023 Bartek thindil Jasicki
#
# This file is part of Steam Sky.
#
# Steam Sky is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Steam Sky is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Steam Sky.  If not, see <http://www.gnu.org/licenses/>.

import std/[strutils, tables]
import bases, basescargo, basestypes, crewinventory, game, game2, maps,
    messages, ships, shipscargo, shipscrew, types, utils

type
  NoTraderError* = object of CatchableError
    ## Raised when there is no crew member assigned to talk

  NoFreeCargoError* = object of CatchableError
    ## Raised when there is no free space in the player's ship cargo

  NoMoneyInBaseError* = object of CatchableError
    ## Raised when there is not enough money in the base for trade

  NoMoneyError* = object of CatchableError
    ## Raised when the player doesn't have money to buy an item

  NotEnoughMoneyError* = object of CatchableError
    ## Raised when the player doesn't have enough money to buy an item

proc generateTraderCargo*(protoIndex: Positive) {.sideEffect, raises: [
    KeyError], tags: [].} =
  ## Generate the list of items for trade.
  ##
  ## * protoIndex - the index of the ship's prototype from which the cargo will
  ##                be generated
  var traderShip = createShip(protoIndex = protoIndex, name = "",
        x = playerShip.skyX, y = playerShip.skyY, speed = fullStop)
  traderCargo = @[]
  for item in traderShip.cargo:
    traderCargo.add(BaseCargo(protoIndex: item.protoIndex, amount: item.amount,
        durability: defaultItemDurability, price: itemsList[
        item.protoIndex].price))
  var cargoAmount = if traderShip.crew.len < 5: getRandom(min = 1, max = 3)
      elif traderShip.crew.len < 10: getRandom(min = 1, max = 5)
      else: getRandom(min = 1, max = 10)
  while cargoAmount > 0:
    var
      itemAmount = if traderShip.crew.len < 5: getRandom(min = 1, max = 100)
        elif traderShip.crew.len < 10: getRandom(min = 1, max = 500)
        else: getRandom(min = 1, max = 1000)
      itemIndex = getRandom(min = 1, max = itemsList.len)
      newItemIndex = 0
    for i in 1 .. itemsList.len:
      itemIndex.dec
      if itemIndex == 0:
        newItemIndex = i
        break
    let cargoItemIndex = findItem(inventory = traderShip.cargo,
        protoIndex = newItemIndex)
    if cargoItemIndex > -1:
      traderCargo[cargoItemIndex].amount = traderCargo[cargoItemIndex].amount + itemAmount
      traderShip.cargo[cargoItemIndex].amount = traderShip.cargo[
          cargoItemIndex].amount + itemAmount
    else:
      if freeCargo(amount = 0 - (itemsList[newItemIndex].weight * itemAmount)) > -1:
        traderCargo.add(BaseCargo(protoIndex: newItemIndex, amount: itemAmount,
            durability: defaultItemDurability, price: itemsList[
            newItemIndex].price))
        traderShip.cargo.add(InventoryData(protoIndex: newItemIndex,
            amount: itemAmount, durability: defaultItemDurability, name: "", price: 0))
      else:
        cargoAmount = 1
    cargoAmount.dec

proc sellItems*(itemIndex: Natural; amount: string) {.sideEffect, raises: [
    NoTraderError, NoFreeCargoError, NoMoneyInBaseError, KeyError, ValueError,
    IOError, Exception], tags: [WriteIOEffect, RootEffect].} =
  ## Sell the selected item from the player's ship cargo to the trader
  ##
  ## * itemIndex - the index of the item in the player's ship cargo
  ## * amount    - the amount of the item to sell
  let traderIndex = findMember(order = talk)
  if traderIndex == -1:
    raise newException(exceptn = NoTraderError, message = "")
  let
    baseIndex = skyMap[playerShip.skyX][playerShip.skyY].baseIndex
    protoIndex = playerShip.cargo[itemIndex].protoIndex
  var baseItemIndex = -1
  if baseIndex > -1:
    baseItemIndex = findBaseCargo(protoIndex = protoIndex)
  else:
    for index, item in traderCargo:
      if item.protoIndex == protoIndex:
        baseItemIndex = index
        break
  var price: Natural = 0
  if baseItemIndex == -1:
    price = getPrice(baseType = skyBases[baseIndex].baseType,
        itemIndex = protoIndex)
  else:
    price = if baseIndex > 0:
        skyBases[baseIndex].cargo[baseItemIndex].price
      else:
        traderCargo[baseItemIndex].price
  let eventIndex = skyMap[playerShip.skyX][playerShip.skyY].eventIndex
  if eventIndex > -1 and eventsList[eventIndex].eType == doublePrice and
      eventsList[eventIndex].itemIndex == protoIndex:
    price = price * 2
  let sellAmount = amount.parseInt
  var profit = price * sellAmount
  if playerShip.cargo[itemIndex].durability < 100:
    profit = (profit.float * (playerShip.cargo[itemIndex].durability.float / 100.0)).int
  countPrice(price = price, traderIndex = traderIndex, reduce = false)
  for index, member in playerShip.crew:
    if member.payment[2] == 0:
      continue
    if profit < 1:
      updateMorale(ship = playerShip, memberIndex = index, value = getRandom(
          min = -25, max = -5))
      addMessage(message = member.name &
          " is sad because doesn't get own part of profit.",
          mType = tradeMessage, color = red)
      profit = 0
      continue
    profit = profit - (profit.float * (member.payment[2].float / 100.0)).int
    if profit < 1:
      if profit < 0:
        updateMorale(ship = playerShip, memberIndex = index, value = getRandom(
            min = -12, max = -2))
        addMessage(message = member.name &
            " is sad because doesn't get own part of profit.",
            mType = tradeMessage, color = red)
      profit = 0
  if freeCargo(amount = itemsList[protoIndex].weight * sellAmount) - profit < 0:
    raise newException(exceptn = NoFreeCargoError, message = "")
  let itemName = itemsList[protoIndex].name
  if baseIndex > 0:
    if profit > skyBases[baseIndex].cargo[0].amount:
      raise newException(exceptn = NoMoneyInBaseError, message = itemName)
    updateBaseCargo(protoIndex = protoIndex, amount = sellAmount,
        durability = playerShip.cargo[itemIndex].durability)
  else:
    if profit > traderCargo[0].amount:
      raise newException(exceptn = NoMoneyInBaseError, message = itemName)
    var cargoAdded = false
    for item in traderCargo.mitems:
      if item.protoIndex == protoIndex and item.durability == playerShip.cargo[
          itemIndex].durability:
        item.amount = item.amount + sellAmount
        cargoAdded = true
        break
    if not cargoAdded:
      traderCargo.add(BaseCargo(protoIndex: protoIndex, amount: sellAmount,
          durability: playerShip.cargo[itemIndex].durability, price: itemsList[
          protoIndex].price))
  updateCargo(ship = playerShip, cargoIndex = itemIndex, amount = -sellAmount,
      price = playerShip.cargo[itemIndex].price)
  updateCargo(ship = playerShip, protoIndex = moneyIndex, amount = profit)
  if baseIndex > 0:
    updateBaseCargo(protoIndex = moneyIndex, amount = -profit)
    gainRep(baseIndex = baseIndex, points = 1)
    if itemsList[protoIndex].reputation > skyBases[baseIndex].reputation.level:
      gainRep(baseIndex = baseIndex, points = 1)
  else:
    traderCargo[0].amount = traderCargo[0].amount - profit
  gainExp(amount = 1, skillNumber = talkingSkill, crewIndex = traderIndex)
  let gain = profit - (sellAmount * price)
  addMessage(message = "You sold " & $sellAmount & " " & itemName & " for " &
      $profit & " " & moneyName & "." & (if gain == 0: "" else: " You " & (
      if gain > 0: "gain " else: "lost ") & $(gain.abs) & " " & moneyName &
      " compared to the base price."), mType = tradeMessage)
  if baseIndex > 0 and eventIndex > -1:
    eventsList[eventIndex].time = eventsList[eventIndex].time + 5
  updateGame(minutes = 5)

proc buyItems*(baseItemIndex: Natural; amount: string) =
  let traderIndex = findMember(order = talk)
  if traderIndex == -1:
    raise newException(exceptn = NoTraderError, message = "")
  let
    baseIndex = skyMap[playerShip.skyX][playerShip.skyY].baseIndex
    eventIndex = skyMap[playerShip.skyX][playerShip.skyY].eventIndex
  var
    itemIndex, price = 0
    itemName = ""
  if baseIndex > 0:
    itemIndex = skyBases[baseIndex].cargo[baseItemIndex].protoIndex
    itemName = itemsList[itemIndex].name
    price = skyBases[baseIndex].cargo[baseItemIndex].price
    if eventIndex > -1 and eventsList[eventIndex].eType == doublePrice and
        eventsList[eventIndex].itemIndex == itemIndex:
      price = price * 2
  else:
    itemIndex = traderCargo[baseItemIndex].protoIndex
    itemName = itemsList[itemIndex].name
    price = traderCargo[baseItemIndex].price
  let buyAmount = amount.parseInt
  var cost: Natural = buyAmount * price
  countPrice(price = cost, traderIndex = traderIndex)
  if freeCargo(amount = cost - (itemsList[itemIndex].weight * buyAmount)) < 0:
    raise newException(exceptn = NoFreeCargoError, message = "")
  let moneyIndex2 = findItem(inventory = playerShip.cargo,
      protoIndex = moneyIndex)
  if moneyIndex2 == -1:
    raise newException(exceptn = NoMoneyError, message = itemName)
  if cost > playerShip.cargo[moneyIndex2].amount:
    raise newException(exceptn = NotEnoughMoneyError, message = itemName)
  updateCargo(ship = playerShip, cargoIndex = moneyIndex2, amount = -cost)
  if baseIndex > 0:
    updateBaseCargo(protoIndex = moneyIndex, amount = cost)
  else:
    traderCargo[0].amount = traderCargo[0].amount + cost
  if baseIndex > 0:
    updateCargo(ship = playerShip, protoIndex = itemIndex, amount = buyAmount,
        durability = skyBases[baseIndex].cargo[baseItemIndex].durability, price = price)
    updateBaseCargo(cargoIndex = baseItemIndex.cint, amount = -buyAmount,
        durability = skyBases[baseIndex].cargo[baseItemIndex].durability)
    gainRep(baseIndex = baseIndex, points = 1)
  else:
    updateCargo(ship = playerShip, protoIndex = itemIndex, amount = buyAmount,
        durability = traderCargo[baseItemIndex].durability, price = price)
    traderCargo[baseItemIndex].amount = traderCargo[baseItemIndex].amount - buyAmount
    if traderCargo[baseItemIndex].amount == 0:
      traderCargo.delete(baseItemIndex)
  gainExp(amount = 1, skillNumber = talkingSkill, crewIndex = traderIndex)
  let gain = (buyAmount * price) - cost
  addMessage(message = "You bought " & $buyAmount & " " & itemName & " for " &
      $cost & " " & moneyName & "." & (if gain == 0: "" else: "You " & (
      if gain > 0: "gain " else: "lost ") & $(gain.abs) & " " & moneyName &
      " compared to the base price."), mType = tradeMessage)
  if baseIndex == 0 and eventIndex > -1:
    eventsList[eventIndex].time = eventsList[eventIndex].time + 5
  updateGame(minutes = 5)

# Temporary code for interfacing with Ada

proc generateAdaTraderCargo(protoIndex: cint) {.raises: [], tags: [], exportc.} =
  try:
    generateTraderCargo(protoIndex = protoIndex)
  except KeyError:
    discard

proc sellAdaItems(itemIndex: cint; amount: cstring): cstring {.raises: [],
    tags: [WriteIOEffect, RootEffect], exportc.} =
  try:
    sellItems(itemIndex = itemIndex.Natural - 1, amount = $amount)
    return "".cstring
  except Exception as e:
    return ($e.name & " " & e.msg).cstring

proc buyAdaItems(baseItemIndex: cint; amount: cstring): cstring {.raises: [],
    tags: [WriteIOEffect, RootEffect], exportc.} =
  try:
    buyItems(baseItemIndex = baseItemIndex.Natural - 1, amount = $amount)
    return "".cstring
  except Exception as e:
    return ($e.name & " " & e.msg).cstring
