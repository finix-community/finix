# tcl test driver preamble

package require Tcl 8.6

# ensure stderr is line-buffered for real-time output display
fconfigure stderr -buffering line

# ============================================================================
# timeout constants (in seconds)
# ============================================================================

# default timeout for command execution via shell backdoor
if {![info exists DEFAULT_CMD_TIMEOUT]} { set DEFAULT_CMD_TIMEOUT 900 }

# timeout for socket connections (waiting for qemu to create sockets)
if {![info exists CONNECT_TIMEOUT]} { set CONNECT_TIMEOUT 60 }

# timeout for monitor commands and quick operations
if {![info exists QUICK_TIMEOUT]} { set QUICK_TIMEOUT 10 }

# timeout for draining initial shell buffer
if {![info exists DRAIN_TIMEOUT]} { set DRAIN_TIMEOUT 2 }

# timeout for polling operations (waitUntilSucceeds inner loop)
if {![info exists POLL_TIMEOUT]} { set POLL_TIMEOUT 30 }

# log a message to stderr
proc log {msg} {
  puts stderr $msg
}

# exit successfully
proc success {} {
  exit 0
}

# exit with failure (test-level failure)
proc testFail {reason} {
  log "FAIL: $reason"
  exit 1
}

# ============================================================================
# test organization helpers
# ============================================================================

# start all defined test nodes
# useful for multi-vm tests that want all vms running in parallel
# usage: startAll
proc startAll {} {
  foreach node [namespace children ::testNodes] {
    ${node}::start
  }
}

# run a test section with logging and timing
# groups related tests together for better output organization
# if the body fails (throws an error), the test is marked as failed
# usage: subtest "description" { test commands... }
proc subtest {name body} {
  log "subtest: $name"
  set start [clock milliseconds]
  if {[catch {uplevel 1 $body} err]} {
    log "test \"$name\" failed: $err"
    testFail $err
  }
  set elapsed [expr {([clock milliseconds] - $start) / 1000.0}]
  log "(finished: $name, in ${elapsed}s)"
}

# ============================================================================
# shell quoting helper
# ============================================================================

# quote a string for safe use in shell commands using single quotes.
# this handles embedded single quotes by breaking out of the quoted string,
# adding an escaped single quote, and re-entering the quoted string.
#
# limitations:
# - does not handle null bytes (use base64 encoding for binary data)
# - for very long strings, consider using file-based transfer instead
#
# example: shellQuote "it's cool" => 'it'\''s cool'
proc shellQuote {str} {
  return "'[string map {' '\\''} $str]'"
}

# ============================================================================
# node namespace definition
# ============================================================================

