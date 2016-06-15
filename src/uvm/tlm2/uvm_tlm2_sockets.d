//----------------------------------------------------------------------
//   Copyright 2010 Mentor Graphics Corporation
//   Copyright 2010 Synopsys, Inc.
//   Copyright 2016 Coverify Systems Technology
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
//----------------------------------------------------------------------

//----------------------------------------------------------------------
// Title: TLM Sockets
//
// Each uvm_tlm_*_socket class is derived from a corresponding
// uvm_tlm_*_socket_base class.  The base class contains most of the
// implementation of the class, The derived classes (in this file)
// contain the connection semantics.
//
// Sockets come in several flavors: Each socket is either an initiator or a 
// target, a pass-through or a terminator. Further, any particular socket 
// implements either the blocking interfaces or the nonblocking interfaces. 
// Terminator sockets are used on initiators and targets as well as 
// interconnect components as shown in the figure above. Pass-through
//  sockets are used to enable connections to cross hierarchical boundaries.
//
// There are eight socket types: the cross of blocking and nonblocking,
// pass-through and termination, target and initiator
//
// Sockets are specified based on what they are (IS-A)
// and what they contains (HAS-A).
// IS-A and HAS-A are types of object relationships. 
// IS-A refers to the inheritance relationship and
//  HAS-A refers to the ownership relationship. 
// For example if you say D is a B that means that D is derived from base B. 
// If you say object A HAS-A B that means that B is a member of A.
//----------------------------------------------------------------------

module uvm.tlm2.uvm_tlm2_sockets;


//----------------------------------------------------------------------
// Class: uvm_tlm_b_initiator_socket
//
// IS-A forward port; has no backward path except via the payload
// contents
//----------------------------------------------------------------------

