# adaptive-theme.nvim

Change your Neovim theme based on the current system theme preference (light/dark)

## Dependences

This plugin requires `ldbus` from `luarocks`

```shell
luarocks install ldbus --lua-version 5.1 --local --server https://luarocks.org/dev/ DBUS_ARCH_INCDIR=/usr/lib64/dbus-1.0/include/ DBUS_INCDIR=/usr/include/dbus-1.0/
```

>[!NOTE]
> You may need to change the paths to the `dbus` include directories

## Usage

On Lazy.nvim

```lua
{ 
  "mktip/adaptive-theme.nvim", 
  opts = { 

    -- The function that will be called when the system theme preference changes
    theme_handler = function(background) 
      if background == "none" then 
        return
      end

      vim.o.background = background
      if background == "dark" then
        vim.cmd [[colorscheme your_prefered_dark_theme]]
      else
        vim.cmd [[colorscheme your_prefered_light_theme]]
      end
    end
  }
},
```
