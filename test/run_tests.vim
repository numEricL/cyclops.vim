" Test runner for cyclops.vim
" Usage: vim -Nu test/run_tests.vim

" Disable Vi compatibility
set nocompatible

" Add the plugin to runtimepath
let s:plugin_dir = expand('<sfile>:p:h:h')
execute 'set runtimepath^=' . s:plugin_dir

" Load the plugin
runtime! plugin/cyclops.vim

" Source all test files
let s:test_dir = expand('<sfile>:p:h')
for s:test_file in glob(s:test_dir . '/test_*.vim', 0, 1)
  execute 'source' s:test_file
endfor

" Test result tracking
let s:tests_run = 0
let s:tests_passed = 0
let s:tests_failed = 0
let s:failed_tests = []

" Run all test functions
function! s:RunTests()
  echo "Running cyclops.vim tests..."
  echo "============================="
  echo ""
  
  " Get all test functions
  let l:test_functions = []
  redir => l:functions_output
  silent function
  redir END
  
  for l:line in split(l:functions_output, "\n")
    if l:line =~ '^function Test_'
      let l:func_name = matchstr(l:line, 'Test_\w\+')
      call add(l:test_functions, l:func_name)
    endif
  endfor
  
  " Run each test
  for l:test_func in l:test_functions
    let s:tests_run += 1
    
    try
      " Run the test
      execute 'call ' . l:test_func . '()'
      
      " Run cleanup if it exists
      if exists('*TearDown')
        call TearDown()
      endif
      
      let s:tests_passed += 1
      echo printf("✓ %s", l:test_func)
    catch
      let s:tests_failed += 1
      call add(s:failed_tests, {'name': l:test_func, 'error': v:exception})
      echo printf("✗ %s", l:test_func)
      echo printf("  Error: %s", v:exception)
    endtry
  endfor
  
  " Print summary
  echo ""
  echo "============================="
  echo printf("Tests run:    %d", s:tests_run)
  echo printf("Tests passed: %d", s:tests_passed)
  echo printf("Tests failed: %d", s:tests_failed)
  echo ""
  
  if s:tests_failed > 0
    echo "Failed tests:"
    for l:failed in s:failed_tests
      echo printf("  - %s", l:failed.name)
      echo printf("    %s", l:failed.error)
    endfor
    echo ""
    cquit 1
  else
    echo "All tests passed!"
    qall!
  endif
endfunction

" Run tests after a short delay to ensure everything is loaded
augroup TestRunner
  autocmd!
  autocmd VimEnter * call timer_start(100, {-> s:RunTests()})
augroup END
