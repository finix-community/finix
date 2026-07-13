# several functions in this file were copied from `nixpkgs` with minimal to no modification
{ lib }:
{
  # simple path escape into a name safe for use as a finit stanza name and conditions
  escapePath =
    s: if s == "/" then "root" else lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" s);

  # Convert a shell package or path into an absolute shell path.
  toShellPath =
    shell:
    if lib.types.shellPackage.check shell then
      "/run/current-system/sw${shell.shellPath}"
    else if lib.types.package.check shell then
      throw "${shell} is not a shell package"
    else
      shell;

  # Comparator for topologically sorting filesystems so that a mount is ordered
  # before any mount that depends on it (its parent mountpoints and devices).
  fsBefore =
    a: b:
    let
      # Add a trailing slash if missing, so that e.g. mountPoint "/aaa" is not
      # treated as a prefix of device "/aaaa".
      normalisePath = path: "${path}${lib.optionalString (!(lib.hasSuffix "/" path)) "/"}";
      normalise =
        mount:
        mount
        // {
          device = normalisePath (toString mount.device);
          mountPoint = normalisePath mount.mountPoint;
          depends = map normalisePath mount.depends;
        };
      a' = normalise a;
      b' = normalise b;
    in
    lib.hasPrefix a'.mountPoint b'.device
    || lib.hasPrefix a'.mountPoint b'.mountPoint
    || lib.any (lib.hasPrefix a'.mountPoint) b'.depends;
}