class uvm_tlm_b_initiator_socket(T=uvm_tlm_generic_payload)
  : uvm_tlm_b_initiator_socket_base!T
  {

    // Function: new
    // Construct a new instance of this socket
    this(string name, uvm_component parent) {
      super(name, parent);
    }
   
   // Function: Connect
   //
   // Connect this socket to the specified <uvm_tlm_b_target_socket>
    override void connect(this_type provider) {

      super.connect(provider);

      if(cast(uvm_tlm_b_passthrough_initiator_socket_base!(T)) provider  ||
	 cast(uvm_tlm_b_passthrough_target_socket_base!(T)) provider     ||
	 cast(uvm_tlm_b_target_socket_base!(T)) provider) {
	return;
      }

      uvm_component c = get_comp();
      uvm_error_context(get_type_name(),
			"type mismatch in connect -- connection cannot " ~
			"be completed", c);
    }
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_b_target_socket
//
// IS-A forward imp; has no backward path except via the payload
// contents.
//
// The component instantiating this socket must implement
// a b_transport() method with the following signature
//
//|   task b_transport(T t, uvm_tlm_time delay);
//
//----------------------------------------------------------------------

class uvm_tlm_b_target_socket(IMP=int,
			      T=uvm_tlm_generic_payload)
  : uvm_tlm_b_target_socket_base!T
  {

    IMP m_imp;

    // Function: new
    // Construct a new instance of this socket
    // ~imp~ is a reference to the class implementing the
    // b_transport() method.
    // If not specified, it is assume to be the same as ~parent~.
    this (string name, uvm_component parent, IMP imp = null) {
      synchronized(this) {
	super(name, parent);
	if (imp is null) {
	  m_imp = cast(IMP) parent;
	}
	else {
	  m_imp = imp;
	}
	if (m_imp is null) {
	  uvm_error("UVM/TLM2/NOIMP", "b_target socket " ~ name ~
		    " has no implementation");
	}
      }
    }

    // Function: Connect
    //
    // Connect this socket to the specified <uvm_tlm_b_initiator_socket>
    void connect(this_type provider) {

      super.connect(provider);

      uvm_component c = get_comp();
      uvm_error_context(get_type_name(),
			"You cannot call connect() on a target "
			~ "termination socket", c);
    }

    // `UVM_TLM_B_TRANSPORT_IMP(m_imp, T, t, delay)
    // task
    void b_transport(T t, uvm_tlm_time delay) {
      if (delay is null) {
	uvm_error("UVM/TLM/NULLDELAY", get_full_name(),
		  ".b_transport() called with 'null' delay");
	return;
      }
      this.m_imp.b_transport(t, delay);
    }
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_nb_initiator_socket
//
// IS-A forward port; HAS-A backward imp
//
// The component instantiating this socket must implement
// a nb_transport_bw() method with the following signature
//
//|   function uvm_tlm_sync_e nb_transport_bw(T t, ref P p, input uvm_tlm_time delay);
//
//----------------------------------------------------------------------

class uvm_tlm_nb_initiator_socket(IMP=int,
				  T=uvm_tlm_generic_payload,
				  P=uvm_tlm_phase_e)
  : uvm_tlm_nb_initiator_socket_base!(T,P)
  {

    uvm_tlm_nb_transport_bw_imp!(T,P,IMP) bw_imp;

    // Function: new
    // Construct a new instance of this socket
    // ~imp~ is a reference to the class implementing the
    // nb_transport_bw() method.
    // If not specified, it is assume to be the same as ~parent~.
    this(string name, uvm_component parent, IMP imp = null) {
      synchronized(this) {
	super (name, parent);
	if (imp is null) imp = cast(IMP) parent;
	if (imp is null) {
	  uvm_error("UVM/TLM2/NOIMP", "nb_initiator socket " ~ name ~
		    " has no implementation");
	}
	bw_imp = new uvm_tlm_nb_transport_bw_imp!(T,P,IMP)("bw_imp", imp);
      }
    }

    // Function: Connect
    //
    // Connect this socket to the specified <uvm_tlm_nb_target_socket>
    void connect(this_type provider) {

      super.connect(provider);

      if(cast(uvm_tlm_nb_passthrough_initiator_socket_base!(T,P)) provider) {
	initiator_pt_socket.bw_export.connect(bw_imp);
	return;
      }
      if(cast(uvm_tlm_nb_passthrough_target_socket_base!(T,P)) provider) {
	target_pt_socket.bw_port.connect(bw_imp);
	return;
      }

      if(cast(uvm_tlm_nb_target_socket_base!(T,P)) provider) {
	target_socket.bw_port.connect(bw_imp);
	return;
      }
    
      uvm_component c = get_comp();
      uvm_error_context(get_type_name(),
			"type mismatch in connect -- connection cannot " ~
			"be completed", c);
    }
  }


//----------------------------------------------------------------------
// Class: uvm_tlm_nb_target_socket
//
// IS-A forward imp; HAS-A backward port
//
// The component instantiating this socket must implement
// a nb_transport_fw() method with the following signature
//
//|   function uvm_tlm_sync_e nb_transport_fw(T t, ref P p, input uvm_tlm_time delay);
//
//----------------------------------------------------------------------

class uvm_tlm_nb_target_socket(IMP=int,
			       T=uvm_tlm_generic_payload,
			       P=uvm_tlm_phase_e)
  : uvm_tlm_nb_target_socket_base!(T,P)
  {

    IMP m_imp;

    // Function: new
    // Construct a new instance of this socket
    // ~imp~ is a reference to the class implementing the
    // nb_transport_fw() method.
    // If not specified, it is assume to be the same as ~parent~.
    this(string name, uvm_component parent, IMP imp = null) {
      synchronized(this) {
	super (name, parent);
	if (imp is null) {
	  m_imp = cast(IMP) parent;
	}
	else {
	  m_imp = imp;
	}
	bw_port = new uvm_tlm_nb_transport_bw_port!(T,P)("bw_port", get_comp());
	if (m_imp is null) {
	  uvm_error("UVM/TLM2/NOIMP", "nb_target socket " ~ name ~
		    " has no implementation");
	}
      }
    }

    // Function: connect
    //
    // Connect this socket to the specified <uvm_tlm_nb_initiator_socket>
    void connect(this_type provider) {

      super.connect(provider);

      uvm_component c = get_comp();
      uvm_error_context(get_type_name(),
			"You cannot call connect() on a target " ~
			"termination socket", c);
    }

    // `UVM_TLM_NB_TRANSPORT_FW_IMP(m_imp, T, P, t, p, delay)
    uvm_tlm_sync_e nb_transport_fw(T t, ref P p, in uvm_tlm_time delay) {
      if (delay is null) {
	uvm_error("UVM/TLM/NULLDELAY", get_full_name() ~
		  ".nb_transport_fw() called with 'null' delay");
	return UVM_TLM_COMPLETED;
      }
      return m_imp.nb_transport_fw(t, p, delay);
    }
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_b_passthrough_initiator_socket
//
// IS-A forward port;
//----------------------------------------------------------------------

class uvm_tlm_b_passthrough_initiator_socket(T=uvm_tlm_generic_payload)
  : uvm_tlm_b_passthrough_initiator_socket_base!T
  {

    this(string name, uvm_component parent) {
      super(name, parent);
    }

    // Function : connect
    //
    // Connect this socket to the specified <uvm_tlm_b_target_socket>
    void connect(this_type provider) {


      super.connect(provider);

      if(cast(uvm_tlm_b_passthrough_initiator_socket_base!(T)) provider ||
	 cast(uvm_tlm_b_passthrough_target_socket_base!(T)) provider    ||
	 cast(uvm_tlm_b_target_socket_base!(T)) provider) {
	return;
      }

      uvm_component c = get_comp();
      uvm_error_context(get_type_name(), "type mismatch in connect -- connection cannot be completed", c);
    }
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_b_passthrough_target_socket
//
// IS-A forward export;
//----------------------------------------------------------------------
class uvm_tlm_b_passthrough_target_socket(T=uvm_tlm_generic_payload)
  : uvm_tlm_b_passthrough_target_socket_base!(T)
  {

    this(string name, uvm_component parent) {
      super(name, parent);
    }
   
    // Function : connect
    //
    // Connect this socket to the specified <uvm_tlm_b_initiator_socket>
    void connect(this_type provider) {

      super.connect(provider);

      if(cast(uvm_tlm_b_passthrough_target_socket_base!(T)) provider    ||
	 cast(uvm_tlm_b_target_socket_base!(T)) provider) {
	return;
      }

      uvm_component c = get_comp();
      uvm_error_context(get_type_name(),
			"type mismatch in connect -- connection cannot"
			~ " be completed", c);
    }
  }



//----------------------------------------------------------------------
// Class: uvm_tlm_nb_passthrough_initiator_socket
//
// IS-A forward port; HAS-A backward export
//----------------------------------------------------------------------

class uvm_tlm_nb_passthrough_initiator_socket(T=uvm_tlm_generic_payload,
					      P=uvm_tlm_phase_e)
  : uvm_tlm_nb_passthrough_initiator_socket_base!(T,P)
  {

    this(string name, uvm_component parent) {
      super(name, parent);
    }

   // Function : connect
   //
   // Connect this socket to the specified <uvm_tlm_nb_target_socket>
    void connect(this_type provider) {


      super.connect(provider);

      if(cast(uvm_tlm_nb_passthrough_initiator_socket_base!(T,P)) provider) {
	bw_export.connect(initiator_pt_socket.bw_export);
	return;
      }

      if(cast(uvm_tlm_nb_passthrough_target_socket_base!(T,P)) provider) {
	target_pt_socket.bw_port.connect(bw_export);
	return;
      }

      if(cast(uvm_tlm_nb_target_socket_base!(T,P)) provider) {
	target_socket.bw_port.connect(bw_export);
	return;
      }

      uvm_component c = get_comp();
      uvm_error_context(get_type_name(),
			"type mismatch in connect -- connection " ~
			"cannot be completed", c);

    }
  }

//----------------------------------------------------------------------
// Class: uvm_tlm_nb_passthrough_target_socket
//
// IS-A forward export; HAS-A backward port
//----------------------------------------------------------------------

class uvm_tlm_nb_passthrough_target_socket(T=uvm_tlm_generic_payload,
                                           P=uvm_tlm_phase_e)
  : uvm_tlm_nb_passthrough_target_socket_base!(T,P)
  {

    this(string name, uvm_component parent) {
      super(name, parent);
    }

   // Function: connect
   //
   // Connect this socket to the specified <uvm_tlm_nb_initiator_socket>
    void connect(this_type provider) {

      super.connect(provider);

      if(cast(uvm_tlm_nb_passthrough_target_socket_base!(T,P)) provider) {
	target_pt_socket.bw_port.connect(bw_port);
	return;
      }

      if(cast(uvm_tlm_nb_target_socket_base!(T,P)) provider) {
	target_socket.bw_port.connect(bw_port);
	return;
      }

      uvm_component c = get_comp();
      uvm_error_context(get_type_name(),
			"type mismatch in connect -- connection cannot " ~
			"be completed", c);
    }
  }

//----------------------------------------------------------------------
