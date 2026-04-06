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

package provide sqlk 0.8

##########
##########
##
##
##
namespace eval sqlk {
  variable seq
  variable enc 1

  try {
    package require aes
  } on error {} {
    set enc 0
  }


  ##########
  #
  #
  #
  proc kinit {filepath args} {
    variable seq
    variable enc

    if {[llength $args] % 2 != 0} {
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
      return -code error "Package aes needed for encryption"
    } elseif {$filepath == ":memory:" && [string length $enckey] > 0} {
      return -code error "Memory keyed lists can not be encrypted"
    }

    if {![info exists seq]} {set seq 0}
    set dbid [format %08s [incr seq]]

    try {
      sqlite3 _db$dbid $filepath
    } on error {e} {
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
      variable watches   [dict create]
      
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
      proc kcount    {name {key ""}}          {::sqlk::_kcount}
      proc kfind     {name pattern}           {::sqlk::_kfind}
      proc kgetall   {name {key ""}}          {::sqlk::_kgetall}
      proc krename   {name key newname}       {::sqlk::_krename}
      proc kmerge    {oldname src_key newname {target_key ""}} {::sqlk::_kmerge}
      proc kclone    {oldname newname}        {::sqlk::_kclone}
      proc kdiff     {name key1 key2}         {::sqlk::_kdiff}
      proc kbatch    {name list}              {::sqlk::_kbatch}
      proc kwatch    {name key callback}      {::sqlk::_kwatch}

      proc varcmd    {name {procname ""}}     {::sqlk::_varcmd}

      # Internal usage
      proc doenc     {data}                   {::sqlk::_doenc}
      proc dodec     {data}                   {::sqlk::_dodec}
      proc doencdata {data}                   {::sqlk::_doencdata}
      proc dodecdata {data}                   {::sqlk::_dodecdata}
      proc nameid    {name}                   {::sqlk::_nameid}
      proc keyid     {name_id key}            {::sqlk::_keyid}
      proc validname {name}                   {::sqlk::validname $name}
      proc validkey  {name}                   {::sqlk::validkey  $name}
      proc keysort   {name_id parent}         {::sqlk::_keysort}
      proc trigger_watches {name key op old new} {::sqlk::_trigger_watches}
      namespace export varlist varadd vardel keys kget kset kdel kexist kmove attrset attrget serialize closefile varcmd parse tree backup restore kcount kfind kgetall krename kmerge kclone kdiff kbatch kwatch
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
      sqlk::${objname} closefile
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
        proc keys      {{key ""}}          {tailcall [namespace parent]::keys      [myname] $key}
        proc tree      {{key ""}}          {tailcall [namespace parent]::tree      [myname] $key}
        proc kget      {key}               {tailcall [namespace parent]::kget      [myname] $key}
        proc kset      {args}              {tailcall [namespace parent]::kset      [myname] {*}$args}
        proc kdel      {key}               {tailcall [namespace parent]::kdel      [myname] $key}
        proc kexist    {key}               {tailcall [namespace parent]::kexist    [myname] $key}
        proc kmove     {key {afterkey ""}} {tailcall [namespace parent]::kmove     [myname] $key $afterkey}
        proc attrset   {key args}          {tailcall [namespace parent]::attrset   [myname] $key {*}$args}
        proc attrget   {key {attr ""}}     {tailcall [namespace parent]::attrget   [myname] $key $attr}
        proc attrdel   {key attr}          {tailcall [namespace parent]::attrdel   [myname] $key $attr}
        proc serialize {args}              {tailcall [namespace parent]::serialize [myname] {*}$args}
        proc parse     {args}              {tailcall [namespace parent]::parse     [myname] {*}$args}
        proc kcount    {{key ""}}          {tailcall [namespace parent]::kcount    [myname] $key}
        proc kfind     {pattern}           {tailcall [namespace parent]::kfind     [myname] $pattern}
        proc kgetall   {{key ""}}          {tailcall [namespace parent]::kgetall   [myname] $key}
        proc krename   {key newname}       {tailcall [namespace parent]::krename   [myname] $key $newname}
        proc kmerge    {oldname src_key newname {target_key ""}} {::sqlk::_kmerge}
        proc kdiff     {key1 key2}         {tailcall [namespace parent]::kdiff     [myname] $key1 $key2}
        proc kbatch    {list}              {tailcall [namespace parent]::kbatch    [myname] $list}
        proc kwatch    {key callback}      {tailcall [namespace parent]::kwatch    [myname] $key $callback}
        proc myname    {}                  {variable name ; return $name}

        namespace export keys kget kset kdel kexist kmove attrset attrget attrdel serialize parse tree kcount kfind kgetall krename kmerge kdiff kbatch kwatch
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
        set ename [doenc "$name[string repeat "+" [expr {45 - [string length $name]}]]*****"]
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

      if {[string match {*[*?]*} $key]} {
        # Wildcard search
        set sql_pattern [string map {* % ? _} $key]
        set res [list]
        $db eval {select path, val from key_data where name_id = $name_id and path like $sql_pattern} {
          lappend res $path [dodecdata $val]
        }
        return $res
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }

      if {$encrypt} {
        return [dodecdata [$db onecolumn {select val from key_data where id = $p}]]
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
      variable watches
      set istrict 0
      if {[lindex $args 0] eq "-strict"} {
        set istrict [lindex $args 1]
        set args [lrange $args 2 end]
      }
      $db eval {begin immediate transaction}
      try {
        set data $args
        ::sqlk::_kset_core
      } on error {e} {
        $db eval {rollback}
        return -code error $e
      }
      $db eval {commit}
    }
  }

  proc _kset_core {} {
    uplevel 1 {
      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }
      if {[llength $data] % 2 != 0} {
        return -code error "Keyed list must be a valid, 2 elements list, got \"[llength $data]\""
      }

      foreach {k v} $data {
        if {[validkey $k]} {
          return -code error "Invalid characters or invalid size in \"$k\""
        }
        
        set ev [expr {$encrypt ? [doencdata $v] : $v}]

        # Performance Shortcut: Try direct update by path first
        set x [$db eval {select id, val from key_data where name_id = $name_id and path = $k}]
        if {$x ne ""} {
          lassign $x p oldval
          $db eval {update key_data set val = $ev where id = $p}
          set key $k ; set _watch_op "set" ; set old [dodecdata $oldval] ; set new $v
          ::sqlk::_trigger_watches
          continue
        }

        set p 0
        set parts [split $k .]
        set depth 0
        set max_depth [llength $parts]
        foreach s $parts {
          incr depth
          set x [$db eval {select id, val from key_data where name_id = $name_id and parent = $p and name = $s}]
          if {$x == ""} {
            if {$istrict && $depth < $max_depth} {
               return -code error "Parent node for \"$k\" does not exist (strict mode)"
            }
            $db eval {insert into key_data (name_id,parent,name,val,attr) values ($name_id,$p,$s,'','')}
            set p [$db last_insert_rowid]
            set oldval ""
          } else {
            lassign $x p val
            set oldval [dodecdata $val]
          }
        }
        $db eval {update key_data set val = $ev where id = $p}
        set key $k ; set _watch_op "set" ; set old $oldval ; set new $v
        ::sqlk::_trigger_watches
      }
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
      variable watches

      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }

      $db eval {begin immediate transaction}
      
      set parent [$db onecolumn {select parent from key_data where id = $p}]

      set next_after_id [$db onecolumn {select id from key_data where after_id = $p and parent = $parent}]
      if {$next_after_id != ""} {
        set curr_after_id [$db onecolumn {select after_id from key_data where id = $p}]
        if {$curr_after_id == 0} {
          $db eval {update key_data set after_id = $curr_after_id, key_order = 0 where id = $next_after_id}
        } else {
          $db eval {update key_data set after_id = $curr_after_id where id = $next_after_id}
        }
      } else {
        set last_id [$db onecolumn {select after_id from key_data where id = $p}]
        if {$parent == 0} {
          $db eval {update key_name set last_id = $last_id where id = $name_id}
        } else {
          $db eval {update key_data set last_id = $last_id where id = $parent}
        }
      }

      set r $p
      while {$r != ""} {
        set r [$db eval "select id from key_data where parent in ([join $r ,])"]
        set p [lsort -unique -integer "$p $r"]
      }

      set oldval ""
      try {
        set oldval [_kget $name $key]
      } on error {} {}
      $db eval "delete from key_data where id in ([join $p ,])"

      $db eval {commit}
      set _watch_op "del" ; set old $oldval ; set new ""
      ::sqlk::_trigger_watches
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
      set g [$db onecolumn {select parent from key_data where id = $p}]


      if {$afterkey == ""} {
        set n 0
      } else {
        if {[llength [split $afterkey .]] == 1} {
          set afterkey [join "$path $afterkey" .]
        }
        if {[set n [keyid $name_id $afterkey]] == ""} {
          return -code error "key name \"$afterkey\" does not exists"
        }
        if {[$db onecolumn {select count(*) from key_data where id = $n and parent = $g and name_id = $name_id}] == 0} {
          return -code error "key \"$afterkey\" and $key does not belong to the same parent"
        }
      }


      if {[$db onecolumn {select count(*) from key_data where parent = $g}] == 1} {
        return ""
      }

      if {$n == [$db onecolumn {select after_id from key_data where id = $p}]} {
        # Same positions, dont change
        return ""
      }

      set setorder 0
      set last_id ""

      $db eval {begin immediate transaction}

      # First move, to set my follower to follow who i used to follow
      set next_after_id [$db onecolumn {select id from key_data where after_id = $p and name_id = $name_id and parent = $g}]
      if {$next_after_id != ""} {
        set curr_after_id [$db onecolumn {select after_id from key_data where id = $p}]
        if {$curr_after_id == 0} {
          $db eval {update key_data set after_id = $curr_after_id, key_order = 0 where id = $next_after_id}
        } else {
          $db eval {update key_data set after_id = $curr_after_id where id = $next_after_id}
        }
      } else {
        set last_id [$db onecolumn {select after_id from key_data where id = $p}]
      }

      # Second move, to set the follower of the one i m going to follow to follow me
      #   AND... set myself to follow the new one
      if {$n == 0} {
        set curr_order 0
        lassign [$db eval {select id,key_order from key_data where after_id = 0 and parent = $g and name_id = $name_id limit 1}] next_id next_order
        if {$next_order == 0} {
          lassign [$db eval {select id,key_order from key_data where after_id = $next_id and parent = $g}] next_next_id next_order
        } else {
          set next_next_id [$db onecolumn {select id from key_data where after_id = $next_id and parent = $g}]
        }
        if {$next_next_id == $p} {
          $db eval {update key_data set after_id = $p, key_order = id where id = $next_id}
          set last_id $next_id
        } else {
          set next_order [::sqlk::inmiddle $next_order $curr_order]
          if {$next_order == 0} {
            set setorder 1
          }
          $db eval {update key_data set after_id = $p, key_order = $next_order where id = $next_id}
        }
      } else {
        lassign [$db eval {select id,key_order from key_data where after_id = $n and name_id = $name_id and parent = $g}] prev_after_id curr_order
        set prev_order [$db onecolumn {select key_order from key_data where id = $n}]
        if {$prev_after_id != ""} {
          set curr_order [::sqlk::inmiddle $prev_order $curr_order]
          if {$curr_order == 0} {
            set setorder 1
          }
          $db eval {update key_data set after_id = $p where id = $prev_after_id}
        } else {
          set last_id $p
          set curr_order [$db onecolumn {select max(key_order)+0.0001 from key_data where parent = $g}]
        }
      }
      $db eval {update key_data set after_id = $n, key_order = $curr_order where id = $p}
      
      if {$last_id != ""} {
        if {$g == 0} {
          $db eval {update key_name set last_id = $last_id where id = $name_id}
        } else {
          $db eval {update key_data set last_id = $last_id where id = $g}
        }
      }

      $db eval {commit}

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

      $db eval {begin immediate transaction}

      # online sort
      set n 0
      set id 0
      set last_id 0
      set step [$db onecolumn {select max(id)/count(*) from key_data where parent = $parent and name_id = $name_id}]
      while {[set id [$db onecolumn {select id from key_data where parent = $parent and after_id = $id and name_id = $name_id}]] != ""} {
        incr n $step
        $db eval {update key_data set key_order = $n where id = $id}
        set last_id $id
      }

      if {$parent == 0} {
        $db eval {update key_name set last_id = $last_id where id = $name_id}
      } else {
        $db eval {update key_data set last_id = $last_id where id = $parent}
      }

      $db eval {commit}
    }
  }

  ##########
  #
  #
  #
  proc _krename {} {
    uplevel 1 {
      variable db
      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }
      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }
      if {[validkey $newname] || [string first "." $newname] != -1} {
        return -code error "Invalid new name \"$newname\""
      }

      set old_path $key
      set parts [split $key .]
      set parent_path [join [lrange $parts 0 end-1] .]
      if {$parent_path eq ""} {
        set new_path $newname
      } else {
        set new_path "$parent_path.$newname"
      }

      # Check if destination exists
      if {[keyid $name_id $new_path] ne ""} {
        return -code error "destination key \"$new_path\" already exists"
      }

      $db eval {begin immediate transaction}
      # Update the node name
      $db eval {update key_data set name = $newname where id = $p}
      
      # Update path for node and all descendants
      # Using SQLite substr and || for concatenation
      set old_path_len [string length $old_path]
      $db eval {
        update key_data 
        set path = $new_path || substr(path, $old_path_len + 1)
        where name_id = $name_id and (path = $old_path or path like $old_path || '.%')
      }
      $db eval {commit}
    }
  }

  ##########
  #
  #
  #
  proc _kmerge {} {
    uplevel 1 {
      variable db
      variable encrypt
      variable watches
      # Merge source subtree into target
      set key $src_key
      set data [kgetall $oldname $src_key]
      set src_prefix $src_key
      set target_prefix [expr {$target_key eq "" ? "" : $target_key}]

      $db eval {begin immediate transaction}
      try {
        dict for {p info} $data {
          # Calculate new path
          set relative_path [string range $p [string length $src_prefix] end]
          set new_path "${target_prefix}${relative_path}"
          # Strip leading dot if relative_path was the node itself and target was empty
          if {[string index $new_path 0] eq "."} { set new_path [string range $new_path 1 end] }
          
          set data [list $new_path [dict get $info val]]
          set istrict 0
          set name $newname
          ::sqlk::_kset_core
          dict for {ak av} [dict get $info attr] {
            set key $new_path
            set k $ak
            set v $av
            set name $newname
            ::sqlk::_attrset_core
          }
        }
      } on error {e} {
        $db eval {rollback}
        return -code error $e
      }
      $db eval {commit}
    }
  }

  # Helper for kmerge (non-transactional)
  proc _attrset_core {} {
    uplevel 1 {
      set name_id [nameid $name]
      set p [keyid $name_id $key]
      if {$encrypt} {
        set val [$db onecolumn {select attr from key_data where id = $p}]
        array set a [dodecdata $val]
      } else {
        array set a [$db onecolumn {select attr from key_data where id = $p}]
      }
      set a($k) $v
      set val [array get a]
      set x [expr {$encrypt ? [doencdata $val] : $val}]
      $db eval {update key_data set attr = $x where id = $p}
    }
  }

  ##########
  #
  #
  #
  proc _kbatch {} {
    uplevel 1 {
      variable db
      variable encrypt
      variable watches
      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }
      $db eval {begin immediate transaction}
      foreach {k v} $list {
        if {[validkey $k]} { continue }
        set p 0
        set oldval ""
        # For batch, we'll try to trigger watches but it may slow down.
        # Still better to have it consistent.
        foreach s [split $k .] {
          set ev [expr {$encrypt ? [doencdata $v] : $v}]
          set x [$db eval {select id, val from key_data where name_id = $name_id and parent = $p and name = $s}]
          if {$x eq ""} {
            $db eval {insert into key_data (name_id,parent,name,val,attr) values ($name_id,$p,$s,'','')}
            set p [$db last_insert_rowid]
          } else {
            lassign $x p oldval
            set oldval [dodecdata $oldval]
          }
        }
        $db eval {update key_data set val = $ev where id = $p}
        set key $k ; set _watch_op "set" ; set old $oldval ; set new $v
        ::sqlk::_trigger_watches
      }
      $db eval {commit}
    }
  }

  ##########
  #
  #
  #
  proc _kwatch {} {
    uplevel 1 {
      variable watches
      dict lappend watches $key $callback
    }
  }

  ##########
  #
  #
  #
  proc _trigger_watches {} {
    uplevel 1 {
      if {![info exists watches]} { return }
      # Trigger watches for this key and all its parent paths
      set path_parts [split $key .]
      for {set i [llength $path_parts]} {$i >= 0} {incr i -1} {
        set p [join [lrange $path_parts 0 [expr {$i-1}]] .]
        if {[dict exists $watches $p]} {
          foreach cb [dict get $watches $p] {
            try {
              uplevel #0 [list {*}$cb $name $key $_watch_op $old $new]
            } on error {} {
              # Ignore errors in callbacks
            }
          }
        }
      }
    }
  }

  ##########
  #
  #
  #
  proc _kclone {} {
    uplevel 1 {
      variable db
      if {[set src_id [nameid $oldname]] == ""} {
        return -code error "source var \"$oldname\" does not exists"
      }
      if {[nameid $newname] ne ""} {
        return -code error "destination var \"$newname\" already exists"
      }
      
      # Create new var
      varadd $newname
      set dst_id [nameid $newname]
      
      # Copy all key_data entries
      # We need to preserve hierarchical structure (parent pointers)
      # easiest is to walk and insert or do a massive SQL insert if possible
      # But parent IDs will change. Better use kgetall/kmerge logic or SQL join.
      
      $db eval {begin immediate transaction}
      # Map old IDs to new IDs
      set id_map [dict create 0 0]
      
      # Use key_sort view to ensure we process parents before children
      $db eval {select id, parent, name, val, attr, key_order, path from key_data where name_id = $src_id order by parent, id} {
        set new_parent [dict get $id_map $parent]
        $db eval {
          insert into key_data (name_id, parent, name, val, attr, key_order, path, ctime, utime)
          values ($dst_id, $new_parent, $name, $val, $attr, $key_order, $path, strftime('%s'), strftime('%s'))
        }
        dict set id_map $id [$db last_insert_rowid]
      }
      $db eval {commit}
    }
  }

  ##########
  #
  #
  #
  proc _kdiff {} {
    uplevel 1 {
      set data1 [kgetall $name $key1]
      set data2 [kgetall $name $key2]
      
      set diff [list]
      # Keys in 1 not in 2 or different values
      dict for {p info1} $data1 {
        set rel_p [string range $p [string length $key1] end]
        set p2 "${key2}${rel_p}"
        if {![dict exists $data2 $p2]} {
          lappend diff [list "-" $p]
        } else {
          set info2 [dict get $data2 $p2]
          if {[dict get $info1 val] ne [dict get $info2 val]} {
            lappend diff [list "M" $p [dict get $info1 val] [dict get $info2 val]]
          }
          if {[dict get $info1 attr] ne [dict get $info2 attr]} {
            lappend diff [list "A" $p [dict get $info1 attr] [dict get $info2 attr]]
          }
        }
      }
      # Keys in 2 not in 1
      dict for {p info2} $data2 {
        set rel_p [string range $p [string length $key2] end]
        set p1 "${key1}${rel_p}"
        if {![dict exists $data1 $p1]} {
          lappend diff [list "+" $p]
        }
      }
      return $diff
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
      } elseif {[llength $args] % 2 != 0} {
        return -code error "Argument list must be a valid, 2 elements list, got \"[llength $args]\""
      }

      if {[set p [keyid $name_id $key]] == ""} {
        return -code error "key name \"$key\" does not exists"
      }

      if {$encrypt} {
        array set a [dodecdata [$db onecolumn {select attr from key_data where id = $p}]]
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
        set x [doencdata [array get a]]
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
        array set a [dodecdata [$db onecolumn {select attr from key_data where id = $p}]]
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
        array set a [dodecdata [$db onecolumn {select attr from key_data where id = $p}]]
      } else {
        array set a [$db onecolumn {select attr from key_data where id = $p}]
      }

      if {[info exist a($attr)]} {
        unset a($attr)
        set x [array get a]
        if {$encrypt} {
          set x [doencdata $x]
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
  proc _kcount {} {
    uplevel 1 {
      variable db
      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }
      set p [keyid $name_id $key]
      if {$p == "" && $key ne ""} {
        return -code error "key name \"$key\" does not exists"
      }
      if {$key eq ""} {set p 0}
      return [$db onecolumn {select count(*) from key_data where name_id = $name_id and parent = $p}]
    }
  }

  ##########
  #
  #
  #
  proc _kfind {} {
    uplevel 1 {
      variable db
      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }
      # Convert Tcl wildcard (*, ?) to SQL (%, _)
      set sql_pattern [string map {* % ? _} $pattern]
      set res [list]
      $db eval {select path, val from key_data where name_id = $name_id and path like $sql_pattern} {
        lappend res $path [dodecdata $val]
      }
      return $res
    }
  }

  ##########
  #
  #
  #
  proc _kgetall {} {
    uplevel 1 {
      variable db
      if {[set name_id [nameid $name]] == ""} {
        return -code error "var name \"$name\" does not exists"
      }
      set res [dict create]
      set prefix ""
      if {$key ne ""} {
        set p [keyid $name_id $key]
        if {$p == ""} { return -code error "key name \"$key\" does not exists" }
        set prefix $key
        # Get the node itself
        $db eval {select path, val, attr from key_data where id = $p} {
          dict set res $path [dict create val [dodecdata $val] attr [dodecdata $attr]]
        }
        set sql_pattern "$key.%"
      } else {
        set sql_pattern "%"
      }

      $db eval {select path, val, attr from key_data where name_id = $name_id and path like $sql_pattern} {
        dict set res $path [dict create val [dodecdata $val] attr [dodecdata $attr]]
      }
      return $res
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

  ##########
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
        try {
          array set options $args
        } on error {e} {
          return -code error "wrong # args: should be \"serialize ?-format XML|TCL|TEXT? ?-indent 0|1? ?-key key?\""
        }
        if {[llength $args] % 2 != 0} {
          return -code error "wrong # args: should be \"serialize ?-format XML|TCL|TEXT? ?-indent 0|1? ?-key key?\""
        }
        while {[llength [array names options]] > 0} {
          if {[info exist options(-format)]} {
            if {$options(-format) ni "XML TCL TEXT JSON"} {
              return -code error "invalid format \"$options(-format)\": must be XML, TCL, TEXT or JSON"
            }
            set oformat $options(-format)
            unset options(-format)
          } elseif  {[info exist options(-indent)]} {
            if {$options(-indent) ni "0 1"} {
              return -code error "invalid indent value \"$options(-indent)\": must be 0 or 1"
            }
            set oindent $options(-indent)
            unset options(-indent)
          } elseif  {[info exist options(-key)]} {
            try {
              keys $name $options(-key)
            } on error {e} {
              return -code error $e
            }
            set okey $options(-key)
            unset options(-key)
          } else {
            return -code error "invalid arg \"[lindex [array names options] 0]\": must be -format or -indent"
          }
        }
      }

      # Check if name or procname exists
      if {$name ni [varlist]} {
        return -code error "var name does not exist \"$name\""
      }
      if {$oformat eq "JSON"} {
        set data [kgetall $name $okey]
        return [::sqlk::_dict2json $data $oindent]
      }
      
      # Set-based optimization: fetch everything in one query
      set prefix_pattern [expr {$okey eq "" ? "%" : "$okey.%"}]
      set subtree_data [dict create]
      set name_id [nameid $name]
      
      # Fetch the node itself if okey is not empty
      if {$okey ne ""} {
        $db eval {select path, val, attr from key_data where name_id = $name_id and path = $okey} {
          dict set subtree_data $path [dict create val [dodecdata $val] attr [dodecdata $attr]]
        }
      }
      
      # Fetch all descendants using key_sort view to maintain order
      $db eval {select path, val, attr from key_sort where name_id = $name_id and path like $prefix_pattern} {
        dict set subtree_data $path [dict create val [dodecdata $val] attr [dodecdata $attr]]
      }

      if {$oformat eq "XML"} {
        set res "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<sqlk>\n"
        append res [::sqlk::__serialize_xml_fast $subtree_data $oindent $okey 1]
        append res "</sqlk>\n"
        return $res
      } else {
        return [::sqlk::__serialize_fast $subtree_data $oformat $oindent $okey 1]
      }
    }
  }

  ##########
  # Optimized non-querying recursive serializers
  #
  proc __serialize_fast {subtree_data oformat oindent okey level} {
    set y [list]
    set okey_len [string length $okey]
    
    # Identify direct children from the pre-fetched subtree_data
    set children [list]
    dict for {p info} $subtree_data {
      if {$okey eq ""} {
        if {[string first "." $p] == -1} { lappend children $p }
      } else {
        if {[string range $p 0 $okey_len] eq "$okey."} {
          set sub [string range $p [expr {$okey_len + 1}] end]
          if {[string first "." $sub] == -1} { lappend children $sub }
        }
      }
    }
    
    # Note: subtree_data was fetched from key_sort, so order is preserved if we iterate carefully
    # But dict iteration isn't guaranteed. We'll use the pre-fetched list.
    
    foreach x $children {
      set nkey [expr {$okey eq "" ? $x : "$okey.$x"}]
      set info [dict get $subtree_data $nkey]
      
      set d [__serialize_fast $subtree_data $oformat $oindent $nkey [expr {$level + 1}]]
      
      if {$oformat == "TCL"} {
        if {$oindent == "1"} {
          set s [string repeat " " [expr {$level * 2}]]
          set dd ""
          foreach n $d { append dd $s[list $n]\n }
          if {[llength $d] > 0} {
            set d \n$dd[string range $s 0 end-2]
          } else { set d "" }
        }
        lappend y [list $x [dict get $info val] [dict get $info attr] $d]
      } elseif {$oformat == "TEXT"} {
        set a ""
        foreach {ak av} [dict get $info attr] { lappend a "$ak=\"$av\"" }
        append y "$nkey\n [join $a]\n [dict get $info val]\n$d"
      }
    }
    
    if {$oformat == "TCL" && $oindent == "1" && $level == "1"} {
      set dd ""
      foreach n $y { lappend dd [list $n] }
      return [join $dd \n]
    }
    if {$oformat == "TEXT"} { return [join $y ""] }
    return $y
  }

  proc __serialize_xml_fast {subtree_data oindent okey level} {
    set res ""
    set s [expr {$oindent ? [string repeat " " [expr {$level * 2}]] : ""}]
    set okey_len [string length $okey]
    
    set children [list]
    dict for {p info} $subtree_data {
      if {$okey eq ""} {
        if {[string first "." $p] == -1} { lappend children $p }
      } else {
        if {[string range $p 0 $okey_len] eq "$okey."} {
          set sub [string range $p [expr {$okey_len + 1}] end]
          if {[string first "." $sub] == -1} { lappend children $sub }
        }
      }
    }

    foreach x $children {
      set nkey [expr {$okey eq "" ? $x : "$okey.$x"}]
      set info [dict get $subtree_data $nkey]
      set val [dict get $info val]
      set attrs ""
      foreach {an av} [dict get $info attr] {
        append attrs " [::sqlk::_xml_escape $an]=\"[::sqlk::_xml_escape $av]\""
      }
      set child_xml [__serialize_xml_fast $subtree_data $oindent $nkey [expr {$level + 1}]]
      set tag [::sqlk::_xml_escape $x]
      if {$child_xml eq "" || $child_xml eq "\n"} {
        if {$val eq ""} {
          append res "$s<$tag$attrs/>"
        } else {
          append res "$s<$tag$attrs>[::sqlk::_xml_escape $val]</$tag>"
        }
      } else {
        append res "$s<$tag$attrs>"
        if {$val ne ""} { append res [::sqlk::_xml_escape $val] }
        append res [expr {$oindent ? "\n" : ""}]
        append res $child_xml
        append res "$s</$tag>"
      }
      append res [expr {$oindent ? "\n" : ""}]
    }
    return $res
  }

  proc _xml_escape {str} {
    return [string map {& &amp; < &lt; > &gt; \" &quot; ' &apos;} $str]
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
        try {
          array set options [lrange $args 0 end-1]
        } on error {e} {
          return -code error "wrong # args: should be \"parse ?-format XML|TCL|JSON? ?-into key? string\""
        }
        if {[llength $args] < 1} {
          return -code error "wrong # args: should be \"parse ?-format XML|TCL|JSON? ?-into key? string\""
        }
        while {[llength [array names options]] > 0} {
          if {[info exist options(-format)]} {
            if {$options(-format) ni "XML TCL JSON"} {
              return -code error "invalid format \"$options(-format)\": must be XML, TCL or JSON"
            }
            set oformat $options(-format)
            unset options(-format)
          } elseif  {[info exist options(-into)]} {
            set okey $options(-into)
            unset options(-into)
          } else {
            return -code error "invalid arg \"[lindex [array names options] 0]\": must be -format or -into"
          }
        }
      }

      # Check if name or procname exists
      if {$name ni [varlist]} {
        return -code error "var name \"$name\" does not exists"
      }

      if {$oformat eq "JSON"} {
        set decoded [::sqlk::_json2dict $data]
        dict for {p info} $decoded {
          set lkey [expr {$okey eq "" ? $p : "$okey.$p"}]
          kset $name $lkey [dict get $info val]
          dict for {ak av} [dict get $info attr] {
            attrset $name $lkey $ak $av
          }
        }
        return ""
      }
      if {$oformat eq "XML"} {
        package require xml
        set p [::xml::parser]
        set ::sqlk::_xml_state [dict create ns [namespace current] name $name into $okey stack [list $okey]]
        $p configure \
            -elementstartcommand [list ::sqlk::_xml_start_handler] \
            -elementendcommand [list ::sqlk::_xml_end_handler] \
            -characterdatacommand [list ::sqlk::_xml_data_handler]
        try {
          $p parse $data
        } on error {e} {
          $p free
          return -code error "XML Parse Error: $e"
        }
        $p free
        unset ::sqlk::_xml_state
        return ""
      }
      ::sqlk::__parse [namespace current] $name $data $oformat $okey
      return ""
    }
  }

  proc _xml_start_handler {elname attrList args} {
    variable _xml_state
    if {$elname eq "sqlk"} { return }
    
    if {[llength $attrList] % 2 != 0} { array set attrs {} } else { array set attrs $attrList }
    set parent [lindex [dict get $_xml_state stack] end]
    set fullkey [expr {$parent eq "" ? $elname : "$parent.$elname"}]
    
    set ns [dict get $_xml_state ns]
    set vname [dict get $_xml_state name]
    # Ensure key exists
    ${ns}::kset $vname $fullkey ""
    # Set attributes
    foreach {an av} [array get attrs] {
      ${ns}::attrset $vname $fullkey $an $av
    }
    dict lappend _xml_state stack $fullkey
    dict set _xml_state current_val ""
  }

  proc _xml_data_handler {data args} {
    variable _xml_state
    if {![dict exists $_xml_state current_val]} { return }
    dict append _xml_state current_val $data
  }
  
  # Note: Need an end handler to pop stack
  proc _xml_end_handler {elname args} {
    variable _xml_state
    if {$elname eq "sqlk"} { return }
    
    set fullkey [lindex [dict get $_xml_state stack] end]
    set val [string trim [dict get $_xml_state current_val]]
    if {$val ne ""} {
      set ns [dict get $_xml_state ns]
      set vname [dict get $_xml_state name]
      ${ns}::kset $vname $fullkey $val
    }
    
    set stack [dict get $_xml_state stack]
    dict set _xml_state stack [lrange $stack 0 end-1]
    dict set _xml_state current_val ""
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
  # AES key derivation — normalizes passphrase to 16 bytes (AES-128)
  #
  proc _derive_aes_key {passphrase} {
    set raw [encoding convertto utf-8 $passphrase]
    set len [string length $raw]
    if {$len == 16} {
      return $raw
    } elseif {$len > 16} {
      return [string range $raw 0 15]
    } else {
      return $raw[string repeat \x00 [expr {16 - $len}]]
    }
  }

  ##########
  # Deterministic IV derived from key (for searchable var names)
  #
  proc _fixed_iv {aes_key} {
    set iv ""
    for {set i 15} {$i >= 0} {incr i -1} {
      append iv [string index $aes_key $i]
    }
    return $iv
  }

  ##########
  # Random 16-byte IV (for values/attrs)
  #
  proc _random_iv {} {
    set iv ""
    for {set i 0} {$i < 16} {incr i} {
      append iv [binary format c [expr {int(rand() * 256)}]]
    }
    return $iv
  }

  ##########
  # Encrypt string → hex (deterministic, for var names)
  #
  proc _doenc {} {
    uplevel 1 {
      variable kenckey
      if {$kenckey eq ""} {
        return $data
      }
      set _aes_key [::sqlk::_derive_aes_key $kenckey]
      set _aes_iv  [::sqlk::_fixed_iv $_aes_key]
      set _ct [::aes::aes -mode cbc -dir encrypt -key $_aes_key -iv $_aes_iv $data]
      binary scan $_ct H* _hex
      return $_hex
    }
  }

  ##########
  # Decrypt hex → string (deterministic, for var names)
  #
  proc _dodec {} {
    uplevel 1 {
      variable kenckey
      if {$kenckey eq ""} {
        return $data
      }
      set _aes_key [::sqlk::_derive_aes_key $kenckey]
      set _aes_iv  [::sqlk::_fixed_iv $_aes_key]
      return [::aes::aes -mode cbc -dir decrypt -key $_aes_key -iv $_aes_iv [binary format H* $data]]
    }
  }

  ##########
  # Encrypt data → binary (random IV, for values/attrs)
  #
  proc _doencdata {} {
    uplevel 1 {
      variable kenckey
      if {$kenckey eq ""} {
        return $data
      }
      set _aes_key [::sqlk::_derive_aes_key $kenckey]
      set _aes_iv  [::sqlk::_random_iv]
      set _ct [::aes::aes -mode cbc -dir encrypt -key $_aes_key -iv $_aes_iv $data]
      return $_aes_iv$_ct
    }
  }

  ##########
  # Decrypt binary → data (random IV, for values/attrs)
  #
  proc _dodecdata {} {
    uplevel 1 {
      variable kenckey
      if {$kenckey eq ""} {
        return $data
      }
      set _aes_key [::sqlk::_derive_aes_key $kenckey]
      set _aes_iv  [string range $data 0 15]
      set _ct [string range $data 16 end]
      return [::aes::aes -mode cbc -dir decrypt -key $_aes_key -iv $_aes_iv $_ct]
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
        set ename [doenc "$name[string repeat "+" [expr {45 - [string length $name]}]]*****"]
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

      set p [$db onecolumn {select id from key_data where name_id = $name_id and path = $key}]
      return $p

    }
  }



  ##########
  #
  #
  #
  ##########
  # Minimal JSON serializer for Tcl dict/list
  #
  proc _dict2json {dict {indent 0} {level 0}} {
    set res ""
    set s [string repeat " " [expr {$level * 2}]]
    set s2 [string repeat " " [expr {($level + 1) * 2}]]
    
    set items [list]
    dict for {k v} $dict {
      set key [string map {\" \\\" \\ \\\\ \n \\n \r \\r \t \\t} $k]
      if {[string is list $v] && [llength $v] % 2 == 0 && [llength $v] > 0} {
        # Check if it's a dict-like or list-like
        # For our use case (sqlk), we know the structure
        set val [_dict2json $v $indent [expr {$level + 1}]]
      } else {
        set val "\"[string map {\" \\\" \\ \\\\ \n \\n \r \\r \t \\t} $v]\""
      }
      if {$indent} {
        lappend items "${s2}\"${key}\": ${val}"
      } else {
        lappend items "\"${key}\":${val}"
      }
    }
    
    if {$indent} {
      return "\x7b\n[join $items ",\n"]\n${s}\x7d"
    } else {
      return "\x7b[join $items ","]\x7d"
    }
  }

  ##########
  # Minimal JSON parser for Tcl (handles simple objects/strings)
  #
  proc _json2dict {json} {
    # This is a very basic parser for the specific format we export
    # It assumes the format is a flat object of paths
    set json [string trim $json]
    if {[string index $json 0] ne "\x7b"} { return [dict create] }
    set res [dict create]
    
    # Simple regex based tokenization for name/value pairs
    # Note: This doesn't handle all JSON escapes but works for our export
    set pairs [regexp -all -inline {"([^"]+)":\s*(\x7b.*?\x7d|"[^"]*")} $json]
    foreach {match key val} $pairs {
      if {[string index $val 0] eq "\x7b"} {
        # Recursive call for nested dict
        dict set res $key [_json2dict $val]
      } else {
        # String value
        dict set res $key [string range $val 1 end-1]
      }
    }
    return $res
  }

  ##########
  #
  #
  #
  proc validname {name} {
    return [expr {![regexp -- {^[[:alnum:]][[:alnum:]_-]{1,128}$} $name]}]
  }


  ##########
  #
  #
  #
  proc validkey {name} {
    return [expr {![regexp -- {^[[:alnum:]][[:alnum:]_.-]{0,39}$} $name]}]
  }

  ##########
  #
  #
  #
  proc inmiddle {a b} {
    # Integer
    set c [expr {int(($a + $b) / 2)}]
    if {$a > $b && $c > $b || $b > $a && $c > $a} {
      return $c
    }

    # Real
    set c [expr {($a + $b) / 2.0}]
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
        PRAGMA journal_mode = WAL;
        PRAGMA threads = 8;
        PRAGMA cache_size = -6000;
      }
      # Auto-migrate: upgrade index from (path) to (name_id, path)
      set idx_sql [$db onecolumn {SELECT sql FROM sqlite_master WHERE type='index' AND name='key_data_key0'}]
      if {$idx_sql ne "" && [string first "name_id" $idx_sql] == -1} {
        $db eval {DROP INDEX key_data_key0}
        $db eval {CREATE INDEX key_data_key0 ON key_data (name_id, path)}
      }
      # New resolution index
      $db eval {CREATE INDEX IF NOT EXISTS key_data_key3 ON key_data (name_id, parent, name)}
    } else {
      $db eval {
	PRAGMA auto_vacuum = 1;
  PRAGMA journal_mode = WAL;
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

  CREATE INDEX key_data_key0 on key_data (name_id, path);
  CREATE INDEX key_data_key1 on key_data (parent,after_id,key_order);
  CREATE INDEX key_data_key2 on key_data (parent,after_id);
  CREATE INDEX key_data_key3 on key_data (name_id, parent, name);

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
