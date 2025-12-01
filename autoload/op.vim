"
" external op# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:AssertExprMap     = function('_op_#init#AssertExprMap')
let s:ExtendDefaultOpts = function('_op_#init#ExtendDefaultOpts')
let s:RegisterNoremap   = function('_op_#init#RegisterNoremap')

function op#Map(map, ...) abort
    call s:AssertExprMap()
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:map
    endif
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'op', a:map, s:ExtendDefaultOpts(a:000))
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#op#ComputeMapCallback()\<cr>"
endfunction

function op#Noremap(map, ...) abort
    call s:AssertExprMap()
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:map
    endif
    let l:map = s:RegisterNoremap(a:map)
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'op', l:map, s:ExtendDefaultOpts(a:000))
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#op#ComputeMapCallback()\<cr>"
endfunction

function op#SetMap(mapping_type, map, ...) abort
    let l:opts_dict = a:0 ? a:1 : {}
    call s:SetMap(a:mapping_type, a:map, l:opts_dict)
endfunction

function s:SetMap(mapping_type, map, opts_dict) abort
    try
        let l:plugmap = _op_#init#RegisterMap(a:mapping_type, a:map)
    catch /op#MAP_noremap/
        echohl ErrorMsg | echomsg 'cyclops.vim: Error: SetMap cannot be used with noremap mappings: ' .. string(a:map) | echohl None
        return
    catch /op#MAP_DNE/
        echohl WarningMsg | echomsg 'cyclops.vim: Warning: Could not set mapping: ' .. string(a:map) .. ' -- mapping does not exist.' | echohl None
        return
    endtry
    execute a:mapping_type .. ' <expr> ' .. a:map .. ' op#Map(' .. string(l:plugmap) .. ', ' .. string(a:opts_dict) .. ')'
endfunction

function op#PrintDebugLog() abort
    call _op_#log#PrintDebugLog()
endfunction

function op#PrintScriptVars() abort
    call _op_#log#PrintScriptVars()
endfunction

let &cpo = s:cpo
unlet s:cpo
