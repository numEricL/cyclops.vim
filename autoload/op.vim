"
" external op# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:InitCallback      = function('_op_#op#InitCallback')
let s:AssertExprMap     = function('_op_#init#AssertExprMap')
let s:ExtendDefaultOpts = function('_op_#init#ExtendDefaultOpts')
let s:RegisterNoremap   = function('_op_#init#RegisterNoremap')

function op#Map(map, ...) abort range
    call s:AssertExprMap()
    let l:handle = _op_#op#StackInit()
    call s:InitCallback(l:handle, 'op', a:map, s:ExtendDefaultOpts(a:000))
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#op#ComputeMapCallback()\<cr>"
endfunction

function op#Noremap(map, ...) abort range
    call s:AssertExprMap()
    let l:map = s:RegisterNoremap(a:map)
    let l:handle = _op_#op#StackInit()
    call s:InitCallback(l:handle, 'op', l:map, s:ExtendDefaultOpts(a:000))
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#op#ComputeMapCallback()\<cr>"
endfunction

function op#PrintDebugLog() abort
    call _op_#log#PrintDebugLog()
endfunction

function op#PrintScriptVars() abort
    call _op_#log#PrintScriptVars()
endfunction

let &cpo = s:cpo
unlet s:cpo
