package require Tcl 8.6
source [file join [file dirname [info script]] .. sqlk.tcl]

proc test {name script {expected ""}} {
    puts -nonewline "Testing $name... "
    try {
        set res [uplevel 1 $script]
        if {$expected ne "" && $res ne $expected} {
            puts "FAILED"
            puts "  Expected: $expected"
            puts "  Got:      $res"
        } else {
            puts "OK"
        }
    } on error {msg options} {
        puts "ERROR: $msg"
        puts "  Options: $options"
    }
}

# 1. Initialization
set db [sqlk::kinit :memory:]
$db varadd config

# 2. Strict Mode
test "Kset Strict (fail)" {
    set res ""
    try {
        $db kset config -strict 1 key1.key2.key3 val
    } on error {msg options} {
        set res $msg
    }
    set res
} "Parent node for \"key1.key2.key3\" does not exist (strict mode)"

test "Kset Normal (success)" {
    $db kset config key1.key2.key3 val
    $db kget config key1.key2.key3
} "val"

# 3. Wildcards
$db kset config item.a 1 item.b 2 other.c 3
test "Kget Wildcard" {
    lsort -stride 2 [$db kget config item.*]
} "item.a 1 item.b 2"

# 4. XML Serialization
test "XML Serialize" {
    set xml [$db serialize config -format XML -indent 0]
    string match "*<key1><key2><key3>val</key3></key2></key1>*" $xml
} 1

# 5. XML Parsing
test "XML Parse" {
    $db varadd newconfig
    set xml "<?xml version=\"1.0\"?><sqlk><a>1<b>2</b></a></sqlk>"
    $db parse newconfig -format XML $xml
    $db kget newconfig a.b
} "2"

# 6. Merge
test "Kmerge" {
    $db varadd target
    $db kmerge config item target imported
    $db kget target imported.a
} "1"

puts "Tests completed."
