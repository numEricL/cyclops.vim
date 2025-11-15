" ============================================================================
" File: autoload/_op_/init.vim
" Description: Internal initialization and validation functions
" ============================================================================
"
" This module provides validation, assertion, and initialization utilities
" used internally by the cyclops.vim plugin.
"
" Key responsibilities:
"   - Validate that functions are called from <expr> mapping context
"   - Validate operator options and pair structures
"   - Register mappings and noremaps with <plug> wrappers
"   - Merge user options with defaults
"
" ============================================================================

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

" _op_#init#AssertExprMap - Verify function is called from <expr> mapping
"
" Throws an error if not called from an <expr> mapping context.
" Uses normal! 1 which fails (E523) inside <expr> maps as a detection method.
function _op_#init#AssertExprMap() abort
    if !g:cyclops_asserts_enabled
        return
    endif

    " Try to execute a normal command - this fails inside <expr> maps
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

" _op_#init#AssertSameRHS - Verify mapping has same RHS across modes
"
" For multi-mode mappings (e.g., 'map'), ensures all modes have the same
" right-hand side. Throws 'op#MAP_DNE' if mapping doesn't exist.
"
" Args:
"   map          - The mapping to check
"   mapping_type - Type of mapping ('map', 'nmap', 'vmap', etc.)
function _op_#init#AssertSameRHS(map, mapping_type) abort
    if !g:cyclops_asserts_enabled
        return
    endif

    " Extract modes from mapping_type (e.g., 'map' -> 'nvo')
    let l:modes = (a:mapping_type =~# '\v^(map)')? 'nvo' : a:mapping_type[0]
    let l:mode_list = split(l:modes, '\zs')

    " Check if mapping exists in first mode
    let l:first_rhs = maparg(a:map, l:mode_list[0])
    if empty(l:first_rhs)
        throw 'op#MAP_DNE'
    endif

    " If single mode, no need to check consistency
    if len(l:mode_list) < 2
        return
    endif

    " Verify all modes have the same RHS
    for l:next_mode in l:mode_list[1:]
        if l:first_rhs !=# maparg(a:map, l:next_mode)
            throw 'cyclops.vim: Assertion failed: Mapped keys in different modes must have the same RHS: ' .. a:map
        endif
    endfor
endfunction

" _op_#init#AssertPair - Verify pair structure is valid
"
" Ensures pair is a two-element list for forward/backward operations.
"
" Args:
"   pair - Should be a list like ['f', 'F'] or ['<c-w>>', '<c-w><']
function _op_#init#AssertPair(pair) abort
    if !g:cyclops_asserts_enabled
        return
    endif

    if type(a:pair) != v:t_list || len(a:pair) != 2
        throw 'cyclops.vim: Assertion failed: Input must be a list of two maps, got a ' .. _op_#utils#GetType(a:pair) .. ' of length ' .. string(len(a:pair))
    endif
endfunction

" _op_#init#ExtendDefaultOpts - Merge user options with defaults
"
" Validates user options and merges them with g:cyclops_map_defaults.
" User options take precedence (via 'keep' parameter to extend()).
"
" Args:
"   vargs - Variable argument list, should contain 0 or 1 dictionary
"
" Returns: Dictionary with merged options
function _op_#init#ExtendDefaultOpts(vargs)
    " Validate argument format
    if len(a:vargs) > 1 || ( len(a:vargs) == 1 && type(a:vargs[0]) != v:t_dict )
        throw 'cyclops.vim: Incorrect parameter, only a dictionary of options is accepted.'
    endif

    let l:opts = len(a:vargs) == 1 ? a:vargs[0] : {}

    " Validate each user-provided option
    for [l:key, l:value] in items(l:opts)
        if !has_key(g:cyclops_map_defaults, l:key)
            throw 'cyclops.vim: Unrecognized option ' .. string(l:key) .. '.'
        endif
        if l:value != v:true && l:value != v:false
            throw 'cyclops.vim: Unrecognied option value ' .. string(l:key) .. ': ' .. string(l:value) .. '. Values must be 0 or 1.'
        endif
    endfor

    " Merge with defaults (user opts take precedence via 'keep')
    return extend(l:opts, g:cyclops_map_defaults, 'keep')
endfunction

" _op_#init#RegisterNoremap - Create a <plug> wrapper for literal keys
"
" Creates a noremap <plug> mapping for the given keys if it doesn't exist.
" This allows literal keys to be treated like named mappings.
"
" Args:
"   map - Literal keys to map (e.g., '/', 'dd', 'ciw')
"
" Returns: The <plug> mapping name as a string with special codes
function _op_#init#RegisterNoremap(map) abort
    let l:map_string = '<plug>(op#_noremap_' .. a:map .. ')'

    " Only register if it doesn't already exist
    if empty(maparg(l:map_string))
        execute 'noremap <silent> ' .. l:map_string .. ' ' .. a:map
    endif

    " Return with proper key code encoding
    return "\<plug>(op#_noremap_" .. a:map .. ')'
endfunction

" _op_#init#RegisterMap - Create a <plug> wrapper for an existing mapping
"
" Verifies the mapping exists, creates a <plug> wrapper, and copies
" the mapping info so it can be invoked through the wrapper.
"
" Args:
"   mapping_type - Type of mapping ('map', 'nmap', etc.)
"   map          - Name of existing mapping
"
" Returns: The <plug> mapping name
" Throws: 'op#MAP_DNE' if mapping doesn't exist
function _op_#init#RegisterMap(mapping_type, map) abort
    " Verify mapping exists and is consistent across modes
    call _op_#init#AssertSameRHS(a:map, a:mapping_type)

    " Create <plug> wrapper name
    let l:plugmap = '<plug>(op#_' .. a:mapping_type .. '_' .. a:map .. ')'
    if !empty(maparg(l:plugmap))
        throw 'cyclops.vim: Mapping for ' .. l:plugmap .. ' already exists.'
    endif

    " Create temporary mapping
    execute a:mapping_type .. ' ' .. l:plugmap .. ' <nop>'

    " Copy mapping info from original to <plug> wrapper
    let l:mode = a:mapping_type ==# 'map'? '' : a:mapping_type[0]
    let l:lhs_mapinfo = maparg(l:plugmap, l:mode, 0, 1)
    let l:rhs_mapinfo = maparg(a:map, l:mode, 0, 1)

    " Update LHS info to point to <plug> mapping
    for l:key in ['lhs', 'lhsraw', 'lhsrawalt', 'mode']
        if has_key(l:lhs_mapinfo, l:key)
            let l:rhs_mapinfo[l:key] = l:lhs_mapinfo[l:key]
        else
            silent! remove(l:rhs_mapinfo, l:key)
        endif
    endfor

    " Apply the modified mapping
    call mapset(l:rhs_mapinfo)
    return l:plugmap
endfunction

let &cpo = s:cpo
unlet s:cpo
