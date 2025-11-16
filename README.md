# cyclops.vim

A utility for building repeatable operators in Vim

## Features

* Build or extend operators that support dot `.` or pair `;` `,` repeating
* No changes needed to existing mappings, designed to work with any mapping
* Dot repeat does not interfere with Vim's native dot repeat functionality
* Operator input is interactive! Use the backspace key to erase incorrect input
* No macro recording used, doesn't interfere with user macros

## What it does

This plugin expands the vim notion of an operator. Instead of being limited to
the built-in operators like `d`, `c`, `y`, etc, any mapping can be treated as an
operator, including maps ending in input or search modes (such as 'i' or '/').

Operators are simply defined, for example:

``` vim
nmap <expr> / dot#Noremap('/')
```

When the operator is executed, cyclops.vim records the input and saves it for
later use. Since this is defined with `dot#` it is a dot operator, pressing `.`
will repeat the last execution of the operator, including all user input. For
example, if you type `/foo<CR>`, pressing `.` will search for `foo` again.

Likewise, pair operators can be defined that repeat with `;` and `,`. For
example, pair repeating can be added to window resize commands:

``` vim
nmap <expr> <c-w>> pair#NoremapNext(['<c-w>>', '<c-w><'], {'accepts_register': 0})
nmap <expr> <c-w>< pair#NoremapPrev(['<c-w>>', '<c-w><'], {'accepts_register': 0})
```

Now after executing either `<c-w>>` or `<c-w><`, pressing `;` or `,` will
increase or decrease the window width again. The options dictionary
`{'accepts_register': 0}` specifies that cyclops.vim should not supply the
default register to the mapping.

Defaults are located in `autoload/init/settings.vim` and can be overridden by
defining `g:cyclops_map_defaults` dictionary. Settings work similarly. By default it is
assumed that mappings accept registers and counts. If a mapping is specified to
not accept a count but a count is provided anyway, cyclops.vim repeats
the mapping literally count times.

## Why not a related plugin?

Other plugins for repeating mappings has one or more of the following
limitations:

* requires plugin authors to support your framework
* only work with maps that update the change marks
* only work with movement mappings or mappings without user input
* relies on constantly repeating autocommands or macro recording
* cannot be nested
* no support for visual mode
* not interactive

## Limitations

Performance is not optimal, there is a short, but perceptible, delay when
executing operators with input. This will be improved in future releases.

`iminsert` is enabled while processing mappings, this may have unintended side
effects if language mappings (`:lmap`) are used. A workaround could be
implemented.

This plugin is effectively disabled during macro recording due to unpredictable
behavior when mixing macros and feedkeys

## Sample usage:

Add dot repeat functionality + other goodies to [tpope/vim-surround](https://github.com/tpope/vim-surround)
``` vim
let g:surround_no_mappings = 1
nmap <expr> ds  dot#Map('<Plug>Dsurround')
nmap <expr> cs  dot#Map('<Plug>Csurround')
nmap <expr> cS  dot#Map('<Plug>CSurround')
nmap <expr> ys  dot#Map('<Plug>Ysurround')
nmap <expr> yS  dot#Map('<Plug>YSurround')
nmap <expr> yss dot#Map('<Plug>Yssurround')
nmap <expr> ySs dot#Map('<Plug>YSsurround')
nmap <expr> ySS dot#Map('<Plug>YSsurround')
xmap <expr> s   dot#Map('<Plug>VSurround')
xmap <expr> gs  dot#Map('<Plug>VgSurround')
```

Add pair repeat functionality with `;` `,` to window resizing:
``` vim
call pair#SetMaps('noremap', [['<c-w>>', '<c-w><'], ['<c-w>+', '<c-w>-']], {'accepts_register': 0})
```

Extend dot `d`
```vim
nmap <expr> d dot#Noremap('d')
vmap <expr> d dot#Noremap('d')
```

Create a (dot repeatable) operator from composition: Search for a pattern, then change the whole word:
``` vim
nmap <expr> <plug>(search) op#Noremap('/')
nmap <expr> <plug>(change) op#Noremap('ciw')
nmap <expr> R dot#Map('<plug>(search)<plug>(change)')
```
