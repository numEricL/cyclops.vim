"
" external dot# interface
"

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:AssertExprMap     = function('_op_#init#AssertExprMap')
let s:ExtendDefaultOpts = function('_op_#init#ExtendDefaultOpts')
let s:RegisterNoremap   = function('_op_#init#RegisterNoremap')

function dot#Map(map, ...) abort
    call s:AssertExprMap()
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'dot', a:map, s:ExtendDefaultOpts(a:000))
    call _op_#dot#InitCallback(l:handle)
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    let l:cmd_COMPAT = _op_#utils#HasVersion(802, 1978)? "\<cmd>" : ":\<c-u>"
    return l:omap_esc .. l:cmd_COMPAT .. "call _op_#dot#ComputeMapCallback()\<cr>"
endfunction

function dot#Noremap(map, ...) abort
    call s:AssertExprMap()
    let l:map = s:RegisterNoremap(a:map)
    let l:handle = _op_#op#StackInit()
    call _op_#op#InitCallback(l:handle, 'dot', l:map, s:ExtendDefaultOpts(a:000))
    call _op_#dot#InitCallback(l:handle)
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    let l:cmd_COMPAT = _op_#utils#HasVersion(802, 1978)? "\<cmd>" : ":\<c-u>"
    return l:omap_esc .. l:cmd_COMPAT .. "call _op_#dot#ComputeMapCallback()\<cr>"
endfunction

function dot#SetMap(mapping_type, map, ...) abort
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
    execute a:mapping_type .. ' <expr> ' .. a:map .. ' dot#Map(' .. string(l:plugmap) .. ', ' .. string(a:opts_dict) .. ')'
endfunction

function dot#SetMaps(mapping_type, maps, ...) abort
    let l:opts_dict = a:0 ? a:1 : {}
    if type(a:maps) == v:t_list
        for l:map in a:maps
            call s:SetMapDeprecated(a:mapping_type, l:map, l:opts_dict)
        endfor
    else
        call s:SetMapDeprecated(a:mapping_type, a:maps, l:opts_dict)
    endif
    call _op_#init#DeprecationNotice('dot#SetMaps is deprecated. Please use dot#SetMap for individual mappings. Suppress this message with g:cyclops_suppress_deprecation_warnings')
endfunction

function s:SetMapDeprecated(mapping_type, map, opts_dict) abort
    if a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)'
        execute a:mapping_type .. ' <expr> ' .. a:map .. ' dot#Noremap(' .. string(a:map) .. ', ' .. string(a:opts_dict) .. ')'
        call _op_#init#DeprecationNotice('dot#SetMap(s) will no longer support noremap mappings in future releases. Use dot#Noremap instead.')
    else
        try
            let l:plugmap = _op_#init#RegisterMap(a:mapping_type, a:map)
        catch /op#MAP_DNE/
            echohl WarningMsg | echomsg 'cyclops.vim: Warning: Could not set mapping: ' .. string(a:map) .. ' -- mapping does not exist.' | echohl None
            return
        endtry
        execute a:mapping_type .. ' <expr> ' .. a:map .. ' dot#Map(' .. string(l:plugmap) .. ', ' .. string(a:opts_dict) .. ')'
    endif
endfunction

let &cpo = s:cpo
unlet s:cpo
