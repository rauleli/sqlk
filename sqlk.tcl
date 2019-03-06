#
# TODO:
#  * SERIALIZE XML
#  * EVITAR asignaciones cuando el nivel anterior no existe, ej {namecmd kset key1.key2 val}, inválido si key1 no existe
#  * Búsquedas con kget, ej {namecmd kget key1.key*.key3}, el resultado sería por pares {{key1 value1} {key2 value2}} (wilcards *? o regexp) entre {})
#

# sqlk.tcl -- sqlite keyed lists
#
#
# sqlk::kinit filename ?-procname procname?
# sqlk::klist
# sqlk::kcloseall
#
# procname varlist
# procname varadd name ?-procname procname? ?-enckey key?
# procname vardel name
# procname kset var key val ?key val? ?key val?
# procname kdel var key
# procname kget var key
# procname kexist var key
# procname attrset var key attr val ?attr val? ?attr val?
# procname attrget var key ?attr?
# procname attrdel var key attr
# procname keys var ?key?
# procname tree var ?key?
# procname serialize name ?-key key? ?-indent 0|1? ?-format TCL|XML|TEXT?
# procname parse name tcldata
# procname closefile
# procname varcmd name ?procname?
# procname backup filename
# procname restore filename
#
#
#  namecmd kget key
#  namecmd kset key val ?key val? ?key val?
#  namecmd kdel key
#  namecmd kexist key
#  namecmd attrset key attr val ?attr val? ?attr val?
#  namecmd attrget key ?attr?
#  namecmd attrdel key attr
#  namecmd keys ?key?
#  namecmd tree ?key?
#  namecmd serialize ?-key key? ?-indent 0|1? ?-format TCL|XML|TEXT?
#  namecmd parse tcldata
#
#
# set e [base64::encode [vfs::zip -mode compress -level 9 [fileutil::cat sqlk.tcl]]]
#

#package require Tcl 8.5
package require sqlite3

package provide sqlk 0.7

##########
##########
##
##
##
namespace eval sqlk {
  variable seq
  variable enc 1

  if {[catch {package require rc4}]} {
    set enc 0
  }


  ##########
  #
  #
  #
  proc kinit {filepath args} {
    variable seq
    variable enc

    if {fmod([llength $args],2)} {
      return -code error "Invalid number of options, should be 2 elements list, got \"[llength $args]\""
    }
    set procname ""
    set enckey ""
    if {[llength $args] > "0"} {
      array set op $args
      if {[info exists op(-procname)]} {
        set procname $op(-procname)
        unset op(-procname)
      }
      if {[info exists op(-enckey)]} {
        set enckey $op(-enckey)
        unset op(-enckey)
      }
      if {[llength [array names op]] > 0} {
        return -code error "Invalid option \"[lindex [array names op] 0]\", should be -procname or -enckey"
      }
    }
    
    if {!$enc && [string length $enckey] > 0} {
      return -code error "Package rc4 needed for encryption"
    } elseif {$filepath == ":memory:" && [string length $enckey] > 0} {
      return -code error "Memory keyed lists can not be encripted"
    }

    if {![info exists seq]} {set seq 0}
    set dbid [format %08s [incr seq]]

    if {[catch {sqlite3 _db$dbid $filepath} e]} {
      puts ok
      return -code error $e
    }

    _db$dbid busy 10000
    _db$dbid timeout 10000
    _db$dbid cache size 100

    initkdb _db$dbid


    ##########
    ##########
    ##
    ##
    ##
    namespace eval $dbid {
      variable db _db[namespace tail [namespace current]]
      variable filepath  ""
      variable kprocname ""
      variable kenckey   ""
      variable encrypt   0
      
      proc varlist   {}                       {::sqlk::_varlist}
      proc varadd    {name {procname ""}}     {::sqlk::_varadd}
      proc vardel    {name}                   {::sqlk::_vardel}
      proc keys      {name {key ""}}          {::sqlk::_keys}
      proc tree      {name {key ""}}          {::sqlk::_tree}
      proc kget      {name key}               {::sqlk::_kget}
      proc kset      {name args}              {::sqlk::_kset}
      proc kdel      {name key}               {::sqlk::_kdel}
      proc kmove     {name key {afterkey ""}} {::sqlk::_kmove}
      proc kexist    {name key}               {::sqlk::_kexist}
      proc attrset   {name key args}          {::sqlk::_attrset}
      proc attrget   {name key {attr ""}}     {::sqlk::_attrget}
      proc attrdel   {name key attr}          {::sqlk::_attrdel}
      proc serialize {name args}              {::sqlk::_serialize}
      proc parse     {name args}              {::sqlk::_parse}
      proc closefile {}                       {::sqlk::_closefile}
      proc backup    {filename}               {::sqlk::_backup}
      proc restore   {filename}               {::sqlk::_restore}

      proc varcmd    {name {procname ""}}     {::sqlk::_varcmd}

      # Internal usage
      proc doenc     {data}                   {::sqlk::_doenc}
      proc dodec     {data}                   {::sqlk::_dodec}
      proc doencbin  {data}                   {::sqlk::_doencbin}
      proc nameid    {name}                   {::sqlk::_nameid}
      proc keyid     {name_id key}            {::sqlk::_keyid}
      proc validname {name}                   {::sqlk::validname $name}
      proc validkey  {name}                   {::sqlk::validkey  $name}
      proc keysort   {name_id parent}         {::sqlk::_keysort}
      namespace export varlist varadd vardel keys kget kset kdel kexist kmove attrset attrget serialize closefile varcmd parse tree backup restore
      namespace ensemble create
    }
    set ${dbid}::filepath $filepath
    set ${dbid}::kenckey $enckey

    if {$enckey != "" && $enc} {
      set ${dbid}::encrypt 1
    }

    if {$procname != ""} {
      set ${dbid}::kprocname $procname
      uplevel #0 "rename [namespace current]::$dbid $procname"
    } else {
      return [namespace current]::$dbid
    }
  }

