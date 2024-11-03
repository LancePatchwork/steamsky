# Copyright © 2024 Bartek Jasicki
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met*:
# 1. Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 3. Neither the name of the copyright holder nor the
# names of its contributors may be used to endorse or promote products
# derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY COPYRIGHT HOLDERS AND CONTRIBUTORS ''AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES *(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT *(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import nk_context, nk_types

# ---------------------
# Procedures parameters
# ---------------------
using ctx: PContext

proc colorPicker*(color: NimColorF;
    format: colorFormat): NimColorF {.raises: [], tags: [].} =
  ## Create the color picker widget
  ##
  ## * color  - the starting color for the widget
  ## * format - the color format for the widget
  ##
  ## Returns Nim color selected by the user in the widget
  proc nk_color_picker(ctx; color: nk_colorf;
      fmt: colorFormat): nk_colorf {.importc, nodecl.}
  let newColor = nk_color_picker(ctx, nk_colorf(r: color.r, g: color.g,
      b: color.b, a: color.a), format)
  result = NimColorF(r: newColor.r, g: newColor.g, b: newColor.b, a: newColor.a)

proc checkBox*(label: string; checked: var bool): bool {.discardable, raises: [
    ], tags: [].} =
  ## Create a Nuklear checkbox widget
  ##
  ## * label   - the text to show with the checkbox
  ## * checked - the state of the checkbox, if true, the checkbox is checked
  ##
  ## Returns true if the state of the checkbox was changed, otherwise false.
  proc nk_checkbox_label(ctx; text: cstring;
      active: var cint): nk_bool {.importc, nodecl.}
  var active: cint = (if checked: 1 else: 0)
  result = nk_checkbox_label(ctx = ctx, text = label.cstring,
      active = active) == nkTrue
  checked = active == 1

proc option*(label: string; selected: bool): bool {.raises: [], tags: [].} =
  ## Create a Nuklear option (radio) widget
  ##
  ## * label    - the text show with the option
  ## * selected - the state of the option, if true the option is selected
  ##
  ## Returns true if the option is selected, otherwise false
  proc nk_option_label(ctx; name: cstring; active: cint): nk_bool {.importc, nodecl.}
  var active: cint = (if selected: 1 else: 0)
  return nk_option_label(ctx = ctx, name = label.cstring, active = active) == nkTrue

proc progressBar*(value: var int; maxValue: int;
    modifyable: bool = true): bool {.discardable, raises: [], tags: [].} =
  ## Create a Nuklear progress bar widget
  ##
  ## * value      - the current value of the progress bar
  ## * maxValue   - the maximum value of the progress bar
  ## * modifyable - if true, the user can modify the value of the progress bar
  ##
  ## Returns true if the value parameter was changed, otherwise false
  proc nk_progress(ctx; cur: var nk_size; max: nk_size;
      modifyable: nk_bool): nk_bool {.importc, nodecl.}
  return nk_progress(ctx = ctx, cur = value, max = maxValue,
      modifyable = modifyable.nk_bool) == nkTrue

