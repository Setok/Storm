source [file join $MyDir StorageFilterDelegate.tcl]

Class Storage


Storage instproc init {args} {
    my set filterProcessing false
    return [next]
}


@ Storage abstract instproc writeOb {} {
    description {
	Storage implementors should implement this method and store the
	object based on its content in whatever storage they use.
    }
}


Storage instproc writeChanges {} {
    next
    my emptyChangeList
}


@ Storage instproc annihilate {} {
    description {
	Total destruction of object. Removes from storage.
    }
}

Storage instproc annihilate {} {
    next
    return [my destroy]
}


@ Storage instproc dirtyChecker {args} {
    description {
	Filter method attached to every object with storage.
	This checks to see if the method being called, the circumstances
	in which it is called or the repercussions of it being called will
	lead to the object being 'dirty' -- ie. requiring it to be saved
	to the store. Basically any method that changes the object should
	result in a dirty condition.
    }
}

Storage instproc dirtyChecker {args} {
    ::set oldFPValue [::info exists ::xodb::filterProcessing([self])]
    #set oldFPValue [my set filterProcessing]
    ::set ::xodb::filterProcessing([self]) true
    #my set filterProcessing true
    if {! [::info exists ::xodb::filterDelegate([self])]} {
	::set ::xodb::filterDelegate([self]) [StorageFilterDelegate new [self]]
    }
    ::set delegate $::xodb::filterDelegate([self])

    set r [next]

    set delegatedProcName "delegated_[self calledproc]"
    if {[$delegate info methods $delegatedProcName] ne ""} {
	eval [list $delegate $delegatedProcName] $args
    }

    if {0} {
    switch -- [self calledproc] {
	"init" {
	    #my writeOb
	    $delegate addChange class [my info class]
	}
	"set" {
	    if {[llength $args] == 2} {
		$delegate addChange attr [lindex $args 0]
	    }
	}
	"instvar" {
	    my trace [lindex $args 0] [list read unset] [list [self] varUpdate]
	}
    }
    }

    if {! $oldFPValue} {
	# Only actually start writing things out when filter processing has
	# ended. This way the object can change variables multiple times 
	# before the value is written out.
	if {[$delegate hasChanges]} {
	    my writeChanges
	}
	::unset ::xodb::filterProcessing([self])
    }

    return $r
}


Storage instproc hasChanges {} {
    if {[my exists attrChanges]} {
	return true
    } else {
	return false
    }
}


Storage instproc addChange {type args} {
    my instvar attrChanges relationChanges

    switch -- $type {
	attr {
	    set attrChanges([lindex $args 0]) set
	}
	rmAttr {
	    set attrChanges([lindex $args 0]) unset
	}
    }
}


Storage instproc emptyChangeList {} {
    my unset attrChanges
    return
}


Storage instproc varUpdate {name1 name2 op} {
    if {$op eq "read"} {
	if {$name2 ne ""} {
	    my addChange attr $name1\($name2\)
	} else {
	    my addChange attr $name1
	}
    } else {
	my addChange rmAttr $name1
    }
    return
}