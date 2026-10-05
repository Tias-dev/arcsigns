# arcsigns

Минимальный набор функций Neovim для Arcadia/`arc`, вдохновлённый gitsigns.

```lua
vim.opt.rtp:prepend('/home/tabuchkin/git/arc-blame')
require('arcsigns').setup()
```

Команды:

- `:ArcSignsRefresh` — получить `arc diff` и обновить знаки/подсветку изменённых строк;
- `:ArcSignsBlame` — открыть полную построчную blame-панель слева;
- визуальный диапазон поддерживается: `:'<,'>ArcSignsBlame`.

По умолчанию также доступны `<leader>ar` и `<leader>ab`. В blame-панели `q` закрывает окно, `<CR>` открывает коммит в Arcanum.
