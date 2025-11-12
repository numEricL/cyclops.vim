if exists("g:cyclops_loaded")
    finish
endif
let g:cyclops_loaded = 1

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

command PL call op#PrintDebugLog()
command PV call op#PrintScriptVars()

noremap <expr> <plug>(dot#dot) dot#RepeatMap()

if !g:cyclops_no_mappings
    map . <plug>(dot#dot)
    map ; <plug>(pair#next)
    map , <plug>(pair#previous)
endif

let &cpo = s:cpo
unlet s:cpo