  ##########
  #
  #
  #
  proc klist {} {
    set y [list]
    foreach x [namespace children [namespace current]] {
      set a [list]
      foreach z [namespace children $x] {
        lappend a [list [namespace tail $z] $z [set ${z}::kprocname]]
      }
      lappend y [list $x [set ${x}::filepath] [set ${x}::kprocname] $a]
    }
    return $y
  }

  ##########
  #
  #
  #
  proc kclose {objname} {
    foreach x [namespace children [namespace current]] {
      if {$x == $objname} {
        $objname closefile
        return
      }
    }
    if {[namespace exists ::sqlk::$objname]} {
      sqkl::${objname} closefile
    } else {
      return -code error "keyed list object \"$objname\" does not exist or is not open"
    }
  }

  ##########
  #
  #
  #
  proc kcloseall {} {
    foreach x [namespace children] {
      ${x}::closefile
    }
  }


  ##########
  #
  #
  #
  proc _closefile {} {
    uplevel 1 {
      variable db
      $db close
      namespace delete [namespace current]
    }
  }

  ##########
  #
  #
  #
  proc _backup {} {
    uplevel 1 {
      variable db
      $db backup $filename
    }
  }

  ##########
  #
  #
  #
  proc _restore {} {
    uplevel 1 {
      variable db
      $db restore $filename
    }
  }

