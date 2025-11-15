# Inline Documentation Guide for cyclops.vim

This document provides detailed explanations for the key functions in cyclops.vim that would benefit from inline comments.

## autoload/_op_/op.vim

### ComputeMapCallback()
```vim
" Main entry point for operator execution
" Called via <cmd>call _op_#op#ComputeMapCallback()<cr> from public API
"
" Responsibilities:
" 1. Run ComputeMapOnStack() to probe expression and hijack input
" 2. Store the completed operator handle for repeat functionality
" 3. For top-level operators: execute via feedkeys() with modifiers
" 4. For nested operators: execution handled by parent
"
" Stack depth == 1: Top-level operator
" Stack depth > 1: Nested operator (called by another operator)
```

### ComputeMapOnStack(handle)
```vim
" Execute operator with input hijacking
"
" For top-level operators (depth == 1):
" - Steals typeahead to detect ambiguous map chars
" - Probes expression to detect if input needed
" - Hijacks input if needed
" - Stores handle
"
" For nested operators (depth > 1):
" - Sets up parent call tracking
" - Uses inputsave/restore to preserve parent's input state
" - Updates parent's expression after completion
```

### ProbeExpr(expr, type)
```vim
" Test an expression to determine its mode without side effects
"
" Process:
" 1. Push stack frame for this probe
" 2. Save complete editor state (cursor, undo, buffer, visual)
" 3. Set timeouts=0, iminsert=1, belloff+=error,esc
" 4. feedkeys(expr + probe_char + escape_sequence, 'tx!')
" 5. HijackProbeMap() captures resulting mode in s:hijack
" 6. Restore complete editor state
" 7. Pop stack frame
"
" The 't' flag prevents cursor movement at end of buffer from breaking probe
" The probe character (×) triggers HijackProbeMap() which records mode()
```

### HijackInput(handle)
```vim
" Collect user input for an operator that needs it
"
" Input sources (handle.expr.input_source):
" - 'cache': Use stored input from handle.expr.inputs (for repeat)
" - 'user': Interactive input with visual feedback
" - 'typeahead': Fast typing, consume from keyboard buffer
"
" Flow for 'user' input:
" 1. While in operator-pending/insert/command mode:
"    a. Get character from user (with highlights and echo)
"    b. Add to input_stream
"    c. Probe again to check if operator complete
" 2. When probe shows normal mode, input is complete
" 3. Store input in s:inputs array for nested operator support
"
" Returns: Complete input string for this operator
```

### GetCharFromUser_*(handle)
```vim
" Mode-specific user input collection with visual feedback
"
" _i (insert mode):
" - Feed current input to buffer to show what user typed
" - Highlight cursor position
" - Get character
" - Restore state
"
" _no (operator-pending/normal):
" - Echo "Operator Input:" + current input
" - Highlight visual selection if applicable
" - Highlight cursor
" - Get character
"
" _c (command mode):
" - Echo command-line prompt + input
" - If incsearch enabled, highlight matches
" - Get character
"
" All modes support <bs> to erase incorrect input
" Interrupt (<c-c> or <esc>) throws exception to abort
```

### ParentCallInit(handle)
```vim
" Determine which keys in parent operator triggered this nested operator
"
" Problem: When operator B is called by operator A, we need to know which
" exact keys in A's expression invoked B so we can replace them with B's
" full expanded expression.
"
" Solution:
" - calling_expr = parent.reduced
" - Remove typeahead from end (that's not executed yet)
" - Remove parent.reduced_so_far from start (already processed)
" - What remains is the call that triggered us
"
" Example:
" - Parent has reduced='<plug>Dsurround" foo'
" - Parent reduced_so_far='<plug>D'
" - Typeahead='foo'
" - Calling expr='surround"' (this is what called us)
```

### ParentCallUpdate(handle)
```vim
" Replace parent's calling keys with child's full expression
"
" After nested operator completes:
" - Find parent_call in parent.reduced
" - Replace it with our full expression (init.op + expr.reduced)
" - Update parent.reduced_so_far
"
" Example:
" - Parent reduced='<plug>Dsurround" foo'
" - Our parent_call='surround"'
" - Our full expr='s"' (after reduction)
" - Parent reduced becomes='<plug>Ds" foo'
```

