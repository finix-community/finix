{
  imports = [
    ./firmware.nix
    ./console.nix
    ./graphics.nix
    ./i2c.nix
    ./uinput.nix
    ./cpu/amd-ucode.nix
    ./cpu/intel-ucode.nix
    ./video/nvidia.nix
    ./video/nvidia-prime.nix
  ];
}
