# cyclops.vim
A utility for building repeatable operators in Vim

## Features
* Build custom operators that support dot `.` and pair `;` `,` repeating
* Extend Vim operators! Any mapping that expects user input (including input and
    command line modes) is an operator for this plugin
* Make most any existing mapping repeatable with this plugin
* Dot repeat operators do not interfere with native dot repeat functionality
* Operator input is interactive! Use the backspace key to erase incorrect input
* Works with constant operators (i.e. those that don't take input)

## Why not a related plugin?

Other plugins for repeating mappings has one or more of the following
limitations:

* requires other plugin authors to support your framework
* difficult to configure
* only works with maps that change the buffer
* only works with movement mappings or non-operators
* relies on constantly repeating autocommands or macro recording
* cannot be nested
* no support for visual mode
* not interactive

## Limitations

iminsert is enabled while processing mappings, this may have unintended side
effects if language mappings (`:lmap`) are encountered. A workaround exists.

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
call pair#SetMaps('noremap', [['<c-w>>', '<c-w><'], ['<c-w>+', '<c-w>-']] )
```

Extend dot `d`
```vim
nmap <expr> d dot#Noremap('d')
vmap <expr> d dot#Noremap('d')
```

Create a (dot repeatable) operator from composition: Search for a pattern and then change the whole word:
``` vim
nmap <expr> <plug>(search) op#Noremap('/')
nmap <expr> <plug>(change) op#Noremap('ciw')
nmap <expr> R dot#Map('<plug>(search)<plug>(change)')
```
