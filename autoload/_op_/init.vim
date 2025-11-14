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
        throw 'cyclops.vim: Error while processing map, <expr> map must be used for this plugin'
    endif
endfunction

function _op_#init#AssertSameRHS(map, modes) abort
    if !g:cyclops_asserts_enabled
        return
    endif

    let l:mode_list = split(a:modes, '\zs')
    let l:first_rhs = maparg(a:map, l:mode_list[0])
    if empty(l:first_rhs)
        throw 'cyclops.vim: Mapping "' .. a:map .. '" does not exist'
    endif

    if len(l:mode_list) < 2
        return
    endif

    for l:next_mode in l:mode_list[1:]
        if l:first_rhs !=# maparg(a:map, l:next_mode)
            throw 'cyclops.vim: Mapped keys in different modes must have the same RHS: '.a:map
        endif
    endfor
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

let &cpo = s:cpo
unlet s:cpo
