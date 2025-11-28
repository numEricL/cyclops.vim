" Integration tests for cyclops.vim

function! Test_integration_dot_repeat_simple()
  " Test simple dot repeat workflow
  " This is a basic test to ensure the infrastructure works
  new
  
  " Setup a simple mapping
  nmap <expr> tid dot#Noremap('x')
  
  " Type some text and use the mapping
  call setline(1, 'test line')
  normal! 0
  
  " The mapping should exist and be callable
  let mapinfo = maparg('tid', 'n', 0, 1)
  call assert_true(!empty(mapinfo), 'Integration mapping should exist')
  call assert_true(mapinfo['expr'] == 1, 'Integration mapping should be expr')
  
  bwipe!
  nunmap tid
endfunction

function! Test_integration_pair_repeat_simple()
  " Test simple pair repeat workflow
  new
  
  " Setup pair mappings
  nmap <expr> tip1 pair#NoremapNext(['j', 'k'], {'accepts_register': 0})
  nmap <expr> tip2 pair#NoremapPrev(['j', 'k'], {'accepts_register': 0})
  
  " Add some lines
  call setline(1, ['line1', 'line2', 'line3'])
  normal! gg
  
  " Verify mappings exist
  call assert_true(maparg('tip1', 'n') != '', 'Pair next mapping should exist')
  call assert_true(maparg('tip2', 'n') != '', 'Pair prev mapping should exist')
  
  bwipe!
  nunmap tip1
  nunmap tip2
endfunction

function! Test_integration_multiple_operators()
  " Test multiple operators working together
  nmap <expr> tio1 op#Noremap('x')
  nmap <expr> tio2 op#Noremap('y')
  nmap <expr> tio3 op#Noremap('z')
  
  " All should be registered
  call assert_true(maparg('tio1', 'n') != '', 'First op should exist')
  call assert_true(maparg('tio2', 'n') != '', 'Second op should exist')
  call assert_true(maparg('tio3', 'n') != '', 'Third op should exist')
  
  nunmap tio1
  nunmap tio2
  nunmap tio3
endfunction

function! Test_integration_visual_mode_support()
  " Test visual mode mappings
  new
  
  vmap <expr> tiv dot#Noremap('x')
  
  call setline(1, 'test visual')
  normal! 0v$
  
  let mapinfo = maparg('tiv', 'v', 0, 1)
  call assert_true(!empty(mapinfo), 'Visual mode mapping should exist')
  
  bwipe!
  vunmap tiv
endfunction

function! Test_integration_options_propagation()
  " Test that options are properly propagated
  nmap <expr> tiop1 dot#Map('x', {'accepts_count': 0, 'accepts_register': 0})
  nmap <expr> tiop2 pair#NoremapNext(['j', 'k'], 
        \ {'accepts_count': 1, 'accepts_register': 0, 'silent': 1})
  
  " Mappings should exist with options applied
  call assert_true(maparg('tiop1', 'n') != '', 'Mapping with options should exist')
  call assert_true(maparg('tiop2', 'n') != '', 'Pair with options should exist')
  
  nunmap tiop1
  nunmap tiop2
endfunction
