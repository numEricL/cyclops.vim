" ============================================================================
" File: autoload/_op_/init/settings.vim
" Description: Plugin configuration and default settings
" ============================================================================

let s:cpo = &cpo
set cpo&vim

if exists("g:cyclops_settings_loaded")
    finish
endif
let g:cyclops_settings_loaded = 1

" g:cyclops_asserts_enabled - Enable/disable runtime assertions for debugging
let g:cyclops_asserts_enabled           = !exists('g:cyclops_asserts_enabled')           ? 1       : g:cyclops_asserts_enabled

" g:cyclops_max_input_size - Maximum number of characters in operator input
let g:cyclops_max_input_size            = !exists('g:cyclops_max_input_size')            ? 1024    : g:cyclops_max_input_size

" g:cyclops_max_trunc_esc - Maximum consecutive <esc> characters before truncation
let g:cyclops_max_trunc_esc             = !exists('g:cyclops_max_trunc_esc')             ? 10      : g:cyclops_max_trunc_esc

" g:cyclops_no_mappings - Disable default key mappings (., ;, ,, f, F, t, T)
let g:cyclops_no_mappings               = !exists('g:cyclops_no_mappings')               ? 0       : g:cyclops_no_mappings

" g:cyclops_cursor_highlight_fallback - Highlight group for cursor when 'Cursor' unavailable
let g:cyclops_cursor_highlight_fallback = !exists('g:cyclops_cursor_highlight_fallback') ? 'Error' : g:cyclops_cursor_highlight_fallback

" g:cyclops_debug_log_enabled - Enable debug logging (use op#PrintDebugLog() to view)
let g:cyclops_debug_log_enabled         = !exists('g:cyclops_debug_log_enabled')         ? 0       : g:cyclops_debug_log_enabled

" g:cyclops_map_defaults - Default options for all cyclops operators
" These can be overridden per-mapping by passing an options dictionary
if !exists('g:cyclops_map_defaults')
    let g:cyclops_map_defaults = {
                \ 'accepts_count': 1,
                \ 'accepts_register': 1,
                \ 'consumes_typeahead': 0,
                \ 'silent': 1,
                \ }
endif

let &cpo = s:cpo
unlet s:cpo