  ##########
  #
  #
  #
  proc _varcmd {} {
    uplevel 1 {
      if {[namespace exists [namespace current]::$name]} {
        if {$procname != ""} {
          if {[set [namespace current]::${name}::kprocname] == ""} {
            set [namespace current]::${name}::kprocname $procname
            uplevel #0 "rename [namespace current]::$name $procname"
            return ""
          } else {
            return [set [namespace current]::${name}::kprocname]
          }
        } else {
          return [namespace current]::$name
        }
      }

      ##########
      ##########
      ##
      ##
      ##
      namespace eval $name {
        variable name [namespace tail [namespace current]]
        variable kprocname ""
        proc keys      {{key ""}}          {eval "[namespace parent]::keys      [myname] $key"}
        proc tree      {{key ""}}          {eval "[namespace parent]::tree      [myname] $key"}
        proc kget      {key}               {eval "[namespace parent]::kget      [myname] $key"}
        proc kset      {args}              {eval "[namespace parent]::kset      [myname] $args"}
        proc kdel      {key}               {eval "[namespace parent]::kdel      [myname] $key"}
        proc kexist    {key}               {eval "[namespace parent]::kexist    [myname] $key"}
        proc kmove     {key {afterkey ""}} {eval "[namespace parent]::kmove     [myname] $key $afterkey"}
        proc attrset   {key args}          {eval "[namespace parent]::attrset   [myname] $key $args"}
        proc attrget   {key {attr ""}}     {eval "[namespace parent]::attrget   [myname] $key $attr"}
        proc attrdel   {key attr}          {eval "[namespace parent]::attrdel   [myname] $key $attr"}
        proc serialize {args}              {eval "[namespace parent]::serialize [myname] $args"}
        proc parse     {args}              {eval "[namespace parent]::parse     [myname] $args"}
        proc myname    {}                  {variable name ; return $name}

        namespace export keys kget kset kdel kexist kmove attrset attrget attrdel serialize parse tree
        namespace ensemble create
      }
      if {$procname != ""} {
        set [namespace current]::${name}::kprocname $procname
        uplevel #0 "rename [namespace current]::$name $procname"
      } else {
        return [namespace current]::$name
      }
    }
  }


