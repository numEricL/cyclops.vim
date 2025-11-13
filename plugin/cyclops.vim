if exists("g:cyclops_loaded")
    finish
endif
let g:cyclops_loaded = 1

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

command PL call op#PrintDebugLog()
command PV call op#PrintScriptVars()

noremap <expr> <plug>(dot#dot) _op_#dot#RepeatMap()
noremap <expr> <plug>(pair#next) _op_#pair#PairRepeatMap('next')
noremap <expr> <plug>(pair#prev) _op_#pair#PairRepeatMap('prev')

if !g:cyclops_no_mappings
    noremap . <plug>(dot#dot)
    noremap ; <plug>(pair#next)
    noremap , <plug>(pair#prev)
    noremap <expr> f pair#NoremapNext(['f', 'F'])
    noremap <expr> F pair#NoremapPrev(['f', 'F'])
    noremap <expr> t pair#NoremapNext(['t', 'T'])
    noremap <expr> T pair#NoremapPrev(['t', 'T'])
endif

let &cpo = s:cpo
unlet s:cpo
