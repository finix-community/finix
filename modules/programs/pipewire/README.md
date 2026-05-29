# pipewire

This module installs PipeWire as a standalone program and allows you to define configuration options for its various components, which are then serialized to PipeWire's native config format. Config files are then generated from these options and symlinked to the necessary directories that PipeWire expects. 

## usage

This module does not provide a system service like NixOS. Instead, you will need to run the `pipewire` command in an `autostart` script in your Wayland compositor or x11 window manager. Here is an example of what this might look like:

```
pipewire 2>&1 &
sleep 0.5; wireplumber 2>&1 &
sleep 0.5; pipewire-pulse 2>&1 &
```

The half a second sleep between starting `wireplumber` and `pipewire-pulse` is recommended to make sure `pipewire` has enough time to fully start up. This would normally be handled in service conditions.