  ##########
  #
  #
  #
  proc _varlist {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {$encrypt} {
        set l [list]
        $db eval {select name from key_name where encrypt = 1} {
          if {[string range [set e [dodec $name]] end-4 end] == "*****"} {
            lappend l [string map {* "" + ""} $e]
          }
        }
        return $l
      } else {
        $db eval {select name from key_name where encrypt = 0}
      }
    }
  }

  ##########
  #
  #
  #
  proc _varadd {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[validname $name]} {
        if {[string length $name] > 128} {
          return -code error "Invalid size, max 128, got [string length $name]"
        } else {
          return -code error "Invalid characters"
        }
      } elseif {[nameid $name] != ""} {
        return -code error "var name \"$name\" already exists"
      }

      if {$encrypt} {
        set ename [doenc "$name[string repeat "+" [expr 45 - [string length $name]]]*****"]
      } else {
        set ename $name
      }
      $db eval {begin immediate transaction}
      $db eval {insert into key_name (name,encrypt,ctime,utime) values ($ename,$encrypt,strftime('%s'),strftime('%s'))}
      $db eval {commit}

      varcmd $name
      if {$procname != ""} {
        varcmd $name $procname
      } else {
        varcmd $name
      }
    }
  }

  ##########
  #
  #
  #
  proc _vardel {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[set name_id [nameid $name]] == ""} {
        return -code error "key name \"$name\" does not exists"
      }

      if {[namespace exists [namespace current]::$name]} {
        namespace delete [namespace current]::$name
      }
      $db eval {delete from key_name where id = $name_id}
    }
  }

  ##########
  #
  #
  #
  proc _keys {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }

      if {$key == ""} {
        return [$db eval {select name from key_sort where parent = 0 and name_id = $name_id}]
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }

      return [$db eval {select name from key_sort where parent = $p and name_id = $name_id}]
    }
  }


  ##########
  #
  #
  #
  proc _kget {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }

      if {$encrypt} {
        set y [list]
        return [doencbin [$db onecolumn {select val from key_data where id = $p}]]
      } else {
        return [$db onecolumn {select val from key_data where id = $p}]
      }
    }
  }

  ##########
  #
  #
  #
  proc _kset {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      } elseif {fmod([llength $args],2)} {
        return -code error "Keyed list must be a valid, 2 elements list, got \"[llength $args]\""
      }

      $db eval "begin immediate transaction"
      foreach {k v} $args {
        if {[validkey $k]} {
          $db eval "rollback transaction"
          return -code error "Invalid characters or invalid size in \"$k\""
        }
        set p 0
        foreach s [split $k .] {
          if {$encrypt} {
            set ev [doencbin $v]
          } else {
            set ev $v
          }
          set x [$db onecolumn {select id from key_data where name_id = $name_id and parent = $p and name = $s}]
          if {$x == ""} {
            $db eval {insert into key_data (name_id,parent,name,val,attr) values ($name_id,$p,$s,'','')}
            set p [$db last_insert_rowid]
          } else {
            set p $x
          }
        }
        $db eval {update key_data set val = $ev where id = $p}
      }
      $db eval "commit"

    }
  }

  ##########
  #
  #
  #
  proc _kdel {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }

      $db eval "begin immediate transaction"
      
      set parent [$db onecolumn "select parent from key_data where id = $p"]

      set next_after_id [$db onecolumn "select id from key_data where after_id = $p and parent = $parent"]
      if {$next_after_id != ""} {
        set curr_after_id [$db onecolumn "select after_id from key_data where id = $p"]
        if {$curr_after_id == 0} {
          $db eval "update key_data set after_id = $curr_after_id, key_order = 0 where id = $next_after_id"
        } else {
          $db eval "update key_data set after_id = $curr_after_id where id = $next_after_id"
        }
      } else {
        set last_id [$db onecolumn "select after_id from key_data where id = $p"]
        if {$parent == 0} {
          $db eval {update key_name set last_id = $last_id where id = $name_id}
        } else {
          $db eval {update key_data set last_id = $last_id where id = $parent}
        }
      }

      set a ""
      set r $p
      set i 0
      while {$r != ""} {
        set r [$db eval "select id from key_data where parent in ([join $r ,])"]
        set p [lsort -unique -integer "$p $r"]
      }

      $db eval "delete from key_data where id in ([join $p ,])"

      $db eval "commit"
    }
  }


  ##########
  #
  #
  #
  proc _kexist {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return 0
      }
      return 1
    }
  }

  ##########
  #
  #
  #
  proc _kmove {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }

      set path [split $key .]
      if {[llength $path] == 1} {
        set path ""
      } else {
        set path [join [lrange $path 0 end-1] .]
      }
      set g [$db onecolumn "select parent from key_data where id = $p"]


      if {$afterkey == ""} {
        set n 0
      } else {
        if {[llength [split $afterkey .]] == 1} {
          set afterkey [join "$path $afterkey" .]
        }
        if {[set n [keyid $name_id $afterkey]] == ""} {
          return -code error "key name \"$afterkey\" does not exists"
        }
        if {[$db onecolumn "select count(*) from key_data where id = $n and parent = $g and name_id = $name_id"] == 0} {
          return -code error "key \"$afterkey\" and $key does not belong to the same parent"
        }
      }


      if {[$db onecolumn "select count(*) from key_data where parent = $g"] == 1} {
        return ""
      }

      if {$n == [$db onecolumn "select after_id from key_data where id = $p"]} {
        # Same positions, dont change
        return ""
      }

      set setorder 0
      set last_id ""

      $db eval "begin immediate transaction"

      # First move, to set my follower to follow who i used to follow
      set next_after_id [$db onecolumn "select id,key_order from key_data where after_id = $p and name_id = $name_id and parent = $g"]
      if {$next_after_id != ""} {
        set curr_after_id [$db onecolumn "select after_id from key_data where id = $p"]
        if {$curr_after_id == 0} {
          $db eval "update key_data set after_id = $curr_after_id, key_order = 0 where id = $next_after_id"
        } else {
          $db eval "update key_data set after_id = $curr_after_id where id = $next_after_id"
        }
      } else {
        set last_id [$db onecolumn "select after_id from key_data where id = $p"]
      }

      # Second move, to set the follower of the one i m going to follow to follow me
      #   AND... set myself to follow the new one
      if {$n == 0} {
        set curr_order 0
        lassign [$db eval "select id,key_order from key_data where after_id = 0 and parent = $g and name_id = $name_id limit 1"] next_id next_order
        if {$next_order == 0} {
          lassign [$db eval "select id,key_order from key_data where after_id = $next_id and parent = $g"] next_next_id next_order
        } else {
          set next_next_id [$db onecolumn "select id,key_order from key_data where after_id = $next_id and parent = $g"]
        }
        if {$next_next_id == $p} {
          $db eval "update key_data set after_id = $p, key_order = id where id = $next_id"
          set last_id $next_id
        } else {
          set next_order [::sqlk::inmiddle $next_order $curr_order]
          if {$next_order == 0} {
            set setorder 1
          }
          $db eval "update key_data set after_id = $p, key_order = $next_order where id = $next_id"
        }
      } else {
        lassign [$db eval "select id,key_order from key_data where after_id = $n and name_id = $name_id and parent = $g"] prev_after_id curr_order
        set prev_order [$db onecolumn "select key_order from key_data where id = $n"]
        if {$prev_after_id != ""} {
          set curr_order [::sqlk::inmiddle $prev_order $curr_order]
          if {$curr_order == 0} {
            set setorder 1
          }
          $db eval {update key_data set after_id = $p where id = $prev_after_id}
        } else {
          set last_id $p
          set curr_order [$db onecolumn "select max(key_order)+0.0001 from key_data where parent = $g"]
        }
      }
      $db eval "update key_data set after_id = $n, key_order = $curr_order where id = $p"
      
      if {$last_id != ""} {
        if {$g == 0} {
          $db eval {update key_name set last_id = $last_id where id = $name_id}
        } else {
          $db eval {update key_data set last_id = $last_id where id = $g}
        }
      }

      $db eval "commit"

      if {$setorder} {
        keysort $name_id $g
      }
    }
  }

  ##########
  #
  #
  #
  proc _keysort {} {
    uplevel 1 {
      variable db

      $db eval "begin immediate transaction"

      # online sort
      set n 0
      set id 0
      set last_id 0
      set step [$db onecolumn "select max(id)/count(*) from key_data where parent = $parent and name_id = $name_id"]
      while {[set id [$db onecolumn "select id from key_data where parent = $parent and after_id = $id and name_id = $name_id"]] != ""} {
        incr n $step
        $db eval {update key_data set key_order = $n where id = $id}
        set last_id $id
      }

      if {$parent == 0} {
        $db eval {update key_name set last_id = $last_id where id = $name_id}
      } else {
        $db eval {update key_data set last_id = $last_id where id = $parent}
      }

      $db eval "commit"
    }
  }

  ##########
  #
  #
  #
  proc _attrset {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      } elseif {fmod([llength $args],2)} {
        return -code error "Argument list must be a valid, 2 elements list, got \"[llength $args]\""
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }

      if {$encrypt} {
        array set a [doencbin [$db onecolumn {select attr from key_data where id = $p}]]
      } else {
        array set a [$db onecolumn {select attr from key_data where id = $p}]
      }

      $db eval {begin immediate transaction}

      foreach {k v} $args {
        if {[validname $k]} {
          $db eval {commit}
          if {[string length $k] > 128} {
            return -code error "Invalid size, max 128, got [string length $k]"
          } else {
            return -code error "Invalid characters"
          }
        }
        set a($k) $v
      }
      if {$encrypt} {
        set x [doencbin [array get a]]
      } else {
        set x [array get a]
      }
      $db eval {update key_data set attr = $x where id = $p}

      $db eval {commit}
    }
  }
  
  ##########
  #
  #
  #
  proc _attrget {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }

      if {$encrypt} {
        array set a [doencbin [$db onecolumn {select attr from key_data where id = $p}]]
      } else {
        array set a [$db onecolumn {select attr from key_data where id = $p}]
      }

      if {$attr == ""} {
        return [array names a]
      } elseif {[info exist a($attr)]} {
        return $a($attr)
      } else {
        return -code error "no attribute name \"$attr\" found in $key"
      }
    }
  }

  ##########
  #
  #
  #
  proc _attrdel {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }

      if {$encrypt} {
        array set a [dodec [$db onecolumn {select attr from key_data where id = $p}]]
      } else {
        array set a [$db onecolumn {select attr from key_data where id = $p}]
      }

      if {[info exist a($attr)]} {
        unset a($attr)
        set x [array get a]
        if {$encrypt} {
          set x [doenc $x]
        }

        $db eval {begin immediate transaction}

        $db eval {update key_data set attr = $x where id = $p}

        $db eval {commit}

      } else {
        return -code error "no attribute name \"$attr\" found in $key"
      }
    }
  }

  ##########
  #
  #
  #
  proc _tree {} {
    uplevel 1 {
      variable db
      if {$name ni [varlist]} {
        return -code error "var name does not exist \"$name\""
      }
      ::sqlk::__tree [namespace current] $name $key
    }
  }

  ##########
  #
  #
  #
  proc __tree {ns name key} {
    set y ""
    foreach x [${ns}::keys $name $key] {
      set nkey [join "$key $x" .]
      lappend y $nkey
      if {[set z [::sqlk::__tree $ns $name $nkey]] != ""} {
        lappend y $z
      }
    }
    return [join $y]
  }

  ########## and name_id = $name_id
  #
  #
  #
  proc _serialize {} {
    uplevel 1 {
      variable db
      # nsk serialize name ?-format XML|TCL|TEXT? ?-indent 0|1? ?-key key?
      set oformat TCL
      set oindent 0
      set okey    ""

      # Check for options
      if {[llength $args] > 1} {
        if {[catch {array set op $args} e] || fmod([llength $args],2) != "0"} {
          return -code error "wrong # args: should be \"serialize ?-format XML|TCL|TEXT? ?-indent 0|1? ?-key key?\""
        }
        while {[llength [array names op]] > 0} {
          if {[info exist op(-format)]} {
            if {$op(-format) ni "XML TCL TEXT"} {
              return -code error "invalid format \"$op(-format)\": must be XML, TCL or TEXT"
            }
            set oformat $op(-format)
            unset op(-format)
          } elseif  {[info exist op(-indent)]} {
            if {$op(-indent) ni "0 1"} {
              return -code error "invalid indent value \"$op(-indent)\": must be 0 or 1"
            }
            set oindent $op(-indent)
            unset op(-indent)
          } elseif  {[info exist op(-key)]} {
            if {[catch {keys $name $op(-key)} e]} {
              return -code error $e
            }
            set okey $op(-key)
            unset op(-key)
          } else {
            return -code error "invalid arg \"[lindex [array names op] 0]\": must be -format or -indent"
          }
        }
      }

      # Check if name or procname exists
      if {$name ni [varlist]} {
        return -code error "var name does not exist \"$name\""
      }
      ::sqlk::__serialize [namespace current] $name $oformat $oindent $okey
    }
  }

  ##########
  #
  #
  #
  proc __serialize {ns name oformat oindent okey {level 1}} {
    if {$oformat == "TCL"} {
      set y [list]
      set i ""
      set s ""
      foreach x [${ns}::keys $name $okey] {
        set nkey [join "$okey $x" .]
        set d [__serialize $ns $name $oformat $oindent $nkey [expr $level + 1]]
        if {$oindent == "1"} {
          set s [string repeat " " [expr $level * 2]]
          set dd ""
          foreach n $d {
            append dd $s[list $n]\n
          }
          if {[llength $d] > 0} {
            set d \n$dd[string range $s 0 end-2]
          } else {
            set d ""
          }
        }
        array unset a
        foreach n [${ns}::attrget $name $nkey] {
          set a($n) [${ns}::attrget $name $nkey $n]
        }
        lappend y [list $x [${ns}::kget $name $nkey] [array get a] $d]
      }
      if {$oindent == "1"} {
        if {$level == "1"} {
          set dd ""
          foreach n $y {
            lappend dd [list $n]
          }
          set y [join $dd \n]
        }
        return $y
      } else {
        return $y
      }
    } elseif {$oformat == "TEXT"} {
      set y ""
      set i ""
      set s ""
      foreach x [${ns}::keys $name $okey] {
        set nkey [join "$okey $x" .]
        set d [__serialize $ns $name $oformat $oindent $nkey [expr $level + 1]]
        set a ""
        foreach n [${ns}::attrget $name $nkey] {
          lappend a "$n=\"[${ns}::attrget $name $nkey $n]\""
        }
        append y "$nkey\n [join $a]\n [${ns}::kget $name $nkey]\n$d"
      }
      return $y
    } elseif {$oformat == "XML"} {
    }
  }

  ##########
  #
  #
  #
  proc _parse {} {
    uplevel 1 {
      variable db

      # nsk parse ?-into key? ?-format XML|TCL? string
      set oformat TCL
      set oname ""
      set okey ""

      set data [lindex $args end]

      # Check for options
      if {[llength $args] > 1} {
        if {[catch {array set op [lrange $args 0 end-1]} e] || [llength $args] ni "3 5"} {
          return -code error "wrong # args: should be \"parse ?-format XML|TCL? ?-into key? string\""
        }
        while {[llength [array names op]] > 0} {
          if {[info exist op(-format)]} {
            if {$op(-format) ni "XML TCL"} {
              return -code error "invalid format \"$op(-format)\": must be XML or TCL"
            }
            set oformat $op(-format)
            unset op(-format)
          } elseif  {[info exist op(-into)]} {
            set okey $op(-into)
            unset op(-into)
          } else {
            return -code error "invalid arg \"[lindex [array names op] 0]\": must be -format or -into"
          }
        }
      }

      # Check if name or procname exists
      if {$name ni [varlist]} {
        return -code error "var name \"$name\" does not exists"
      }

      ::sqlk::__parse [namespace current] $name $data TCL $okey
      return ""
    }
  }

  ##########
  #
  #
  #
  proc __parse {ns name str oformat {key ""}} {
    if {$oformat == "TCL"} {
      foreach x $str {
        lassign $x k v a c
        set lkey [join "$key $k" .]
        ${ns}::kset $name $lkey $v
        foreach {ak av} $a {
          ${ns}::attrset $name $lkey $ak $av
        }
        if {[llength $c] > 0} {
          __parse $ns $name $c $oformat $lkey
        }
      }
    }
  }


  ##########
  #
  #
  #
  proc _doenc {} {
    uplevel 1 {
      variable kenckey
      if {$kenckey == ""} {
        return $data
      } else {
        return [::rc4::rc4 -hex -key $kenckey $data] 
      }
    }
  }


  ##########
  #
  #
  #
  proc _dodec {} {
    uplevel 1 {
      variable kenckey
      if {$kenckey == ""} {
        return $data
      } else {
        return [::rc4::rc4 -key $kenckey [binary format H* $data]]
      }
    }
  }

  ##########
  #
  #
  #
  proc _doencbin {} {
    uplevel 1 {
      variable kenckey
      if {$kenckey == ""} {
        return $data
      } else {
        return [::rc4::rc4 -key $kenckey $data] 
      }
    }
  }


  ##########
  #
  #
  #
  proc _nameid {} {
    uplevel 1 {
      variable db
      variable encrypt

      if {$encrypt} {
        variable kenckey
        set ename [doenc "$name[string repeat "+" [expr 45 - [string length $name]]]*****"]
        $db onecolumn {select id from key_name where name = $ename}
      } else {
        $db onecolumn {select id from key_name where name = $name and encrypt = 0}
      }
    }
  }


  ##########
  #
  #
  #
  proc _keyid {} {
    uplevel 1 {
      variable db

#      set n ""
#      set p 0
#      foreach s [split $key .] {
#        set x [$db onecolumn {select id from key_data where name_id = $name_id and parent = $p and name = $s}]
#        lappend n $s
#        if {$x == ""} {
#          return ""
#        }
#        set p $x
#      }
#      return $p

      set p [$db onecolumn "select id from key_data where name_id = '$name_id' and path = '$key'"]
      return $p

    }
  }



  ##########
  #
  #
  #
  proc validname {name} {
    return [expr ![regexp -- {^[[:alnum:]][[:alnum:]_-]{1,128}$} $name]]
  }


  ##########
  #
  #
  #
  proc validkey {name} {
    return [expr ![regexp -- {^[[:alnum:]][[:alnum:]_.-]{1,39}$} $name]]
  }

  ##########
  #
  #
  #
  proc inmiddle {a b} {
    # Integer
    set c [expr int(($a + $b) / 2)]
    if {$a > $b && $c > $b || $b > $a && $c > $a} {
      return $c
    }

    # Real
    set c [expr ($a + $b) / 2.0]
    if {$a > $b && $c > $b || $b > $a && $c > $a} {
      return $c
    }

    return 0
  }

  ##########
  #
  #
  #
  proc initkdb {db} {
    set tables [$db eval {
        SELECT
            name
        FROM
            sqlite_master
        WHERE
            type = 'table' AND
            (name = 'key_data' OR name = 'key_name')
        ORDER BY name
    }]
    if {$tables eq {key_data key_name}} {
      set cols {}
      $db eval "PRAGMA table_info(key_name)" {lappend cols $name}
      if {$cols ne {id name encrypt last_id ctime utime}} {
        error "Column names for key_name table do not match -> $cols"
      }

      set cols {}
      $db eval "PRAGMA table_info(key_data)" {lappend cols $name}
      if {$cols ne {id name_id parent after_id last_id key_order path ctime utime name val attr}} {
        error "Column names for key_data table do not match -> $cols"
      }
      $db eval {
      	PRAGMA auto_vacuum = 1;
        PRAGMA threads = 8;
        PRAGMA cache_size = -6000;
      }
    } else {
      $db eval {
	PRAGMA auto_vacuum = 1;
  PRAGMA threads = 8;
  PRAGMA cache_size = -6000;
	CREATE TABLE "key_name" (
	    "id"      INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	    "name"    TEXT NOT NULL,
	    "encrypt" INTEGER NOT NULL DEFAULT(0),
	    "last_id" INTEGER NOT NULL DEFAULT(0),
	    "ctime"   INTEGER,
	    "utime"   INTEGER,
	    UNIQUE(name)
	);
  CREATE INDEX key_name_key0 on key_name (name);

	CREATE TABLE "key_data" (
	    "id"         INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
	    "name_id"    INTEGER NOT NULL,
	    "parent"     INTEGER NOT NULL,
	    "after_id"   INTEGER,
	    "last_id"    INTEGER NOT NULL DEFAULT(0),
	    "key_order"  REAL,
	    "path"       TEXT,
	    "ctime"      INTEGER,
	    "utime"      INTEGER,
	    "name"       TEXT    NOT NULL,
	    "val"        BLOB,
	    "attr"       BLOB,
	    UNIQUE(name,parent,name_id)
	);

  CREATE INDEX key_data_key0 on key_data (path);
  CREATE INDEX key_data_key1 on key_data (parent,after_id,key_order);
  CREATE INDEX key_data_key2 on key_data (parent,after_id);

	CREATE TRIGGER key_name_delete AFTER DELETE ON key_name
	  FOR EACH ROW
	    BEGIN
	      delete from key_data where name_id = OLD.id;
	    END;

  CREATE TRIGGER key_data_insert0 AFTER INSERT on key_data
    FOR EACH ROW
      WHEN NEW.parent = 0
        BEGIN
	        update key_data
	          set 
	            after_id =
	              (select a.last_id from key_name as a where id = NEW.name_id),
              key_order =
                NEW.id,
              path =
                ifnull((select p.name || '.' from key_data as p where p.id = NEW.parent),'') || NEW.name, ctime = strftime('%s'),utime = strftime('%s')
	          where
	            id = NEW.id;

            update key_name
              set
	        utime = strftime('%s'),
                last_id = NEW.id
              where
                id = NEW.name_id;
          END;

        CREATE TRIGGER key_data_insert1 AFTER INSERT on key_data
         FOR EACH ROW
          WHEN NEW.parent <> 0
          BEGIN
	    update key_data
	      set 
	        after_id =
	         (select a.last_id from key_data as a where a.id = NEW.parent),
                key_order =
                 NEW.id,
                path =
                 ifnull((select p.path || '.' from key_data as p where p.id = NEW.parent),'') || NEW.name,
                ctime = strftime('%s'),
                utime = strftime('%s')
	      where
	        id = NEW.id;

            update key_data
              set
                last_id = NEW.id
              where
                id = NEW.parent;

	    update key_name
	      set 
	        utime = strftime('%s')
	      where
	        id = NEW.name_id;
          END;


	CREATE TRIGGER key_data_update AFTER UPDATE OF name, val, attr ON key_data
	 FOR EACH ROW
	  BEGIN
	    update key_data
	      set 
                utime = strftime('%s')
	      where
	        id = OLD.id;
	    update key_name
	      set 
	        utime = strftime('%s')
	      where
	        id = OLD.name_id;
	  END;

        CREATE VIEW "key_sort" AS
          select * from key_data order by key_order;
      }
    }
  }
}
