# cyclops.vim
Give your operators giant-like strength

Currently in beta, API subject to change.

Uses:

* add dot repeating to virtually any map
* add pair repeating with `;` and `,`
* add dot and pair operator pending mode
* repeat while in visual mode
* use count and registers while repeating
* `Backspace` out of typos while in operator-pending mode
* create complex mappings from composing operators

## Why not a related plugin?

Other plugins for repeating mappings has one or more of the following
limitations:

* only works with maps that change the buffer
* only works with movement mappings or non-operators
* no support for visual mode
* doesn't have other goodies!
* difficult to configure
* cannot be nested
* relies on constantly repeating autocommands or macro recording

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

Extend dot `d`
```vim
call dot#('nnoremap', ['d'])
diw
c.  # same as ciw
```

Add pair repeat functionality with `;` `,` to window resizing:
``` vim
call pair#SetMaps('noremap', [['<c-w>>', '<c-w><'], ['<c-w>+', '<c-w>-']] )
```

Create a (repeatable) mapping that searches for a pattern and then changes the whole word:
``` vim
nmap <expr> <plug>(search) op#Noremap('/')
nmap <expr> <plug>(change) op#Noremap('ciw')
nmap <expr> R dot#Map('<plug>(search)<plug>(change)')
```
