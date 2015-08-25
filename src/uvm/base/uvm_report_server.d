//
//------------------------------------------------------------------------------
//   Copyright 2007-2010 Mentor Graphics Corporation
//   Copyright 2007-2011 Cadence Design Systems, Inc.
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2012-2014 Coverify Systems Technology
//   All Rights Reserved Worldwide
//
//   Licensed under the Apache License, Version 2.0 (the
//   "License"); you may not use this file except in
//   compliance with the License.  You may obtain a copy of
//   the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in
//   writing, software distributed under the License is
//   distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
//   CONDITIONS OF ANY KIND, either express or implied.  See
//   the License for the specific language governing
//   permissions and limitations under the License.
//------------------------------------------------------------------------------

module uvm.base.uvm_report_server;

//------------------------------------------------------------------------------
//
// CLASS: uvm_report_server
//
// uvm_report_server is a global server that processes all of the reports
// generated by an uvm_report_handler. None of its methods are intended to be
// called by normal testbench code, although in some circumstances the virtual
// methods process_report and/or compose_uvm_info may be overloaded in a
// subclass.
//
//------------------------------------------------------------------------------

import uvm.base.uvm_object;
import uvm.meta.mcd;
import uvm.meta.meta;
import uvm.base.uvm_globals;
import uvm.base.uvm_object_globals;
import uvm.base.uvm_report_handler;
import uvm.base.uvm_report_object;
import uvm.base.uvm_report_catcher;
import uvm.base.uvm_root;

import esdl.base.core: finish, getRootEntity;

class uvm_report_server: /*extends*/ uvm_object
{
  static class uvm_once
  {
    @uvm_private_sync private uvm_report_server _m_global_report_server;
    this() {
      synchronized(this) {
	_m_global_report_server = new uvm_report_server();
      }
    }
  }

  mixin uvm_once_sync;
  mixin uvm_sync;

  private int _max_quit_count;
  private int _quit_count;
  // SV implementation uses assoc array array here -- while D also supports assoc
  // arrays, I preferred using normal array for efficiency reasons
  private int[uvm_severity_type] _severity_count;

  // Variable: id_count
  //
  // An associative array holding the number of occurences
  // for each unique report ID.

  protected int[string] _id_count;

  @uvm_public_sync private bool _enable_report_id_count_summary = true;

  // Needed for callbacks
  public override string get_type_name() {
    return qualifiedTypeName!(typeof(this));
  }


  // Function: new
  //
  // Creates an instance of the class.

  public this() {
    synchronized(this) {
      set_name("uvm_report_server");
      set_max_quit_count(0);
      reset_quit_count();
      reset_severity_counts();
    }
  }

  // Moved to once
  // static protected uvm_report_server m_global_report_server = get_server();

  // Function: set_server
  //
  // Sets the global report server to use for reporting. The report
  // server is responsible for formatting messages.

  static public void set_server(uvm_report_server server) {
    synchronized(once) {
      import std.exception: enforce;
      enforce(server !is null);

      if(_m_global_report_server !is null) {
	server.set_max_quit_count(_m_global_report_server.get_max_quit_count());
	server.set_quit_count(_m_global_report_server.get_quit_count());
	_m_global_report_server.copy_severity_counts(server);
	_m_global_report_server.copy_id_counts(server);
      }

      _m_global_report_server = server;
    }
  }

  // Function: get_server
  //
  // Gets the global report server. The method will always return
  // a valid handle to a report server.

  static public uvm_report_server get_server() {
    synchronized(once) {
      if (_m_global_report_server is null)
	_m_global_report_server = new uvm_report_server();
      return _m_global_report_server;
    }
  }

  @uvm_public_sync private bool _m_max_quit_overridable = true;

  // Function: set_max_quit_count

  final public void set_max_quit_count(int count, bool overridable = true) {
    synchronized(this) {
      if (_m_max_quit_overridable is false) {
	import std.string: format;
	uvm_report_info("NOMAXQUITOVR",
			format("The max quit count setting of %0d is not "
			       "overridable to %0d due to a previous setting.",
			       _max_quit_count, count),	UVM_NONE);
	return;
      }
      _m_max_quit_overridable = overridable;
      _max_quit_count = count < 0 ? 0 : count;
    }
  }

  // Function: get_max_quit_count
  //
  // Get or set the maximum number of COUNT actions that can be tolerated
  // before an UVM_EXIT action is taken. The default is 0, which specifies
  // no maximum.

  final public int get_max_quit_count() {
    synchronized(this) {
      return _max_quit_count;
    }
  }


  // Function: set_quit_count

  final public void set_quit_count(int count) {
    synchronized(this) {
      this._quit_count = count < 0 ? 0 : count;
    }
  }

  // Function: get_quit_count

  final public int get_quit_count() {
    synchronized(this) {
      return _quit_count;
    }
  }

  // Function: incr_quit_count

  final public void incr_quit_count() {
    synchronized(this) {
      _quit_count++;
    }
  }

