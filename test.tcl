set MyDir [file dirname [info script]]
lappend auto_path $MyDir

package require storm 0.2
package require storm::sqliteStorage 0.2

#source [file join $MyDir storm.tcl]
#source [file join $MyDir FileStorage.tcl]
#source [file join $MyDir SqliteStorage.tcl]


#FileStorage initStorage
SqliteStorage set dbName basic-test.db
SqliteStorage set appNamespace [list storm-test]
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
puts "Created person (should be Peter):"
$ob print
$ob destroy
set ob2 [Person new "Jane"]
$ob set friend $ob2

set ppl [Person searchObjects {eq name "Peter"}]
puts "Query response: $ppl"

set ppl [Person allObjects]
puts "All people: $ppl"
#loadAll

$ob2 destroy

$ob print
puts "Friend: [$ob set friend]"
[$ob set friend] print

puts "Test with parameters:"
PersistentClass Car -superclass SqliteStorage -parameter marque

set newCar [Car new]
$newCar marque "Caterham"
$newCar destroy
puts "Car marque: [$newCar marque]"

$ob annihilate
puts "Should fail:"
$ob print
#set instances [TestClass info instances]
#puts [TestClass info instances]
#[lindex $instances 0] print
