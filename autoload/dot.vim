" ============================================================================
" File: autoload/dot.vim
" Description: Public API for dot-repeatable operators
" ============================================================================
"
" This module adds dot (.) repeat capability to custom operators.
" When an operator is executed, pressing . will repeat the entire operation
" including any user input that was provided.
"
" Functions:
"   dot#Map(map, [opts])       - Create dot-repeatable operator from mapping
"   dot#Noremap(map, [opts])   - Create dot-repeatable operator from literal keys
"   dot#SetMaps(type, maps, [opts]) - Batch create dot-repeatable operators
"
" Example:
"   nmap <expr> / dot#Noremap('/')
"   After: /foo<CR> then pressing . searches for 'foo' again
"
" ============================================================================

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

" Import internal functions
let s:AssertExprMap     = function('_op_#init#AssertExprMap')
let s:ExtendDefaultOpts = function('_op_#init#ExtendDefaultOpts')
let s:StackInit         = function('_op_#op#StackInit')
let s:RegisterNoremap   = function('_op_#init#RegisterNoremap')

" dot#Map - Create a dot-repeatable operator from an existing mapping
"
" Use this when the mapping already exists. Pressing . will repeat the entire
" operation including user input.
"
" Args:
"   map  - String name of existing mapping
"   opts - Optional dictionary to override defaults
"
" Returns: Expression to be used in <expr> mapping
"
" Must be called from within an <expr> mapping context.
function dot#Map(map, ...) abort range
    call s:AssertExprMap()

    " Disable during macro recording/playback
        if !empty(reg_recording()) || !empty(reg_executing())
        return a:map
    endif

    " Initialize stack and configure this dot operator
    let l:handle = s:StackInit()
    call _op_#op#InitCallback(l:handle, 'dot', a:map, s:ExtendDefaultOpts(a:000))
    call _op_#dot#InitCallback(l:handle)

    " Set operatorfunc for g@ operator (used for dot repeat mechanism)
    let &operatorfunc = '_op_#dot#ComputeMapCallback'

    " Escape from operator-pending mode if needed, then use g@ operator
    " g@_ applies operator to current line, g@ waits for motion in visual mode
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. 'g@' .. (mode(0) ==# 'n'? '_' : '')
endfunction

" dot#Noremap - Create a dot-repeatable operator from literal keystrokes
"
" Use this when you want to create an operator from raw keys.
" Pressing . will repeat the operation with the same input.
"
" Args:
"   map  - String of literal keys
"   opts - Optional dictionary to override defaults
"
" Returns: Expression to be used in <expr> mapping
"
" Must be called from within an <expr> mapping context.
function dot#Noremap(map, ...) abort range
    call s:AssertExprMap()

    " Disable during macro recording/playback
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:map
    endif

    " Register the noremap and initialize operator
    let l:map = s:RegisterNoremap(a:map)
    let l:handle = s:StackInit()
    call _op_#op#InitCallback(l:handle, 'dot', l:map, s:ExtendDefaultOpts(a:000))
    call _op_#dot#InitCallback(l:handle)

    " Set operatorfunc for g@ operator
    let &operatorfunc = '_op_#dot#ComputeMapCallback'

    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. 'g@' .. (mode(0) ==# 'n'? '_' : '')
endfunction

" dot#SetMaps - Batch create dot-repeatable operators
"
" Convenience function to create multiple dot-repeatable operators at once.
"
" Args:
"   mapping_type - Type of mapping ('nmap', 'nnoremap', 'xmap', etc.)
"   maps         - Single map string or list of map strings
"   opts         - Optional dictionary to override defaults
"
" If mapping_type contains 'nore', uses dot#Noremap, otherwise uses dot#Map
"
" Example:
"   call dot#SetMaps('nmap', ['<plug>Dsurround', '<plug>Csurround'], {})
function dot#SetMaps(mapping_type, maps, ...) abort range
    let l:opts_dict = a:0 ? a:1 : {}
    if type(a:maps) == v:t_list
        for l:map in a:maps
            call s:SetMap(a:mapping_type, l:map, l:opts_dict)
        endfor
    else
        call s:SetMap(a:mapping_type, a:maps, l:opts_dict)
    endif
endfunction

" s:SetMap - Internal helper to create a single dot-repeatable operator
"
" Determines whether to use Map or Noremap based on mapping_type.
" Registers the mapping if it doesn't use 'nore' prefix.
function s:SetMap(mapping_type, map, opts_dict) abort
    " Check if this is a noremap variant
    if a:mapping_type =~# '\v^(no|nn|vn|xn|sno|ono|no|ino|ln|cno|tno)'
        execute a:mapping_type .. ' <expr> ' .. a:map .. ' dot#Noremap(' .. string(a:map) .. ', ' .. string(a:opts_dict) .. ')'
    else
        " For map variants, verify the mapping exists
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
