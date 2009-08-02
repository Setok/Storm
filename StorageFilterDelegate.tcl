@ Class StorageFilterDelegate -parameter {
    {nofilter false} {If this is set, no filtering will be done.}
} {
    description {
	This class should handle any methods which need to be filtered by the
	storage system. Any method on the stored object that needs to 
	trigger a 'dirty' state, or any other extra functionality, should
	be managed by a method here that is named delegated_<methodname>.
	This delegate should also be used to keep note of any changes
	that were made.

	This is to keep the filter code clean.
    }
}

Class StorageFilterDelegate -parameter {
    {nofilter false}
}


StorageFilterDelegate instproc init {storedOb} {
    my set storedOb $storedOb
    return [next]
}


StorageFilterDelegate instproc hasChanges {} {
    my instvar attrChanges
    if {[my exists attrChanges]} {
	return true
    } else {
	return false
    }
}


StorageFilterDelegate instproc addChange {type args} {
    my instvar attrChanges relationChanges

    switch -- $type {
	attr {
	    set attrChanges([lindex $args 0]) set
	}
	rmAttr {
	    set attrChanges([lindex $args 0]) unset
	}
	class {
	}
	default {
	    error "Unrecognised change type: $type"
	}
    }

    return
}


StorageFilterDelegate instproc emptyChangeList {} {
    my unset attrChanges
    return
}


StorageFilterDelegate instproc varUpdate {name1 name2 op} {
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


StorageFilterDelegate instproc delegated_init {args} {
    my addChange class [[my set storedOb] info class]
    return
}


StorageFilterDelegate instproc delegated_set {args} {
    if {[llength $args] == 2} {
	my addChange attr [lindex $args 0]
    }
    return
}


StorageFilterDelegate instproc delegated_instvar {args} {
    [my set storedOb] trace add variable [lindex $args 0] [list read unset] \
	[list [self] varUpdate]
    return
}