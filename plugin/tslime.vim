" Tslime.vim. Send portion of buffer to tmux instance
" Maintainer: C.Coutinho <kikijump [at] gmail [dot] com>
" Licence:    DWTFYWTPL

if exists("g:loaded_tslime") && g:loaded_tslime
  finish
endif

let g:loaded_tslime = 1

if !exists("g:tslime_ensure_trailing_newlines")
  let g:tslime_ensure_trailing_newlines = 0
endif
if !exists("g:tslime_normal_all_mapping")
  let g:tslime_normal_all_mapping = '<c-c><c-c>'
endif
if !exists("g:tslime_normal_line_mapping")
  let g:tslime_normal_line_mapping = '<c-c><c-c>'
endif
if !exists("g:tslime_visual_mapping")
  let g:tslime_visual_mapping = '<c-c><c-c>'
endif
if !exists("g:tslime_vars_mapping")
  let g:tslime_vars_mapping = '<c-c>v'
endif

function! Chomp(string)
        return substitute(a:string, '\n\+$', '', '')
endfunction

" Main function.
" Use it in your script if you want to send text to a tmux session.
function! Send_to_Tmux(text)
  if !exists("b:tmux_sessionname") || !exists("b:tmux_windowname") || !exists("b:tmux_panenumber")
    if exists("g:tmux_sessionname") && exists("g:tmux_windowname") && exists("g:tmux_panenumber")
      let b:tmux_sessionname = g:tmux_sessionname
      let b:tmux_windowname = g:tmux_windowname
      let b:tmux_panenumber = g:tmux_panenumber
    else
      call <SID>Tmux_Vars()
    end
  end

  let target = b:tmux_sessionname . ":" . b:tmux_windowname . "." . b:tmux_panenumber
  echo target

  " Look, I know this is horrifying.  I'm sorry.
  "
  " THE PROBLEM: Certain REPLs (e.g.: SBCL) choke if you paste an assload of
  " text into them all at once (where 'assload' is 'something more than a few
  " hundred characters but fewer than eight thousand').  They'll seem to get out
  " of sync with the paste, and your code gets mangled.
  "
  " THE SOLUTION: We paste a single line at a time, and sleep for a bit in
  " between each one.  This gives the REPL time to process things and stay
  " caught up.  2 milliseconds seems to be enough of a sleep to avoid breaking
  " things and isn't too painful to sit through.
  "
  " This is my life.  This is computering in 2014.
  for line in split(a:text, '\n\zs' )
    "--------------------------------------------------
    " echo line
    "--------------------------------------------------
    call <SID>set_tmux_buffer(line)
    call system("tmux paste-buffer -dpt " . target)
    sleep 2m
  endfor
endfunction

function! s:ensure_newlines(text)
  let text = a:text
  let trailing_newlines = matchstr(text, '\v\n*$')
  let spaces_to_add = g:tslime_ensure_trailing_newlines - strlen(trailing_newlines)

  while spaces_to_add > 0
    let spaces_to_add -= 1
    let text .= "\n"
  endwhile

  return text
endfunction

function! s:set_tmux_buffer(text)
  call system("tmux set-buffer -- '" . substitute(a:text, "'", "'\\\\''", 'g') . "'")
endfunction

function! SendToTmuxAll(text)
  call Send_to_Tmux(s:ensure_newlines(a:text))
endfunction

function! SendToTmuxLine(text)
  call Send_to_Tmux(s:ensure_newlines(a:text))
endfunction

function! SendToTmuxRaw(text)
  call Send_to_Tmux(a:text)
endfunction

" Session completion
function! Tmux_Session_Names(A,L,P)
  return system("tmux list-sessions | sed -e 's/:.*$//'")
endfunction

" Window completion
function! Tmux_Window_Names(A,L,P)
  return system("tmux list-windows -t" . b:tmux_sessionname . ' | grep -e "^\w:" | sed -e "s/ \[[0-9x]*\]$//"')
endfunction

" Pane completion
function! Tmux_Pane_Numbers(A,L,P)
  return system("tmux list-panes -t " . b:tmux_sessionname . ":" . b:tmux_windowname . " | sed -e 's/:.*$//'")
endfunction

" set tslime.vim variables
function! s:Tmux_Vars()
  "--------------------------------------------------
  " let b:tmux_sessionname = ''
  "--------------------------------------------------
  let b:tmux_sessionname = Chomp(system("tmux list-sessions|grep attached|sed -e 's/:.*$//'"))
  "--------------------------------------------------
  " while b:tmux_sessionname == ''
  "   let b:tmux_sessionname = input("session name: ", "", "custom,Tmux_Session_Names")
  " endwhile
  "--------------------------------------------------
  "--------------------------------------------------
  "--------------------------------------------------
  " let b:tmux_windowname = substitute(input("window name: ", "", "custom,Tmux_Window_Names"), ":.*$" , '', 'g')
  " let b:tmux_panenumber = input("pane number: ", "", "custom,Tmux_Pane_Numbers")
  "--------------------------------------------------


  let b:tmux_windowname = ' '
  let b:tmux_windowname= Chomp(system("tmux display -p| cut -d ':' -f1 | grep -o '[0-9]$'"))

  "--------------------------------------------------
  " if b:tmux_windowname == ''
  "   let b:tmux_windowname = '0'
  " endif
  "--------------------------------------------------
  let b:tmux_panenumber = ' '
  let b:tmux_panenumber= Chomp(system("tmux display -p|grep -o 'pane .* -' | grep -o '[0-9]'")) + 1
  "--------------------------------------------------
  " if b:tmux_panenumber == ''
  "   let b:tmux_panenumber = '0'
  " endif
  "--------------------------------------------------

  "--------------------------------------------------
  " echo b:tmux_sessionname
  "--------------------------------------------------
  echo b:tmux_windowname
  echo b:tmux_panenumber
  "--------------------------------------------------
  let g:tmux_sessionname = b:tmux_sessionname
  let g:tmux_windowname = b:tmux_windowname
  let g:tmux_panenumber = b:tmux_panenumber
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"--------------------------------------------------
" execute "vnoremap" . g:tslime_visual_mapping . ' "ry:call Send_to_Tmux(@r)<CR>'
"--------------------------------------------------
execute "vnoremap" . g:tslime_visual_mapping . ' "ry:call SendToTmuxAll(@r)<CR>'
"--------------------------------------------------
" execute "nnoremap" . g:tslime_normal_all_mapping . ' vip"ry:call Send_to_Tmux(@r)<CR>'
"--------------------------------------------------
execute "nnoremap" . g:tslime_normal_all_mapping . ' vip"ry:call SendToTmuxAll(@r)<CR>'
execute "nnoremap" . g:tslime_normal_line_mapping . ' :call SendToTmuxLine(getline(".")."\n")<CR>'
execute "nnoremap" . g:tslime_vars_mapping   . ' :call <SID>Tmux_Vars()<CR>'
