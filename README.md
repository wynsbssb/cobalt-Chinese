# Cobalt
a shadcn/ui styled remotespy made for developement purposes.

## Features

- Beatiful UI & Animations
- Smart Code Generation
- Syntax Highlighting (to preview the code to replay the remote)
- Remote Filtering (see which remotes get sent by the executor and by the game)
- Cached Paths (prevents losing context of the remote's parent)
- Anti Detection (attempts to mitigate detection vectors)
- Optimizations such as pagination
- Better Remote Firing Detector

## Usage

```lua
loadstring(game:HttpGet("https://github.com/notpoiu/cobalt/releases/latest/download/Cobalt.luau"))()
```

# Development
## Prerequisites

To enhance your work environment, I recommend installing all the recommended [extensions](.vscode/extensions.json).

## Bundling everything

> [!IMPORTANT]
> Bundling should only be used for testing.
> If you want to make a new Release, please head to the GitHub "Actions" tab and run the "Release" action.

To bundle all the scripts, you have to follow these steps:

1. Install [rokit](https://github.com/rojo-rbx/rokit) if you haven't already
2. Open Powershell or the command-line shell of your liking and [cd to this repository](https://www.quora.com/What-does-it-mean-to-CD-into-a-directory-and-how-can-I-do-that-Can-someone-explain-it-in-a-laymans-term)
3. Run `rokit install` and wait for it to install all the dependencies
4. In VSCode, press CTRL + SHIFT + B to build or run this command `lune run Build bundle header=Build/Header.luau`
5. The bundled file will be located in `Build/Script.luau` and can be used in your executor via loadstring if you use live share plugin (`loadstring(game:HttpGet("http://localhost:5500/Distribution/Script.luau"))()`)