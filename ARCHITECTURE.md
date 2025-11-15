# cyclops.vim Architecture Documentation

## Overview

cyclops.vim makes custom Vim operators repeatable using dot (`.`) and pair (`;`, `,`) commands. It works by "hijacking" user input during operator execution and storing it for later replay.

## Core Concepts

### 1. The Probe Mechanism

The plugin's most innovative feature is the "probe" mechanism that determines when an operator needs user input:

1. Execute the operator with a special probe character (×) appended
2. Capture the resulting Vim mode using an `<expr>` mapping
3. If Vim is in operator-pending, insert, or command mode -> needs input
4. If Vim is in normal mode -> operator is complete

The probe is executed inside a try/finally block that:
- Saves editor state (cursor, undo tree, buffer, visual selection)
- Disables timeouts to prevent delays
- Sets `iminsert=1` to activate language mappings for the probe
- Restores all state after probing (making it side-effect free)

### 2. Input Hijacking

When an operator needs input, the plugin:

1. Shows visual feedback (highlights cursor position, displays "Operator Input:")
2. Gets characters from user with `getcharstr()`
3. After each character, runs another probe to check if operator is complete
4. Supports backspace to erase incorrect input
5. Continues until operator reaches normal mode

### 3. Stack-Based Execution

Operators can be nested (e.g., a surround operator that calls search). The plugin uses a stack to track:

- Current operator being executed
- Parent operators in the call chain
- Input collected at each level
- Options and modifiers (count, register) for each level

Each stack frame (handle) contains:
- `stack`: Level and unique ID
- `init`: Handle type ('op', 'dot', 'pair'), mode, operator type
- `mods`: Count and register
- `opts`: Options like accepts_count, accepts_register, etc.
- `expr`: Original expression, reduced expression, input collected
- Type-specific data (dot, pair, parent_call, etc.)

### 4. Handle Storage

After an operator completes, its handle is stored in `s:handles[type]`:
- `s:handles['dot']` - Last dot operator for `.` repeat
- `s:handles['pair']` - Last pair operator for `;` `,` repeat
- `s:handles['op']` - Last basic operator (no repeat)

Handles store all information needed to repeat the operation:
- The reduced expression (with all nested calls resolved)
- All user input collected (in `expr.inputs` array)
- Original mode and cursor position
- Options and modifiers

## File Structure

### Public API Files (`autoload/`)

**`op.vim`** - Basic operators (no repeat capability)
- `op#Map(map, opts)` - Wrap existing mapping
- `op#Noremap(map, opts)` - Wrap literal keys
- Used when you only need input hijacking, not repeat

**`dot.vim`** - Dot-repeatable operators
- `dot#Map(map, opts)` - Wrap mapping with dot-repeat
- `dot#Noremap(map, opts)` - Wrap keys with dot-repeat
- `dot#SetMaps(type, maps, opts)` - Batch create
- Uses Vim's `g@` operator and `&operatorfunc` for repeat mechanism

**`pair.vim`** - Pair-repeatable operators
- `pair#MapNext/Prev(pair, opts)` - Wrap mappings with pair-repeat
- `pair#NoremapNext/Prev(pair, opts)` - Wrap keys with pair-repeat
- `pair#SetMaps(type, pairs, opts)` - Batch create
- Tracks direction ('next'/'prev') and original direction for `;` `,`

### Internal Implementation (`autoload/_op_/`)

**`op.vim`** (614 lines) - Core operator logic
- `StackInit()` - Initialize/get stack frame
- `InitCallback()` - Set up operator handle with mode, modifiers, options
- `ComputeMapCallback()` - Main entry point after operator is triggered
- `ProbeExpr()` - Test expression with probe character, capture mode
- `HijackInput()` - Get user input with visual feedback
- `ExprWithModifiers()` - Apply count/register to expression
- Functions to get input from user in different modes (normal, insert, command)
- Typeahead management functions
- Exception handling

**`dot.vim`** (148 lines) - Dot-repeat implementation
- `InitCallback()` - Store cursor position and marks
- `ComputeMapCallback()` - Execute operator via g@
- `RepeatMap()` - Called when `.` is pressed
- `RepeatCallback()` - Replay the stored operation
- `InitRepeatCallback()` - Capture repeat context (mode, cursor)
- Functions to restore cursor/visual state for repeat

**`pair.vim`** (79 lines) - Pair-repeat implementation
- `Initcallback()` - Store pair info and direction
- `ComputeMapCallback()` - Execute and store reduced expression
- `PairRepeatMap()` - Called when `;` or `,` is pressed
- `RepeatCallback()` - Replay the operation
- `InitRepeatCallback()` - Track original vs current direction
- Lazy evaluation: computes second direction only when needed

**`stack.vim`** (96 lines) - Stack management
- `Init()` - Initialize stack if needed
- `Push/Pop()` - Add/remove frames
- `Top/GetPrev()` - Access frames
- `GetException/SetException()` - Error tracking
- Debug stack support

**`init.vim`** (102 lines) - Validation and registration
- `AssertExprMap()` - Verify called from `<expr>` context
- `AssertSameRHS()` - Verify multi-mode maps are consistent
- `AssertPair()` - Verify pair structure
- `ExtendDefaultOpts()` - Merge user opts with defaults
- `RegisterNoremap()` - Create `<plug>` wrapper for literal keys
- `RegisterMap()` - Create `<plug>` wrapper for existing mapping

**`utils.vim`** (89 lines) - State management utilities
- `GetState/RestoreState()` - Capture/restore editor state
- `GetVisualState/RestoreVisualState()` - Visual mode handling
- `GetType()` - Human-readable type names

