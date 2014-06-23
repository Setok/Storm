set MyDir [file dirname [info script]]
lappend auto_path $MyDir

package require storm 0.1
package require storm::sqliteStorage 0.1

#source [file join $MyDir storm.tcl]
#source [file join $MyDir FileStorage.tcl]
#source [file join $MyDir SqliteStorage.tcl]


SqliteStorage set appNamespace [list storm-test]
SqliteStorage set dbName test.db

#FileStorage initStorage
SqliteStorage initStorage
