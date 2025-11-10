{ writeShellApplication }:
writeShellApplication {
  name = "finix-rebuild";
  text = builtins.readFile ./finix-rebuild.sh;
}
