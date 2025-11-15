# Developer Documentation for cyclops.vim

This directory contains comprehensive documentation for developers who want to understand or modify cyclops.vim.

## Documentation Files

### [ARCHITECTURE.md](ARCHITECTURE.md)
**High-level system design and algorithms**

Read this first to understand:
- The probe mechanism and how it works
- Input hijacking and visual feedback
- Stack-based execution for nested operators
- Handle storage and repeat functionality
- File structure and module responsibilities
- Key algorithms and design patterns
- Performance considerations and limitations

Start here if you want to understand the overall system design.

### [INLINE_DOCS.md](INLINE_DOCS.md)
**Detailed function-by-function documentation**

Reference guide explaining:
- What each major function does
- Parameters and return values
- Implementation details and edge cases
- Data structure formats
- Examples of function behavior

Use this when diving into specific functions or debugging.

### [README.md](../README.md)
**User documentation**

For end users who want to:
- Understand what cyclops.vim does
- Learn the public API
- See usage examples
- Configure the plugin

## Quick Start for Developers

### Understanding the Code

1. **Start with public API** (`autoload/op.vim`, `autoload/dot.vim`, `autoload/pair.vim`)
   - These are thin wrappers that call into `autoload/_op_/`
   - See what functions users call and what they return

2. **Read ARCHITECTURE.md**
   - Understand the probe mechanism (the core innovation)
   - Learn about input hijacking and stack management
   - See the execution flow diagrams

3. **Study the core engine** (`autoload/_op_/op.vim`)
   - Main functions: `ComputeMapCallback`, `ProbeExpr`, `HijackInput`
   - Use INLINE_DOCS.md as reference
   - Enable debug logging: `let g:cyclops_debug_log_enabled = 1`

4. **Explore specializations** (`autoload/_op_/dot.vim`, `autoload/_op_/pair.vim`)
   - See how dot-repeat and pair-repeat build on the core
   - Understand handle storage and replay

### Debugging

Enable debug logging:
```vim
let g:cyclops_debug_log_enabled = 1
```

View logs after running operators:
```vim
:call op#PrintDebugLog()
```

View current state:
```vim
:call op#PrintScriptVars()
```

### Common Development Tasks

#### Adding a new operator type

1. Create public API file in `autoload/your_operator.vim`
2. Create internal implementation in `autoload/_op_/your_operator.vim`
3. Follow the pattern from `dot.vim` or `pair.vim`:
   - Call `_op_#op#InitCallback()` with your handle_type
   - Implement `ComputeMapCallback()` for execution
   - Implement repeat functions if needed
   - Store handle in `s:handles['your_type']`

#### Modifying the probe mechanism

The probe is defined in `_op_#op#ProbeExpr()`:
- `s:hijack_probe` character is mapped to `s:HijackProbeMap()`
- That function captures `mode(1)` in `s:hijack`
- State is saved/restored around probe execution
- Modify `s:operator_hmode_pattern` to change which modes trigger hijacking

#### Changing input collection

Input collection happens in `_op_#op#HijackInput()`:
- Three input sources: 'user', 'typeahead', 'cache'
- Visual feedback in `GetCharFromUser_*()` functions
- Backspace support in `ProcessStream()`
- Mode detection after each character

#### Extending supported modes

Currently supports: n, v, V, , no, nov, noV, i, c
To add more:
- Update mode detection in `InitCallback()`
- Add mode to `s:operator_hmode_pattern` if needs hijacking
- Implement `GetCharFromUser_newmode()` if needed
- Update `RestoreVisualState()` for visual-like modes

### Testing

Manual testing workflow:
1. Make changes
2. Restart Vim or `:source` the modified file
3. Enable debug logging
4. Execute operators and check behavior
5. Review logs to see execution flow
6. Check stored handles with `op#PrintScriptVars()`

Test cases to cover:
- Simple operators (search, delete, change)
- Nested operators (surround, which calls search)
- Dot repeat with various counts and registers
- Pair repeat in both directions
- Visual mode operations
- Count and register handling
- Error conditions (interrupts, invalid input)

### Code Style

