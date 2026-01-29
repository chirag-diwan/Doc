# Doc.nvim

![ Demo git]("assets/demo.gif")

## The Problem 
Every found your self jumping between the terminal and google documentation , I have , and let me tell you it is not fun.
The whole workflow gets disrupted just to get a information regarding the language that you are working with

## The Solution
Doc is a nvim plugin that integrates the documentation for many languages into just one simple fuzzy finder . Just search for the thing you want to know about and get it in you neovim session

# Installation


```lazy
{
    "chirag-diwan/Doc"   
}
```

```plug

Plug 'chirag-diwan/Doc'

```

# Configuration

Doc has a minimal configuration setup for its inital development stages

```lua

require("Doc.core").setup({
    enable = true
    keymaps = {
        open = "<leader>dd"
        openauto = "<leader>da"
    }
})

```
