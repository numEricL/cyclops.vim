" ============================================================================
" File: autoload/pair.vim
" Description: Public API for pair-repeatable operators (forward/backward)
" ============================================================================
"
" This module adds semicolon (;) and comma (,) repeat capability to operators.
" Pairs of related operations (like f/F or t/T) can be repeated in either
" direction using ; (next/forward) and , (prev/backward).
"
" Functions:
"   pair#MapNext(pair, [opts])       - Create forward operator from mapping
"   pair#MapPrev(pair, [opts])       - Create backward operator from mapping
"   pair#NoremapNext(pair, [opts])   - Create forward operator from literal keys
"   pair#NoremapPrev(pair, [opts])   - Create backward operator from literal keys
"   pair#SetMaps(type, pairs, [opts]) - Batch create pair-repeatable operators
"
" Example:
"   nmap <expr> f pair#NoremapNext(['f', 'F'])
"   nmap <expr> F pair#NoremapPrev(['f', 'F'])
"   After: fa then pressing ; finds next 'a', , finds previous 'a'
"
" ============================================================================

" Preserve default ; and , behavior for internal use
noremap <silent> <plug>(op#_noremap_;) ;
noremap <silent> <plug>(op#_noremap_,) ,

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

" Import internal functions
let s:AssertExprMap     = function('_op_#init#AssertExprMap')
let s:AssertPair        = function('_op_#init#AssertPair')
let s:ExtendDefaultOpts = function('_op_#init#ExtendDefaultOpts')
let s:StackInit         = function('_op_#op#StackInit')

" pair#MapNext - Create forward (next) operator from an existing mapping
"
" Creates the forward direction of a pair operator. Use with pair#MapPrev
" to create a complete bidirectional operator pair.
"
" Args:
"   pair - Two-element list [forward_map, backward_map]
"   opts - Optional dictionary to override defaults
"
" Returns: Expression to be used in <expr> mapping
"
" Must be called from within an <expr> mapping context.
function pair#MapNext(pair, ...) abort range
    call s:AssertExprMap()
    call s:AssertPair(a:pair)

    " Disable during macro recording/playback
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:pair[0]
    endif

    " Initialize stack and configure this pair operator for 'next' direction
    let l:handle = s:StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', a:pair[0], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, a:pair, 'next')

    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

" pair#MapPrev - Create backward (previous) operator from an existing mapping
"
" Creates the backward direction of a pair operator. Use with pair#MapNext
" to create a complete bidirectional operator pair.
"
" Args:
"   pair - Two-element list [forward_map, backward_map]
"   opts - Optional dictionary to override defaults
"
" Returns: Expression to be used in <expr> mapping
function pair#MapPrev(pair, ...) abort range
    call s:AssertExprMap()
    call s:AssertPair(a:pair)

    " Disable during macro recording/playback
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:pair[1]
    endif

    " Initialize stack and configure this pair operator for 'prev' direction
    let l:handle = s:StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', a:pair[1], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, a:pair, 'prev')

    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

" pair#NoremapNext - Create forward operator from literal keystrokes
"
" Use this when you want to create an operator from raw keys.
" Pressing ; will repeat in the forward direction.
"
" Args:
"   pair - Two-element list [forward_keys, backward_keys]
"   opts - Optional dictionary to override defaults
"
" Returns: Expression to be used in <expr> mapping
function pair#NoremapNext(pair, ...) abort range
    call s:AssertExprMap()
    call s:AssertPair(a:pair)

    " Disable during macro recording/playback
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:pair[0]
    endif

    " Register both directions as noremaps
    let l:pair = s:RegisterNoremapPair(a:pair)
    let l:handle = s:StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', l:pair[0], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, l:pair, 'next')

    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

" pair#NoremapPrev - Create backward operator from literal keystrokes
"
" Use this when you want to create an operator from raw keys.
" Pressing , will repeat in the backward direction.
"
" Args:
"   pair - Two-element list [forward_keys, backward_keys]
"   opts - Optional dictionary to override defaults
"
" Returns: Expression to be used in <expr> mapping
function pair#NoremapPrev(pair, ...) abort range
    call s:AssertExprMap()
    call s:AssertPair(a:pair)

    " Disable during macro recording/playback
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:pair[1]
    endif

    " Register both directions as noremaps
    let l:pair = s:RegisterNoremapPair(a:pair)
    let l:handle = s:StackInit()
    call _op_#op#InitCallback(l:handle, 'pair', l:pair[1], s:ExtendDefaultOpts(a:000))
    call _op_#pair#Initcallback(l:handle, l:pair, 'prev')

    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#pair#ComputeMapCallback()\<cr>"
endfunction

" pair#SetMaps - Batch create pair-repeatable operators
"
" Convenience function to create multiple pair operators at once.
" Automatically creates both forward and backward mappings.
"
" Args:
"   mapping_type - Type of mapping ('nmap', 'nnoremap', etc.)
"   pairs        - Single pair [fwd, bwd] or list of pairs [[f1,F1], [f2,F2]]
"   opts         - Optional dictionary to override defaults
"
" Example:
"   call pair#SetMaps('noremap', [['<c-w>>', '<c-w><'], ['<c-w>+', '<c-w>-']],
"                    \ {'accepts_register': 0})
function pair#SetMaps(mapping_type, pairs, ...) abort range
    let l:opts_dict = a:0 ? a:1 : {}

    " Handle both single pair and list of pairs
    if type(a:pairs[0]) == v:t_list
        " List of pairs
        for l:pair in a:pairs
            call s:SetMap(a:mapping_type, l:pair, l:opts_dict)
        endfor
    else
        " Single pair
        call s:SetMap(a:mapping_type, a:pairs, l:opts_dict)
    endif
endfunction

" s:SetMap - Internal helper to create a single pair of operators
"
" Determines whether to use Map or Noremap based on mapping_type.
" Creates both forward (pair[0]) and backward (pair[1]) mappings.
function s:SetMap(mapping_type, pair, opts_dict) abort
    " Check if this is a noremap variant
    if a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)'
        " Create noremap versions
        execute a:mapping_type .. ' <expr> ' .. a:pair[0] .. ' pair#NoremapNext(' .. string(a:pair) .. ', ' .. string(a:opts_dict) .. ')'
        execute a:mapping_type .. ' <expr> ' .. a:pair[1] .. ' pair#NoremapPrev(' .. string(a:pair) .. ', ' .. string(a:opts_dict) .. ')'
    else
        " For map variants, verify the mappings exist
        try
            let l:plugpair = s:RegisterMapPair(a:mapping_type, a:pair)
        catch /op#MAP_DNE/
            echohl WarningMsg | echomsg 'cyclops.vim: Warning: Could not set mapping for pair: ' .. string(a:pair) .. ' -- one or both mappings do not exist.' | echohl None
            return
        endtry
        " Create map versions
        execute a:mapping_type .. ' <expr> ' .. a:pair[0] .. ' pair#MapNext(' .. string(l:plugpair) .. ', ' .. string(a:opts_dict) .. ')'
        execute a:mapping_type .. ' <expr> ' .. a:pair[1] .. ' pair#MapPrev(' .. string(l:plugpair) .. ', ' .. string(a:opts_dict) .. ')'
    endif
endfunction

" s:RegisterNoremapPair - Register both directions as noremap
"
" Creates <plug> mappings for both forward and backward operations.
" Returns the pair of <plug> mapping names.
function s:RegisterNoremapPair(pair) abort
    let l:map0 = _op_#init#RegisterNoremap(a:pair[0])
    let l:map1 = _op_#init#RegisterNoremap(a:pair[1])
    return [ l:map0, l:map1 ]
endfunction

" s:RegisterMapPair - Register both directions of an existing mapping pair
"
" Verifies both mappings exist and creates <plug> wrappers for them.
" Returns the pair of <plug> mapping names.
" Throws 'op#MAP_DNE' if either mapping doesn't exist.
function s:RegisterMapPair(mapping_type, pair) abort
    let l:map0 = _op_#init#RegisterMap(a:mapping_type, a:pair[0])
    let l:map1 = _op_#init#RegisterMap(a:mapping_type, a:pair[1])
    return [ l:map0, l:map1 ]
endfunction

let &cpo = s:cpo
unlet s:cpo
