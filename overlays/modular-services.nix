final: prev:

let
  inherit (builtins)
    attrNames
    filter
    getAttr
    isAttrs
    listToAttrs
    readDir
    ;

  entries = readDir ../modular-services;
in
entries
|> attrNames
|> filter (name: (getAttr name entries) == "directory")
|> map (name: {
  inherit name;
  value = prev.${name}.overrideAttrs ({ passthru ? { }, ... }:
    {
      passthru = passthru // {
        # TODO: establish a convention on services in passthru.
        #
        # Here a single service is likely being defined but
        # the modular services example has an attrset like:
        # `{ services.default = { config, lib, pkgs, ... }: …; }`
        services = import ../modular-services/${name} final.${name};
      };
    });
})
|> listToAttrs
