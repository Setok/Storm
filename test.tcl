set MyDir [file dirname [info script]]
lappend auto_path $MyDir

package require storm 0.1
package require storm::sqliteStorage 0.1

#source [file join $MyDir storm.tcl]
#source [file join $MyDir FileStorage.tcl]
#source [file join $MyDir SqliteStorage.tcl]


#FileStorage initStorage
SqliteStorage initStorage

#PersistentClass Person -superclass FileStorage
PersistentClass Person -superclass SqliteStorage


Person instproc init {name} {
    my set name $name
    return [next]
}


Person instproc annihilate {} {
    my instvar friend

    if {[info exists friend]} {
	$friend annihilate
    }

    return [next]
}


Person instproc print {} {
    puts "Hello, [my set name]"
}


set ob [Person new "Peter"]
set ob2 [Person new "Jane"]
$ob set friend $ob2

#loadAll

$ob2 destroy

$ob print
puts "Friend: [$ob set friend]"
[$ob set friend] print

$ob annihilate
puts "Should fail:"
$ob print
#set instances [TestClass info instances]
#puts [TestClass info instances]
#[lindex $instances 0] print