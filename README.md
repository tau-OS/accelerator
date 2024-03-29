<div align="center">
  <h1><img src="./data/icons/hicolor/scalable/apps/com.fyralabs.Accelerator.svg" height="64"/>Accelerator</h1>
  <h4>A certain terminal emulator.</h4>
  <p>
    <a href="#features">Features</a> •
    <a href="#install">Install</a> •
    <a href="./CHANGELOG.md">Changelog</a> •
    <a href="./COPYING">License</a> •
    <a href="./CONTRIBUTING.md">Contributing</a>
  </p>
</div>

<div align="center">
  <img src="build-aux/screenshot.png" alt="Preview"/><br/>
</div>

> This is work in progress. Feel free to use Black Box and report any bugs you
> find.

Accelerator is a terminal emulator based on [Black Box](https://gitlab.gnome.org/raggesilver/blackbox) made for the Kiri Desktop. It is a fork of Black Box with libhelium as the UI library.

It is meant to be a successor to Fermion.

## Features

- Theming ([Tilix](https://github.com/gnunn1/tilix) compatible color scheme support)
- Theme integration with the window decorations
- Custom fonts
- Various customizable UI settings
- Tabs
- Toggleable header bar
- Click to open links
- Files drag-n-drop support

## Install
1. [Grab the Flatpakref](https://repo.tauos.co/catalogue/appstream/com.fyralabs.Accelerator.flatpakref)
2. Open it in GNOME Software, Sideload, or your app store of choice **OR** run `flatpak install com.fyralabs.Accelerator.flatpakref`

## Compile

**Flatpak**

To build and run Black Box, use GNOME Builder or VS Code along with [Vala](https://marketplace.visualstudio.com/items?itemName=prince781.vala) and [Flatpak](https://marketplace.visualstudio.com/items?itemName=bilelmoussaoui.flatpak-vscode) extensions.

If you want to build Black Box manually, look at the build script in [.gitlab-ci.yml](./.gitlab-ci.yml).

## Some other screenshots

<div align="center">
  <img src="https://i.imgur.com/O7Nblz8.png" alt="Black Box with 'Show Header bar' off"/><br/>
  <small><i>
    Black Box with "show header bar" off.
  </i></small>
  <br/><br/>
</div>

## Credits

- Most of Black Box's themes come (straight out copied) from [Tilix](https://github.com/gnunn1/tilix)
- Most non-Tilix-default themes come (straight out copied) from [Tilix-Themes](https://github.com/storm119/Tilix-Themes)
- Thank you, @linuxllama, for QA testing and creating Black Box's app icon
- Thank you, @predvodnik, for coming up with the name "Black Box"
- Source code that derives from other projects is properly attributed in the code itself