**`log.vim`** (137 lines) - Debug logging
- `Log()` - Add timestamped log entry
- `PrintDebugLog()` - Display log
- `PrintScriptVars()` - Display all state
- `PModes()` - Format mode strings
- `ToPrintable()` - Convert control characters to readable form

**`init/settings.vim`** (27 lines) - Configuration defaults
- Defines all `g:cyclops_*` settings
- Sets default map options

## Key Algorithms

### Operator Execution Flow

```
1. User triggers operator (e.g., presses '/')
2. op#Noremap('/') called (in <expr> context)
3. Returns: <esc><cmd>call ComputeMapCallback()<cr>
4. ComputeMapCallback():
   a. ProbeExpr('/×') to test if needs input
   b. If operator-pending/insert/command mode:
      - HijackInput() gets characters from user
      - After each char, probe again to check if complete
   c. Store handle with collected input
   d. feedkeys() the complete expression with count/register
```

### Dot Repeat Flow

```
1. User presses '.'
2. dot#RepeatMap() called
3. If in visual mode, returns '<esc>.'
4. Otherwise returns '.' (native dot)
5. Vim's native dot triggers &operatorfunc
6. RepeatCallback():
   a. Restore cursor/visual state
   b. feedkeys() stored expression with new count/register
```

### Pair Repeat Flow

```
1. User presses ';' or ','
2. pair#PairRepeatMap('next' or 'prev') called
3. Determines direction based on:
   - Original direction when operator was first used
   - Current direction (next vs prev)
4. If that direction not yet computed:
   - Run ComputeMapCallback() with cached input
5. Otherwise:
   - feedkeys() the stored expression for that direction
```

### Nested Operator Handling

```
1. Operator A calls operator B (e.g., surround calls search)
2. Stack depth > 1 detected
3. ParentCallInit():
   - Deduce which keys in parent triggered this operator
   - Update parent's expr.reduced_so_far
4. Operator B completes normally
5. ParentCallUpdate():
   - Substitute the calling keys in parent with full expression
   - Parent continues execution
```

## Design Patterns

### Expression Reduction

Operators start with an "orig" expression and build a "reduced" expression:
- `orig`: The original mapping/keys (e.g., `<plug>Dsurround`)
- `reduced`: After probing and input, the final executable form (e.g., `ds"`)
- `reduced_so_far`: During nested calls, tracks what's been processed

### Input Sources

Input can come from three sources:
- `'user'`: Interactive input with visual feedback
- `'typeahead'`: From keyboard buffer (fast typing)
- `'cache'`: From stored handle (for repeat operations)

The source is set in `expr.input_source` and determines how HijackInput() behaves.

### Lazy Pair Evaluation

For pair operators, only the direction actually used is computed initially:
- Press `f`x → computes forward direction, stores input "x"
- Press `;` → uses stored forward direction
- Press `,` → NOW computes backward direction with cached "x"

This avoids unnecessary work and handles cases where directions differ.

### Mode Detection

The probe character's mode reveals operator state:
- `'no'`, `'nov'`, `'noV'` - Operator-pending (needs motion/text object)
- `'i'` - Insert mode (e.g., after `i` or `a`)
- `'c'` - Command mode (e.g., after `/` or `:`)
- `'n'` - Normal mode (operator complete)
- `'consumed'` - Probe char was eaten by command

Modes with `-l` suffix indicate language mappings are active.

## Error Handling

### Probe Exceptions

If an exception occurs during probing:
- Set `s:probe_exception.status = true`
- Store exception and expression that caused it
- After probe returns, check and throw error
- This prevents silent failures during state restoration

### Stack Exceptions

If an operator fails:
- Exception stored in `s:exception` and `s:throwpoint`
- Stack is cleared on next operator
- For dot-repeat, stores exception handler as &operatorfunc
- Shows "last dot operation failed" message

### Graceful Degradation

During macro recording:
- All cyclops functions return the original mapping unchanged
- Prevents unpredictable feedkeys() interactions with macros
- Allows normal Vim repeat behavior to work

## Performance Considerations

### Probe Overhead

Each probe operation:
- Saves/restores full editor state
- Executes the expression once
- Most expensive operation in the plugin

Optimization: After initial probe, subsequent character-by-character probes reuse some state.

### Stack Depth

Nested operators increase complexity linearly. Deep nesting (>3 levels) may be slow due to multiple probes and state saves/restores.

### Input Collection

Interactive input is fast - visual feedback and character collection add minimal overhead. Typeahead consumption is faster as it skips visual feedback.

## Testing Methodology

The plugin is self-contained and can be tested by:

1. Enable debug logging: `let g:cyclops_debug_log_enabled = 1`
2. Execute operations
3. View log: `call op#PrintDebugLog()`
4. View state: `call op#PrintScriptVars()`

Common test patterns:
- Dot repeat after various operators
- Nested operator calls
- Visual mode operations
- Mode transitions
- Count and register handling
- Pair repeat direction changes

## Limitations

1. **`iminsert` side effects**: Language mappings (`:lmap`) may interfere during probe
2. **Macro compatibility**: Plugin disabled during macro record/playback
3. **Mode support**: Only n, v, V, no, nov, noV modes fully supported
4. **Chained operands**: Not yet implemented (e.g., `d2f` where `2f` is an operand)
5. **Terminal mode**: Limited support for terminal (t) mode

## Extension Points

To add new operator types:
1. Create new public API file in `autoload/`
2. Call `_op_#op#InitCallback()` with unique handle type
3. Implement `ComputeMapCallback()` for execution
4. Implement `RepeatMap()` and `RepeatCallback()` for repeat
5. Store handle in `s:handles[your_type]`

Example: A triple-repeat operator that repeats on `;;` could reuse most of the pair logic with a different repeat key sequence.
