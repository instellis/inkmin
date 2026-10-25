# Inkmin

## Introduction

Inkmin is a tool for creating narrative content for games, especially dialogues. It is made with Godot and produces JSON files that games built with any engine can use. This repository contains the tool's source code and an example of how to use its output in a Godot game.

Inkmin source code is compatible with [Godot 4.7](https://godotengine.org/download/).

An executable version of the tool can be downloaded from itch.io : [here](https://instellis.itch.io/inkmin)

https://github.com/user-attachments/assets/fec859ae-8b18-4852-ba9b-29687b0e698a

## How it works

Inkmin is based on a simplified version of the wonderful narrative-making language [Ink](https://www.inklestudios.com/ink/). It's purpose is to make writing for games as simple as possible, while tackling some technical issues linked to performance and translations on bigger projects.

Inkmin is an editor that organizes a story project into **knots**: named sections that contain readable lines of dialogue and use simple tags to add choices, branches, conditions, variable changes, and signals for the game. The editor also provides a preview panel for testing the game flow.

Behind the hood, Inkmin converts the knots into JSON files. The game is then responsible for loading the JSON files and deciding how to display text and choices or react to signals they contain. This repository includes a sample scene showing one way to do this.

## Repository content

This repository contains the source code of the inkmin tool and an example scene. 

- main folder: `editor.tscn` and `editor.gd`: the main Inkmin editor scene.
- `inkmin/` folder: the JSON converter, narrative reader, and supporting editor components.
- `scenariocreator/` folder: a separate helper for drawing scenario graphs.
- `samples/` folder: a sample dialogue project, a Godot dialogue scene, and example integration code.
- `help/` folder: detailed guidance for the editor and Inkmin's narrative syntax.

## Detailed instructions

- [Create and work with a project](help/help.en.md#editor)
- [Write Inkmin narrative content](help/help.en.md#inkmin-language)
- [Implement Inkmin in a Godot game](help/help.en.md#implementation)

## License

(c) 2026 Instellis
Inkmin is released under the [MIT License](LICENSE).
