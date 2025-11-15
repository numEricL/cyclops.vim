# Quick Reference - cyclops.vim

## For Plugin Users

### Basic Usage

```vim
" Make search dot-repeatable
nmap <expr> / dot#Noremap('/')

" Make surround dot-repeatable
nmap <expr> ds dot#Map('<Plug>Dsurround')
nmap <expr> cs dot#Map('<Plug>Csurround')

" Make window resize pair-repeatable
call pair#SetMaps('noremap', [['<c-w>>', '<c-w><'], ['<c-w>+', '<c-w>-']],
                 \ {'accepts_register': 0})
```

### Configuration

```vim
" Disable default mappings
let g:cyclops_no_mappings = 1

" Enable debug logging
let g:cyclops_debug_log_enabled = 1

" Change max input size
let g:cyclops_max_input_size = 2048

" Custom map defaults
let g:cyclops_map_defaults = {
    \ 'accepts_count': 1,
    \ 'accepts_register': 1,
    \ 'consumes_typeahead': 0,
    \ 'silent': 1,
    \ }
```

### Debugging

```vim
" View debug log
:call op#PrintDebugLog()

" View internal state
:call op#PrintScriptVars()
```

## For Developers

### Key Files (in reading order)

1. `plugin/cyclops.vim` - Entry point
2. `autoload/op.vim` - Public API (basic)
3. `autoload/dot.vim` - Public API (dot-repeat)
4. `autoload/pair.vim` - Public API (pair-repeat)
5. `autoload/_op_/op.vim` - Core engine (614 lines)
6. `autoload/_op_/stack.vim` - Stack management
7. `autoload/_op_/utils.vim` - State utilities

### Core Concepts

**Probe Mechanism:**
```vim
feedkeys(expr + '×' + '<esc><esc><esc>', 'tx!')
" Probe char '×' is mapped to capture mode()
" If mode is 'no', 'i', or 'c' → needs input
" If mode is 'n' → operator complete
" State is saved/restored (no side effects)
```

**Input Hijacking:**
```vim
while in_operator_pending_mode
    char = getcharstr()
    input_stream ..= char
    probe(expr + input_stream)
endwhile
" Shows visual feedback
" Supports backspace
" Stops when operator completes
```

**Handle Structure:**
```vim
handle = {
    'stack': {'level': 0, 'id': 1},
    'init': {'handle_type': 'dot', 'mode': 'n'},
    'expr': {'orig': '/', 'reduced': '/foo', 'inputs': ['foo']},
    'mods': {'count1': 1, 'register': '"'},
    'opts': {...},
    ...
}
```

### Function Call Flow

```
User presses '/'
  ↓
dot#Noremap('/')
  ↓
Returns: <esc>g@_ (or g@ in visual)
  ↓
Vim calls &operatorfunc = _op_#dot#ComputeMapCallback
  ↓
_op_#op#ComputeMapCallback()
  ├─ ProbeExpr('/×')
  │   ├─ Save state
  │   ├─ feedkeys('/×<esc><esc><esc>', 'tx!')
  │   ├─ HijackProbeMap() captures mode → 'c'
  │   └─ Restore state
  ├─ HijackInput()
  │   ├─ Show prompt: "Operator Input:"
  │   ├─ Get 'f' → probe('/f×')
  │   ├─ Get 'o' → probe('/fo×')
  │   ├─ Get 'o' → probe('/foo×')
  │   ├─ Get '<CR>' → probe('/foo<CR>×') → mode 'n'
  │   └─ Return 'foo<CR>'
  ├─ StoreHandle()
  └─ feedkeys('/foo<CR>', 'x!')

User presses '.'
  ↓
dot#RepeatMap() returns '.'
  ↓
Vim's native . calls &operatorfunc
  ↓
_op_#dot#RepeatCallback()
  ├─ Restore cursor position
  ├─ feedkeys('/foo<CR>', 'x!') with new count/register
  └─ Set &operatorfunc to self
```

### Important Patterns

**Stack Depth Detection:**
```vim
if _op_#stack#Depth() == 1
    " Top-level operator
    " Execute via feedkeys()
else
    " Nested operator
    " Update parent and return
endif
```

