@ Class FileStorage -superclass Storage {
    Implements file-based storage for XODB
}

Class FileStorage -superclass Storage

FileStorage set ObjectPath [file join ~ .xodb objects]
file mkdir [FileStorage set ObjectPath]


FileStorage proc recreateObFromID {id} {
    set fileID [string map {: ง} $cmdName]
    set path [file join [my set ObjectPath] $fileID]]

    set file [open $path r]
    set data [read $file]
    close $file
    
    set fileName [file tail $path]
    set ob [Object create $id]

    foreach attr $data {
	switch -- [lindex $attr 0] {
	    "instvar" {
		$ob set [lindex $attr 1] [lindex $attr 2]
	    }
	    "class" {
		$ob class [lindex $attr 1]
	    }
	}
    }

    return $ob
}


FileStorage proc loadAll {} {
    set files [glob [file join [FileStorage set ObjectPath] *]]
    foreach file $files {
	createObFromPath $file
    }

    return
}


FileStorage instproc init {args} {
    set fileID [string map {: ง} [self]]
    my set fileName [file join [FileStorage set ObjectPath] $fileID]
    return [next]
}


FileStorage instproc annihilate {} {
    next
    file delete [my set fileName]
    return
}


FileStorage instproc writeChanges {} {
    #global ObjectPath
    #my requreNamespace

    #set fileID [string map {: ยง} [self]]

    set data [list]
    foreach var [my info vars] {
	lappend data [list instvar $var [my set $var]]
    }
    lappend data [list class [my info class]]

    #set file [open [file join $ObjectPath $fileID] w]
    set file [open [my set fileName] w]
    puts $file $data
    close $file

    return
}

Storage registerStorageClass FileStorage






