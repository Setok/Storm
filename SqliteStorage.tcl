package require sqlite3
package require storm 0.1

package provide storm::sqliteStorage 0.1


@ Class SqliteStorage -superclass Storage {
    Implements storage based on an SQLite DB.
}

Class SqliteStorage -superclass Storage

SqliteStorage set dbPath [file join ~ .storm sqlite]
file mkdir [SqliteStorage set dbPath]

@ SqliteStorage set dbName "default.db" {
    description {
	This is the name of the database that will be stored under
	[SqliteStorage set dbPath]. Change it to whatever should be appropriate
	for your project.
    }
}

SqliteStorage set dbName "default.db"

SqliteStorage set nextDbID 0


@ SqliteStorage proc initStorage {} {
    description {
	Call this after you have set dbName and other configuration.
    }
}

SqliteStorage proc initStorage {} {
    my instvar nextDbID dbPath dbName sqlite_db

    set sqlite_db "stormsqlitedb-$nextDbID"
    sqlite3 $sqlite_db [file join $dbPath $dbName]
    # Create the metadata and field tables, if needed.
    # Metadata will be for metadata about the object (class, filters, procs)
    # Fields will be for the instance variables of the object
    catch {$sqlite_db eval {
	CREATE TABLE metadata(object text, key text, value text)
    }}
    catch {$sqlite_db eval {
	CREATE TABLE fields(object text, key text, value text)
    }}
}
    

SqliteStorage proc recreateObFromID {id} {
    my instvar sqlite_db

    set ob [Object create $id]
    $sqlite_db eval {SELECT * FROM fields WHERE object=$ob} values {
	$ob set $values(key) $values(value)
    } 

    $sqlite_db eval {SELECT * FROM metadata WHERE object=$ob} values {
	set metadata($values(key)) $values(value)
    }
    
    if {! [info exists metadata(class)]} {
	$ob destroy
	return ""
    }
    $ob class $metadata(class)
    return $ob
}


SqliteStorage proc searchClassObjects {class expr} {
    my instvar sqlite_db

    set op [lindex $expr 0]

    set query ""
    switch -- $op {
	eq {
	    set query "SELECT metadata.object FROM fields,metadata WHERE fields.object=metadata.object AND fields.key='[lindex $expr 1]' AND fields.value='[lindex $expr 2]' AND metadata.key='class' AND metadata.value = '$class'"
	}
    }	    

    puts "query: $query"
    set r [$sqlite_db eval $query]
    puts "r: $r"
    return $r
}


SqliteStorage instproc init {args} {
    [self class] instvar sqlite_db

    set myclass [my info class]
    set me [self]
    if {! [$sqlite_db exists {
	SELECT 1 FROM metadata WHERE object=$me
    }]} {
	$sqlite_db eval {
	    INSERT INTO metadata VALUES($me, "class", $myclass)
	}
    }
    
    return [next]
}


SqliteStorage instproc annihilate {} {
    [self class] instvar sqlite_db

    set me [self]
    $sqlite_db eval {
	DELETE FROM fields WHERE object=$me;
	DELETE FROM metadata WHERE object=$me;
    }

    return [next]
}


SqliteStorage instproc writeChanges {} {
    [self class] instvar sqlite_db

    foreach {attr op} [my getAttrChanges] {
	set value [my set $attr]
	set me [self]
	if {[$sqlite_db exists {
	    SELECT 1 FROM fields WHERE object=$me AND key=$attr
	}]} {
	    $sqlite_db eval {
		UPDATE fields
		SET value=$value
		WHERE object=$me AND key=$attr
	    }
	} else {
	    $sqlite_db eval {
		INSERT INTO fields VALUES($me, $attr, $value)
	    }
	}
    }

    return [next]
}


Storage registerStorageClass SqliteStorage
