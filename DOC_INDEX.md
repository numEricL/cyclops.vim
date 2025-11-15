# cyclops.vim Documentation Index

Complete documentation for understanding and working with cyclops.vim.

## For Users

**Start here:** [README.md](README.md)
- What cyclops.vim does
- Installation instructions
- Usage examples
- Configuration options

**Quick lookup:** [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - User section
- Common usage patterns
- Configuration snippets
- Debugging commands

## For Developers

### Getting Started (Read in Order)

1. **[README.md](README.md)** ← Start here to understand what the plugin does
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** ← Core concepts and system design
3. **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** ← Developer section for quick lookups
4. **[INLINE_DOCS.md](INLINE_DOCS.md)** ← Detailed function reference
5. **[DEVELOPERS.md](DEVELOPERS.md)** ← Contributing guide and best practices

### Documentation Overview

#### [ARCHITECTURE.md](ARCHITECTURE.md) - System Design
**Read this to understand HOW the plugin works**

Contents:
- Core concepts (probe, hijack, stack, storage)
- File structure and responsibilities
- Key algorithms and data flow
- Design patterns and decisions
- Performance considerations
- Known limitations

Best for:
- Understanding the overall architecture
- Learning the probe mechanism
- Understanding nested operator handling
- Seeing execution flow diagrams

#### [INLINE_DOCS.md](INLINE_DOCS.md) - Function Reference
**Read this to understand WHAT each function does**

Contents:
- Detailed documentation for every major function
- Parameter descriptions
- Return values
- Implementation notes
- Data structure formats
- Code examples

Best for:
- Understanding specific function behavior
- Debugging issues
- Modifying existing functions
- Learning implementation details

#### [DEVELOPERS.md](DEVELOPERS.md) - Contributing Guide
**Read this to understand HOW to work with the code**

Contents:
- Quick start for developers
- Debugging workflows
- Common development tasks
- Code style and conventions
- Testing strategies
- Common pitfalls
- File organization

Best for:
- Setting up development environment
- Learning how to add features
- Understanding testing approach
- Contributing changes

#### [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Quick Lookup
**Read this when you need quick answers**

Contents:
- Common usage patterns
- Configuration examples
- Key file list in reading order
- Core concepts summary
- Function call flow diagrams
- Testing checklist
- Troubleshooting guide

Best for:
- Quick lookups during development
- Remembering syntax
- Debugging common issues
- Testing workflows

## Documentation by Topic

### Understanding the System

| Topic | Best Resource | Section |
|-------|--------------|---------|
| What is cyclops.vim? | README.md | Features |
| How does it work? | ARCHITECTURE.md | Core Concepts |
| Probe mechanism | ARCHITECTURE.md | The Probe Mechanism |
| Input hijacking | ARCHITECTURE.md | Input Hijacking |
| Stack execution | ARCHITECTURE.md | Stack-Based Execution |
| Handle storage | ARCHITECTURE.md | Handle Storage |

### Working with the Code

| Task | Best Resource | Section |
|------|--------------|---------|
| Find a file to read | QUICK_REFERENCE.md | Key Files |
| Understand a function | INLINE_DOCS.md | Function name |
| Add a feature | DEVELOPERS.md | Common Development Tasks |
| Debug an issue | DEVELOPERS.md | Debugging |
| Run tests | QUICK_REFERENCE.md | Testing Checklist |
| Fix a bug | DEVELOPERS.md | Common Pitfalls |

### Specific Features

| Feature | Architecture | Functions | Example |
|---------|-------------|-----------|---------|
| Dot repeat | ARCHITECTURE.md | INLINE_DOCS.md (dot.vim) | README.md |
| Pair repeat | ARCHITECTURE.md | INLINE_DOCS.md (pair.vim) | README.md |
| Nested operators | ARCHITECTURE.md (Nested Handling) | INLINE_DOCS.md (ParentCall*) | N/A |
| Visual feedback | ARCHITECTURE.md | INLINE_DOCS.md (GetCharFromUser*) | N/A |

## Quick Navigation

### By Persona

**I want to use the plugin:**
1. [README.md](README.md) for overview
2. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for configuration

**I want to understand how it works:**
1. [ARCHITECTURE.md](ARCHITECTURE.md) for concepts
2. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for diagrams

**I want to fix a bug:**
1. [DEVELOPERS.md](DEVELOPERS.md) for debugging
2. [INLINE_DOCS.md](INLINE_DOCS.md) for function details
3. [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for common issues

**I want to add a feature:**
1. [DEVELOPERS.md](DEVELOPERS.md) for development tasks
2. [ARCHITECTURE.md](ARCHITECTURE.md) for design patterns
3. [INLINE_DOCS.md](INLINE_DOCS.md) for similar implementations

**I want to contribute:**
1. [DEVELOPERS.md](DEVELOPERS.md) for contributing guide
2. [ARCHITECTURE.md](ARCHITECTURE.md) for design decisions

### By File Type

**Markdown Documentation:**
- `README.md` - User guide
- `ARCHITECTURE.md` - System design
- `INLINE_DOCS.md` - Function reference
- `DEVELOPERS.md` - Developer guide
- `QUICK_REFERENCE.md` - Quick lookup
- `DOC_INDEX.md` - This file

**Vim Script Files:**
- `plugin/cyclops.vim` - Entry point
- `autoload/op.vim` - Public API (basic operators)
- `autoload/dot.vim` - Public API (dot repeat)
- `autoload/pair.vim` - Public API (pair repeat)
- `autoload/_op_/op.vim` - Core engine
- `autoload/_op_/dot.vim` - Dot repeat implementation
- `autoload/_op_/pair.vim` - Pair repeat implementation
- `autoload/_op_/stack.vim` - Stack management
- `autoload/_op_/init.vim` - Validation and registration
- `autoload/_op_/utils.vim` - State management utilities
- `autoload/_op_/log.vim` - Debug logging
- `autoload/_op_/init/settings.vim` - Configuration

## Learning Paths

### Path 1: Understanding the Architecture (Recommended First)

```
README.md
   ↓
ARCHITECTURE.md (Core Concepts)
   ↓
ARCHITECTURE.md (File Structure)
   ↓
ARCHITECTURE.md (Key Algorithms)
   ↓
QUICK_REFERENCE.md (Function Call Flow)
   ↓
Read actual code with INLINE_DOCS.md as reference
```

### Path 2: Hands-On Development

```
README.md
   ↓
DEVELOPERS.md (Quick Start)
   ↓
QUICK_REFERENCE.md (Key Files)
   ↓
Read plugin/cyclops.vim
   ↓
Read autoload/op.vim, dot.vim, pair.vim
   ↓
ARCHITECTURE.md (to understand what you just read)
   ↓
Read autoload/_op_/op.vim with INLINE_DOCS.md
```

### Path 3: Fixing a Specific Issue

```
DEVELOPERS.md (Debugging section)
   ↓
QUICK_REFERENCE.md (Common Issues)
   ↓
Enable debug logging and reproduce
   ↓
INLINE_DOCS.md (look up functions in log)
   ↓
ARCHITECTURE.md (understand affected subsystem)
   ↓
Fix and test
```

### Path 4: Adding a Feature

```
ARCHITECTURE.md (understand design patterns)
   ↓
DEVELOPERS.md (Adding new features)
   ↓
INLINE_DOCS.md (study similar existing feature)
   ↓
QUICK_REFERENCE.md (testing checklist)
   ↓
Implement, test, document
```

## Documentation Statistics

| File | Lines | Purpose | Audience |
|------|-------|---------|----------|
| README.md | ~110 | User guide | Users |
| ARCHITECTURE.md | ~430 | System design | Developers |
| INLINE_DOCS.md | ~530 | Function reference | Developers |
| DEVELOPERS.md | ~260 | Contributing guide | Developers |
| QUICK_REFERENCE.md | ~350 | Quick lookup | Users & Developers |
| **Total** | **~1680** | **Complete docs** | **All** |

Plus ~1500 lines of actual code = ~3200 lines of documented functionality

## Key Insights by Document

### README.md
- cyclops.vim makes operators repeatable
- Works via input hijacking
- Supports dot (.) and pair (; ,) repeat

### ARCHITECTURE.md
- Probe mechanism: feedkeys + mode detection
- Input hijacking with visual feedback
- Stack-based for nested operators
- Handle storage for repeat operations

### INLINE_DOCS.md
- ProbeExpr() does side-effect-free testing
- HijackInput() has 3 input sources
- ComputeMapCallback() orchestrates execution
- Handles store complete operator state

### DEVELOPERS.md
- Start with public API files
- Enable debug logging for development
- Test with nested operators and edge cases
- Follow existing patterns for new features

### QUICK_REFERENCE.md
- Top-level operators use feedkeys()
- Nested operators update parent
- Probe detects operator completion
- Stack depth determines behavior

## Getting Help

1. **For usage questions:** See README.md
2. **For understanding how it works:** See ARCHITECTURE.md
3. **For specific functions:** See INLINE_DOCS.md
4. **For development setup:** See DEVELOPERS.md
5. **For quick answers:** See QUICK_REFERENCE.md

If still stuck:
- Enable debug logging: `let g:cyclops_debug_log_enabled = 1`
- Run operation
- View log: `:call op#PrintDebugLog()`
- View state: `:call op#PrintScriptVars()`
- Search docs for error message or function name

## Contributing to Documentation

When updating docs:

1. **README.md** - For user-facing features or configuration
2. **ARCHITECTURE.md** - For design decisions or new subsystems
3. **INLINE_DOCS.md** - For function documentation
4. **DEVELOPERS.md** - For development processes or guidelines
5. **QUICK_REFERENCE.md** - For quick lookup examples
6. **DOC_INDEX.md** (this file) - For navigation changes

Keep docs in sync:
- New function → Add to INLINE_DOCS.md
- New feature → Update README.md + ARCHITECTURE.md
- New workflow → Update DEVELOPERS.md
- Common pattern → Add to QUICK_REFERENCE.md

---

**Documentation Version:** 1.0
**Last Updated:** 2024-11-15
**Plugin Version:** Compatible with current cyclops.vim
