let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

let s:map_count = 0
let s:noremap_dict = {}
let s:noremap_invert = []

function _op_#init#AssertExprMap() abort
    if !g:cyclops_asserts_enabled
        return
    endif

    try " throws if in <expr> map
        execute "normal! 1"
        let l:expr_map = 0
    catch /^Vim\%((\a\+)\)\=:E523:/
        let l:expr_map = 1
    endtry
    if !l:expr_map
        throw 'cyclops.vim: Assertion failed: <expr> must be used for this map'
    endif
endfunction

function _op_#init#AssertRemap(map, mapping_type) abort
    if !g:cyclops_asserts_enabled
        return
    endif
    if a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)'
        throw 'op#MAP_noremap'
    endif
endfunction

function _op_#init#AssertSameRHS(map, mapping_type) abort
    if !g:cyclops_asserts_enabled
        return
    endif

    let l:modes = (a:mapping_type =~# '\v^(map)')? 'nvo' : a:mapping_type[0]
    let l:mode_list = split(l:modes, '\zs')
    let l:first_rhs = maparg(a:map, l:mode_list[0])
    if empty(l:first_rhs)
        throw 'op#MAP_DNE'
    endif

    if len(l:mode_list) < 2
        return
    endif

    for l:next_mode in l:mode_list[1:]
        if l:first_rhs !=# maparg(a:map, l:next_mode)
            throw 'cyclops.vim: Assertion failed: Mapped keys in different modes must have the same RHS: ' .. a:map
        endif
    endfor
endfunction

function _op_#init#AssertPair(pair) abort
    if !g:cyclops_asserts_enabled
        return
    endif
    if type(a:pair) != v:t_list || len(a:pair) != 2
        throw 'cyclops.vim: Assertion failed: Input must be a list of two maps, got a ' .. _op_#utils#GetType(a:pair) .. ' of length ' .. string(len(a:pair))
    endif
endfunction

function _op_#init#ExtendDefaultOpts(vargs)
    if len(a:vargs) > 1 || ( len(a:vargs) == 1 && type(a:vargs[0]) != v:t_dict )
        throw 'cyclops.vim: Incorrect parameter, only a dictionary of options is accepted.'
    endif
    let l:opts = len(a:vargs) == 1 ? a:vargs[0] : {}
    for [l:key, l:value] in items(l:opts)
        if !has_key(g:cyclops_map_defaults, l:key)
            throw 'cyclops.vim: Unrecognized option ' .. string(l:key) .. '.'
        endif
        if l:value != v:true && l:value != v:false
            throw 'cyclops.vim: Unrecognied option value ' .. string(l:key) .. ': ' .. string(l:value) .. '. Values must be 0 or 1.'
        endif
    endfor
    return extend(l:opts, g:cyclops_map_defaults, 'keep')
endfunction

function _op_#init#RegisterNoremap(map) abort
    if !has_key(s:noremap_dict, a:map)
        let l:plugmap  = '<plug>(op#noremap_' .. s:map_count .. ')'
        execute 'noremap <silent> ' .. l:plugmap .. ' ' .. a:map
        let s:map_count += 1
        let s:noremap_dict[a:map] = substitute(l:plugmap, '<plug>', "\<plug>", 'g')
        call add(s:noremap_invert, a:map)
    endif
    return s:noremap_dict[a:map]
endfunction

function _op_#init#RegisterMap(mapping_type, map) abort
    call _op_#init#AssertRemap(a:map, a:mapping_type)
    call _op_#init#AssertSameRHS(a:map, a:mapping_type)

    let l:map_with_sentinel = substitute(a:map, ')', 'RPAREN', 'g')
    let l:plugmap = '<plug>(op#' .. a:mapping_type .. '_' .. l:map_with_sentinel .. ')'

    let l:mode = a:mapping_type ==# 'map'? '' : a:mapping_type[0]
    let l:rhs_mapinfo = maparg(a:map, l:mode, 0, 1)
    if empty(l:rhs_mapinfo)
        throw 'cyclops.vim: Cannot register non-existent mapping: ' .. a:map
    endif
    if get(l:rhs_mapinfo, 'rhs', '') =~# substitute(l:plugmap, '<plug>', "\<plug>", 'g')
        throw 'cyclops.vim: Recursive mapping for ' .. a:map .. ' detected.'
    endif

    execute a:mapping_type .. ' ' .. l:plugmap .. ' <nop>'
    let l:new_mapinfo = maparg(l:plugmap, l:mode, 0, 1)
    for l:key in ['lhs', 'lhsraw', 'lhsrawalt', 'mode']
        if has_key(l:new_mapinfo, l:key)
            let l:rhs_mapinfo[l:key] = l:new_mapinfo[l:key]
        else
            silent! remove(l:rhs_mapinfo, l:key)
        endif
    endfor
    if exists('*mapset')
        try
            call mapset(l:rhs_mapinfo)
        catch /^Vim\%((\a\+)\)\=:E119:/
            call mapset(l:mode, 0, l:rhs_mapinfo)
        endtry
    else
        call s:MapSet_COMPAT(l:rhs_mapinfo)
    endif
    return substitute(l:plugmap, '<plug>', "\<plug>", 'g')
endfunction

function s:MapSet_COMPAT(dict) abort
  let l:mode = get(a:dict, 'mode', '')
  let l:lhs = get(a:dict, 'lhs', '')
  let l:rhs = get(a:dict, 'rhs', '')
  let l:noremap = get(a:dict, 'noremap', v:false)
  let l:silent = get(a:dict, 'silent', v:false)
  let l:expr = get(a:dict, 'expr', v:false)
  let l:unique = get(a:dict, 'unique', v:false)
  let l:buffer = get(a:dict, 'buffer', v:false)

  let l:cmd = l:mode
  let l:cmd ..= l:noremap ? 'noremap'  : 'map'
  let l:cmd ..= l:silent  ? '<silent>' : ''
  let l:cmd ..= l:expr    ? '<expr>'   : ''
  let l:cmd ..= l:unique  ? '<unique>' : ''
  let l:cmd ..= l:buffer  ? '<buffer>' : ''
  let l:cmd ..= ' ' .. l:lhs .. ' ' .. l:rhs
  execute l:cmd
endfunction

function _op_#init#NoremapInvertLookup(nr) abort
    return get(s:noremap_invert, a:nr, '')
endfunction

function _op_#init#DeprecationNotice(msg) abort
    if !g:cyclops_suppress_deprecation_warnings
        echohl WarningMsg | echomsg 'cyclops.vim: Deprecation Notice: ' .. a:msg | echohl None
    endif
endfunction

let &cpo = s:cpo
unlet s:cpo
