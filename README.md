# F-nixos

<p align="center">
  <a href="https://nixos.org"><img src="https://img.shields.io/badge/Built_with-Nix-5277C3?logo=nixos&logoColor=white" alt="Built with Nix"></a>
  <a href="https://discord.gg/nVe5Zkaypg"><img src="https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white" alt="Discord"></a>
  <a href="https://github.com/finix-community/finix"><img src="https://img.shields.io/badge/Community-finix-orange" alt="Finix Community"></a>
</p>

> F-nixos (Fixing nixos) of all the hardcoded asumptions fork of finix which decopules the init to be agnostic keeping compatibility with nixos

> **Note:** F-nixos is a fork of [finix](https://github.com/finix-community/finix) by the finix-community. All credits for the foundational work go to them!

This project aims to fix NixOS by creating a software system without hardcoded assumptions or opinions—striving for true agnosticism.


## Overview

**F-nixos** is an experimental, modular NixOS framework designed to push declarative systems engineering to the absolute edge.

### The Core Vision & Mission
- **Currently working on decoupling bash and bashisms for true system minimalism.**
- **The Ultimate OpenWrt Slayer & Embedded RISC-V Powerhouse:** Managing embedded systems to replace OpenWrt and build ultra-small, deterministic flash images using `ubase`, `busybox`, or custom `uutils`. Perfect for constrained targets like RISC-V boards (Milk-V, StarFive, D1) and IoT devices.
- **True Shell Agnosticism:** Who says `/bin/sh` has to be a bloated GNU Bash? Run a system completely free of Bash, leveraging lightweight alternatives like `ash`, `dash`, `kmsh`, or whatever fits your architecture.
- **The Next-Gen Config Language:** Planned development of a dedicated, non-Turing-complete configuration language (inspired by Dhall) to guarantee evaluation termination and eliminate Nix quirks, keeping a cleaner and less abstract approach than alternatives like Lix, Snix, or Nickel.
- **Daemon & Tooling Agnostic:** Decoupling userland from the traditional `nix-daemon` RPC protocol to allow modular store managers, transport layers, and independent tooling ecosystems.
- **Kernel Agnostic Explorations:** Investigating alternative kernel architectures and primitives, including framework experiments like [sigil](https://git.sr.ht/~ehmry/sigil) and [lladios](https://github.com/llakala/lladios).

## Features

- **Agnostic Architecture:** Build custom system configurations using reusable, decoupled Nix modules.
- **Flexible Shells & Utilities:** Plug-and-play support for alternative shells (`ash`, `dash`, `bash`, `fish`) and minimal userland coreutils.
- **Embedded & Multi-System Support:** Optimized for minimal resource footprints across `x86_64-linux`, `aarch64-linux`, and RISC-V architectures.

## Ideas into consideration (feel free to reach me and suggest ideas)
- Exploring alternative high-performance lazy module evaluation engines (such as [lladios](https://github.com/llakala/lladios)) to slash evaluation overhead.
- Designing custom non-Turing complete configurations to bypass traditional Nix interpreter bottlenecks.

## TODO
- [ ] Decouple remaining hardcoded bashisms from core build scripts and activation logic
- [ ] Agnostic init system integration (finit and minimal PID 1 architectures)
- [ ] Agnostic shell support (`ash`, `dash`, `kmsh` integration)
- [ ] Minimal embedded image generation using `ubase`, `busybox`, and `uutils` (OpenWrt replacement target)
- [ ] RISC-V hardware target validation and optimization
- [ ] Kernel-agnostic component and framework integration (via [sigil](https://git.sr.ht/~ehmry/sigil))
- [ ] Non-Turing-complete configuration language specification (guaranteed termination/Dhall-inspired)
- [ ] Daemon-agnostic tooling decoupling (`nix-daemon` independence)
- [ ] Ensure full backward compatibility with standard NixOS packages and modules
- [ ] Remove all remaining hardcoded system assumptions and opinions
- [ ] Expand documentation and agnostic configuration examples
- [ ] Agnostic init system integration (finit and minimal PID 1 architectures)
- [ ] Agnostic shell support (`ash`, `dash`, `kmsh` integration)
- [ ] Minimal embedded image generation using `ubase`, `busybox`, and `uutils` (OpenWrt replacement target)
- [ ] RISC-V hardware target validation and optimization
- [ ] Kernel-agnostic component and framework integration (via [sigil](https://git.sr.ht/~ehmry/sigil))
- [ ] Non-Turing-complete configuration language specification (guaranteed termination/Dhall-inspired)
- [ ] Daemon-agnostic tooling decoupling (`nix-daemon` independence)
- [ ] Ensure full backward compatibility with standard NixOS packages and modules
- [ ] Remove all remaining hardcoded system assumptions and opinions
- [ ] Expand documentation and agnostic configuration examples

- [ ] Agnostic init
- [ ] Agnostic shell
- [ ] Agnostic utilities
- [ ] Agnostic kernel
- [ ] Ensure full compatibility with NixOS
- [ ] Remove remaining hardcoded system assumptions
- [ ] Enhance modular shell support
- [ ] Expand documentation and agnostic configuration examples
- [ ] Improve testing workflows
