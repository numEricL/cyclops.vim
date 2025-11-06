if exists("g:cyclops_loaded")
    finish
endif
let g:cyclops_loaded = 1

let g:cyclops_max_input_size              = !exists('g:cyclops_max_input_size')              ? 1024    : g:cyclops_max_input_size
let g:cyclops_no_mappings                 = !exists('g:cyclops_no_mappings')                 ? 0       : g:cyclops_no_mappings
let g:cyclops_cursor_highlight_fallback   = !exists('g:cyclops_cursor_highlight_fallback')   ? 'Error' : g:cyclops_cursor_highlight_fallback
let g:cyclops_map_defaults = {
            \ 'accepts_count': 1,
            \ 'accepts_register': 1,
            \ 'shift_marks': 0,
            \ 'visual_motion': 0,
            \ 'consumes_typeahead': 0,
            \ 'silent': 1,
            \ }

if !g:cyclops_no_mappings
    nmap . <plug>(dot#dot)
    vmap . <plug>(dot#visual_dot)
    omap . <plug>(dot#op_pending_dot)

    nmap ; <plug>(pair#next)
    vmap ; <plug>(pair#visual_next)
    omap ; <plug>(pair#op_pending_next)

    nmap , <plug>(pair#previous)
    vmap , <plug>(pair#visual_previous)
    omap , <plug>(pair#op_pending_previous)
endif