### StoreHandle(handle)
```vim
" Save operator handle for repeat functionality
"
" Prepares handle for storage:
" - Deep copy to avoid mutations
" - Add expr.inputs array with all collected input
" - For operands: store only their own input
" - For operators: store all nested inputs
" - Remove 'stack' key (not needed for storage)
" - Store in s:handles[handle_type]
"
" The stored handle contains everything needed to repeat the operation
```

### ExprWithModifiers(expr, mods, opts, [op])
```vim
" Apply count and register to an expression
"
" If accepts_count:
"   count=3 → '3' + register + op + expr
" If !accepts_count:
"   count=3 → repeat(register + op + expr, 3)
"
" Register is always prepended as '"r' if accepts_register
" Op (operator key) is prepended if in operator-pending mode
"
" Example:
" - expr='fa', count=2, register='a', accepts_count=1
" - Result: '2"afa'
"
" - expr='<c-w>>', count=3, accepts_count=0
" - Result: '<c-w>><c-w>><c-w>>'
```

### StealTypeahead() / StealTypeaheadTruncated()
```vim
" Read keyboard buffer without consuming it for command execution
"
" StealTypeahead():
" - Read all available typeahead
" - Used when we need complete typeahead
" - Throws error if > max_input_size (prevents infinite loops)
"
" StealTypeaheadTruncated():
" - Read typeahead but stop after max_trunc_esc consecutive escapes
" - Used for ambiguous map detection
" - Prevents reading too much on abort
"
" Both functions read from getcharstr(1) and must feedkeys() it back
" The 'i' flag inserts at front of typeahead queue
```

## autoload/_op_/dot.vim

### ComputeMapCallback(dummy)
```vim
" Execute dot operator and set up repeat mechanism
"
" Process:
" 1. Restore entry state (cursor/visual from when operator was invoked)
" 2. Call _op_#op#ComputeMapCallback() to execute
" 3. If successful: set &operatorfunc = RepeatCallback
" 4. If failed: set &operatorfunc = ExceptionCallback
"
" The dummy parameter is required by Vim's operatorfunc interface
" Vim's g@ operator calls operatorfunc with motion type, which we ignore
```

### RepeatCallback(dummy)
```vim
" Called when . is pressed to repeat last dot operation
"
" Process:
" 1. Restore repeat entry state (cursor from when . was pressed)
" 2. feedkeys() stored expression with new count/register
" 3. Set &operatorfunc back to this function for next repeat
"
" The stored handle contains expr.reduced with all input captured
" Modifiers (count/register) come from repeat_mods, not original mods
```

### RestoreRepeatEntry(handle)
```vim
" Set up cursor/visual state for repeat operation
"
" Mode combinations:
" - init=normal, repeat=normal: Set cursor to repeat position
" - init=visual, repeat=normal: Recreate visual selection at repeat position
" - init=visual, repeat=visual: Use gv to restore last visual selection
"
" For visual→normal repeat, shifts the visual selection:
" - Original selection was from v mark to . mark
" - New selection is same size/shape but at new cursor position
" - Uses ShiftPos() to compute vector offset
```

### ShiftPos(point, v_beg, v_end)
```vim
" Compute position shifted by a vector
"
" Math: point + (v_end - v_beg)
" Uses virtual columns for proper tab/multibyte handling
" Returns position in getpos() format [bufnum, lnum, col, off]
```

## autoload/_op_/pair.vim

### Initcallback(handle, pair, dir)
```vim
" Set up pair operator handle
"
" Stores:
" - pair.orig: The original [forward, backward] pair
" - pair.reduced: ['', ''] - will be filled as directions are used
" - pair.id: 0 for 'next', 1 for 'prev' (index into pair arrays)
"
" Lazy evaluation: Only compute direction when actually used
```

