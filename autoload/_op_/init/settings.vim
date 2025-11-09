let s:cpo = &cpo
set cpo&vim

if exists("g:cyclops_settings_loaded")
    finish
endif
let g:cyclops_settings_loaded = 1

let g:cyclops_asserts_enabled             = !exists('g:cyclops_asserts_enabled')             ? 1       : g:cyclops_asserts_enabled
let g:cyclops_max_input_size              = !exists('g:cyclops_max_input_size')              ? 1024    : g:cyclops_max_input_size
let g:cyclops_max_trunc_esc               = !exists('g:cyclops_max_trunc_esc')               ? 10      : g:cyclops_max_trunc_esc
let g:cyclops_no_mappings                 = !exists('g:cyclops_no_mappings')                 ? 0       : g:cyclops_no_mappings
let g:cyclops_cursor_highlight_fallback   = !exists('g:cyclops_cursor_highlight_fallback')   ? 'Error' : g:cyclops_cursor_highlight_fallback
let g:cyclops_debug_log_enabled           = !exists('g:cyclops_debug_log_enabled')           ? 0       : g:cyclops_debug_log_enabled
let g:cyclops_check_for_errors_enabled    = !exists('g:cyclops_check_for_errors_enabled')    ? 1       : g:cyclops_check_for_errors_enabled

if !exists('g:cyclops_map_defaults')
    let g:cyclops_map_defaults = {
                \ 'accepts_count': 1,
                \ 'accepts_register': 1,
                \ 'shift_marks': 0,
                \ 'visual_motion': 0,
                \ 'consumes_typeahead': 0,
                \ 'silent': 1,
                \ }
endif

let &cpo = s:cpo
unlet s:cpo