  // Function: reset_quit_count
  //
  // Set, get, increment, or reset to 0 the quit count, i.e., the number of
  // COUNT actions issued.

  final public void reset_quit_count() {
    synchronized(this) {
      _quit_count = 0;
    }
  }

  // Function: is_quit_count_reached
  //
  // If is_quit_count_reached returns 1, then the quit counter has reached
  // the maximum.

  final public bool is_quit_count_reached() {
    synchronized(this) {
      return (_quit_count >= _max_quit_count);
    }
  }


  // Function: set_severity_count

  final public void set_severity_count(uvm_severity_type severity, int count) {
    synchronized(this) {
      _severity_count[severity] = count < 0 ? 0 : count;
    }
  }

  // Function: get_severity_count

  final public int get_severity_count(uvm_severity_type severity) {
    synchronized(this) {
      return _severity_count.get(severity, 0);
    }
  }

  // Function: incr_severity_count

  final public void incr_severity_count(uvm_severity_type severity) {
    synchronized(this) {
      _severity_count[severity]++;
    }
  }

  // Function: reset_severity_counts
  //
  // Set, get, or increment the counter for the given severity, or reset
  // all severity counters to 0.

  final public void reset_severity_counts() {
    synchronized(this) {
      foreach (ref sevcou; _severity_count) {
	sevcou = 0;
      }
    }
  }


  // Function: set_id_count

  final public void set_id_count(string id, int count) {
    synchronized(this) {
      _id_count[id] = count < 0 ? 0 : count;
    }
  }

  // Function: get_id_count

  final public int get_id_count(string id) {
    synchronized(this) {
      if(id in _id_count) return _id_count[id];
      return 0;
    }
  }

  // Function: incr_id_count
  //
  // Set, get, or increment the counter for reports with the given id.

  final public void incr_id_count(string id) {
    synchronized(this) {
      if(id in _id_count) _id_count[id]++;
      else _id_count[id] = 1;
    }
  }


  // f_display
  //
  // This method sends string severity to the command line if file is 0 and to
  // the file(s) specified by file if it is not 0.

  static public void f_display(UVM_FILE file, string str) {
    if (file is 0) vdisplay("%s", str);
    else vfdisplay(file, "%s", str);
  }


  // Function- report
  //
  //

  public void report(uvm_severity_type severity,
		     string name,
		     string id,
		     string message,
		     int verbosity_level,
		     string filename,
		     size_t line,
		     uvm_report_object client
		     ) {
    synchronized(this) {
      bool report_ok;

      uvm_report_handler rh = client.get_report_handler();

      // filter based on verbosity level

      if(!client.uvm_report_enabled(verbosity_level, severity, id)) {
	return;
      }

      // determine file to send report and actions to execute

      uvm_action a = rh.get_action(severity, id);
      if(a is UVM_NO_ACTION ) return;

      UVM_FILE f = rh.get_file_handle(severity, id);

      // The hooks can do additional filtering.  If the hook function
      // return 1 then continue processing the report.  If the hook
      // returns 0 then skip processing the report.

      if(a & UVM_CALL_HOOK) {
	report_ok = rh.run_hooks(client, severity, id,
				 message, verbosity_level, filename, line);
      }
      else {
	report_ok = true;
      }

      if(report_ok) {
	report_ok =
	  uvm_report_catcher.process_all_report_catchers(this, client,
							 severity, name,
							 id, message,
							 verbosity_level,
							 a, filename, line);
      }

      if(report_ok) {
	string m = compose_message(severity, name, id, message, filename, line);
	process_report(severity, name, id, message, a, f, filename,
		       line, m, verbosity_level, client);
      }

    }
  }



  // Function: process_report
  //
  // Calls <compose_message> to construct the actual message to be
  // output. It then takes the appropriate action according to the value of
  // action and file.
  //
  // This method can be overloaded by expert users to customize the way the
  // reporting system processes reports and the actions enabled for them.

  public void process_report(uvm_severity_type severity,
			     string name,
			     string id,
			     string message,
			     uvm_action action,
			     UVM_FILE file,
			     string filename,
			     size_t line,
			     string composed_message,
			     int verbosity_level,
			     uvm_report_object client
			     ) {
    synchronized(this) {
      // update counts
      incr_severity_count(severity);
      incr_id_count(id);

      if(action & UVM_DISPLAY) {
	vdisplay("%s", composed_message);
      }

      // if log is set we need to send to the file but not resend to the
      // display. So, we need to mask off stdout for an mcd or we need
      // to ignore the stdout file handle for a file handle.
      if(action & UVM_LOG) {
	if( (file is 0) || (file !is STDOUT) ) { //ignore stdout handle
	  UVM_FILE tmp_file = file;
	  // if( (file&32'h8000_0000) is 0) //is an mcd so mask off stdout
	  // begin
	  tmp_file = file & 0xFFFFFFFFFFFFFFFE;
	  // end
	  f_display(tmp_file,composed_message);
	}
      }

      if(action & UVM_EXIT) client.die();

      if(action & UVM_COUNT) {
	if(get_max_quit_count() !is 0) {
	  incr_quit_count();
	  if(is_quit_count_reached()) {
	    client.die();
	  }
	}
      }

      // $stop
      if (action & UVM_STOP) {
	debug(FINISH) {
	  import std.stdio;
	  writeln("uvm_report_server.process_report");
	}
	finish(); // $stop;
      }
    }
  }



