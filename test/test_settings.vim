" Test suite for settings and initialization

function! Test_settings_defaults_loaded()
  " Test that default settings are loaded
  call assert_true(exists('g:cyclops_settings_loaded'), 
        \ 'Settings should be loaded')
endfunction

function! Test_settings_default_values()
  " Test default setting values
  call assert_true(exists('g:cyclops_asserts_enabled'), 
        \ 'asserts_enabled should exist')
  call assert_true(exists('g:cyclops_max_input_size'), 
        \ 'max_input_size should exist')
  call assert_true(exists('g:cyclops_max_trunc_esc'), 
        \ 'max_trunc_esc should exist')
  call assert_true(exists('g:cyclops_no_mappings'), 
        \ 'no_mappings should exist')
  call assert_true(exists('g:cyclops_cursor_highlight_fallback'), 
        \ 'cursor_highlight_fallback should exist')
  call assert_true(exists('g:cyclops_debug_log_enabled'), 
        \ 'debug_log_enabled should exist')
  call assert_true(exists('g:cyclops_persistent_count'), 
        \ 'persistent_count should exist')
endfunction

function! Test_settings_map_defaults()
  " Test map defaults dictionary
  call assert_true(exists('g:cyclops_map_defaults'), 
        \ 'map_defaults should exist')
  call assert_true(has_key(g:cyclops_map_defaults, 'accepts_count'), 
        \ 'map_defaults should have accepts_count')
  call assert_true(has_key(g:cyclops_map_defaults, 'accepts_register'), 
        \ 'map_defaults should have accepts_register')
  call assert_true(has_key(g:cyclops_map_defaults, 'consumes_typeahead'), 
        \ 'map_defaults should have consumes_typeahead')
  call assert_true(has_key(g:cyclops_map_defaults, 'silent'), 
        \ 'map_defaults should have silent')
endfunction

function! Test_settings_map_defaults_values()
  " Test default values in map_defaults
  call assert_equal(1, g:cyclops_map_defaults['accepts_count'])
  call assert_equal(1, g:cyclops_map_defaults['accepts_register'])
  call assert_equal(0, g:cyclops_map_defaults['consumes_typeahead'])
  call assert_equal(1, g:cyclops_map_defaults['silent'])
endfunction

function! Test_plugin_loaded()
  " Test that plugin is loaded
  call assert_true(exists('g:cyclops_loaded'), 'Plugin should be loaded')
endfunction

function! Test_plugin_default_mappings()
  " Test default mappings exist (if not disabled)
  if !g:cyclops_no_mappings
    call assert_true(maparg('.', 'x') != '', 'Visual dot mapping should exist')
    call assert_true(maparg(';', '') != '', 'Semicolon mapping should exist')
    call assert_true(maparg(',', '') != '', 'Comma mapping should exist')
    call assert_true(maparg('f', '') != '', 'f mapping should exist')
    call assert_true(maparg('F', '') != '', 'F mapping should exist')
    call assert_true(maparg('t', '') != '', 't mapping should exist')
    call assert_true(maparg('T', '') != '', 'T mapping should exist')
  endif
endfunction

function! Test_plugin_plugs_exist()
  " Test that plug mappings exist
  call assert_true(maparg('<plug>(dot#vdot)', 'x') != '', 
        \ 'Visual dot plug should exist')
  call assert_true(maparg('<plug>(pair#next)', '') != '', 
        \ 'Pair next plug should exist')
  call assert_true(maparg('<plug>(pair#prev)', '') != '', 
        \ 'Pair prev plug should exist')
endfunction
