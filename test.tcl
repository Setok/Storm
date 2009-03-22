set MyDir [file dirname [info script]]
source [file join $MyDir xodb.tcl]
source [file join $MyDir FileStorage.tcl]


PersistentClass Person -superclass FileStorage


Person instproc init {name} {
    my set name $name
    return [next]
}


Person instproc annihilate {} {
    my instvar friend

    if {[info exists friend]} {
	[my set friend] annihilate
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
#set instances [TestClass info instances]
#puts [TestClass info instances]
#[lindex $instances 0] print