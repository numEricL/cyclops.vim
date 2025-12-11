if exists("g:cyclops_loaded")
    finish
endif
let g:cyclops_loaded = 1

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

xnoremap <expr> <plug>(dot#vdot) _op_#dot#VisRepeatMap()
 noremap <expr> <plug>(pair#next) _op_#pair#PairRepeatMap('next')
 noremap <expr> <plug>(pair#prev) _op_#pair#PairRepeatMap('prev')

if !g:cyclops_no_mappings
    xmap . <plug>(dot#vdot)
    map ; <plug>(pair#next)
    map , <plug>(pair#prev)

    noremap <expr> f pair#NoremapNext(['f', 'F'])
    noremap <expr> F pair#NoremapPrev(['f', 'F'])
    noremap <expr> t pair#NoremapNext(['t', 'T'])
    noremap <expr> T pair#NoremapPrev(['t', 'T'])
endif

augroup _op_#op#InsertMode
augroup END

let &cpo = s:cpo
unlet s:cpo