# create and populate a namespace for a node.
# the body is evaluated inside the namespace
# to setup node specific variables.
proc CreateNode {name body} {

  # each node has a namespace nested within testNodes.
  set ns ::testNodes::$name

  namespace eval $ns {
    variable spawn_id -1
    variable nodeName [namespace tail [namespace current]]
    variable stateDir ""
    variable shellSpawnId ""
    variable shellConnected 0

    # start the node.
    proc start {} {
      variable spawnCmd
      variable spawn_id
      variable stateDir

      # create state directory if specified
      if {$stateDir ne "" && ![file exists $stateDir]} {
        file mkdir $stateDir
      }

      # ensure vm console output is visible
      ::log_user 1
      ::spawn {*}$spawnCmd
    }

    proc failTimeout {pat} {
      variable nodeName
      testFail "timeout while waiting for $nodeName to produce $pat"
    }

    # expect output from the node.
    proc expect {args} {
      variable spawn_id
      # fail on timeout unless overridden by the caller.
      expect_after timeout [list failTimeout $args]
      ::expect {*}$args
      # clear expect_after to avoid affecting subsequent expect calls
      expect_after
    }

    # tell the node to quit.
    proc sendQuit {} {
      variable spawn_id
      close -i $spawn_id
    }

    # wait for the spawned process to exit.
    proc wait {} {
      variable spawn_id
      ::wait -i $spawn_id
    }

    # ================================================================
    # socket connection helper
    # ================================================================

    # connect to a unix socket using socat, waiting for it to appear.
    # returns the spawn_id for the connection.
    proc connectSocket {socketPath {connectTimeout {}}} {
      # use global constant if not specified
      if {$connectTimeout eq ""} {
        set connectTimeout $::CONNECT_TIMEOUT
      }

      # wait for socket file to appear (qemu creates it)
      set deadline [expr {[clock seconds] + $connectTimeout}]
      while {![file exists $socketPath] && [clock seconds] < $deadline} {
        after 100
      }
      if {![file exists $socketPath]} {
        testFail "timed out waiting for socket: $socketPath"
      }

      # spawn socat to connect to the unix socket
      # disable expect's output logging (we only want vm console output)
      ::log_user 0
      ::spawn socat - "UNIX-CONNECT:$socketPath"
      return $spawn_id
    }

    # ================================================================
    # shell socket communication
    # ================================================================

    # connect to the shell backdoor socket using socat
    # note: unlike NixOS (which stays connected), we create a new socat connection.
    # the backdoor's "Spawning backdoor root shell..." message may already have been
    # sent before we connect, so we don't wait for it - we just try to use the shell.
    proc shellConnect {} {
      variable stateDir
      variable shellSpawnId
      variable shellConnected
      variable nodeName
      variable backdoorEnabled

      if {$shellConnected} return

      # validate that backdoor is enabled for this node
      if {!$backdoorEnabled} {
        testFail "$nodeName: cannot use shell commands - backdoor is not enabled. Add 'testing.backdoor.enable = true;' to the node configuration."
      }

      set shellSpawnId [connectSocket "$stateDir/shell.sock"]

      # consume any initial output that might be in the buffer
      # (like "spawning backdoor root shell...") before sending commands.
      # use a short timeout since this is just cleanup.
      # we drain in a loop to handle race conditions where data arrives
      # just as the timeout fires.
      set savedTimeout $::timeout
      set ::timeout $::DRAIN_TIMEOUT
      set drainAttempts 0
      set maxDrainAttempts 3
      while {$drainAttempts < $maxDrainAttempts} {
        set gotData 0
        ::expect -i $shellSpawnId \
          -re ".+" {
            # got some data, reset attempts and try to get more
            set gotData 1
            set drainAttempts 0
            exp_continue
          } \
          timeout {
            # no data this round
          } \
          eof {
            testFail "$nodeName: shell connection closed unexpectedly"
          }
        if {!$gotData} {
          incr drainAttempts
          # small delay before next attempt to catch trailing data
          after 50
        }
      }
      set ::timeout $savedTimeout

      set shellConnected 1
      ::log "$nodeName: shell connected"
    }

    # execute a command via the shell socket
    # returns: list of {status output}
    # simple approach: send command with delimiter, parse output
    proc shellExecute {cmd {cmdTimeout {}}} {
      variable shellSpawnId
      variable nodeName

      # use global constant if not specified
      if {$cmdTimeout eq ""} {
        set cmdTimeout $::DEFAULT_CMD_TIMEOUT
      }

      # use a unique marker with prefix to identify the end of output.
      # the prefix "FINIX_" is unlikely to appear in normal command output.
      set markerPrefix "FINIX_"
      set marker "${markerPrefix}END_MARKER"

      # build the full command string we'll send
      # wrap in subshell so "exit 1" doesn't kill the main shell
      set fullCmd "($cmd); echo $marker \$?"

      ::send -i $shellSpawnId -- "$fullCmd\n"

      # the pty echoes our command back, so we skip lines that look like the echo.
      # we detect the echo by checking if the line contains our unique marker prefix
      # and appears before we've seen any real output.
      set savedTimeout $::timeout
      set ::timeout $cmdTimeout
      set output ""
      set status 0
      set sawEcho 0

      ::expect -i $shellSpawnId \
        -re "(\[^\r\n\]*)\\r?\\n" {
          set line $expect_out(1,string)
          # skip the echoed command - it will contain the marker in an echo statement
          # the actual marker output is just the marker followed by status
          if {!$sawEcho && [string match "*echo $marker*" $line]} {
            set sawEcho 1
            exp_continue
          }
          # check for the marker with status (the actual output line)
          # use (.*) prefix to handle commands that output without trailing newline,
          # which causes their output to concatenate with the marker line
          if {[regexp "^(.*)$marker (\[0-9\]+)$" $line -> prefix exitCode]} {
            # capture any output that was concatenated before the marker
            if {$prefix ne ""} {
              if {$output ne ""} {
                append output "\n"
              }
              append output $prefix
            }
            set status $exitCode
            # done - don't continue
          } else {
            # accumulate output lines
            if {$output ne ""} {
              append output "\n"
            }
            append output $line
            exp_continue
          }
        } \
        timeout {
          set ::timeout $savedTimeout
          testFail "$nodeName: timeout waiting for command output (got: $output)"
        } \
        eof {
          set ::timeout $savedTimeout
          error "$nodeName: shell connection closed"
        }

      set ::timeout $savedTimeout
      return [list $status $output]
    }

    # ================================================================
    # command execution api
    # ================================================================

    # execute command(s), fail if any returns non-zero
    proc succeed {args} {
      variable nodeName
      shellConnect

      set output ""
      foreach cmd $args {
        ::log "$nodeName: succeed: $cmd"
        lassign [shellExecute $cmd] status out
        if {$status != 0} {
          testFail "$nodeName: command failed (exit $status): $cmd\nOutput: $out"
        }
        append output $out
      }
      return $output
    }

    # execute command(s), expect non-zero exit (fail test if any returns zero)
    proc fail {args} {
      variable nodeName
      shellConnect

      set output ""
      foreach cmd $args {
        ::log "$nodeName: fail: $cmd"
        lassign [shellExecute $cmd] status out
        if {$status == 0} {
          testFail "$nodeName: command unexpectedly succeeded: $cmd\nOutput: $out"
        }
        append output $out
      }
      return $output
    }

    # execute a single command, return {status output}
    proc execute {cmd {timeout 900}} {
      variable nodeName
      shellConnect

      ::log "$nodeName: execute: $cmd"
      return [shellExecute $cmd $timeout]
    }

    # ================================================================
    # polling/wait helpers
    # ================================================================

    # wait for command to succeed, retrying every second
    proc waitUntilSucceeds {cmd {timeout 900}} {
      variable nodeName
      shellConnect

      ::log "$nodeName: waitUntilSucceeds: $cmd"
      set deadline [expr {[clock seconds] + $timeout}]
      while {[clock seconds] < $deadline} {
        lassign [shellExecute $cmd $::POLL_TIMEOUT] status output
        if {$status == 0} {
          return $output
        }
        after 1000
      }
      testFail "$nodeName: timed out waiting for success: $cmd"
    }

    # wait for command to fail, retrying every second
    proc waitUntilFails {cmd {timeout 900}} {
      variable nodeName
      shellConnect

      ::log "$nodeName: waitUntilFails: $cmd"
      set deadline [expr {[clock seconds] + $timeout}]
      while {[clock seconds] < $deadline} {
        lassign [shellExecute $cmd $::POLL_TIMEOUT] status output
        if {$status != 0} {
          return $output
        }
        after 1000
      }
      testFail "$nodeName: timed out waiting for failure: $cmd"
    }

    # wait for a file to exist
    proc waitForFile {path {timeout 900}} {
      variable nodeName
      ::log "$nodeName: waitForFile: $path"
      waitUntilSucceeds "test -e $path" $timeout
    }

    # wait for a tcp port to be open
    proc waitForOpenPort {port {addr localhost} {timeout 900}} {
      variable nodeName
      ::log "$nodeName: waitForOpenPort: $port on $addr"
      waitUntilSucceeds "nc -z $addr $port" $timeout
    }

    # wait for a tcp port to be closed
    proc waitForClosedPort {port {addr localhost} {timeout 900}} {
      variable nodeName
      ::log "$nodeName: waitForClosedPort: $port on $addr"
      waitUntilFails "nc -z $addr $port" $timeout
    }

    # wait for a finit condition to be set
    # condition should be in finit condition format, e.g.:
    #   - service/foo/running
    #   - task/foo/success
    #   - net/eth0/up
    proc waitForCondition {condition {timeout 900}} {
      variable nodeName
      ::log "$nodeName: waitForCondition: $condition"
      waitUntilSucceeds "initctl cond get $condition" $timeout
    }

    # wait for vm to shutdown (process to exit)
    proc waitForShutdown {{timeout 900}} {
      variable spawn_id
      variable nodeName

      ::log "$nodeName: waitForShutdown"
      set ::timeout $timeout
      ::expect -i $spawn_id \
        eof {
          ::log "$nodeName: VM has shut down"
          disconnect
        } \
        timeout {
          testFail "$nodeName: timed out waiting for shutdown"
        }
    }

    # wait until console output matches a regex pattern
    proc waitUntilTtyMatches {pattern {timeout 900}} {
      variable spawn_id
      variable nodeName

      ::log "$nodeName: waitUntilTtyMatches: $pattern"
      set ::timeout $timeout
      ::expect -i $spawn_id \
        -re $pattern {
          ::log "$nodeName: matched pattern"
          return $expect_out(0,string)
        } \
        timeout {
          testFail "$nodeName: timed out waiting for tty to match: $pattern"
        } \
        eof {
          testFail "$nodeName: VM exited while waiting for tty to match: $pattern"
        }
    }

    # ================================================================
    # shutdown/power control
    # ================================================================

    # cleanly shutdown the vm and wait for it to exit
    proc shutdown {{timeout 60}} {
      variable nodeName
      ::log "$nodeName: initiating shutdown"
      # send poweroff command, catching errors since socket may close
      catch {shellExecute "poweroff" 10}
      waitForShutdown $timeout
    }

    # simulate a sudden power failure (kill qemu immediately)
    proc crash {} {
      variable spawn_id
      variable nodeName
      ::log "$nodeName: simulating crash (killing QEMU)"
      disconnect
      catch {close -i $spawn_id}
      catch {exec kill -9 [exp_pid -i $spawn_id]}
    }

    # reboot the vm (graceful shutdown + start)
    # works with both finit (entering runlevel) and synit (awaiting signals)
    proc reboot {{timeout 60}} {
      variable nodeName
      variable spawn_id
      ::log "$nodeName: rebooting"
      # send reboot command, catching errors since socket may close
      catch {shellExecute "reboot" $::QUICK_TIMEOUT}
      # wait briefly for reboot to initiate
      after 2000
      # disconnect existing sockets (they'll be invalid after reboot)
      disconnect
      # wait for boot messages indicating vm has restarted
      # match either finit or synit boot completion messages
      set savedTimeout $::timeout
      set ::timeout $timeout
      ::expect -i $spawn_id \
        -re {entering runlevel [0-9]+} {
          ::log "$nodeName: reboot complete (finit)"
        } \
        "synit_pid1: Awaiting signals..." {
          ::log "$nodeName: reboot complete (synit)"
        } \
        timeout {
          set ::timeout $savedTimeout
          testFail "$nodeName: timed out waiting for reboot to complete"
        } \
        eof {
          set ::timeout $savedTimeout
          testFail "$nodeName: VM exited during reboot"
        }
      set ::timeout $savedTimeout
    }

    # ================================================================
    # interactive debugging
    # ================================================================

    # drop into an interactive shell session for debugging
    # uses socat with READLINE for a nice interactive experience (like NixOS)
    # press ctrl+d or ctrl+c to exit
    # note: after exiting, the shell connection is closed and cannot be reused
    proc shellInteract {} {
      variable stateDir
      variable nodeName
      variable shellConnected
      variable shellSpawnId
      variable backdoorEnabled

      # validate that backdoor is enabled for this node
      if {!$backdoorEnabled} {
        testFail "$nodeName: cannot use shellInteract - backdoor is not enabled. Add 'testing.backdoor.enable = true;' to the node configuration."
      }

      # close any existing shell connection first
      # (qemu chardev socket only accepts one client at a time)
      if {$shellConnected && $shellSpawnId ne ""} {
        catch {close -i $shellSpawnId}
        set shellConnected 0
        set shellSpawnId ""
      }

      ::log "$nodeName: entering interactive shell (ctrl+d to exit)"

      # use socat with READLINE for readline support and a prompt
      # this matches the NixOS approach exactly
      set socketPath "$stateDir/shell.sock"

      # run socat interactively - this blocks until user exits
      catch {
        exec socat "READLINE,prompt=\$ " "UNIX-CONNECT:$socketPath" \
          >@stdout <@stdin 2>@stderr
      }

      ::log "$nodeName: exited interactive shell"
    }

    # drop into an interactive console session for debugging
    # this connects directly to the vm's serial console
    # press ctrl+] to exit back to the test
    proc consoleInteract {} {
      variable spawn_id
      variable nodeName

      ::log "$nodeName: entering console interaction (Ctrl+] to exit)"
      interact -i $spawn_id
      ::log "$nodeName: exited console interaction"
    }

    # ================================================================
    # network control
    # ================================================================

    # block all network traffic (using iptables)
    proc block {} {
      variable nodeName
      shellConnect

      ::log "$nodeName: blocking network traffic"
      shellExecute "iptables -I INPUT -j DROP 2>/dev/null || true"
      shellExecute "iptables -I OUTPUT -j DROP 2>/dev/null || true"
      shellExecute "iptables -I FORWARD -j DROP 2>/dev/null || true"
    }

    # unblock network traffic (remove iptables drop rules)
    proc unblock {} {
      variable nodeName
      shellConnect

      ::log "$nodeName: unblocking network traffic"
      shellExecute "iptables -D INPUT -j DROP 2>/dev/null || true"
      shellExecute "iptables -D OUTPUT -j DROP 2>/dev/null || true"
      shellExecute "iptables -D FORWARD -j DROP 2>/dev/null || true"
    }

    # ================================================================
    # file transfer
    # ================================================================

    # read a file from the vm and return its contents.
    # returns empty string for empty files.
    # fails the test if file doesn't exist or can't be read.
    proc getFile {path} {
      variable nodeName
      shellConnect

      ::log "$nodeName: getFile: $path"
      # first check if file exists and is readable (gives clearer error message)
      lassign [shellExecute "test -r [shellQuote $path]" 5] existStatus _
      if {$existStatus != 0} {
        testFail "$nodeName: file not found or not readable: $path"
      }
      # now read the file
      lassign [shellExecute "base64 -w 0 < [shellQuote $path]" 60] status b64
      if {$status != 0} {
        testFail "$nodeName: failed to read file: $path"
      }
      set trimmed [string trim $b64]
      if {$trimmed eq ""} {
        # empty file - this is valid, not an error
        return ""
      }
      return [exec printf %s $trimmed | base64 -d]
    }

    # copy a file from the vm to the host
    # named to match NixOS convention: "from" indicates the source
    proc copyFromVm {vmPath hostPath} {
      variable nodeName
      ::log "$nodeName: copyFromVm: $vmPath -> $hostPath"
      set content [getFile $vmPath]
      set fh [open $hostPath w]
      fconfigure $fh -translation binary
      puts -nonewline $fh $content
      close $fh
    }

    # copy a file from the host to the vm
    # named to match NixOS convention: "from" indicates the source
    # for large files, chunks the data to avoid shell argument limits
    proc copyFromHost {hostPath vmPath} {
      variable nodeName
      shellConnect

      ::log "$nodeName: copyFromHost: $hostPath -> $vmPath"
      # read and base64-encode the host file
      set b64 [exec base64 -w 0 < $hostPath]

      # chunk size for base64 data (must be multiple of 4 for valid base64)
      # use 60kb to stay well under shell argument limits (~128kb on linux)
      set chunkSize 61440

      # for small files, use simple one-shot approach
      if {[string length $b64] <= $chunkSize} {
        lassign [shellExecute "printf '%s' [shellQuote $b64] | base64 -d > [shellQuote $vmPath]" 60] status out
        if {$status != 0} {
          testFail "$nodeName: failed to write file: $vmPath\nOutput: $out"
        }
        return
      }

      # for large files, write base64 chunks to temp file, then decode
      set numChunks [expr {([string length $b64] + $chunkSize - 1) / $chunkSize}]
      ::log "$nodeName: large file ($numChunks chunks), using chunked transfer"

      # clear temp file
      lassign [shellExecute "rm -f /tmp/.copyFromHost.b64" 5] status out

      for {set i 0} {$i < [string length $b64]} {incr i $chunkSize} {
        set chunk [string range $b64 $i [expr {$i + $chunkSize - 1}]]
        lassign [shellExecute "printf '%s' [shellQuote $chunk] >> /tmp/.copyFromHost.b64" 60] status out
        if {$status != 0} {
          testFail "$nodeName: failed to write chunk: $vmPath\nOutput: $out"
        }
      }

      # decode the complete base64 to the target file and cleanup
      lassign [shellExecute "base64 -d < /tmp/.copyFromHost.b64 > [shellQuote $vmPath] && rm -f /tmp/.copyFromHost.b64" 60] status out
      if {$status != 0} {
        testFail "$nodeName: failed to decode file: $vmPath\nOutput: $out"
      }
    }

    # ================================================================
    # cleanup
    # ================================================================

    # close socket connections
    proc disconnect {} {
      variable shellSpawnId
      variable shellConnected

      if {$shellConnected && $shellSpawnId ne ""} {
        catch {close -i $shellSpawnId}
        set shellConnected 0
      }
    }
  }

  # eval node-specific script.
  namespace eval $ns $body

  # create the command syntax.
  namespace eval $ns {
    namespace export *
    namespace ensemble create
  }
  namespace eval testNodes [list namespace export $name]
}

# if this is a nix build then log to $out and copy that to stderr.
if {[info exists env(out)]} {
   log_file $env(out)
   set fid [open $env(out) r]
   chan configure $fid -blocking 0
   chan event $fid readable [list apply {{fid} {
     if {[eof $fid]} {
       chan event $fid readable {}
     } else {
       puts -nonewline stderr [read $fid]
     }
   }} $fid]
}
