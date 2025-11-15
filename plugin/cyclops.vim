" ============================================================================
" Plugin: cyclops.vim
" Description: Makes custom Vim operators repeatable with dot (.) and pair (; ,)
" ============================================================================

if exists("g:cyclops_loaded")
    finish
endif
let g:cyclops_loaded = 1

" Save and restore compatibility options
let s:cpo = &cpo
set cpo&vim

" Load plugin settings and defaults
silent! call _op_#init#settings#Load()

" Define <plug> mappings for dot-repeat and pair-repeat functionality
" These are used internally and can be remapped by users
noremap <expr> <plug>(dot#dot) _op_#dot#RepeatMap()
noremap <expr> <plug>(pair#next) _op_#pair#PairRepeatMap('next')
noremap <expr> <plug>(pair#prev) _op_#pair#PairRepeatMap('prev')

" Set up default mappings unless disabled by user
" g:cyclops_no_mappings = 1 disables all default mappings
if !g:cyclops_no_mappings
    " Override dot (.) to support custom operator repeat
    noremap . <plug>(dot#dot)

    " Override semicolon (;) and comma (,) for pair-repeat
    noremap ; <plug>(pair#next)
    noremap , <plug>(pair#prev)

    " Make f/F and t/T repeatable with ; and ,
    noremap <expr> f pair#NoremapNext(['f', 'F'])
    noremap <expr> F pair#NoremapPrev(['f', 'F'])
    noremap <expr> t pair#NoremapNext(['t', 'T'])
    noremap <expr> T pair#NoremapPrev(['t', 'T'])
endif

" Restore compatibility options
let &cpo = s:cpo
unlet s:cpo
