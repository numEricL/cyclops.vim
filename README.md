# cyclops.vim

The simplest yet most powerful way to add dot `.` and pair `;` `,` repeat to
any vim/neovim map or operator.

## Features

* Build or extend operators that support dot `.` or pair `;` `,` repeating
* Works with all mappings, with and without input
* Supports dot and pair repeat in visual mode
* Easy to configure: no changes needed to existing mappings
* Dot repeat does not interfere with any other source dot repeat functionality
* Operator input is interactive! Use the backspace key to erase incorrect input

## What it does

cyclops.vim adds repeat functionality to mappings by storing user input (if any)
and resupplying it when the mapping is repeated. This is done through a REPL
pattern, the mapping is continually probed and fed the necessary input until the
mapping completes (reaches normal or visual mode). When the mapping is repeated,
the original input is supplied again ensuring identical behavior.

This effectively expands the notion of an operator. Instead of being limited to
the built-in operators like `d`, `c`, `y`, etc, any mapping can be treated as an
operator, including maps ending in input or search modes (such as 'i' or '/').

Operators are simply defined, for example:

``` vim
nmap <expr> / dot#Noremap('/')
```

Since this is defined with `dot#` it is a dot operator, pressing `.`
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
defining `g:cyclops_map_defaults` dictionary. Settings work similarly. By
default it is assumed that mappings accept registers and counts. If a mapping is
specified to not accept a count but a count is provided anyway, cyclops.vim
repeats the mapping literally count times.

## Why not a related plugin?

Another plugin for repeating mappings may have one or more of the following
limitations:

* requires plugin authors to support its framework
* overrides the default `.` behavior
* only works with maps that update the change marks
* only works with movement mappings or mappings without user input
* no support for visual mode
* cannot be nested

## Limitations

`iminsert` is enabled while processing mappings, this may have unintended side
effects if language mappings (`:lmap`) are used. A workaround could be
implemented.

This plugin is effectively disabled during macro recording due to unpredictable
behavior when mixing macros and feedkeys. All mappings work as normal, but
repeat functionality is disabled.

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
nmap <expr> <c-w>> pair#NoremapNext(['<c-w>>', '<c-w><'], {'accepts_register': 0})
nmap <expr> <c-w>< pair#NoremapPrev(['<c-w>>', '<c-w><'], {'accepts_register': 0})

nmap <expr> <c-w>+ pair#NoremapNext(['<c-w>+', '<c-w>-'], {'accepts_register': 0})
nmap <expr> <c-w>- pair#NoremapPrev(['<c-w>+', '<c-w>-'], {'accepts_register': 0})
```

If the mapping you wish to make repeatable already exists, you can use the
helper function xx#SetMap, for example:

``` vim
"scroll half window with ctrl-hjkl
noremap <c-l> zL
noremap <c-h> zH
noremap <c-j> <c-d>
noremap <c-k> <c-u>
call pair#SetMap('map', ['<c-l>', '<c-h>'])
call pair#SetMap('map', ['<c-j>', '<c-k>'])
```

Extend dot `d`
``` vim
nmap <expr> d dot#Noremap('d')
vmap <expr> d dot#Noremap('d')
```

Create a (dot repeatable) operator from composition: Search for a pattern, then change the whole word:
``` vim
nmap <expr> <plug>(search) op#Noremap('/')
nmap <expr> <plug>(change) op#Noremap('ciw')
nmap <expr> R dot#Map('<plug>(search)<plug>(change)')
```

## Deprecation Notice

dot#SetMaps and pair#SetMaps are deprecated. Use dot#SetMap and pair#SetMap for
each individual mapping instead. For noremap mappings, use dot#Noremap and
pair#NoremapNext/Prev.
