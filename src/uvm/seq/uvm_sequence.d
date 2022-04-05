//----------------------------------------------------------------------
// Copyright 2012-2021 Coverify Systems Technology
// Copyright 2010-2012 AMD
// Copyright 2007-2018 Cadence Design Systems, Inc.
// Copyright 2013 Cisco Systems, Inc.
// Copyright 2007-2014 Mentor Graphics Corporation
// Copyright 2014-2020 NVIDIA Corporation
// Copyright 2014 Semifore
// Copyright 2010-2014 Synopsys, Inc.
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
module uvm.seq.uvm_sequence;

import uvm.meta.misc;
import uvm.base.uvm_printer;
import uvm.base.uvm_object_globals;

import uvm.seq.uvm_sequence_item;
import uvm.seq.uvm_sequence_base;
import uvm.seq.uvm_sequencer_param_base;

import std.string: format;

import esdl.rand.misc: rand;

//------------------------------------------------------------------------------
//
// CLASS -- NODOCS -- uvm_sequence #(REQ,RSP)
//
// The uvm_sequence class provides the interfaces necessary in order to create
// streams of sequence items and/or other sequences.
//
//------------------------------------------------------------------------------

// @uvm-ieee 1800.2-2020 auto 14.3.1
abstract class uvm_sequence (REQ_T = uvm_sequence_item, RSP_T = REQ_T):
  uvm_sequence_base, rand.barrier
{
  mixin (uvm_sync_string);

  alias sequencer_t = uvm_sequencer_param_base!(REQ_T, RSP_T);
  alias REQ = REQ_T;
  alias RSP = RSP_T;
  

  version(UVM_NO_RAND) {
    @uvm_public_sync
      private sequencer_t        _param_sequencer;
  }
  else {
    @uvm_public_sync
      private sequencer_t        _param_sequencer;
  }

  // Variable -- NODOCS -- req
  //
  // The sequence contains a field of the request type called req.  The user
  // can use this field, if desired, or create another field to use.  The
  // default ~do_print~ will print this field.
  version(UVM_NO_RAND) {
    protected REQ_T                req;
  }
  else {
    protected REQ_T              req;
  }


  // Variable -- NODOCS -- rsp
  //
  // The sequence contains a field of the response type called rsp.  The user
  // can use this field, if desired, or create another field to use.   The
  // default ~do_print~ will print this field.
  version(UVM_NO_RAND) {
    protected RSP_T                rsp;
  }
  else {
    protected RSP_T              rsp;
  }    

  // Function -- NODOCS -- new
  //
  // Creates and initializes a new sequence object.

  // @uvm-ieee 1800.2-2020 auto 14.3.3.1
  this(string name = "uvm_sequence") {
    super(name);
  }

  // Function -- NODOCS -- send_request
  //
  // This method will send the request item to the sequencer, which will forward
  // it to the driver.  If the rerandomize bit is set, the item will be
  // randomized before being sent to the driver. The send_request function may
  // only be called after <uvm_sequence_base::wait_for_grant> returns.

  final override void send_request(uvm_sequence_item request,
				   bool rerandomize=false) {
    synchronized (this) {
      if (m_sequencer is null) {
	uvm_report_fatal("SSENDREQ", "Null m_sequencer reference", uvm_verbosity.UVM_NONE);
      }

      REQ_T m_request = cast (REQ_T) request;
      if (request is null) {
	uvm_report_fatal("SSENDREQ", "Failure to cast uvm_sequence_item to request", uvm_verbosity.UVM_NONE);
      }
      m_sequencer.send_request(this, m_request, rerandomize);
    }
  }


  // Function -- NODOCS -- get_current_item
  //
  // Returns the request item currently being executed by the sequencer. If the
  // sequencer is not currently executing an item, this method will return ~null~.
  //
  // The sequencer is executing an item from the time that get_next_item or peek
  // is called until the time that get or item_done is called.
  //
  // Note that a driver that only calls get will never show a current item,
  // since the item is completed at the same time as it is requested.

  // @uvm-ieee 1800.2-2020 auto 14.3.3.2
  final REQ_T get_current_item() {
    synchronized (this) {
      _param_sequencer = cast (sequencer_t) m_sequencer;
      if (_param_sequencer is null) {
	uvm_report_fatal("SGTCURR", "Failure to cast m_sequencer to the" ~
			 " parameterized sequencer", uvm_verbosity.UVM_NONE);
      }
      return (_param_sequencer.get_current_item());
    }
  }

  // Task -- NODOCS -- get_response
  //
  // By default, sequences must retrieve responses by calling get_response.
  // If no transaction_id is specified, this task will return the next response
  // sent to this sequence.  If no response is available in the response queue,
  // the method will block until a response is received.
  //
  // If a transaction_id is parameter is specified, the task will block until
  // a response with that transaction_id is received in the response queue.
  //
  // The default size of the response queue is 8.  The get_response method must
  // be called soon enough to avoid an overflow of the response queue to prevent
  // responses from being dropped.
  //
  // If a response is dropped in the response queue, an error will be reported
  // unless the error reporting is disabled via
  // set_response_queue_error_report_enabled.

  // task
  // @uvm-ieee 1800.2-2020 auto 14.3.3.3
  void get_response(out RSP_T response, int transaction_id=-1) {
    uvm_sequence_item rsp;
    get_base_response(rsp, transaction_id);
    response = cast (RSP_T) rsp;
  }



  // Function- put_response
  //
  // Internal method.

  override void put_response(uvm_sequence_item response_item) {
    if (response_item is null) {
      uvm_report_fatal("PUTRSP", "Received a null in response",
		       uvm_verbosity.UVM_NONE);
    }
    RSP_T response = cast (RSP_T) response_item;
    if (response is null) {
      uvm_report_fatal("PUTRSP",
		       format("Failure to cast response to type %s in put_response",
			      RSP_T.stringof), uvm_verbosity.UVM_NONE);
    }
    put_base_response(response_item);
  }


  // Function- do_print
  //
  override void do_print (uvm_printer printer) {
    super.do_print(printer);
    printer.print_object("req", req);
    printer.print_object("rsp", rsp);
  }

}
