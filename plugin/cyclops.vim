if exists("g:cyclops_loaded")
    finish
endif
let g:cyclops_loaded = 1

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

command PL call op#PrintDebugLog()
command PV call op#PrintScriptVars()

nmap <silent> <plug>(dot#dot) <cmd>call _op_#dot#Repeat(v:count, v:register, 'normal')<cr>
vmap <silent> <plug>(dot#visual_dot) <cmd>call _op_#dot#Repeat(v:count, v:register, 'visual')<cr>
omap <silent><expr> <plug>(dot#op_pending_dot) _op_#dot#RepeatOpPending()

if !g:cyclops_no_mappings
    nmap . <plug>(dot#dot)
    vmap . <plug>(dot#visual_dot)
    omap . <plug>(dot#op_pending_dot)

    nmap ; <plug>(pair#next)
    vmap ; <plug>(pair#visual_next)
    omap ; <plug>(pair#op_pending_next)

    nmap , <plug>(pair#previous)
    vmap , <plug>(pair#visual_previous)
    omap , <plug>(pair#op_pending_previous)
endif

let &cpo = s:cpo
unlet s:cpo