### PairRepeatMap(dir)
```vim
" Called when ; or , is pressed
"
" dir: 'next' or 'prev' (from which key was pressed)
"
" Process:
" 1. Get stored handle
" 2. InitRepeatCallback() to compute actual direction based on:
"    - init_id: Original direction when first used
"    - Current dir: 'next' or 'prev'
" 3. If that direction's reduced expr not yet computed:
"    - Run ComputeMapCallback() with cached input
" 4. Else:
"    - Run RepeatCallback() to execute stored expr
"
" Example: Press fa, then ;, then ,
" - fa: init_id=0 (next), reduced[0]='fa'
" - ;: dir='next', id=0, use reduced[0]='fa'
" - ,: dir='prev', id=1, compute reduced[1]='Fa' with cached input 'a'
```

### InitRepeatCallback(handle, dir)
```vim
" Determine which direction ID to use for repeat
"
" Logic:
" - init_id = original direction (0=next, 1=prev)
" - If dir=='next': use init_id
" - If dir=='prev': use !init_id (flip direction)
"
" Stores in repeat.id for use by Repeat/ComputeMapCallback
" Also stores repeat.init_id to remember original for future repeats
```

## autoload/_op_/stack.vim

### Init(init_func)
```vim
" Initialize or reset the operator stack
"
" Called at start of each top-level operator execution
"
" If depth > 0 and exception exists:
" - Clear stack (previous operator failed)
"
" If depth == 0:
" - Call init_func() to reset script variables
" - Clear exception
" - Reset stack_id counter
" - Clear debug stack
" - Initialize debug log
" - Push 'init' frame
"
" Returns: Top frame (handle for this operator)
```

### Push(type, msg) / Pop(stack_id, msg)
```vim
" Stack frame management
"
" Push:
" - Increment stack_id (unique ID for this frame)
" - Create frame with level and id
" - Add to stack (and debug_stack if enabled)
" - Log with arrows showing stack growth
"
" Pop:
" - Log with arrows showing stack shrinkage
" - Remove top frame
"
" Stack frames form a tree of nested operator calls
" Each frame contains operator state, not just a function call frame
```

## autoload/_op_/init.vim

### RegisterNoremap(map)
```vim
" Create <plug> wrapper for literal keys
"
" Creates: <plug>(op#_noremap_{map}) → {map}
" Example: RegisterNoremap('dd') creates
"   noremap <plug>(op#_noremap_dd) dd
"
" This allows literal keys to be treated like named mappings
" Only creates if doesn't already exist (idempotent)
"
" Returns: "\<plug>(op#_noremap_" .. map .. ')'
"   Note: Uses key codes, not string (for feedkeys)
```

### RegisterMap(mapping_type, map)
```vim
" Create <plug> wrapper that preserves existing mapping
"
" Process:
" 1. Verify mapping exists (AssertSameRHS)
" 2. Create temporary <plug> mapping
" 3. Get maparg() info for both <plug> and original
" 4. Copy original's RHS but use <plug>'s LHS
" 5. Use mapset() to create the hybrid mapping
"
" Example: RegisterMap('nmap', '<plug>Dsurround')
"   Creates: <plug>(op#_nmap_<plug>Dsurround)
"   Which behaves exactly like <plug>Dsurround
"
" This allows cyclops to wrap and track existing mappings
```

## autoload/_op_/utils.vim

### GetState() / RestoreState()
```vim
" State capture/restore for side-effect-free probing
"
" GetState() captures:
" - winid: Which window we're in
" - win: View state (winsaveview - cursor, topline, etc.)
" - bufnr: Which buffer
" - undo_pos: Position in undo tree (undotree()['seq_cur'])
" - v_state: Visual mode state (GetVisualState)
"
" RestoreState() restores in order:
" 1. Window (win_gotoid)
" 2. Buffer
" 3. Undo position (undo N)
" 4. Visual state
" 5. View (winrestview)
"
" This makes probes completely transparent to the user
```

