{ extendModules, lib, ... }:
let
  noClone = {
    specialisation = lib.mkOverride 0 { };
  };
in
{
  options.specialisation = lib.mkOption {
    type = lib.types.attrsOf (extendModules { modules = [ noClone ]; }).type;
    default = { };
    example = lib.literalExpression ''
      {
        mdevd = {
          services.mdevd.enable = lib.mkForce true;
          services.udev.enable = lib.mkForce false;
        };
      }
    '';
    description = ''
      Additional configurations to build.
    '';
    visible = "shallow";
  };
}
