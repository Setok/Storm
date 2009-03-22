package require Tcl 8.4
package require XOTcl 1.2
namespace import xotcl::*

set MyDir [file dirname [info script]]
source [file join $MyDir Storage.tcl]


#rename unknown unknown_prev

namespace eval xodb {}


proc override {cmdName argList body} {
    global NextOverrideID

    if {! [info exists NextOverrideID($cmdName)]} {
	set NextOverrideID($cmdName) 0
    }

    set nextProc $cmdName-chain-$NextOverrideID($cmdName)
    rename $cmdName $nextProc

    set r [proc $cmdName $argList "set nextproc $nextProc\n$body"]
    incr NextOverrideID($cmdName)
    return $r
}


Class PersistentClass -superclass Class 


@ PersistentClass instproc init {} {
    description {
	Set up the dirty checker for each PersistentClass class.
    }
}

PersistentClass instproc init {} {
    # Number to ensure no conflict if lots of obs created on same second.
    # Still not perfect: if prog opens, creates obs, closes and loads again,
    # all within a second, there is a conflict.
    my set childNum 0
    my instfilter dirtyChecker
}

PersistentClass instproc new {args} {
    my instvar childNum
    set name ::xodb::[clock seconds]-$childNum    
    incr childNum
    return [eval [list my create $name] $args]
}
    