  // Function: compose_message
  //
  // Constructs the actual string sent to the file or command line
  // from the severity, component name, report id, and the message itself.
  //
  // Expert users can overload this method to customize report formatting.

  public string compose_message(uvm_severity severity,
				string name,
				string id,
				string message,
				string filename,
				size_t line
				) {
    synchronized(this) {
      string line_str;
      import std.string: format;
      import std.conv: to;

      string retval;

      uvm_severity_type sv = cast(uvm_severity_type) severity;
      string time_str = format("%s", getRootEntity().getSimTime());

      if (name == "" && filename == "")
	retval = to!string(sv) ~ " @ " ~ time_str ~ " [" ~ id ~ "] " ~ message;
      if (name != "" && filename == "")
	retval = to!string(sv) ~ " @ " ~ time_str ~ ": " ~ name ~
	  " [" ~ id ~ "] " ~ message;
      if (name == "" && filename != "") {
	line_str = format("%0d", line);
	retval = to!string(sv) ~ " " ~filename ~ "(" ~ line_str ~ ")" ~
	  " @ " ~ time_str ~ " [" ~ id ~ "] " ~ message;
      }
      if (name != "" && filename != "") {
	line_str = format("%0d", line);
	retval = to!string(sv) ~ " " ~ filename ~ "(" ~ line_str ~ ")" ~
	  " @ " ~ time_str ~ ": " ~ name ~ " [" ~ id ~ "] " ~ message;
      }
      return retval;
    }
  }


  // Function: summarize
  //
  // See <uvm_report_object::report_summarize> method.

  public void summarize(UVM_FILE file=0) {
    synchronized(this) {
      import std.string: format;
      uvm_report_catcher.summarize_report_catcher(file);
      f_display(file, "");
      f_display(file, "--- UVM Report Summary ---");
      f_display(file, "");

      if(_max_quit_count !is 0) {
	if(_quit_count >= _max_quit_count) f_display(file, "Quit count reached!");
	f_display(file, format("Quit count : %5d of %5d",
			       _quit_count, _max_quit_count));
      }

      f_display(file, "** Report counts by severity");
      foreach(key, val; _severity_count) {
	f_display(file, format("%s :%5d", key, val));
      }

      if (enable_report_id_count_summary) {
	f_display(file, "** Report counts by id");
	foreach(id; _id_count.keys) {
	  int cnt;
	  cnt = _id_count[id];
	  f_display(file, format("[%s] %5d", id, cnt));
	}

      }

    }
  }


  // Function: dump_server_state
  //
  // Dumps server state information.

  final public void dump_server_state() {
    synchronized(this) {
      import std.string: format;

      f_display(0, "report server state");
      f_display(0, "");
      f_display(0, "+-------------+");
      f_display(0, "|   counts    |");
      f_display(0, "+-------------+");
      f_display(0, "");

      f_display(0, format("max quit count = %5d", _max_quit_count));
      f_display(0, format("quit count = %5d", _quit_count));

      for(auto _sev = uvm_severity_type.min; _sev <= uvm_severity_type.max;
	  ++_sev) {
	int cnt;
	cnt = _severity_count[_sev];
	f_display(0, format("%s :%5d", _sev, cnt));
      }

      foreach (id; _id_count.keys) {
	int cnt = _id_count[id];
	f_display(0, format("%s :%5d", id, cnt));
      }
    }
  }

  // Function- copy_severity_counts
  //
  // Internal method.

  final private void copy_severity_counts(uvm_report_server dst) {
    synchronized(this) {
      foreach(i, cou; _severity_count) {
	dst.set_severity_count(i, _severity_count[i]);
      }
    }
  }


  // Function- copy_severity_counts
  //
  // Internal method.

  final private void copy_id_counts(uvm_report_server dst) {
    synchronized(this) {
      foreach(id; _id_count.keys) {
	dst.set_id_count(id, _id_count[id]);
      }
    }
  }

}



//----------------------------------------------------------------------
// CLASS- uvm_report_global_server
//
// Singleton object that maintains a single global report server
//----------------------------------------------------------------------
final class uvm_report_global_server {
  public this() {
    synchronized(this) {
      get_server();
    }
  }

  // Function: get_server
  //
  // Returns a handle to the central report server.

  static public uvm_report_server get_server() {
    return uvm_report_server.get_server();
  }

  // Function- set_server (deprecated)
  //
  //

  static public void set_server(uvm_report_server server) {
    uvm_report_server.set_server(server);
  }

}
