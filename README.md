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

**F-nixos** is a modular NixOS framework designed to provide granular control over your system architecture, from initialization and shells to kernels and utilities.

## Features

- **Agnostic Architecture:** Build custom system configurations using reusable Nix modules.
- **Flexible Shells & Utilities:** Supports multiple shells (`ash`, `bash`, `fish`) and modular system services.
- **Multi-System Support:** Built for both `x86_64-linux` and `aarch64-linux`.

## TODO

- [ ] Agnostic init
- [ ] Agnostic shell
- [ ] Agnostic utilities
- [ ] Agnostic kernel
- [ ] Ensure full compatibility with NixOS
- [ ] Remove remaining hardcoded system assumptions
- [ ] Enhance modular shell support
- [ ] Expand documentation and agnostic configuration examples
- [ ] Improve testing workflows
