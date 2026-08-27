colorscheme solarized8_high

" --------------- Plugins --------------
set nocompatible
filetype off
call plug#begin('~/.vim/plugged')

Plug 'scrooloose/nerdtree'  " file explorer
Plug 'vim-airline/vim-airline'  " custom status line
Plug 'vim-airline/vim-airline-themes'  " custom status line themes
Plug 'ryanoasis/vim-devicons'  " enable file icons
Plug 'ervandew/supertab'  " use tab for completion
Plug 'tpope/vim-commentary'  " allows gcc for comment
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim' " fuzzy file finding
Plug 'neoclide/coc.nvim', {'branch': 'release'}  " needed for LSP
Plug 'sheerun/vim-polyglot'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'autozimu/LanguageClient-neovim', {  
    \ 'branch': 'next',
    \ 'do': 'bash install.sh',
    \ }
" Plug 'dense-analysis/ale'  " linting and LSP features
" Plug 'davidhalter/jedi-vim'   " jedi for python

call plug#end()
filetype plugin indent on 
filetype on
syntax on

" --------------- Options --------------
set termencoding=utf-8
set number relativenumber " enable rel line numbers 
set autoread 
set encoding=utf8 " set file/terminal encodings
set clipboard=unnamed " enable clipboard outside of vim
set autoread " automatically refresh file if changed from outside vim
set title " show file titles
set cursorline " highlight the cursor's line
set mouse=a " enable mouse support
set autoindent " automatically indent new lines
set expandtab smarttab tabstop=8 shiftwidth=4 softtabstop=0 " python autoindent
set history=1000  " remember more commands and search history
set splitright splitbelow  " prefer below when splitting
" set omnifunc=syntaxcomplete#Complete " use omni completion
set backspace=indent,eol,start " allow backspace everywhere
set showmatch " highlight matches when searching
set linebreak  " make line breaks on words
set hlsearch smartcase ignorecase
set noswapfile  " swap files give annoying warning

" --------------- Airline --------------
let g:bargreybars_auto=1
let g:airline_theme='google_dark'
let g:airline_solorized_bg='dark'
let g:airline_powerline_fonts=1
let g:airline#extensions#languageclient#enabled = 1
let g:airline#extension#tabline#enable=1
let g:airline#extension#tabline#left_sep=' '
let g:airline#extension#tabline#left_alt_sep='|'
let g:airline#extension#tabline#formatter='unique_tail'

" --------------- Nerdtree --------------
let NERDTreeIgnore=['\.pyc$','\~$'] 
map <C-b> :NERDTreeToggle<CR>
autocmd VimEnter * NERDTree
autocmd BufEnter * if (winnr("$") == 1 && exists("b:NERDTree") && b:NERDTree.isTabTree()) | q | endif

" --------------- Python  --------------
let python_highlight_all=1
let g:kite_supported_languages=['python', 'javascript']
au BufNewFile,BufRead,BufEnter *.py set textwidth=82 fileformat=unix

" --------------- Keymaps  --------------
nnoremap <C-t> :terminal<CR>  

" --------------- LSP --------------
let g:LanguageClient_serverCommands = {'python': ['~/.pyenv/shims/pylsp']}
" let g:LanguageClient_autoStart=1
" let g:LanguageClient_serverStderr=1

nnoremap  K :call LanguageClient#textDocument_hover()<CR>
nnoremap  gd :vs +call\ LanguageClient#textDocument_definition()<CR>
nnoremap  gr :call LanguageClient#textDocument_references()<CR>
nnoremap  ren :call LanguageClient#textDocument_rename()<CR>
nnoremap  fmt :call LanguageClient#textDocument_formatting()<CR>

" -------------- Misc --------------
highlight VertSplit ctermbg=253