**Input Source Detection:**
```vim
if handle.expr.input_source ==# 'cache'
    " Use stored input from handle.expr.inputs
elseif handle.expr.input_source ==# 'user'
    " Get interactive input with visual feedback
else  " 'typeahead'
    " Consume from keyboard buffer
endif
```

**Mode Pattern Matching:**
```vim
let operator_hmode_pattern = '\v^(no[vV]?|consumed|i|c|[nv]-l)(-l)?$'
if s:hijack['hmode'] =~# operator_hmode_pattern
    " Operator needs more input
else
    " Operator is complete
endif
```

### Common Debug Commands

```vim
" Enable logging
let g:cyclops_debug_log_enabled = 1

" Run operation
/foo<CR>

" View log
call op#PrintDebugLog()
" Shows: time, stack level, function calls, modes, arguments

" View state
call op#PrintScriptVars()
" Shows: all handles, stack frames, settings

" Clear for next test
let g:cyclops_debug_log_enabled = 0
```

### Testing Checklist

- [ ] Simple operator (e.g., `/foo<CR>`)
- [ ] Dot repeat with count (`3.`)
- [ ] Dot repeat with register (`"a.`)
- [ ] Visual mode operation (`v/foo<CR>`)
- [ ] Nested operators (e.g., vim-surround + search)
- [ ] Pair repeat forward (`;`)
- [ ] Pair repeat backward (`,`)
- [ ] Pair repeat direction change (`fa;;;,,`)
- [ ] Backspace during input
- [ ] Interrupt with `<esc>` or `<c-c>`
- [ ] Fast typing (typeahead)
- [ ] Macro recording (should pass through)

### Probe Mechanics

**Successful Probe (operator complete):**
```
ProbeExpr('dd×')
  mode before: n
  feedkeys('dd×<esc><esc><esc>', 'tx!')
  mode after: n
  hijack_hmode: 'consumed' or 'n'
  → Operator complete, no input needed
```

**Failed Probe (needs input):**
```
ProbeExpr('/×')
  mode before: n
  feedkeys('/×<esc><esc><esc>', 'tx!')
  mode after: c
  hijack_hmode: 'c'
  → Operator waiting for input
```

### Adding New Features

**New operator type:**
1. Create `autoload/myop.vim` with public API
2. Create `autoload/_op_/myop.vim` with implementation
3. Add handle type to `s:handles['myop'] = {}`
4. Implement `InitCallback()` and `ComputeMapCallback()`
5. Implement repeat functions if needed

**New input mode:**
1. Update `s:operator_hmode_pattern`
2. Add `GetCharFromUser_mymode()`
3. Test probe detection
4. Add visual feedback

**New modifier:**
1. Capture in `InitCallback()` from `v:mymodifier`
2. Store in `handle.mods.mymodifier`
3. Apply in `ExprWithModifiers()`
4. Test with repeat operations

## Common Issues

### Operator not repeating
- Check if in `<expr>` mapping: `nmap <expr> ...`
- Verify handle is stored: `call op#PrintScriptVars()`
- Check debug log for errors

### Input hijacking not working
- Verify mode pattern matches: `echo s:hijack['hmode']`
- Check probe detected correct mode
- Ensure visual feedback is shown

### Nested operators failing
- Check stack depth in log
- Verify ParentCallInit/Update logic
- Check typeahead handling

### State not restored
- Verify try/finally in ProbeExpr
- Check undo tree position
- Verify buffer and window restoration

## Performance Tips

- Probe is expensive (state save/restore)
- Minimize probes by using typeahead when available
- Deep copy handles only when storing
- Lazy evaluation (like pair operators)
- Cache results when possible

## Architecture Mantras

1. **Probe before executing** - Know what you're getting into
2. **Save state before probe** - No side effects
3. **Stack for nesting** - Support composability
4. **Store for repeat** - Enable . and ; ,
5. **Visual feedback** - Help the user
6. **Graceful degradation** - Work with macros

---

**See Also:**
- ARCHITECTURE.md - Full system design
- INLINE_DOCS.md - Function reference
- DEVELOPERS.md - Contributing guide
- README.md - User documentation
