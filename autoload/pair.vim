noremap <silent> <plug>(op#_noremap_;) ;
noremap <silent> <plug>(op#_noremap_,) ,
"
" external pair# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:AssertExprMap     = function('_op_#init#AssertExprMap')
let s:AssertPair        = function('_op_#init#AssertPair')
let s:ExtendDefaultOpts = function('_op_#init#ExtendDefaultOpts')
let s:StackInit         = function('_op_#op#StackInit')

function pair#MapNext(pair, ...) abort
    call s:AssertExprMap()
    call s:AssertPair(a:pair)
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:pair[0]
    endif
    let l:handle = s:StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', a:pair[0], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, a:pair, 'next')
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

function pair#MapPrev(pair, ...) abort
    call s:AssertExprMap()
    call s:AssertPair(a:pair)
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:pair[1]
    endif
    let l:handle = s:StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', a:pair[1], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, a:pair, 'prev')
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

function pair#NoremapNext(pair, ...) abort
    call s:AssertExprMap()
    call s:AssertPair(a:pair)
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:pair[0]
    endif
    let l:pair = s:RegisterNoremapPair(a:pair)
    let l:handle = s:StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', l:pair[0], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, l:pair, 'next')
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

function pair#NoremapPrev(pair, ...) abort
    call s:AssertExprMap()
    call s:AssertPair(a:pair)
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:pair[1]
    endif
    let l:pair = s:RegisterNoremapPair(a:pair)
    let l:handle = s:StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', l:pair[1], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, l:pair, 'prev')
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

function pair#SetMap(mapping_type, pair, ...) abort
    let l:opts_dict = a:0 ? a:1 : {}
    call s:SetMap(a:mapping_type, a:pair, l:opts_dict)
endfunction

function s:SetMap(mapping_type, pair, opts_dict) abort
    try
        let l:plugpair = s:RegisterMapPair(a:mapping_type, a:pair)
    catch /op#MAP_noremap/
        echohl ErrorMsg | echomsg 'cyclops.vim: Error: SetMap cannot be used with noremap mappings: ' .. string(a:pair) | echohl None
        return
    catch /op#MAP_DNE/
        echohl WarningMsg | echomsg 'cyclops.vim: Warning: Could not set mapping for pair: ' .. string(a:pair) .. ' -- one or both mappings do not exist.' | echohl None
        return
    endtry
    execute a:mapping_type .. ' <expr> ' .. a:pair[0] .. ' pair#MapNext(' .. string(l:plugpair) .. ', ' .. string(a:opts_dict) .. ')'
    execute a:mapping_type .. ' <expr> ' .. a:pair[1] .. ' pair#MapPrev(' .. string(l:plugpair) .. ', ' .. string(a:opts_dict) .. ')'
endfunction

function s:RegisterNoremapPair(pair) abort
    let l:map0 = _op_#init#RegisterNoremap(a:pair[0])
    let l:map1 = _op_#init#RegisterNoremap(a:pair[1])
    return [ l:map0, l:map1 ]
endfunction

function s:RegisterMapPair(mapping_type, pair) abort
    let l:map0 = _op_#init#RegisterMap(a:mapping_type, a:pair[0])
    let l:map1 = _op_#init#RegisterMap(a:mapping_type, a:pair[1])
    return [ l:map0, l:map1 ]
endfunction

function pair#SetMaps(mapping_type, pairs, ...) abort
    let l:opts_dict = a:0 ? a:1 : {}
    if type(a:pairs[0]) == v:t_list
        for l:pair in a:pairs
            call s:SetMapDeprecated(a:mapping_type, l:pair, l:opts_dict)
        endfor
    else
        call s:SetMapDeprecated(a:mapping_type, a:pairs, l:opts_dict)
    endif
    echohl WarningMsg | echomsg 'cyclops.vim: Deprecation Notice: pair#SetMaps is deprecated. Please use dot#SetMap for individual mappings.' | echohl None
endfunction

function s:SetMapDeprecated(mapping_type, pair, opts_dict) abort
    if a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)'
        execute a:mapping_type .. ' <expr> ' .. a:pair[0] .. ' pair#NoremapNext(' .. string(a:pair) .. ', ' .. string(a:opts_dict) .. ')'
        execute a:mapping_type .. ' <expr> ' .. a:pair[1] .. ' pair#NoremapPrev(' .. string(a:pair) .. ', ' .. string(a:opts_dict) .. ')'
        echohl WarningMsg | echomsg 'cyclops.vim: Deprecation Notice: pair#SetMap(s) will no longer support noremap mappings in future versions. Use pair#NoremapNext/Prev instead.' | echohl None
    else
        try
            let l:plugpair = s:RegisterMapPair(a:mapping_type, a:pair)
        catch /op#MAP_DNE/
            echohl WarningMsg | echomsg 'cyclops.vim: Warning: Could not set mapping for pair: ' .. string(a:pair) .. ' -- one or both mappings do not exist.' | echohl None
            return
        endtry
        execute a:mapping_type .. ' <expr> ' .. a:pair[0] .. ' pair#MapNext(' .. string(l:plugpair) .. ', ' .. string(a:opts_dict) .. ')'
        execute a:mapping_type .. ' <expr> ' .. a:pair[1] .. ' pair#MapPrev(' .. string(l:plugpair) .. ', ' .. string(a:opts_dict) .. ')'
    endif
endfunction

let &cpo = s:cpo
unlet s:cpo
