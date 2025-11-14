let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

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
        throw 'cyclops.vim: Assertion failed: Error while processing map, <expr> map must be used for this plugin'
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
            throw 'cyclops.vim: Assertion failed: Mapped keys in different modes must have the same RHS: '.a:map
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
            throw 'cyclops.vim: Unrecognized option '.string(l:key).'.'
        endif
        if l:value != v:true && l:value != v:false
            throw 'cyclops.vim: Unrecognied option value '.string(l:key).': '.string(l:value).'. Values must be 0 or 1.'
        endif
    endfor
    return extend(l:opts, g:cyclops_map_defaults, 'keep')
endfunction

function _op_#init#RegisterNoremap(map) abort
    let l:map_string = '<plug>(op#_noremap_'.a:map.')'
    if empty(maparg(l:map_string))
        execute 'noremap <silent> ' .. l:map_string .. ' ' .. a:map
    endif
    return "\<plug>(op#_noremap_".a:map.')'
endfunction

function _op_#init#RegisterMap(mapping_type, map) abort
    call _op_#init#AssertSameRHS(a:map, a:mapping_type)

    let l:plugmap = '<plug>(op#_'.a:mapping_type.'_'.a:map.')'
    if !empty(maparg(l:plugmap))
        throw 'cyclops.vim: Mapping for '.l:plugmap.' already exists.'
    endif
    execute a:mapping_type .. ' ' .. l:plugmap .. ' <nop>'

    let l:mode = a:mapping_type ==# 'map'? '' : a:mapping_type[0]
    let l:lhs_mapinfo = maparg(l:plugmap, l:mode, 0, 1)
    let l:rhs_mapinfo = maparg(a:map, l:mode, 0, 1)
    for l:key in ['lhs', 'lhsraw', 'mode']
        if has_key(l:lhs_mapinfo, l:key)
            let l:rhs_mapinfo[l:key] = l:lhs_mapinfo[l:key]
        else
            silent! remove(l:rhs_mapinfo, l:key)
        endif
    endfor
    call mapset(l:rhs_mapinfo)
    return l:plugmap
endfunction

let &cpo = s:cpo
unlet s:cpo