### GetVisualState() / RestoreVisualState()
```vim
" Visual mode state management
"
" GetVisualState() returns:
"   [mode(), '< mark, '> mark, visualmode(), 'v mark, '. mark]
"
" These 6 pieces fully describe a visual selection:
" - Current mode (v/V/)
" - Last visual selection marks (for gv)
" - Visual mode type
" - Start and end of current selection
"
" RestoreVisualState():
" 1. Set visualmode for gv (enter/exit that mode)
" 2. Set '< and '> marks
" 3. If was in visual mode:
"    a. Move to start position
"    b. Enter visual mode
"    c. Move to end position
"
" The selectmode save/restore prevents entering select mode
```

## autoload/_op_/log.vim

### Log(...)
```vim
" Add timestamped debug log entry
"
" Only logs if g:cyclops_debug_log_enabled = 1
"
" Format: [time_ms] [depth] [arg1 padded] [arg2 padded] [arg3+]
"
" - time_ms: Milliseconds since operation start
" - depth: Stack depth (0-9 or -)
" - Arguments padded to columns for alignment
"
" Example log line:
"   "   123   2  ComputeMapCallback   (n|no)         expr=/foo"
"    [time][lvl][function name....... ][modes][message]
```

### PModes(kind)
```vim
" Format mode strings for logging
"
" kind=0: (current_mode|)
" kind=1: (|hijack_mode)
" kind=2: (current_mode|hijack_mode)
"
" Modes abbreviated:
" - 'consumed' → 'cns'
" - empty → '-'
"
" Shows both user-visible mode and operator's internal state
" Example: (n|i) means in normal mode but operator is in insert mode
```

### ToPrintable(value)
```vim
" Convert control characters to readable form
"
" <nul>, <c-a>, <bs>, <tab>, <cr>, <esc>, etc.
" Also handles <plug> and <cmd> special keys
"
" Used for displaying feedkeys() arguments in logs
" Makes debugging much easier than seeing raw binary
```

## Key Data Structures

### Handle (operator state)
```vim
{
  'stack': {
    'level': 0,      " Depth in stack (0=top-level)
    'id': 42         " Unique ID for this execution
  },
  'init': {
    'handle_type': 'dot',     " Type: 'op', 'dot', or 'pair'
    'mode': 'n',              " Entry mode when operator triggered
    'op_type': 'operator',    " 'operator' or 'operand'
    'op': ''                  " Operator key if in operator-pending mode
  },
  'mods': {
    'count1': 1,     " Count (v:count1)
    'register': '"'  " Register (v:register)
  },
  'opts': {
    'accepts_count': 1,
    'accepts_register': 1,
    'consumes_typeahead': 0,
    'silent': 1
  },
  'expr': {
    'orig': '/',           " Original expression passed to op#Noremap()
    'reduced': '/foo',     " After reduction (probing + input)
    'reduced_so_far': '/', " For nested ops: how much of parent processed
    'input_source': 'user'," 'user', 'typeahead', or 'cache'
    'op_input_id': 3,      " Index in s:inputs where our input is stored
    'inputs': ['foo']      " (Only in stored handles) All input collected
  },
  'dot': {              " (Only for dot operators)
    'mode': 'n',
    'curpos': [0, 1, 1, 0]
  },
  'marks': {            " (Only for dot operators)
    '.': [0, 1, 1, 0],
    'v': [0, 1, 1, 0]
  },
  'pair': {             " (Only for pair operators)
    'orig': ['f', 'F'],
    'reduced': ['fa', ''],  " Lazy evaluation
    'id': 0                  " Current direction
  },
  'repeat': {           " (Only during repeat operations)
    'mode': 'n',
    'curpos': [0, 5, 10, 0],
    'init_id': 0        " (pair only) Original direction
  },
  'repeat_mods': {      " (Only during repeat)
    'count1': 2,
    'register': 'a'
  },
  'parent_call': '<plug>D'  " (Only for nested operators)
}
```

### s:hijack (probe result)
```vim
{
  'hmode': 'no',      " Mode after expression executed
  'cmd': '',          " Command-line content if in command mode
  'cmd_type': ''      " Command type if in command mode ('/', ':', etc.)
}
```

This state is captured by HijackProbeMap() during probe execution
Used to determine if operator needs more input
