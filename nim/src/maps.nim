# Copyright 2022-2023 Bartek thindil Jasicki
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

import types

type SkyCell* = object
  ## Used to store information about the map's cell
  baseIndex*: ExtendedBasesRange ## The index of the sky base located in the cell
  visited*: bool ## If true, the cell was visited by the player
  eventIndex*: int ## Index of the event which happens in the cell
  missionIndex*: int ## Index of the mission which takes place in the cell

var skyMap*: array[MapXRange, array[MapYRange, SkyCell]] ## The list of all map's cells

func normalizeCoord*(coord: var cint; isXAxis: cint = 1) {.gcsafe, raises: [],
    tags: [], exportc.} =
  ## FUNCTION
  ##
  ## Normalize (fix to be in range of) the map's coordinates
  ##
  ## PARAMETERS
  ##
  ## * coord   - The coordinate which will be normalized
  ## * isXAxis - If 1 the coordinate to be normalized is in X axis, otherwise
  ##             it is in Y axis
  ##
  ## RETURNS
  ##
  ## The updated coord argument
  if isXAxis == 1:
    if coord < MapXRange.low:
      coord = MapXRange.low
    elif coord > MapXRange.high:
      coord = MapXRange.high
  else:
    if coord < MapYRange.low:
      coord = MapYRange.low
    elif coord > MapYRange.high:
      coord = MapYRange.high
