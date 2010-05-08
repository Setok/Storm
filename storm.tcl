package require Tcl 8.4
package require XOTcl 1.2
catch {namespace import xotcl::*}

package provide storm 0.1


#rename unknown unknown_prev

namespace eval storm {
    set myDir [file dirname [info script]]

    # Number to ensure no conflict if lots of obs created on same second.
    # Still not perfect: if prog opens, creates obs, closes and loads again,
    # all within a second, there is a conflict.
    set obNum 0
}



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


source [file join $storm::myDir Storage.tcl]


Class PersistentClass -superclass Class 


@ PersistentClass instproc init {} {
    description {
	Set up the dirty checker for each PersistentClass class.
    }
}

PersistentClass instproc init {} {
    my instfilter dirtyChecker
}

PersistentClass instproc new {args} {
    #my instvar Childnum
    set name ::storm::[clock seconds]-$::storm::obNum    
    incr ::storm::obNum
    return [eval [list my create $name] $args]
}


PersistentClass instproc searchObjects {expr} {
    set objects [list]

    set expr [uplevel subst [list $expr]]

    # Go through each superclass of this class to see which storage
    # classes it has.
    foreach superClass [my info superclass] {
	if {[Storage info subclass $superClass]} {
	    set objects [concat $objects \
			     [$superClass searchClassObjects [self] $expr]]
	}
    }

    return $objects
}
    
