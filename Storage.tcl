source [file join $storm::myDir StorageFilterDelegate.tcl]

Class Storage

@ Class Storage {
    description {
	This is the base class that all storage providers should extend
	to provide storage functionality.

	Classes that should be stored should be created from the 
	PersistentClass meta-class and extend an implementation of this
	class.
    }
}


# The list of classes which implement storage.
Storage set storageClasses [list]


Storage instproc init {args} {
#    my set filterProcessing false
    return [next]
}


@ Storage proc initStorage {} {
    description {
	This should be the first method called on a class implementing
	Storage. This allows it to set up things in preparation for actual
	storage, if necessary. Each Storage subclass should implement it's
	own version of this, if it needs to do initialisation.
    }
}

Storage proc initStorage {} {
    return
}


@ Storage proc registerStorageClass {class} {
    description {
	Each new Storage sub-class should call this to register itself
	as providing storage. It can then later be called to try and
	retreive an unknown object (which would have been previously 
	stored).
    }
}

Storage proc registerStorageClass {class} {
    my lappend storageClasses $class
    return
}


@ Storage proc getStorageClasses {} {
    description {
	Return list of all registered storage provider classes.
    }
}

Storage proc getStorageClasses {} {
    return [my set storageClasses]
}


@ Storage abstract proc recreateObFromID {id} {
    description {
	Every sub-class of Storage should implement this. This is the method
	to recreate an XOTcl object based on the name or id of the original
	object (the XOTcl name of the object). The Storage class should
	search its own storage for an object which matches the given id.
	It should then create it and set its fields and metadata.

	If an object with that id cannot be found from the class's storage,
	an empty string should be returned.
    }
}

Storage abstract proc recreateObFromID {id}

Storage abstract proc searchObjects {expr}

Storage instproc writeChanges {} {
    next
    set delegate $::storm::filterDelegate([self])
    $delegate emptyChangeList
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

	TODO: Check if this could be done with mixins. If yes, should be 
	way less messy and possibly quicker too.
    }
}

Storage instproc dirtyChecker {args} {
    if {[self calledproc] ne "destroy"} {
        # Normally we postpone writing changes until the completion of the
        # first method of this object being called on the stack. However,
        # if that method is [destroy] we do not want to wait that long as
        # the object will cease to exist after the full [next] chain, so
        # changes should be made before that happens.
        ::set oldFPValue [::info exists ::storm::filterProcessing([self])]
        ::set ::storm::filterProcessing([self]) true
    }
    if {! [::info exists ::storm::filterDelegate([self])]} {
	::set ::storm::filterDelegate([self]) \
	    [StorageFilterDelegate new -childof [self] [self]]
    }
    ::set delegate $::storm::filterDelegate([self])

    if {[$delegate nofilter]} {
	return [next]
    }

    if {[self calledproc] eq "annihilate"} {
	# Don't catch events during annihilation or the object might 
	# effectively be recreated!
	$delegate nofilter true
	return [next]
    }

    ::set targetclass [my info class]
    ::set r [next]

    #::puts "errorcode: $::errorCode"
    #::puts "errorinfo: $::errorInfo"
    #puts "rc: $rc"
    
    if {[self calledproc] eq "destroy"} {
        # We know destroy itself is not dirty (the methods it called might
        # have been), ie. nothing needs to be written (as [destroy] was
        # ignored for the normal 'write-when-method-stack-complete' logic). 
        # However if we don't
        # check for it here, all of the below will cease to work. If it
        # is destroy, do nothing further and return.

        return $r
    }

    if { ([$targetclass info instparametercmd [self calledproc]] eq \
	      [self calledproc]) &&
	 ([llength $args] > 0) } {	
	# If a parameter command was accessed for setting a variable, mark
	# as dirty.
	$delegate addChange attr [self calledproc]
    } else {
	# Otherwise check with the delegated implementation of the command
	# to see if it thinks the result is dirty.
	set delegatedProcName "delegated_[self calledproc]"
	if {[$delegate info methods $delegatedProcName] ne ""} {
	    eval [list $delegate $delegatedProcName] $args
	}
    }

    if {! $oldFPValue} {
	# Only actually start writing things out when filter processing has
	# ended. This way the object can change variables multiple times 
	# before the value is written out.
	if {[$delegate hasChanges]} {
	    my writeChanges
	}
	::unset ::storm::filterProcessing([self])
    }

    return $r
}


Storage instproc hasChanges {} {
    set delegate $::storm::filterDelegate([self])
    return [$delegate hasChanges]
}


Storage instproc getAttrChanges {} {
    set delegate $::storm::filterDelegate([self])
    return [$delegate getAttrChanges]
}


if {0} {
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
    catch {my unset attrChanges}
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
}

## Provides the facility to load an object from a file, if not already
## loaded.

override unknown {cmdName args} {
    if {[string match "::storm*" $cmdName]} {
	foreach class [Storage getStorageClasses] {
	    set ob [$class recreateObFromID $cmdName]
	    if {$ob ne ""} {
		return [eval [list $ob] $args]
	    }
	}
	# None of the Storage classes could recreate this object.
	return [eval $nextproc [list $cmdName] $args]
    } else {
	return [eval $nextproc [list $cmdName] $args]
    }
}

