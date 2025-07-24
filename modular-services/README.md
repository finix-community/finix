# Modular services overlay

This directory contains a Nixpkgs overlay imported from [../overlays/modular-services.nix](../overlays/modular-services.nix) that injects modular services into packages.

Each subdirectory contains a function that is called with the package that it matches the name of the subdirectory. The function returns a service module or an attrset thereof.
