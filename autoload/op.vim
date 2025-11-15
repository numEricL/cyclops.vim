" ============================================================================
" File: autoload/op.vim
" Description: Public API for basic operator creation (no repeat capability)
" ============================================================================
"
" This module provides the simplest operator interface. Use when you want
" to capture user input for a mapping but don't need repeat functionality.
"
" Functions:
"   op#Map(map, [opts])     - Create operator from existing mapping
"   op#Noremap(map, [opts]) - Create operator from literal keys
"
" Example:
"   nmap <expr> / op#Noremap('/')  " Captures search input but no repeat
"
" ============================================================================

let s:cpo = &cpo
set cpo&vim

silent! call _op_#init#settings#Load()

" Import internal functions
let s:InitCallback      = function('_op_#op#InitCallback')
let s:AssertExprMap     = function('_op_#init#AssertExprMap')
let s:ExtendDefaultOpts = function('_op_#init#ExtendDefaultOpts')
let s:RegisterNoremap   = function('_op_#init#RegisterNoremap')

" op#Map - Create an operator from an existing mapping
"
" Use this when the mapping already exists and you want to capture its input.
" The mapping is preserved and input hijacking is added.
"
" Args:
"   map  - String name of existing mapping (e.g., '<plug>MySurround')
"   opts - Optional dictionary to override defaults (see g:cyclops_map_defaults)
"
" Returns: Expression to be used in <expr> mapping
"
" Must be called from within an <expr> mapping context.
function op#Map(map, ...) abort range
    call s:AssertExprMap()

    " Disable during macro recording/playback to avoid interference
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:map
    endif

    " Initialize operator stack and configure this operator
    let l:handle = _op_#op#StackInit()
    call s:InitCallback(l:handle, 'op', a:map, s:ExtendDefaultOpts(a:000))

    " Escape from operator-pending mode if needed, then compute the mapping
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#op#ComputeMapCallback()\<cr>"
endfunction

" op#Noremap - Create an operator from literal keystrokes
"
" Use this when you want to create an operator from raw keys (not a mapping).
" The keys are treated as-is (like noremap vs map).
"
" Args:
"   map  - String of literal keys (e.g., '/', 'ciw', 'dd')
"   opts - Optional dictionary to override defaults
"
" Returns: Expression to be used in <expr> mapping
"
" Must be called from within an <expr> mapping context.
function op#Noremap(map, ...) abort range
    call s:AssertExprMap()

    " Disable during macro recording/playback
    if !empty(reg_recording()) || !empty(reg_executing())
        return a:map
    endif

    " Register the noremap and initialize operator
    let l:map = s:RegisterNoremap(a:map)
    let l:handle = _op_#op#StackInit()
    call s:InitCallback(l:handle, 'op', l:map, s:ExtendDefaultOpts(a:000))

    " Escape from operator-pending mode if needed, then compute the mapping
    let l:omap_esc = (mode(1)[:1] ==# 'no')? "\<esc>" : ""
    return l:omap_esc .. "\<cmd>call _op_#op#ComputeMapCallback()\<cr>"
endfunction

" op#PrintDebugLog - Display the debug log
"
" Prints all logged debug information to the message area.
" Requires g:cyclops_debug_log_enabled = 1
function op#PrintDebugLog() abort
    call _op_#log#PrintDebugLog()
endfunction

" op#PrintScriptVars - Display internal script state
"
" Prints all internal variables and stack frames for debugging.
function op#PrintScriptVars() abort
    call _op_#log#PrintScriptVars()
endfunction

let &cpo = s:cpo
unlet s:cpo
