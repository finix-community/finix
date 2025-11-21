#!/usr/bin/env bash

set -e

declare -A nix_paths
config_file=""
action="switch"
attr_path="config.system.topLevel"
attr_specified=false
flake=""
use_flake=false
specialisation=""
impure=""

# Check for nom availability and set build commands
if command -v nom-build &> /dev/null; then
  nix_build_cmd="nom-build"
else
  nix_build_cmd="nix-build"
fi

if command -v nom &> /dev/null; then
  flake_build_cmd="nom build"
else
  flake_build_cmd="nix build"
fi

show_help() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS] [ACTION]

ACTIONS:
  build       build the configuration
  boot        build and install to system profile, update boot loader
  test        build and activate configuration without making it default
  switch      build, install, update boot loader, and activate (default)
  repl        start an interactive nix repl with the configuration

OPTIONS:
  -f, --file FILE      use FILE as the configuration file
                       (default: finix-config from NIX_PATH, or ./default.nix if not set)
  --flake FLAKE        build from flake at FLAKE (default: current directory)
                       format: path#name (e.g., .#myhost or /path/to/flake#server)
                       if name is omitted, uses current hostname
  -A, --attr ATTR      nix attribute path to build (default: config.system.topLevel)
                       ignored when using --flake
  --impure             allow access to mutable paths and environment variables (flakes only)
  -h, --help           show this help message
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--file)
      if [[ -z "$2" || "$2" == -* ]]; then
        echo "Error: --file requires a file path" >&2
        exit 1
      fi
      config_file="$2"
      shift 2
      ;;
    --flake)
      use_flake=true
      if [[ -z "$2" || "$2" == -* ]] || [[ "$2" =~ ^(build|boot|test|switch)$ ]]; then
        flake="."
        shift 1
      else
        flake="$2"
        shift 2
      fi
      ;;
    -A|--attr)
      if [[ -z "$2" || "$2" == -* ]]; then
        echo "Error: --attr requires an attribute path" >&2
        exit 1
      fi
      attr_path="$2"
      attr_specified=true
      shift 2
      ;;
    --specialisation|-c)
      if [ -z "$1" ]; then
          log "$0: ‘--specialisation’ requires an argument"
          exit 1
      fi
      specialisation="$2"
      shift 2
      ;;
    --impure)
      impure="--impure"
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    build|boot|test|switch|repl)
      action="$1"
      shift
      ;;
    *)
      echo "Error: Unknown option or action: $1" >&2
      echo "Use --help for usage information" >&2
      exit 1
      ;;
  esac
done

IFS=':'

for item in $NIX_PATH; do
  IFS='=' read -r key value <<< "$item"
  nix_paths["$key"]="$value"
done

unset IFS

# Handle flake configuration
if [[ "$use_flake" == true ]]; then
  # Parse flake path and name
  if [[ "$flake" == *"#"* ]]; then
    flake_path="${flake%%#*}"
    flake_name="${flake##*#}"
  else
    flake_path="$flake"
    flake_name=""
  fi
  
  # Ensure flake_path defaults to current directory if empty
  if [[ -z "$flake_path" ]]; then
    flake_path="."
  fi
  
  # Use hostname if flake_name is empty
  if [[ -z "$flake_name" ]]; then
    flake_name="$(hostname)"
  fi
  
  # Build the full flake reference
  flake_ref="${flake_path}#finixConfigurations.${flake_name}.config.system.topLevel"
else
  # Determine config source for non-flake builds
  if [[ -n "$config_file" ]]; then
    config_source="$config_file"
  elif [[ "$attr_specified" == true ]]; then
    # If --attr is explicitly specified but --file is not, use ./default.nix
    config_source="./default.nix"
  elif [[ -v nix_paths[finix-config] ]] && [[ -n "${nix_paths[finix-config]}" ]]; then
    config_source="${nix_paths[finix-config]}"
  else
    config_source="./default.nix"
  fi
fi

if [[ ! -z "$specialisation" && ! "$action" = switch && ! "$action" = test ]]; then
  echo "error: ‘--specialisation’ can only be used with ‘switch’ and ‘test’"
  exit 1
fi

case "$action" in
  build)
    # build the configuration
    if [[ "$use_flake" == true ]]; then
      pathToConfig=$($flake_build_cmd "$flake_ref" $impure --print-out-paths)
    else
      pathToConfig=$($nix_build_cmd "$config_source" -A "$attr_path")
    fi
  ;;

  boot)
    # build the configuration
    if [[ "$use_flake" == true ]]; then
      pathToConfig=$($flake_build_cmd "$flake_ref" --no-link $impure --print-out-paths)
    else
      pathToConfig=$($nix_build_cmd "$config_source" --no-out-link -A "$attr_path")
    fi

    # install to the system profile
    sudo --preserve-env=NIX_PATH nix-env --profile /nix/var/nix/profiles/system --set "$pathToConfig"

    # rebuild boot loader entries
    sudo --preserve-env=NIX_PATH "$pathToConfig/bin/switch-to-configuration" "$action"
  ;;

  test)
    # build the configuration
    if [[ "$use_flake" == true ]]; then
      pathToConfig=$($flake_build_cmd "$flake_ref" --no-link $impure --print-out-paths)
    else
      pathToConfig=$($nix_build_cmd "$config_source" --no-out-link -A "$attr_path")
    fi

    if [[ -z "$specialisation" ]]; then
      cmd="$pathToConfig/bin/switch-to-configuration"
    else
      cmd="$pathToConfig/specialisation/$specialisation/bin/switch-to-configuration"
    fi

    if [[ ! -f "$cmd" ]]; then
      echo "error: specialisation not found: $specialisation"
      exit 1
    fi

    # activate the configuration, reload finit
    sudo --preserve-env=NIX_PATH "$cmd" "$action"
  ;;

  switch)
    # build the configuration
    if [[ "$use_flake" == true ]]; then
      pathToConfig=$($flake_build_cmd "$flake_ref" --no-link $impure --print-out-paths)
    else
      pathToConfig=$($nix_build_cmd "$config_source" --no-out-link -A "$attr_path")
    fi

    if [[ -z "$specialisation" ]]; then
      cmd="$pathToConfig/bin/switch-to-configuration"
    else
      cmd="$pathToConfig/specialisation/$specialisation/bin/switch-to-configuration"
    fi

    if [[ ! -f "$cmd" ]]; then
      echo "error: specialisation not found: $specialisation"
      exit 1
    fi

    # install to the system profile
    sudo --preserve-env=NIX_PATH nix-env --profile /nix/var/nix/profiles/system --set "$pathToConfig"

    # rebuild boot loader entries, activate the configuration, reload finit
    sudo --preserve-env=NIX_PATH "$cmd" "$action"
  ;;

  repl)
    # start a REPL with the configuration
    if [[ "$use_flake" == true ]]; then
      nix repl "$flake_ref" $impure
    else
      nix repl --file "$config_source"
    fi
  ;;

  *)
    echo "Error: Invalid action: $action" >&2
    show_help
    exit 1
  ;;
esac
