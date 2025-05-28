# Tcl test driver preamble.

# Exit successfully.
proc success {} {
  exit 0
}

# Exit with failure.
proc fail {reason} {
  puts stderr $reason
  exit 1
}

# Create and populate a namespace for a node.
# The body is evaluated inside the namespace
# to setup node specific variables.
proc CreateNode {name body} {

  # Each node has a namespace nested within testNodes.
  set ns ::testNodes::$name

  namespace eval $ns {
    variable spawn_id -1
    variable nodeName [namespace tail [namespace current]]

    # Spawn the node.
    proc spawn {} {
      variable spawnCmd
      variable spawn_id
      ::spawn {*}$spawnCmd
    }

    proc failTimeout {pat} {
      variable nodeName
      fail "timeout while waiting for $nodeName to produce $pat"
    }

    # Expect output from the node.
    proc expect {args} {
      variable spawn_id
      # Fail on timeout unless overridden by the caller.
      expect_after timeout [list failTimeout $args]
      ::expect {*}$args
    }

    # Tell the node to quit.
    proc sendQuit {} {
      variable spawn_id
      close -i $spawn_id
    }

    # Wait for the spawned process to exit.
    proc wait {} {
      variable spawn_id
      ::wait -i $spawn_id
    }
  }

  # Eval node-specific script.
  namespace eval $ns $body

  # Create the command syntax.
  namespace eval $ns {
    namespace export *
    namespace ensemble create
  }
  namespace eval testNodes [list namespace export $name]
}

# If this is a Nix build then log to $out and copy that to stderr.
if {[info exists env(out)]} {
   log_file $env(out)
   set fid [open $env(out) r]
   chan configure $fid -blocking 0
   chan event $fid readable [chan copy $fid stderr]
}
