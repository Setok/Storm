package require sqlite3
package require storm 0.1

package provide storm::sqliteStorage 0.2


Class SqlQuery -parameter {
    operation
    {distinct false}
    what
    from
    ordering
    
}


SqlQuery instproc init {} {
    my set conditions [list]
}


SqlQuery instproc addCondition {condition} {
    my lappend conditions $condition
}


SqlQuery instproc getQuery {} {
    my instvar operation distinct what from conditions ordering
    
    set query "$operation"
    if {$distinct} {
	append query " DISTINCT"
    }
    append query " $what FROM $from"
    set conditionPrefix " WHERE "
    foreach condition $conditions {
	append query $conditionPrefix $condition
	set conditionPrefix " AND "
    }
    if {[info exist ordering]} {
	append query " ORDER BY " $ordering
    }

    return $query
}


@ Class SqliteStorage -superclass Storage {
    Implements storage based on an SQLite DB.
}

Class SqliteStorage -superclass Storage

SqliteStorage set dbLocation [file join ~ .storm sqlite]


@ SqliteStorage set appNamespace {
    description {
        Set this with a list of elements that define the application
        namespace. This could be a combination of company and division like,
        for instance, "solu web".
    }
}

SqliteStorage set appNamespace [list]

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
    my instvar nextDbID dbLocation appNamespace dbName sqlite_db
    
    set dbPath [eval file join [list $dbLocation] $appNamespace]
    file mkdir $dbPath

    set sqlite_db "stormsqlitedb-$nextDbID"
    sqlite3 $sqlite_db [file join $dbPath $dbName]
    $sqlite_db timeout 2000

    # Create the metadata and field tables, if needed.
    # Metadata will be for metadata about the object (class, filters, procs)
    # Fields will be for the instance variables of the object
    catch {$sqlite_db eval {
	CREATE TABLE metadata(object text, key text, value text);
	CREATE INDEX IDX_METADATA_OBJECT ON metadata (object);
    }}
    catch {$sqlite_db eval {
	CREATE TABLE fields(object text, key text, value text);
	CREATE INDEX IDX_FIELDS_OBJECT ON fields (object);
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


SqliteStorage proc parseExpression {queryOb expr} {
    set op [lindex $expr 0]

    switch -- $op {
	last {
	    $queryOb ordering "metadata.rowid DESC LIMIT [lindex $expr 1]"
	    if {[llength $expr] == 2} {
		my parseExpression $queryOb [lindex $expr 2]
	    }
	}
	eq {
	    $queryOb addCondition \
		"fields.key='[lindex $expr 1]'\
                 AND fields.value='[lindex $expr 2]'"
	}
    }	    
}


SqliteStorage proc allObjects {class} {
    my instvar sqlite_db

    set query [SqlQuery new -volatile]
    $query operation "SELECT"
    $query what "fields.object"
    $query what "metadata.object"
    $query from "fields,metadata"
    $query addCondition "fields.object=metadata.object AND metadata.key='class' AND metadata.value = '$class'"
    $query distinct true

    set r [$sqlite_db eval [$query getQuery]]
    return $r
}

    
SqliteStorage proc searchClassObjects {class expr} {
    my instvar sqlite_db

    set op [lindex $expr 0]

    #set query ""
    set ordering ""
    set query [SqlQuery new -volatile]
    $query operation "SELECT"
    $query what "metadata.object"
    $query from "fields,metadata"
    $query addCondition "fields.object=metadata.object AND metadata.key='class' AND metadata.value = '$class'"
    $query distinct true

    my parseExpression $query $expr
    
    if {0} {
    switch -- $op {
	last {
	    set ordering "ORDER BY rowid DESC LIMIT [lindex $expr 1]"
	}
	eq {
	    set expr "AND fields.key='[lindex $expr 1]' AND fields.value='[lindex $expr 2]'"

	}
    }	    

    set query "SELECT metadata.object FROM fields,metadata WHERE fields.object=metadata.object $expr AND metadata.key='class' AND metadata.value = '$class' $ordering"
    }

    set r [$sqlite_db eval [$query getQuery]]
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
