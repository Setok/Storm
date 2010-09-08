package require Tcl 8.4
package require XOTcl 1.2
catch {namespace import xotcl::*}

package provide storm 0.2.1


@ @File { 
    description { 

	This is a transparent object storage system. Classes created
	from the PersistentClass meta-class will be automatically stored
	into the selected storage system. Additionally any references to
	objects not yet loaded will get loaded from the storage. You can
	thus freely destroy objects to retain memory or exit the app
	completely.  Objects will be automatically returned if needed,
	without the programmer knowing the details.

	To completely destroy an object, from both memory and storage,
	use [ob annihilate] instead of destroy.

	There is also a query language for querying the objects of a certain
	class, based on various criteria.

	You should also load the storage model you want to use. 
	Currently available: FileStorage and SqliteStorage.
    }
}

#rename unknown unknown_prev

namespace eval storm {
    set myDir [file dirname [info script]]

    # Number to ensure no conflict if lots of obs created on same second.
    # Still not perfect: if prog opens, creates obs, closes and loads again,
    # all within a second, there is a conflict.
    set obNum 0
}



## Override an existing command with a new body. The body can call
## $nextproc to call the original command.

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


PersistentClass instproc allObjects {} {
    set objects [list]

    # Go through each superclass of this class to see which storage
    # classes it has.
    foreach superClass [my info superclass] {
	# This is for compatible between older and newer versions of
	# XOTcl. The interface for [subclass] was changed.
	set subClassResult [Storage info subclass $superClass]
	if {$subClassResult eq ""} {
	    set subClassResult false
	} elseif {![string is boolean $subClassResult]} {
	    set subClassResult true
	}

	if {$subClassResult} {
	    set objects [concat $objects \
			     [$superClass allObjects [self]]]
	}
    }

    return $objects
}


@ PersistentClass instproc searchObjects {
    expr {
	  Search expression.

	  Expression format:
	  op arg1 arg2 ...

	  ops:

	  last <num> <expr> - Return last 'num' that match expression.
	  eq <field> <value> - Return obs where field == value.
      }
} {
    description {
	Return all the objects that match the given expression from
	whichever class 'searchObjects' was called.
    }
}

PersistentClass instproc searchObjects {expr} {
    set objects [list]

    set expr [uplevel subst [list $expr]]

    # Go through each superclass of this class to see which storage
    # classes it has.
    foreach superClass [my info superclass] {
	# This is for compatible between older and newer versions of
	# XOTcl. The interface for [subclass] was changed.
	set subClassResult [Storage info subclass $superClass]
	if {$subClassResult eq ""} {
	    set subClassResult false
	} elseif {![string is boolean $subClassResult]} {
	    set subClassResult true
	}

	if {$subClassResult} {
	    set objects [concat $objects \
			     [$superClass searchClassObjects [self] $expr]]
	}
    }

    return $objects
}
    

