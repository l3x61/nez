# NEZ
NES emulator written in Zig.

![screenshot](screenshot.png)

## ToDo
- [x] load NES file
    - [ ] implement mappers
- [ ] implement input devices
- [ ] emulate CPU
- [ ] emulate PPU
- [ ] emulate APU
---
- [ ] docking
- [ ] save window state (visibility)

## Dependencies
- [Zig 0.14.0-dev.2577+271452d22](https://machengine.org/docs/nominated-zig/)

### Included Dependencies
- [zig-gamedev](https://github.com/zig-gamedev/zig-gamedev)
- [zosdialog](https://github.com/l3x61/zosdialog)
- [NerdFont](https://www.nerdfonts.com/)
- [JetBrains Mono](https://www.jetbrains.com/lp/mono/)
- [nes-test-roms](https://github.com/christopherpow/nes-test-roms)

## References
- NES
    - [NES Architecture](https://www.copetti.org/writings/consoles/nes/)
    - [Nesdev Wiki](https://www.nesdev.org/wiki/Nesdev_Wiki)
- 6502
    - [Visual 6502](http://visual6502.org)
    - [Breadboard](https://github.com/TheParp/PRP-6502/wiki)
    - [Emulator](https://masswerk.at/6502/)
    - [6502 Reset](https://www.pagetable.com/?p=410)

## Issues
- osdialog does not work on Wayland, most likely because of `libdecor-gtk`