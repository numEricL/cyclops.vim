let s:cpo = &cpo
set cpo&vim

if exists("g:cyclops_settings_loaded")
    finish
endif
let g:cyclops_settings_loaded = 1

let g:cyclops_probe_char                    = !exists('g:cyclops_probe_char')                    ? '×'     : g:cyclops_probe_char
let g:cyclops_asserts_enabled               = !exists('g:cyclops_asserts_enabled')               ? 1       : g:cyclops_asserts_enabled
let g:cyclops_max_input_size                = !exists('g:cyclops_max_input_size')                ? 1024    : g:cyclops_max_input_size
let g:cyclops_max_trunc_esc                 = !exists('g:cyclops_max_trunc_esc')                 ? 10      : g:cyclops_max_trunc_esc
let g:cyclops_no_mappings                   = !exists('g:cyclops_no_mappings')                   ? 0       : g:cyclops_no_mappings
let g:cyclops_cursor_highlight_fallback     = !exists('g:cyclops_cursor_highlight_fallback')     ? 'Error' : g:cyclops_cursor_highlight_fallback
let g:cyclops_debug_log_enabled             = !exists('g:cyclops_debug_log_enabled')             ? 0       : g:cyclops_debug_log_enabled
let g:cyclops_suppress_deprecation_warnings = !exists('g:cyclops_suppress_deprecation_warnings') ? 0       : g:cyclops_suppress_deprecation_warnings

if strcharlen(g:cyclops_probe_char) != 1
    throw 'g:cyclops_probe_char must be a single character'
endif
if !exists('g:cyclops_map_defaults')
    let g:cyclops_map_defaults = {}
endif
call extend(g:cyclops_map_defaults, {
            \ 'accepts_count'      : 1,
            \ 'accepts_register'   : 1,
            \ 'silent'             : 1,
            \ 'persistent_count'   : 0,
            \ 'absolute_direction' : 0,
            \ }, 'keep')

let &cpo = s:cpo
unlet s:cpo
