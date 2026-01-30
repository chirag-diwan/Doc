if exists('g:loaded_doc')
  finish
endif

g:loaded_doc = 1

function! s:panic (ch, data, ...) abort 
  echomsg join(a:data , "\n")
endfunction

function! s:Start(host) abort
  return jobstart(['Doc'] , {'rpc':v:true , "on_stderr":function('s:panic')} )
endfunction

call remote#host#Register('Doc' , 'x' , function('s:Start'))

call remote#host#RegisterPlugin('Doc', '0', [
\ {'type': 'function', 'name': 'GetFiles', 'sync': 1, 'opts': {}},
\ {'type': 'function', 'name': 'GetIndices', 'sync': 1, 'opts': {}},
\ {'type': 'function', 'name': 'GetPath', 'sync': 1, 'opts': {}},
\ {'type': 'function', 'name': 'Hello', 'sync': 1, 'opts': {}},
\ {'type': 'function', 'name': 'OpenFile', 'sync': 1, 'opts': {}},
\ ])