The codebase follows these conventions:
- `_op_#function()` - Internal functions (autoload/_op_/)
- `op#function()` - Public API functions (autoload/)
- `s:function()` - Script-local functions
- `l:var` - Local variables (always prefixed)
- `a:var` - Function arguments (always prefixed)
- `g:var` - Global variables (settings)

Naming:
- Functions are PascalCase or camelCase
- Variables are snake_case
- Constants are UPPER_CASE (rare)
- Internal state uses `s:` script variables

### Common Pitfalls

1. **Forgetting state restoration in probe**
   - Always use try/finally in ProbeExpr()
   - Save state before feedkeys(), restore after

2. **Not handling nested operators**
   - Check stack depth > 1
   - Use ParentCallInit/Update for tracking
   - Don't assume you're top-level

3. **feedkeys() flag confusion**
   - 't' - typed keys (don't expand mappings initially)
   - 'x' - execute now (don't wait for next char)
   - 'i' - insert at head of typeahead
   - '!' - remap characters
   - Wrong flags can break the probe mechanism

4. **Mode detection edge cases**
   - Language mappings add '-l' suffix
   - Operator-pending can be 'no', 'nov', 'noV', or 'no'
   - Some commands consume probe char ('consumed' mode)

5. **Input storage for repeat**
   - Must deep copy handles
   - Must store inputs array
   - Must preserve mode and modifiers
   - Lazy evaluation for pair operators

### Performance Notes

Expensive operations (in order):
1. ProbeExpr() - state save/restore + feedkeys
2. Deep copying handles
3. String manipulation (less critical)

Optimization opportunities:
- Cache probe results when possible
- Lazy evaluation (pair operators do this)
- Avoid probing if typeahead available
- Reuse state captures

### Architecture Decisions

**Why probe instead of mode():**
- mode() shows current mode, not operator's expected mode
- Some operators change mode (i, a, /, :)
- Need to know if operator is "done" or "waiting"
- Probe executes and checks resulting state

**Why hijack instead of getline():**
- Operators can call other operators (nesting)
- Need to support all operator types (not just line-based)
- Visual feedback improves UX
- Backspace support requires intercepting input

**Why stack instead of recursion:**
- Need to track multiple operators simultaneously
- Need to update parent after child completes
- Need to store intermediate state
- Stack provides better debugging visibility

**Why feedkeys() instead of normal!:**
- Mappings need to expand
- Counts and registers need to apply
- Operators can be user-defined
- feedkeys() is more flexible

## Contributing

When contributing:
1. Read ARCHITECTURE.md to understand the system
2. Check INLINE_DOCS.md for function details
3. Add debug logging to your changes
4. Test with debug enabled
5. Update documentation if adding features
6. Include examples in comments

Questions? Issues?
- Check the debug log first
- Review existing operator implementations
- Test with minimal vimrc
- Isolate the problem with small examples

## File Map Reference

```
cyclops.vim/
├── plugin/
│   └── cyclops.vim              # Plugin entry point, default mappings
├── autoload/
│   ├── op.vim                   # Public API: basic operators
│   ├── dot.vim                  # Public API: dot-repeat
│   ├── pair.vim                 # Public API: pair-repeat
│   └── _op_/                    # Internal implementation
│       ├── op.vim               # Core: probe, hijack, execution
│       ├── dot.vim              # Dot-repeat implementation
│       ├── pair.vim             # Pair-repeat implementation
│       ├── stack.vim            # Stack management
│       ├── init.vim             # Validation, registration
│       ├── utils.vim            # State capture/restore
│       ├── log.vim              # Debug logging
│       └── init/
│           └── settings.vim     # Configuration defaults
├── README.md                    # User documentation
├── ARCHITECTURE.md              # System design (read this first)
├── INLINE_DOCS.md               # Function reference
├── DEVELOPERS.md                # This file
└── LICENSE                      # License information
```

## Additional Resources

- `:help cyclops` (if installed)
- GitHub issues for bugs and discussions
- Original README.md for usage examples
- Debug logs for runtime behavior
- `:scriptnames` to verify files are loaded

Happy hacking! 🔧
